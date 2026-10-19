extends SceneTree
## Graphics quality: presets only change how things look; AUTO picks from measured frame times
## (medians, never one slow frame) and never changes anything silently after the first launch;
## the low-frame-rate offer appears only after sustained trouble, once, and only when there is
## a lower preset to go to.

var _failures: int = 0
var _gs: Node

## The only GameSettings fields a preset may write: purely visual.
const VISUAL_FIELDS := ["floating_particles", "bg_motion", "afterimages", "pixel_dither", "scanlines", "glow_intensity", "parallax_intensity"]


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_gs = root.get_node("GameSettings")
	_gs.reset_settings()
	_rules()
	_presets()
	await _auto_detection()
	await _struggle_offer()
	await _page_and_toast()
	print("[test_quality] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await process_frame


# ── pure rules ──────────────────────────────────────────────────────

func _rules() -> void:
	var P := GraphicsQuality.Preset
	_check("a smooth 60 fps machine gets HIGH", GraphicsQuality.pick_for(16.7, "NVIDIA GeForce RTX 4060", false) == P.HIGH)
	_check("a 45 fps machine gets MEDIUM", GraphicsQuality.pick_for(22.0, "Intel UHD", false) == P.MEDIUM)
	_check("a 25 fps machine gets LOW", GraphicsQuality.pick_for(40.0, "Old GPU", false) == P.LOW)
	_check("software rendering is always LOW, however fast it looks", GraphicsQuality.pick_for(10.0, "llvmpipe (LLVM 15)", false) == P.LOW
		and GraphicsQuality.pick_for(10.0, "Google SwiftShader", true) == P.LOW)
	_check("the web never starts above MEDIUM", GraphicsQuality.pick_for(16.0, "ANGLE (NVIDIA)", true) == P.MEDIUM)
	_check("lower() steps HIGH -> MEDIUM -> LOW -> LOW", GraphicsQuality.lower(P.HIGH) == P.MEDIUM
		and GraphicsQuality.lower(P.MEDIUM) == P.LOW and GraphicsQuality.lower(P.LOW) == P.LOW)
	var vals := [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 90.0]
	_check("the median ignores one huge spike", is_equal_approx(GraphicsQuality.percentile(vals, 0.5), 14.0))
	_check("p95 does catch sustained trouble", GraphicsQuality.percentile([40.0, 40.0, 40.0, 40.0, 40.0, 10.0], 0.95) > 30.0)


func _presets() -> void:
	var P := GraphicsQuality.Preset
	var only_visual := true
	for preset in [P.LOW, P.MEDIUM, P.HIGH]:
		for k in GraphicsQuality.FIELDS[preset]:
			only_visual = only_visual and (k in VISUAL_FIELDS)
	_check("presets write visual fields only", only_visual)
	var ticks := Engine.physics_ticks_per_second
	var feel_before: int = _gs.feel_preset
	var reg_before: Dictionary = _gs.reg.duplicate()
	GraphicsQuality.apply(_gs, P.LOW)
	_check("LOW turns off particles, background motion, afterimages and dither",
		not _gs.floating_particles and not _gs.bg_motion and not _gs.afterimages and is_equal_approx(_gs.pixel_dither, 0.0))
	_check("LOW lowers glow and parallax", _gs.glow_intensity < 0.5 and _gs.parallax_intensity < 0.6)
	_check("LOW leaves physics, feel and every assist alone",
		Engine.physics_ticks_per_second == ticks and _gs.feel_preset == feel_before and _gs.reg == reg_before)
	GraphicsQuality.apply(_gs, P.HIGH)
	_check("HIGH turns it all back on", _gs.floating_particles and _gs.bg_motion and _gs.afterimages and is_equal_approx(_gs.glow_intensity, 1.0))
	GraphicsQuality.apply(_gs, P.MEDIUM)
	_check("MEDIUM sits between", _gs.floating_particles and not _gs.afterimages and _gs.pixel_dither > 0.0 and _gs.pixel_dither < 1.0)
	# Every preset is a complete set (same keys), so switching never leaves a stray setting.
	var same_keys := true
	for preset in [P.LOW, P.MEDIUM]:
		same_keys = same_keys and GraphicsQuality.FIELDS[preset].keys() == GraphicsQuality.FIELDS[P.HIGH].keys()
	_check("every preset sets the same fields", same_keys)
	# The level data a player is judged by does not depend on quality.
	GraphicsQuality.apply(_gs, P.LOW)
	var low_blades := LevelData.get_level(13).spinning_blades.size() + LevelData.get_level(13).gates.size()
	GraphicsQuality.apply(_gs, P.HIGH)
	var high_blades := LevelData.get_level(13).spinning_blades.size() + LevelData.get_level(13).gates.size()
	_check("hazards are identical on LOW and HIGH", low_blades == high_blades)
	_gs.reset_settings()


# ── automatic detection ─────────────────────────────────────────────

func _fresh_auto() -> AutoQuality:
	_gs.reset_settings()
	var aq := AutoQuality.new()
	root.add_child(aq)
	aq.set_process(false)           # the test feeds it exact frame times
	return aq


func _feed(aq: AutoQuality, ms: float, n: int) -> void:
	for _i in n:
		aq.feed(ms / 1000.0)


func _auto_detection() -> void:
	var P := GraphicsQuality.Preset
	for case in [[12.0, P.HIGH], [22.0, P.MEDIUM], [38.0, P.LOW]]:
		var aq := _fresh_auto()
		await process_frame
		var got := [-1]
		aq.detected.connect(func(p): got[0] = p)
		_feed(aq, case[0], AutoQuality.WARMUP_FRAMES + AutoQuality.DETECT_FRAMES)
		var expect_name: String = GraphicsQuality.NAMES[case[1]]
		_check("%.0f ms frames are detected as %s (got %s)" % [case[0], expect_name, str(got[0])], got[0] == case[1])
		if case[1] == P.LOW:
			_check("a LOW detection applies LOW", not _gs.floating_particles and int(_gs.get_reg("gfx_detected")) == P.LOW)
		aq.queue_free()
	# The warm-up frames do not count: a slow start must not condemn a fast machine.
	var aq2 := _fresh_auto()
	await process_frame
	var got2 := [-1]
	aq2.detected.connect(func(p): got2[0] = p)
	_feed(aq2, 200.0, AutoQuality.WARMUP_FRAMES)
	_feed(aq2, 12.0, AutoQuality.DETECT_FRAMES)
	_check("shader-compile hitches in the warm-up are ignored", got2[0] == P.HIGH)
	aq2.queue_free()
	# Detection happens once: with a stored result it does not run again.
	_gs.reset_settings()
	_gs.set_reg("gfx_detected", float(P.MEDIUM), false)
	var aq3 := AutoQuality.new()
	root.add_child(aq3)
	aq3.set_process(false)
	await process_frame
	var again := [false]
	aq3.detected.connect(func(_p): again[0] = true)
	_feed(aq3, 40.0, AutoQuality.WARMUP_FRAMES + AutoQuality.DETECT_FRAMES + 10)
	_check("an install that was already measured is not measured again", not again[0])
	aq3.queue_free()
	# A chosen preset (not AUTO) is never overridden by detection.
	_gs.reset_settings()
	_gs.set_reg("gfx_quality", P.HIGH, false)
	var aq4 := AutoQuality.new()
	root.add_child(aq4)
	aq4.set_process(false)
	await process_frame
	var ran := [false]
	aq4.detected.connect(func(_p): ran[0] = true)
	_feed(aq4, 40.0, AutoQuality.WARMUP_FRAMES + AutoQuality.DETECT_FRAMES + 10)
	_check("a preset the player chose is never overridden", not ran[0])
	aq4.queue_free()
	_gs.reset_settings()


# ── the low-frame-rate offer ────────────────────────────────────────

func _measured_aq(detected_preset: int) -> AutoQuality:
	_gs.reset_settings()
	_gs.set_reg("gfx_detected", float(detected_preset), false)
	GraphicsQuality.apply(_gs, detected_preset)
	var aq := AutoQuality.new()
	root.add_child(aq)
	aq.set_process(false)
	return aq


func _struggle_offer() -> void:
	var P := GraphicsQuality.Preset
	var aq := _measured_aq(P.HIGH)
	await process_frame
	var offers := [0]
	var suggested := [-1]
	aq.struggling.connect(func(_c, s):
		offers[0] += 1
		suggested[0] = s)
	_feed(aq, 16.0, AutoQuality.WINDOW_FRAMES)
	_feed(aq, 16.0, AutoQuality.WINDOW_FRAMES)
	_check("a smooth game never triggers the offer", offers[0] == 0)
	# One bad window is a hitch, not a verdict.
	_feed(aq, 45.0, AutoQuality.WINDOW_FRAMES)
	_check("one slow window is ignored", offers[0] == 0)
	_feed(aq, 16.0, AutoQuality.WINDOW_FRAMES)
	_feed(aq, 45.0, AutoQuality.WINDOW_FRAMES)
	_check("slow, smooth, slow is still not sustained", offers[0] == 0)
	# A few spikes inside a window (a level load, a hitch) do not count either.
	for _w in 3:
		for i in AutoQuality.WINDOW_FRAMES:
			aq.feed((90.0 if i % 40 == 0 else 16.0) / 1000.0)
	_check("a few spikes in an otherwise smooth window are ignored", offers[0] == 0)
	_feed(aq, 45.0, AutoQuality.WINDOW_FRAMES)
	_feed(aq, 45.0, AutoQuality.WINDOW_FRAMES)
	_check("two slow windows in a row trigger exactly one offer", offers[0] == 1 and suggested[0] == P.MEDIUM)
	_feed(aq, 45.0, AutoQuality.WINDOW_FRAMES * 8)
	_check("and it never nags again after being shown", offers[0] == 1)
	_check("the offer changed nothing by itself", _gs.floating_particles and _gs.afterimages)
	aq.queue_free()
	# Nothing to offer when already on LOW.
	var low := _measured_aq(P.LOW)
	await process_frame
	var low_offers := [0]
	low.struggling.connect(func(_c, _s): low_offers[0] += 1)
	_feed(low, 60.0, AutoQuality.WINDOW_FRAMES * 6)
	_check("on LOW there is no lower preset, so no offer", low_offers[0] == 0)
	low.queue_free()
	_gs.reset_settings()


# ── settings page and toast ─────────────────────────────────────────

func _page_and_toast() -> void:
	_gs.reset_settings()
	var page := SettingsPage.new()
	root.add_child(page)
	await _step(3)
	page._on_quality_picked(GraphicsQuality.Preset.LOW)
	_check("picking LOW on the page applies it", not _gs.floating_particles and _gs.glow_intensity < 0.5)
	page._on_quality_picked(GraphicsQuality.Preset.HIGH)
	_check("picking HIGH on the page applies it", _gs.floating_particles and _gs.afterimages)
	var picked := false
	for p in page._pages:
		for child in p.get_children():
			pass
	page._on_search("quality preset")
	for p in page._pages:
		for child in p.get_children():
			if child.visible and not child.has_meta("is_section"):
				picked = true
	_check("the quality preset row is on the VIDEO page and searchable", picked)
	var hidden_leak := false
	page._on_search("detected preset")
	for p in page._pages:
		for child in p.get_children():
			if child.visible and not child.has_meta("is_section"):
				hidden_leak = true
	_check("the bookkeeping value is not shown to the player", not hidden_leak)
	page.queue_free()
	await process_frame

	var toast := QualityToast.new()
	toast.suggested = GraphicsQuality.Preset.MEDIUM
	root.add_child(toast)
	await _step(3)
	var answer := [null]
	toast.answered.connect(func(v): answer[0] = v)
	var yes := _find_button(toast, "YES, LOWER IT")
	_check("the toast offers YES and NO", yes != null and _find_button(toast, "NO") != null)
	yes.pressed.emit()
	await process_frame
	_check("YES answers true and the toast goes away", answer[0] == true and not is_instance_valid(toast))
	var toast2 := QualityToast.new()
	root.add_child(toast2)
	await _step(2)
	var ans2 := [null]
	toast2.answered.connect(func(v): ans2[0] = v)
	toast2._left = 0.01
	await _step(3)
	_check("an ignored toast times out as NO", ans2[0] == false)
	_gs.reset_settings()


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null

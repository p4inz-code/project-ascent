class_name Cutscene
extends CanvasLayer
## The 45-second opening, built scene-by-scene from docs/design/STORYBOARD.md.
##
## Eight scenes on a 320x180 logical canvas (1 art px = ART screen px at 1080p):
## ORBIT, COCKPIT, THE RIFT, THE FALL, THE SPIRE, LANDING, THE GATE, FIRST STEP.
## PIP, Trevor's suit AI, narrates in captions. Every scene must read with the
## sound off and the text hidden, so the pictures carry the story.
##
## Skipping: hold any key / click / button for SKIP_HOLD seconds. A skip jumps to
## the title slam (scene 8's last beat) instead of hard-cutting, then finishes.
## Runs while the SceneTree is paused (the title menu pauses it): the layer and
## every tween are pause-immune.
##
## Tests drive it with `speed` (a tween speed scale) so a 45 s film runs in a
## couple of seconds; nothing else about its behaviour changes.

signal finished
signal scene_changed(index: int)

const ART: int = 6
const SKIP_HOLD: float = 0.4
const TOTAL: float = 45.0
## Scene start times (s); the last entry is the end of scene 8.
const STARTS: Array[float] = [0.0, 5.0, 10.0, 16.0, 21.0, 28.0, 33.0, 40.0, 45.0]
const P := "res://assets/pixel/"

var speed: float = 1.0

var _bg: ColorRect
var _stage: Control      # fixed 1920x1080 stage, centred in whatever the window is
var _world: Control      # everything a scene builds lives here; wiped per scene
var _ui: Control         # caption, skip hint, progress bar: persists
var _caption: Label
var _bar: ColorRect
var _hint: Label
var _flash: ColorRect
var _tweens: Array[Tween] = []
var _master: Tween
var _scene: int = -1
var _elapsed: float = 0.0
var _hold: float = 0.0
var _ended: bool = false
var _skipping: bool = false
## Skipping needs a fresh press: a key still held from the button that started the film (Enter
## on PLAY, held a moment too long) must not skip it before it begins.
var _armed: bool = false
## The looping PIP spark in scene 8. Tracked so the title slam can stop it BEFORE
## freeing the sprite it animates (a loop whose target is gone is an error).
var _spark: Tween = null
var _sheet: Texture2D
var _table: Dictionary = {}


func _ready() -> void:
	layer = 230
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sheet = load(P + "player_sheet.png") as Texture2D
	var res := load(P + "player_sheet.json")
	if res != null:
		_table = res.data
	_build_frame()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_run_master()


## Centre the fixed stage in the current viewport.
func _layout() -> void:
	if _stage == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_stage.position = ((vp - Vector2(1920, 1080)) * 0.5).floor()


func scene_index() -> int:
	return _scene


func elapsed() -> float:
	return _elapsed


# ── frame: persistent layers ──────────────────────────────────────────────

func _build_frame() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.03, 0.09)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# The film is composed for 1920x1080. A fixed-size stage, centred, keeps that
	# composition intact in a window of any shape (the bg fills the rest).
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(1920, 1080)
	_stage.size = Vector2(1920, 1080)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_world = Control.new()
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_world)

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_ui)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 1)
	_flash.modulate.a = 0.0
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var panel := PanelContainer.new()
	panel.theme = UITheme.build()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -190.0
	panel.offset_bottom = -52.0
	panel.custom_minimum_size = Vector2(1240, 138)
	_ui.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 26 if side in ["left", "right"] else 10)
	panel.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	pad.add_child(row)
	var tag := Label.new()
	tag.text = "PIP"
	tag.add_theme_font_size_override("font_size", UITheme.sz(30))
	tag.add_theme_color_override("font_color", UITheme.AMBER)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	_caption = Label.new()
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", UITheme.sz(30))
	_caption.visible_characters = 0
	row.add_child(_caption)
	panel.modulate.a = 0.0
	panel.name = "CaptionPanel"

	_bar = ColorRect.new()
	_bar.color = UITheme.AMBER
	_bar.position = Vector2(0, 1074)
	_bar.size = Vector2(0, 6)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_bar)

	_hint = Label.new()
	_hint.text = "HOLD ANY KEY - SKIP"
	_hint.add_theme_font_size_override("font_size", UITheme.sz(18))
	_hint.modulate = Color(1, 1, 1, 0.35)
	_hint.position = Vector2(1560, 1020)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hint)


# ── small builders ────────────────────────────────────────────────────────

func _tw() -> Tween:
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_speed_scale(speed)
	_tweens.append(t)
	return t


## A sprite placed in ART units, drawn at whole-number scale `sc`.
func _spr(file: String, art_pos: Vector2, sc: int = ART, region: Rect2 = Rect2()) -> TextureRect:
	var tr := TextureRect.new()
	var tex := load(P + file) as Texture2D
	if region.size != Vector2.ZERO and tex != null:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = region
		tex = at
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if tex != null:
		tr.size = tex.get_size() * sc
	tr.position = art_pos * ART
	_world.add_child(tr)
	return tr


func _rect(art_pos: Vector2, art_size: Vector2, color: Color, parent: Control = null) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = art_pos * ART
	r.size = art_size * ART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _world).add_child(r)
	return r


## A small line of instrument text in screen space (art coordinates for the position).
func _readout(text: String, art_pos: Vector2, color: Color = Color(0.45, 0.85, 1.0, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.sz(24))
	l.add_theme_color_override("font_color", color)
	l.position = art_pos * ART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(l)
	return l


## The survey ship, nose to the RIGHT, with its exhaust attached at the tail (left edge). The
## flame cycles through three frames; the returned ship moves as one piece.
func _ship(art_pos: Vector2) -> TextureRect:
	var ship := _spr("cs_ship.png", art_pos)
	var flame := _spr("cs_exhaust.png", Vector2.ZERO, ART, Rect2(0, 0, 22, 14))
	flame.reparent(ship, false)
	flame.position = Vector2(-20.0 * ART, 7.0 * ART)
	var loop := _tw()
	loop.set_loops()
	for f in 3:
		loop.tween_callback(func(): (flame.texture as AtlasTexture).region = Rect2(f * 22, 0, 22, 14))
		loop.tween_interval(0.07)
	ship.set_meta("flame", flame)
	return ship


func _stars(count: int, seed_: int, twinkle: bool = true, parent: Control = null) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for i in count:
		var s := _rect(Vector2(rng.randi_range(0, 318), rng.randi_range(0, 150)),
			Vector2(1, 1), Color(0.8, 0.88, 1.0, rng.randf_range(0.3, 0.95)), parent)
		if twinkle and i % 6 == 0:
			var t := _tw()
			t.set_loops()
			t.tween_property(s, "modulate:a", 0.2, rng.randf_range(0.6, 1.4))
			t.tween_property(s, "modulate:a", 1.0, rng.randf_range(0.6, 1.4))


## A player-sheet frame (Trevor, as the player will control him).
func _trevor(anim: String, frame: int, art_pos: Vector2, sc: int = ART) -> TextureRect:
	var cell: Array = _table.get("cell", [18, 20])
	var info: Dictionary = _table.get("anims", {}).get(anim, {"row": 0})
	var tr := _spr("player_sheet.png", art_pos, sc,
		Rect2(frame * int(cell[0]), int(info["row"]) * int(cell[1]), int(cell[0]), int(cell[1])))
	return tr


func _say(text: String) -> void:
	var panel := _ui.get_node("CaptionPanel") as Control
	_tw().tween_property(panel, "modulate:a", 1.0, 0.15)
	_caption.text = text
	_caption.visible_characters = 0
	_tw().tween_property(_caption, "visible_characters", text.length(), 0.03 * text.length())


func _hide_caption() -> void:
	_tw().tween_property(_ui.get_node("CaptionPanel"), "modulate:a", 0.0, 0.2)


## Full-screen flashes are the biggest photosensitivity risk in the film: with the death
## flash off (Reduce Motion does that) they are a faint wash instead.
func _flash_strength() -> float:
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null and not bool(gs.death_flash):
		return 0.18
	return 1.0


func _shake_allowed() -> bool:
	var gs := get_node_or_null("/root/GameSettings")
	return gs == null or bool(gs.screen_shake)


func _do_flash(hold: float = 0.05, fade: float = 0.25) -> void:
	_flash.modulate.a = _flash_strength()
	var t := _tw()
	t.tween_interval(hold)
	t.tween_property(_flash, "modulate:a", 0.0, fade)


## Shake the whole world for `time` seconds with a ramping amplitude (px).
func _shake(time: float, peak: float) -> void:
	if not _shake_allowed():
		return
	var t := _tw()
	var steps := int(time / 0.05)
	for i in steps:
		var amp := peak * float(i) / float(max(steps, 1))
		t.tween_property(_world, "position",
			Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.05)
	t.tween_property(_world, "position", Vector2.ZERO, 0.02)


func _clear_scene() -> void:
	for t in _tweens:
		if t != null and t.is_valid() and t != _master:
			t.kill()
	_tweens.clear()
	_tweens.append(_master)
	for c in _world.get_children():
		c.queue_free()
	_world.position = Vector2.ZERO
	_flash.modulate.a = 0.0


# ── the master timeline ───────────────────────────────────────────────────

func _run_master() -> void:
	_master = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_master.set_speed_scale(speed)
	_tweens.append(_master)
	for i in 8:
		_master.tween_callback(_enter_scene.bind(i))
		_master.tween_interval(STARTS[i + 1] - STARTS[i])
	_master.tween_callback(_finish)


func _enter_scene(i: int) -> void:
	_scene = i
	_clear_scene()
	scene_changed.emit(i)
	match i:
		0: _s_orbit()
		1: _s_cockpit()
		2: _s_rift()
		3: _s_fall()
		4: _s_spire()
		5: _s_landing()
		6: _s_gate()
		7: _s_first_step()


# 1 · ORBIT -----------------------------------------------------------------
func _s_orbit() -> void:
	_bg.color = Color(0.02, 0.03, 0.09)
	# The stars drift slowly BACK, which is what makes the ship read as moving forward (right).
	var far := Control.new()
	far.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(far)
	_stars(90, 7, true, far)
	_tw().tween_property(far, "position:x", -ART * 14.0, 5.2)
	_spr("cs_planet.png", Vector2(0, 120))
	# Nose-first: in from the left, out to the right, a long shallow descent toward the limb.
	var ship := _ship(Vector2(-92, 40))
	ship.pivot_offset = ship.size * 0.5
	var t := _tw()
	t.tween_property(ship, "position", Vector2(336, 62) * ART, 5.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(ship, "rotation", 0.05, 5.2)        # a slight nose-down bank
	var tel := _readout("SURVEY RUN 417", Vector2(10, 8))
	var tel2 := _readout("ALT 412 KM   VEL 7.6 KM/S   ALL SYSTEMS NOMINAL", Vector2(10, 14), Color(0.45, 0.85, 1.0, 0.55))
	for l in [tel, tel2]:
		l.modulate.a = 0.0
		_tw().tween_property(l, "modulate:a", 1.0, 0.8)
	_say("SURVEY RUN 417. ALL SYSTEMS NOMINAL.")


# 2 · COCKPIT ---------------------------------------------------------------
func _s_cockpit() -> void:
	_bg.color = Color(0.04, 0.05, 0.12)
	_spr("cs_cockpit.png", Vector2.ZERO)
	var lights: Array[ColorRect] = []
	for i in 6:
		lights.append(_rect(Vector2(26 + i * 28, 135), Vector2(4, 3), Color(0.25, 0.9, 0.45)))
	# Out of the window, far away: a hairline crack of light opens, then a violet glow.
	var crack := _rect(Vector2(190, 56), Vector2(1, 0), Color(0.92, 0.88, 1.0))
	var ct := _tw()
	ct.tween_interval(1.4)
	ct.tween_property(crack, "size:y", 26.0 * ART, 1.6)
	ct.parallel().tween_property(crack, "position:y", 43.0 * ART, 1.6)
	var glow := _spr("rift.png", Vector2(190 - 12, 70 - 12), 1)
	glow.size = glow.texture.get_size() * 2
	glow.position = Vector2(190 * ART, 70 * ART) - glow.size * 0.5
	glow.modulate.a = 0.0
	var gt := _tw()
	gt.tween_interval(3.0)
	gt.tween_property(glow, "modulate:a", 0.85, 1.8)
	# Trevor at the right of the console, PIP hovering at his shoulder.
	# Right of the caption box, so the caption never covers him (five screen pixels per art pixel).
	var bust := _spr("cs_trevor_bust.png", Vector2(266, 120), 5, Rect2(0, 0, 64, 72))
	bust.size = Vector2(64, 72) * 5
	var pip := _spr("cs_pip.png", Vector2(255, 112), ART, Rect2(0, 0, 8, 8))
	var bob := _tw()
	bob.set_loops()
	bob.tween_property(pip, "position:y", pip.position.y - 2.0 * ART, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(pip, "position:y", pip.position.y, 0.9).set_trans(Tween.TRANS_SINE)
	var pulse := _tw()
	pulse.set_loops()
	for f in 3:
		pulse.tween_callback(func(): (pip.texture as AtlasTexture).region = Rect2(f * 8, 0, 8, 8))
		pulse.tween_interval(0.18)
	# The HUD in his visor turns from calm cyan to alert amber when the lights start to change.
	var hud := _tw()
	hud.tween_interval(2.0)
	hud.tween_callback(func(): (bust.texture as AtlasTexture).region = Rect2(64, 0, 64, 72))
	# lights: green -> amber -> red, one by one
	var warn := _tw()
	warn.tween_interval(2.0)
	for i in lights.size():
		warn.tween_callback(func(): lights[i].color = Color(1.0, 0.7, 0.2))
		warn.tween_interval(0.25)
	warn.tween_interval(0.5)
	for i in lights.size():
		warn.tween_callback(func(): lights[i].color = Color(1.0, 0.2, 0.2))
	# slow push-in as a pan (never a fractional scale)
	_tw().tween_property(_world, "position", Vector2(-ART * 2, -ART), 5.0)
	_say("TREVOR. SOMETHING IS... OPENING.")


# 3 · THE RIFT --------------------------------------------------------------
func _s_rift() -> void:
	_bg.color = Color(0.02, 0.03, 0.09)
	_stars(80, 11)
	# The ship, nose to the right, is drawn toward the rift and shakes harder as it nears.
	var ship := _ship(Vector2(40, 82))
	var ft := _tw()
	ft.tween_property(ship, "position:x", 118.0 * ART, 5.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var shiver := _tw()
	shiver.tween_interval(1.4)
	for i in 36:
		var amp := 1.0 + float(i) * 0.22
		shiver.tween_property(ship, "rotation", randf_range(-0.012, 0.012) * amp, 0.1)
	shiver.tween_property(ship, "rotation", 0.0, 0.05)
	# the crack
	var crack := _rect(Vector2(238, 90), Vector2(1, 0), Color(0.9, 0.85, 1.0))
	var ct := _tw()
	ct.tween_property(crack, "position:y", 0.0, 1.2)
	ct.parallel().tween_property(crack, "size:y", 180.0 * ART, 1.2)
	# the rift opens in whole-number steps
	var rift := _spr("rift.png", Vector2(238 - 24, 90 - 24), 1)
	rift.visible = false
	var rt := _tw()
	rt.tween_interval(1.2)
	for sc in [2, 3, 4, 6, 8, 10]:
		rt.tween_callback(func():
			rift.visible = true
			rift.size = rift.texture.get_size() * sc
			rift.position = Vector2(238 * ART, 90 * ART) - rift.size * 0.5)
		rt.tween_interval(0.55)
	# Everything loose is pulled into it: streaks run left to right, toward the rift.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		var y := rng.randi_range(8, 170)
		var ln := rng.randi_range(8, 26)
		var streak := _rect(Vector2(-30, y), Vector2(ln, 1), Color(0.78, 0.7, 1.0, rng.randf_range(0.25, 0.6)))
		var st := _tw()
		st.tween_interval(1.8 + rng.randf() * 0.8)
		st.set_loops()
		st.tween_property(streak, "position:x", 330.0 * ART, rng.randf_range(0.9, 1.6))
		st.tween_property(streak, "position:x", -30.0 * ART, 0.01)
	# shards
	var shards := _tw()
	shards.tween_interval(2.0)
	for i in 14:
		var s := _rect(Vector2(238, 90), Vector2(2, 1), Color(0.8, 0.7, 1.0))
		var dir := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 150.0)
		shards.parallel().tween_property(s, "position", s.position + dir * ART, 3.0)
	_shake(4.0, 7.0)
	var f := _tw()
	f.tween_interval(4.6)
	f.tween_callback(_do_flash.bind(0.08, 0.5))
	_say("TREVOR - BRACE.")


# 4 · THE FALL --------------------------------------------------------------
func _s_fall() -> void:
	_bg.color = Color(0.08, 0.04, 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 22:
		var streak := _rect(Vector2(rng.randi_range(0, 319), rng.randi_range(0, 179)),
			Vector2(1, rng.randi_range(6, 20)), Color(0.7, 0.6, 1.0, rng.randf_range(0.15, 0.5)))
		var t := _tw()
		t.set_loops()
		t.tween_property(streak, "position:y", streak.position.y - 220.0 * ART, rng.randf_range(1.2, 2.4))
		t.tween_property(streak, "position:y", 190.0 * ART, 0.01)
	var names := ["hull", "fin", "nose"]
	for i in 3:
		var w := _spr("cs_wreck_%s.png" % names[i], Vector2(120 + i * 30, 40 + i * 20), 4)
		w.pivot_offset = w.size * 0.5
		var wt := _tw()
		wt.tween_property(w, "position", w.position + Vector2((i - 1) * 90.0, 700.0), 5.0)
		wt.parallel().tween_property(w, "rotation", TAU * (1.0 + i * 0.4) * (1 if i % 2 == 0 else -1), 5.0)
	var tre := _trevor("fall", 0, Vector2(151, 60), 6)
	tre.pivot_offset = tre.size * 0.5
	var tt := _tw()
	tt.tween_property(tre, "rotation", 1.4, 5.0)
	tt.parallel().tween_property(tre, "position:y", tre.position.y + 160.0, 5.0)
	var pip := _spr("cs_pip.png", Vector2(172, 74), 6, Rect2(8, 0, 8, 8))
	_tw().tween_property(pip, "position:y", pip.position.y + 160.0, 5.0)
	_say("SUIT SEALED. SHIP... LOST. I AM SO SORRY, TREVOR.")


# 5 · THE SPIRE -------------------------------------------------------------
func _s_spire() -> void:
	_bg.color = Color(0.03, 0.02, 0.1)
	_stars(60, 19)
	var tower := _spr("cs_spire.png", Vector2(96, 0))
	tower.position.y = -float(tower.size.y - 1080)
	_tw().tween_property(tower, "position:y", 0.0, 7.0).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	var tre := _trevor("fall", 1, Vector2(151, 8), 3)
	_tw().tween_property(tre, "position:y", 880.0, 7.0)
	_say("SCANNING... STRUCTURE NOT IN ANY CHART. NO SKY ABOVE IT. NO GROUND BELOW.")


# 6 · LANDING ---------------------------------------------------------------
func _s_landing() -> void:
	_bg.color = Color(0.03, 0.02, 0.1)
	_stars(40, 23, false)
	_spr("cs_dock.png", Vector2(104, 126))
	var tre := _trevor("fall", 0, Vector2(151, 20))
	var t := _tw()
	t.tween_property(tre, "position:y", (128 - 19 + 1) * float(ART), 0.9).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		var cell: Array = _table.get("cell", [18, 20])
		var row: int = int(_table["anims"]["land"]["row"])
		(tre.texture as AtlasTexture).region = Rect2(0, row * int(cell[1]), int(cell[0]), int(cell[1]))
		for i in 3:
			var d := _rect(Vector2(150 + i * 9, 127), Vector2(2, 2), Color(0.75, 0.8, 0.95, 0.8))
			var dt := _tw()
			dt.tween_property(d, "position:y", d.position.y - 18.0, 0.5)
			dt.parallel().tween_property(d, "modulate:a", 0.0, 0.5))
	t.tween_interval(0.3)
	t.tween_callback(func():
		var cell: Array = _table.get("cell", [18, 20])
		var row: int = int(_table["anims"]["idle"]["row"])
		(tre.texture as AtlasTexture).region = Rect2(0, row * int(cell[1]), int(cell[0]), int(cell[1])))
	_say("GOOD NEWS: YOU ARE ALIVE. BAD NEWS: I HAVE NO BAD NEWS. YET.")


# 7 · THE GATE --------------------------------------------------------------
func _s_gate() -> void:
	_bg.color = Color(0.03, 0.02, 0.1)
	_stars(50, 29)
	# One holder pans everything that belongs to the tower. Screen-pixel layout:
	# the strip's bottom sits on the bottom edge, the gate stands on its top, and
	# the pan then slides the whole thing down to reveal the top.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(holder)
	var tower := _spr("cs_spire.png", Vector2.ZERO)
	tower.position = Vector2(96 * ART, 1080 - tower.size.y)
	tower.reparent(holder, false)
	var gate := _spr("cs_gate.png", Vector2.ZERO)
	gate.position = Vector2(960 - gate.size.x * 0.5, tower.position.y - gate.size.y + 60)
	gate.reparent(holder, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in 6:
		var core := _spr("orb.png", Vector2.ZERO, 3)
		core.position = Vector2(rng.randi_range(780, 1100), rng.randi_range(-900, 900))
		core.reparent(holder, false)
	_tw().tween_property(holder, "position:y", 1500.0, 6.5).set_trans(Tween.TRANS_SINE) 		.set_ease(Tween.EASE_IN_OUT)
	var orb := _spr("orb.png", Vector2(238, 26), 4)
	var count := Label.new()
	count.text = "0 / 100"
	count.add_theme_font_size_override("font_size", UITheme.sz(48))
	count.add_theme_color_override("font_color", UITheme.AMBER)
	count.position = Vector2(238 * ART + 60, 26 * ART - 6)
	_world.add_child(count)
	orb.modulate.a = 0.0
	count.modulate.a = 0.0
	var ct := _tw()
	ct.tween_interval(3.6)
	ct.tween_property(orb, "modulate:a", 1.0, 0.5)
	ct.parallel().tween_property(count, "modulate:a", 1.0, 0.5)
	_say("THAT GATE IS THE ONLY WAY OUT. IT NEEDS ONE HUNDRED CORES. THE SPIRE KEEPS THEM.")


# 8 · FIRST STEP ------------------------------------------------------------
func _s_first_step() -> void:
	_bg.color = Color(0.02, 0.03, 0.08)
	_stars(40, 37, true)
	var bust := _spr("cs_trevor_bust.png", Vector2(116, 16), 8, Rect2(0, 0, 64, 72))
	bust.size = Vector2(64, 72) * 8
	var breathe := _tw()
	breathe.set_loops()
	breathe.tween_property(bust, "position:y", bust.position.y + 8.0, 1.1).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(bust, "position:y", bust.position.y, 1.1).set_trans(Tween.TRANS_SINE)
	var pip := _spr("cs_pip.png", Vector2(194, 52), 6, Rect2(8, 0, 8, 8))
	_spark = _tw()
	_spark.set_loops()
	_spark.tween_property(pip, "modulate:a", 0.3, 0.25)
	_spark.tween_property(pip, "modulate:a", 1.0, 0.25)
	_say("I'LL NAVIGATE. YOU DO THE... JUMPING.")
	var t := _tw()
	t.tween_interval(2.6)
	t.tween_callback(_slam)


## The title slam: logo in on a white flash and a shake. Also where a skip lands.
func _slam() -> void:
	if _spark != null and _spark.is_valid():
		_spark.kill()
	# Every looping tween of the scene must stop BEFORE its targets are freed, or it spins on
	# nothing and reports an infinite loop.
	for t in _tweens:
		if t != null and t.is_valid() and t != _master:
			t.kill()
	_tweens.clear()
	_tweens.append(_master)
	for c in _world.get_children():
		c.queue_free()
	_hide_caption()
	_bg.color = Color(0.02, 0.03, 0.08)
	var logo := _spr("logo.png", Vector2.ZERO, 8)
	logo.position = Vector2(960, 500) - logo.size * 0.5
	_do_flash(0.05, 0.4)
	_shake(0.3, 8.0)
	var t := _tw()
	t.tween_interval(1.4)
	t.tween_property(_bg, "color:a", 0.0, 0.6)
	t.parallel().tween_property(logo, "modulate:a", 0.0, 0.6)


# ── input, progress, skip ────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _ended:
		return
	_elapsed += delta * speed
	_bar.size.x = 1920.0 * clampf(_elapsed / TOTAL, 0.0, 1.0)
	var held := _skip_input_held()
	if not held:
		_armed = true
	elif not _armed:
		held = false       # still the press that started the film: wait for it to be released
	if held:
		_hold += delta
		_hint.modulate.a = 1.0
		_hint.text = "SKIPPING %d%%" % int(clampf(_hold / SKIP_HOLD, 0.0, 1.0) * 100.0)
		if _hold >= SKIP_HOLD:
			skip()
	else:
		_hold = 0.0
		_hint.modulate.a = move_toward(_hint.modulate.a, 0.35, delta)
		_hint.text = "HOLD ANY KEY - SKIP"


## Any key, click or pad button that means "go away": accept, back, pause, space, mouse.
func _skip_input_held() -> bool:
	return Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_cancel") 		or Input.is_action_pressed("pause") or Input.is_key_pressed(KEY_ESCAPE) 		or Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _input(event: InputEvent) -> void:
	# Any press brightens the hint so a player learns that holding skips.
	if event.is_pressed() and not event.is_echo():
		_hint.modulate.a = 1.0


## Jump to the title slam, then finish. Safe to call from any scene, any number
## of times: the first call wins.
func skip() -> void:
	if _ended or _skipping:
		return
	_skipping = true
	if _master != null and _master.is_valid():
		_master.kill()
	_clear_scene()
	_scene = 7
	scene_changed.emit(7)
	_slam()
	var t := _tw()
	t.tween_interval(1.5)
	t.tween_callback(_finish)


func _finish() -> void:
	if _ended:
		return
	_ended = true
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()
	finished.emit()
	queue_free()

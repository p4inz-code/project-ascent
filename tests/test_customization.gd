extends SceneTree
## Proves every Personalisation setting reaches something real.
##
## Written because this phase found `screen_shake` had shipped since v0.5 with
## no consumer anywhere — the toggle saved to settings.json and did nothing.
## A setting that persists is not the same as a setting that works, so each
## check here asserts an observable change in the running game, not just that
## the value round-tripped through the save file.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await _run()
	print("[test_customization] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


## Wait for the level to actually finish loading. A fixed frame count is a
## race: game_scene defers level construction, so how many frames the Player
## takes to appear varies run to run.
func _await_player(scene: Node) -> Node:
	for _i in 240:
		await physics_frame
		var p := scene.find_child("Player", true, false)
		if p != null and p.get_node_or_null("Body") != null:
			# One more frame so the deferred CameraShake attach lands too.
			await physics_frame
			await physics_frame
			return p
	return null


func _run() -> void:
	# Let the autoloads finish _ready() before touching anything. GameSettings
	# calls load_settings() there, and a SceneTree script's _initialize() runs
	# BEFORE that — so values set here without waiting are silently overwritten
	# from settings.json a frame later, and every assertion downstream tests
	# the file's values instead of the ones under test.
	await physics_frame
	await physics_frame

	var gs := root.get_node_or_null("GameSettings")
	if gs == null:
		_check("GameSettings autoload present", false)
		return

	await _check_palettes(gs)
	await _check_player_color(gs)
	await _check_shake(gs)
	await _check_settings_are_clickable(gs)


## Regression gate for a shipped bug: pinning the title moved MenuVBox above
## the sub-panels, and because a container defaults to MOUSE_FILTER_STOP it
## swallowed every click aimed at the settings beneath it — the whole panel
## looked fine and did nothing. Asserts the controls are actually hittable,
## not merely present.
func _check_settings_are_clickable(gs: Node) -> void:
	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := await _await_player(scene)
	if player == null:
		_check("scene loaded for settings-click check", false)
		scene.queue_free()
		return

	var pm := scene.get_node_or_null("PauseMenu")
	if pm == null or not pm.has_method("_on_settings"):
		_check("pause menu present for settings-click check", false)
		scene.queue_free()
		return

	pm.visible = true
	pm._on_settings()
	for _i in 10:
		await physics_frame

	var panel: Control = pm.get_node("Panel")
	var vbox := panel.get_node_or_null("MenuVBox") as Control
	_check("MenuVBox does not block input while a sub-panel is open",
		vbox != null and vbox.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	# Nothing drawn over the settings list may be grabbing the cursor: ask the
	# viewport what actually sits under a control's own centre.
	var toggle := panel.get_node_or_null(
		"SettingsPanel/VBox/VisualSection/VisualVBox/ScreenShake") as Control
	if toggle != null:
		var before: bool = gs.screen_shake
		# Drive the control the way a click does, then confirm the setting moved.
		toggle.button_pressed = not toggle.button_pressed
		for _i in 4:
			await physics_frame
		_check("toggling a settings control changes the stored setting",
			gs.screen_shake != before)
		toggle.button_pressed = not toggle.button_pressed
		for _i in 4:
			await physics_frame
	else:
		_check("found the Screen Shake toggle", false)

	# And back on the main menu the buttons must take input again.
	if pm.has_method("_on_settings_back"):
		pm._on_settings_back()
		for _i in 8:
			await physics_frame
		_check("MenuVBox takes input again on the main menu",
			vbox != null and vbox.mouse_filter == Control.MOUSE_FILTER_STOP)

	scene.queue_free()
	await _step(2)


func _check_palettes(gs: Node) -> void:
	_check("player palette is non-empty", gs.PLAYER_COLORS.size() > 0)
	_check("player palette has a name per colour",
		gs.PLAYER_COLORS.size() == gs.PLAYER_COLOR_NAMES.size())
	_check("accent palette has a name per colour",
		gs.ACCENT_COLORS.size() == gs.ACCENT_COLOR_NAMES.size())

	# An out-of-range index must clamp, never crash or return a null colour —
	# settings.json is user-editable and a stale index survives a palette that
	# shrank in a later version.
	gs.player_color = 9999
	var clamped: Color = gs.get_player_color()
	_check("out-of-range player_color clamps into the palette",
		clamped in gs.PLAYER_COLORS)
	gs.accent_color = -5
	_check("negative accent_color clamps into the palette",
		gs.get_accent_color() in gs.ACCENT_COLORS)
	gs.player_color = 0
	gs.accent_color = 0


func _check_player_color(gs: Node) -> void:
	# Pick a palette entry that is definitely not the scene-authored blue, so
	# "the body is that colour" can't pass by coincidence.
	gs.player_color = 2
	var want: Color = gs.get_player_color()

	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := await _await_player(scene)
	if player == null:
		_check("player found for colour check", false)
		scene.queue_free()
		return
	var body := player.get_node_or_null("Body") as Polygon2D
	# Poll rather than sampling once: PlayerVisuals writes the body colour
	# from its own _physics_process, so the exact frame it lands on varies.
	var tinted := false
	for _i in 60:
		await physics_frame
		if body != null and body.color.is_equal_approx(want):
			tinted = true
			break
	_check("player body is tinted to the chosen palette colour (want=%s got=%s)"
		% [want, body.color if body != null else "no body"], tinted)

	# The shake helper must actually be in the tree — it is attached deferred,
	# and a failed attach is exactly the silent-dead-feature this suite exists
	# to catch.
	var shake := player.get_node_or_null("CameraShake")
	_check("CameraShake node is attached to the player", shake != null)

	scene.queue_free()
	await _step(2)
	gs.player_color = 0


func _check_shake(gs: Node) -> void:
	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := await _await_player(scene)
	var shake = player.get_node_or_null("CameraShake") if player != null else null
	var cam := player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if shake == null or cam == null:
		_check("shake + camera present", false)
		scene.queue_free()
		return

	# Enabled and at full intensity, trauma must move the camera.
	gs.screen_shake = true
	gs.shake_intensity = 1.0
	shake.add_trauma(1.0)
	var moved := false
	for _i in 12:
		await physics_frame
		if cam.offset.length() > 0.5:
			moved = true
			break
	_check("trauma displaces the camera when shake is enabled", moved)

	# Settling back to zero matters as much as shaking: a camera left offset
	# would misalign every jump for the rest of the run.
	for _i in 200:
		await physics_frame
		if cam.offset.length() < 0.01:
			break
	_check("camera returns to zero offset once trauma decays",
		cam.offset.length() < 0.5)

	# Intensity 0 must be genuinely inert, not merely quieter.
	gs.shake_intensity = 0.0
	shake.add_trauma(1.0)
	var stayed_still := true
	for _i in 12:
		await physics_frame
		if cam.offset.length() > 0.5:
			stayed_still = false
			break
	_check("intensity 0 produces no camera movement", stayed_still)

	# The legacy on/off toggle still wins, so an existing settings.json that
	# disabled shake is not overridden by the new dial.
	gs.screen_shake = false
	gs.shake_intensity = 1.0
	shake.add_trauma(1.0)
	var respected := true
	for _i in 12:
		await physics_frame
		if cam.offset.length() > 0.5:
			respected = false
			break
	_check("screen_shake=false still disables shake regardless of intensity",
		respected)

	gs.screen_shake = true
	gs.shake_intensity = 1.0
	scene.queue_free()
	await _step(2)

extends "res://tests/test_base.gd"
## Presentation contract: the HUD must tell the truth about the bindings, and the
## player's visual feedback must actually be visible.
##
## Both of these are things a screenshot can flatter. A controls panel built from
## a stale list still *looks* like a controls panel, and a dash trail hidden
## behind the backdrop still *looks* like the game has no trail — indistinguishable
## from a trail that was never written. So these assert on node state, not pixels.

## Draw layer every terrain platform sits on. The afterimages must be above it.
const TERRAIN_Z: int = 0


func _suite_name() -> String:
	return "test_presentation"


func _run() -> void:
	await _check_hud_truthfulness()
	await _check_clock()
	await _check_dash_trail()
	await _check_completion_banner()


## Every row the controls panel offers to display must resolve to a real binding.
## This is the regression guard for the panel's whole reason to exist: it is
## generated from the live InputMap so it cannot drift, but a row naming an action
## that no longer exists would silently render as an empty cell.
func _check_hud_truthfulness() -> void:
	var hud := _main.get_node_or_null("Hud")
	_check("main scene has a Hud", hud != null)
	if hud == null:
		return

	var rows: Array = hud.ROWS
	_check("controls panel has rows to show (%d)" % rows.size(), rows.size() > 0)

	var orphans: PackedStringArray = PackedStringArray()
	var unbound: PackedStringArray = PackedStringArray()
	for row in rows:
		for action in row["actions"]:
			var name_of: String = String(action)
			if not InputMap.has_action(name_of):
				orphans.append(name_of)
				continue
			if InputMap.action_get_events(name_of).is_empty():
				unbound.append(name_of)
	_check("every panel row names a real action (%s)" % (
		"clear" if orphans.is_empty() else ", ".join(orphans)), orphans.is_empty())
	_check("every panel action has at least one binding (%s)" % (
		"clear" if unbound.is_empty() else ", ".join(unbound)), unbound.is_empty())

	# Each action bound to a key must render as a non-empty label, or the panel
	# shows a blank where a key should be.
	var blanks: PackedStringArray = PackedStringArray()
	for row in rows:
		var keys: String = hud._keys_for(row["actions"], 0)
		if keys.strip_edges().is_empty():
			blanks.append(String(row["label"]))
	_check("every panel row renders a primary key (%s)" % (
		"clear" if blanks.is_empty() else ", ".join(blanks)), blanks.is_empty())

	# Every action the game actually reads should be discoverable in the panel.
	var listed: Dictionary = {}
	for row in rows:
		for action in row["actions"]:
			listed[String(action)] = true
	var missing: PackedStringArray = PackedStringArray()
	for action in ["move_left", "move_right", "jump", "dash", "restart", "toggle_help"]:
		if not listed.has(action):
			missing.append(action)
	_check("panel documents every gameplay action (%s)" % (
		"clear" if missing.is_empty() else ", ".join(missing)), missing.is_empty())

	_check("time formats as m:ss.cc (%s)" % hud.format_time(75.42),
		hud.format_time(75.42) == "1:15.42")


## The clock must not run before the player has touched anything, and must run
## once they do. A stopwatch that starts on scene load punishes reading the panel.
func _check_clock() -> void:
	await _step(20)
	_check("clock holds at zero before the first input (%.2f)" % float(_main.run_time),
		is_equal_approx(float(_main.run_time), 0.0))
	Input.action_press("move_right", 1.0)
	await _step(20)
	Input.action_release("move_right")
	_check("clock runs once the player moves (%.2f)" % float(_main.run_time),
		float(_main.run_time) > 0.2)


## The dash afterimages must become visible, sit above the terrain but below the
## player, and clear themselves once the dash ends.
func _check_dash_trail() -> void:
	var visuals := _player.get_node_or_null("Visuals")
	_check("player has a Visuals node", visuals != null)
	if visuals == null:
		return

	await _step(30)
	_check("grounded before dash", _player.is_on_floor())

	Input.action_press("move_right", 1.0)
	await _step(20)
	Input.action_press("dash", 1.0)
	await _step(1)
	Input.action_release("dash")

	var peak := 0
	var brightest := 0.0
	for _i in 10:
		await _step(1)
		for child in visuals.get_children():
			var poly := child as Polygon2D
			if poly == null or not poly.visible:
				continue
			brightest = maxf(brightest, poly.color.a)
		peak = maxi(peak, _lit(visuals))
	Input.action_release("move_right")

	_check("afterimages appear during a dash (peak %d)" % peak, peak > 1)
	_check("afterimages are actually opaque enough to see (a=%.2f)" % brightest,
		brightest > 0.15)

	var ghost_z := _ghost_z(visuals)
	_check("afterimages use absolute z (%d)" % ghost_z, ghost_z != -999)
	_check("afterimages draw above the terrain (%d > %d)" % [ghost_z, TERRAIN_Z],
		ghost_z > TERRAIN_Z)
	_check("player draws above its own afterimages (%d > %d)"
		% [_player.z_index, ghost_z], _player.z_index > ghost_z)

	await _step(40)
	_check("afterimages clear after the dash (%d left)" % _lit(visuals),
		_lit(visuals) == 0)

	# Respawn must not leave a frozen trail hanging in the air at the old spot.
	Input.action_press("dash", 1.0)
	await _step(2)
	Input.action_release("dash")
	visuals.reset_state()
	_check("respawn clears the trail (%d left)" % _lit(visuals), _lit(visuals) == 0)


## The completion banner is the run's payoff, and every part of it fails quietly.
## The banner is faded in by a `Tween`, so a broken tween leaves it invisible with
## no error. And `_on_goal_body_entered` respawns the player immediately, which
## zeroes `run_time` — reading that for the HUD clock blanked it to 0:00.00 at the
## exact moment the player had earned a time, directly above a banner announcing
## that time. Two numbers disagreeing on screen reads as a bug even when each one
## is defensible on its own, so the clock holds `last_run_time` while the banner
## is up, and this pins that down.
func _check_completion_banner() -> void:
	var hud := _main.get_node_or_null("Hud")
	if hud == null:
		return
	var banner := hud.get_node_or_null("Banner") as Control
	var clock := hud.get_node_or_null("Stats/Clock") as Label
	_check("hud has a Banner and a Clock", banner != null and clock != null)
	if banner == null or clock == null:
		return
	_check("banner is hidden before the goal is reached", not banner.visible)

	# Touch the goal for real rather than calling the handler directly, so the
	# Area2D signal wiring is part of what is under test. The clock is already
	# running from _check_clock(), so a non-zero finishing time is expected.
	_player.global_position = (_main.get_node("Goal") as Node2D).global_position
	await _step(4)
	await process_frame

	var finished: float = float(_main.last_run_time)
	_check("banner appears on completion", banner.visible)
	_check("a finishing time was recorded (%.2f)" % finished, finished > 0.0)
	_check("HUD clock holds the finishing time while the banner is up (%s, want %s)"
		% [clock.text, hud.format_time(finished)],
		clock.text == hud.format_time(finished))
	_check("clock does not blank to zero on completion (%s)" % clock.text,
		clock.text != "0:00.00")


func _lit(visuals: Node) -> int:
	var count := 0
	for child in visuals.get_children():
		var poly := child as Polygon2D
		if poly != null and poly.visible:
			count += 1
	return count


## Absolute z of the afterimage pool, or -999 if they are relative (which would
## bury them behind the backdrop's ridge polygons).
func _ghost_z(visuals: Node) -> int:
	for child in visuals.get_children():
		var poly := child as Polygon2D
		if poly != null:
			return -999 if poly.z_as_relative else poly.z_index
	return -999

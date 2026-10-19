extends SceneTree
## One-shot headless tool: defines Project Ascent's input actions in
## project.godot with correct engine serialization, then quits. Run with:
##   Godot --headless --path <project> --script res://tools/setup_input.gd
## Re-runnable and idempotent (existing actions are cleared and rewritten).
## This is tooling, not shipped game code.

func _key(physical: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	return e

func _axis(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

func _button(index: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e

func _define(action: String, events: Array, deadzone: float = 0.2) -> void:
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": deadzone,
		"events": events,
	})

func _initialize() -> void:
	_define("move_left", [
		_key(KEY_A), _key(KEY_LEFT),
		_axis(JOY_AXIS_LEFT_X, -1.0),
	])
	_define("move_right", [
		_key(KEY_D), _key(KEY_RIGHT),
		_axis(JOY_AXIS_LEFT_X, 1.0),
	])
	_define("jump", [
		_key(KEY_SPACE), _key(KEY_W),
		_button(JOY_BUTTON_A),
	])
	_define("dash", [
		_key(KEY_SHIFT), _key(KEY_J),
		_button(JOY_BUTTON_X),
	])
	# Only THREE verbs get their own key, deliberately. Ledge grab, ground
	# pound, air dash and wall run all ship too, but derived from existing
	# inputs (automatic / Down+Jump / dash-while-airborne / run-into-wall)
	# rather than each claiming a binding. Eleven separately-bound verbs is
	# more than a player can hold, and the kit stops reading as depth.
	_define("slide", [
		_key(KEY_S), _key(KEY_CTRL), _key(KEY_DOWN),
		_button(JOY_BUTTON_B),
	])
	_define("grapple", [
		_key(KEY_E), _key(KEY_K),
		_button(JOY_BUTTON_RIGHT_SHOULDER),
	])
	_define("ability", [
		_key(KEY_G), _key(KEY_F),
		_button(JOY_BUTTON_LEFT_SHOULDER),
	])
	# No dedicated "spin" action — spin triggers on a double-tap of Jump
	# (see player.gd's _handle_spin()), not a separate binding.
	_define("restart", [
		_key(KEY_R),
		_button(JOY_BUTTON_BACK),
	])
	# The controls panel sits on the D-pad (Up). START is the pause button, which is what the
	# HUD tells the player; it used to be bound here and left pausing to a keyboard key.
	_define("toggle_help", [
		_key(KEY_TAB), _key(KEY_F1),
		_button(JOY_BUTTON_DPAD_UP),
	])
	# Hold-to-peek: look around without moving. Keys are the arrow-up and three free letters;
	# on a pad it is the right stick. (Disabled in boss chases; see CameraView.)
	_define("look_up", [_key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_define("look_down", [_key(KEY_C), _axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_define("look_left", [_key(KEY_Z), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	_define("look_right", [_key(KEY_X), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	# Pause is its own action so that menu "back" (ui_cancel, which includes pad B) can never
	# pause the game mid-run: B is Slide, and sliding on a pad must not open the pause menu.
	_define("pause", [
		_key(KEY_ESCAPE),
		_button(JOY_BUTTON_START),
	])
	# Menu navigation on a pad: A accepts, B goes back (explicit, so no build or platform
	# default can leave a menu without them).
	_define("ui_accept", [
		_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE),
		_button(JOY_BUTTON_A),
	])
	_define("ui_cancel", [
		_key(KEY_ESCAPE),
		_button(JOY_BUTTON_B),
	])

	var err := ProjectSettings.save()
	print("[setup_input] ProjectSettings.save() -> ", err)
	quit()

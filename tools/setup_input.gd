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
	_define("toggle_help", [
		_key(KEY_TAB), _key(KEY_F1),
		_button(JOY_BUTTON_START),
	])

	var err := ProjectSettings.save()
	print("[setup_input] ProjectSettings.save() -> ", err)
	quit()

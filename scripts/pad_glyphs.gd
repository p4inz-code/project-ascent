class_name PadGlyphs
extends RefCounted
## Names for gamepad buttons, per controller family, plus a way to read which family a
## connected pad belongs to. Godot's button enum is positional (JOY_BUTTON_A is "the
## bottom face button" on every pad), so each family translates the position to what
## is printed on that pad.

enum Family { XBOX, PLAYSTATION, SWITCH, GENERIC }

## Generic position -> display label, per family.
const LABELS := {
	Family.XBOX: {"A": "A", "B": "B", "X": "X", "Y": "Y", "BACK": "VIEW", "START": "MENU", "LB": "LB", "RB": "RB", "DPAD": "D-PAD UP"},
	Family.PLAYSTATION: {"A": "CROSS", "B": "CIRCLE", "X": "SQUARE", "Y": "TRIANGLE", "BACK": "SHARE", "START": "OPTIONS", "LB": "L1", "RB": "R1", "DPAD": "D-PAD UP"},
	# Nintendo prints A/B and X/Y the other way round from the position names.
	Family.SWITCH: {"A": "B", "B": "A", "X": "Y", "Y": "X", "BACK": "-", "START": "+", "LB": "L", "RB": "R", "DPAD": "D-PAD UP"},
	Family.GENERIC: {"A": "A", "B": "B", "X": "X", "Y": "Y", "BACK": "BACK", "START": "START", "LB": "LB", "RB": "RB", "DPAD": "D-PAD UP"},
}

const POSITIONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "DPAD",
}


## Which family a pad belongs to, from the name the OS reports. Matching is by substring
## because the exact strings differ by OS and driver.
static func classify(joy_name: String) -> int:
	var n := joy_name.to_lower()
	if n.contains("ps3") or n.contains("ps4") or n.contains("ps5") or n.contains("dualshock") \
			or n.contains("dualsense") or n.contains("sony") or n.contains("playstation"):
		return Family.PLAYSTATION
	if n.contains("nintendo") or n.contains("switch") or n.contains("joy-con") or n.contains("pro controller"):
		return Family.SWITCH
	if n.contains("xbox") or n.contains("x-box") or n.contains("xinput") or n.contains("steam deck") \
			or n.contains("microsoft"):
		return Family.XBOX
	return Family.GENERIC


static func family_of_device(device: int) -> int:
	return classify(Input.get_joy_name(device))


static func label(family: int, position: String) -> String:
	var table: Dictionary = LABELS.get(family, LABELS[Family.GENERIC])
	return String(table.get(position, position))


## The generic position of the first joypad button bound to an action ("" if none).
static func position_for_action(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		var b := ev as InputEventJoypadButton
		if b != null and POSITIONS.has(b.button_index):
			return String(POSITIONS[b.button_index])
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			return "STICK"
	return ""


## What to print for an action on a pad of this family: "CROSS", "STICK", or "" if unbound.
static func prompt(family: int, action: String) -> String:
	var pos := position_for_action(action)
	if pos == "":
		return ""
	if pos == "STICK":
		return "STICK"
	return label(family, pos)

class_name InputBindings
extends RefCounted
## Keyboard rebinding. Only KEYBOARD events are ever touched: gamepad bindings
## are left exactly as authored, so rebinding can never strand a controller player.
##
## The authoritative defaults are whatever project.godot defines. They are
## snapshotted once (before any rebinding is applied) so "reset" always restores
## the shipped layout, not whatever the last session left behind.
##
## Bindings are stored as PHYSICAL keycodes (layout-independent: WASD stays
## WASD on AZERTY), the same convention tools/setup_input.gd uses. Everything
## read from disk is validated here, so a hand-edited or corrupt settings file
## can only ever yield a legal key for a known action.

## Rebindable actions, in the order the Controls page shows them.
const ACTIONS: Array[String] = [
	"move_left", "move_right", "jump", "dash", "slide",
	"grapple", "ability", "restart", "toggle_help",
	"look_up", "look_down", "look_left", "look_right",
]
const LABELS: Dictionary = {
	"move_left": "Move left", "move_right": "Move right", "jump": "Jump",
	"dash": "Dash", "slide": "Slide", "grapple": "Grapple", "ability": "Ability",
	"restart": "Restart", "toggle_help": "Controls panel",
	"look_up": "Look up", "look_down": "Look down", "look_left": "Look left", "look_right": "Look right",
}

## Keys that may never be assigned: Escape is the pause key and must always
## work, and the dev-console sequence keys are handled elsewhere.
const RESERVED: Array[int] = [KEY_ESCAPE]

static var _defaults: Dictionary = {}


## Record the shipped keyboard layout. Idempotent: only the first call counts.
static func snapshot_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action in ACTIONS:
		_defaults[action] = keys_for(action)


## Physical keycodes currently bound to an action (keyboard only).
static func keys_for(action: String) -> Array[int]:
	var out: Array[int] = []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k != null and k.physical_keycode != KEY_NONE:
			out.append(int(k.physical_keycode))
	return out


static func default_keys(action: String) -> Array[int]:
	snapshot_defaults()
	var d: Array = _defaults.get(action, [])
	var out: Array[int] = []
	for v in d:
		out.append(int(v))
	return out


static func is_valid_key(code: int) -> bool:
	return code > 0 and code not in RESERVED


## Replace an action's keyboard keys (joypad events untouched).
static func set_keys(action: String, codes: Array) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	for c in codes:
		var e := InputEventKey.new()
		e.physical_keycode = int(c) as Key
		InputMap.action_add_event(action, e)


## Which OTHER rebindable action currently uses `code`, or "" if none.
static func conflict(action: String, code: int) -> String:
	for other in ACTIONS:
		if other != action and code in keys_for(other):
			return other
	return ""


## Give `action` the key `code` as its primary binding. If another action holds
## that key the two swap, so nothing is ever left unbound. Returns the action
## that was displaced ("" if none) so the UI can say so.
static func rebind(action: String, code: int) -> String:
	if not is_valid_key(code) or action not in ACTIONS:
		return ""
	snapshot_defaults()
	var other := conflict(action, code)
	var old_primary := keys_for(action)
	if other != "":
		var other_keys := keys_for(other)
		other_keys.erase(code)
		if not old_primary.is_empty():
			other_keys.insert(0, old_primary[0])
		set_keys(other, other_keys)
	var mine := keys_for(action)
	mine.erase(code)
	mine.insert(0, code)
	set_keys(action, mine)
	return other


static func reset_action(action: String) -> void:
	set_keys(action, default_keys(action))


static func reset_all() -> void:
	for action in ACTIONS:
		reset_action(action)


## The current layout, as saved: {action: [codes]}.
static func export_all() -> Dictionary:
	var out := {}
	for action in ACTIONS:
		out[action] = keys_for(action)
	return out


## Turn untrusted data (parsed JSON) into a safe {action: [int]} dictionary.
## Unknown actions, non-arrays, non-numbers, reserved or out-of-range codes are
## all dropped; an action left with no valid key is omitted (defaults stand).
static func sanitize(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for action in ACTIONS:
		var v = (raw as Dictionary).get(action, null)
		if not v is Array:
			continue
		var codes: Array[int] = []
		for item in v:
			if item is float or item is int:
				var code := int(item)
				if is_valid_key(code) and code < 0x7FFFFFF and code not in codes:
					codes.append(code)
		if not codes.is_empty():
			out[action] = codes
	return out


## Apply a sanitized layout to the InputMap.
static func apply(layout: Dictionary) -> void:
	snapshot_defaults()
	for action in layout:
		if action in ACTIONS:
			set_keys(action, layout[action])


## Human-readable name for a key, matching how the HUD prints them.
static func key_name(code: int) -> String:
	var n := OS.get_keycode_string(code as Key)
	match n:
		"Left": return "<"
		"Right": return ">"
		"Up": return "^"
		"Down": return "v"
	return n.to_upper()

extends Node
## Autoload: remembers which kind of device the player used last (keyboard/mouse or a
## gamepad, and which family of gamepad) so prompts can show the right thing, and swap
## the moment the player picks up the other device. Handles a pad being unplugged.

signal device_changed(using_pad: bool, family: int)

var using_pad: bool = false
var family: int = PadGlyphs.Family.XBOX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Input.joy_connection_changed.is_connected(_on_joy_changed):
		Input.joy_connection_changed.connect(_on_joy_changed)
	# On a Steam Deck the pad is the primary input from the first frame.
	if Platform.is_deck():
		_switch_to(true, PadGlyphs.Family.XBOX)


func _input(event: InputEvent) -> void:
	note_event(event)


## Public so tests can feed events without going through the window.
func note_event(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_switch_to(false, family)
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			_switch_to(true, PadGlyphs.family_of_device(event.device))
	elif event is InputEventJoypadMotion:
		# A drifting stick must not flip the prompts: require a real push.
		if absf(event.axis_value) > 0.6:
			_switch_to(true, PadGlyphs.family_of_device(event.device))


func _switch_to(pad: bool, fam: int) -> void:
	if pad == using_pad and fam == family:
		return
	using_pad = pad
	family = fam
	device_changed.emit(using_pad, family)


func _on_joy_changed(_device: int, connected: bool) -> void:
	# The pad that was in use went away: fall back to the keyboard prompts.
	if not connected and using_pad and Input.get_connected_joypads().is_empty() and not Platform.is_deck():
		_switch_to(false, family)


## What to show for an action right now: the key or the pad button, per the last device.
func prompt(action: String) -> String:
	if using_pad:
		var p := PadGlyphs.prompt(family, action)
		if p != "":
			return p
	var keys := InputBindings.keys_for(action)
	return InputBindings.key_name(keys[0]) if not keys.is_empty() else "?"

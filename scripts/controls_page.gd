class_name ControlsPage
extends CanvasLayer
## The CONTROLS reference screen: what every input does, read live from the
## InputMap so it can never disagree with a rebinding. Opened from the pause
## menu. REBIND jumps to the Settings page on its Controls tab.

signal closed

const GAMEPAD := {
	"move_left": "L STICK / D-PAD", "move_right": "L STICK / D-PAD", "jump": "A",
	"dash": "X", "slide": "B", "grapple": "RB", "ability": "LB",
	"restart": "BACK", "toggle_help": "START",
}
const GROUPS := [
	["MOVEMENT", ["move_left", "move_right", "jump", "slide"]],
	["ABILITIES", ["dash", "grapple", "ability"]],
	["SYSTEM", ["restart", "toggle_help"]],
]

var _theme: Theme
var _rebind: Button
var _done: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 240
	UITheme.refresh_accent(get_node_or_null("/root/GameSettings"))
	_theme = UITheme.build()
	_build()


func _build() -> void:
	add_child(PixelBackdrop.new())
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.theme = _theme
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	frame.add_child(margin)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(820, 0)
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var title := Label.new()
	title.text = "C O N T R O L S"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", UITheme.accent)
	col.add_child(title)

	var head := HBoxContainer.new()
	for text in ["ACTION", "KEYBOARD", "GAMEPAD"]:
		var h := Label.new()
		h.text = text
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		h.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
		head.add_child(h)
	col.add_child(head)

	for group in GROUPS:
		var g := Label.new()
		g.text = group[0]
		g.add_theme_color_override("font_color", UITheme.AMBER)
		g.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
		col.add_child(g)
		var rule := ColorRect.new()
		rule.color = UITheme.LINE
		rule.custom_minimum_size = Vector2(0, UITheme.PX)
		col.add_child(rule)
		for action in group[1]:
			col.add_child(_row(action))

	var tip := Label.new()
	tip.text = "Hold a direction into a wall to slide. Slide needs a run-up. Dash resets on landing."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	tip.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col.add_child(tip)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	_rebind = Button.new()
	_rebind.text = "REBIND KEYS"
	_rebind.custom_minimum_size = Vector2(0, 48)
	_rebind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rebind.pressed.connect(_open_rebind)
	buttons.add_child(_rebind)
	_done = Button.new()
	_done.text = "DONE"
	_done.custom_minimum_size = Vector2(0, 48)
	_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done.pressed.connect(close)
	buttons.add_child(_done)
	_done.call_deferred("grab_focus")


func _row(action: String) -> Control:
	var r := HBoxContainer.new()
	var a := Label.new()
	a.text = String(InputBindings.LABELS.get(action, action))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	var k := Label.new()
	k.text = key_text(action)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_color_override("font_color", UITheme.accent)
	r.add_child(k)
	var p := Label.new()
	p.text = String(GAMEPAD.get(action, "-"))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	r.add_child(p)
	return r


## "A / <" style text for an action's current keyboard keys.
static func key_text(action: String) -> String:
	var names: Array[String] = []
	for code in InputBindings.keys_for(action):
		names.append(InputBindings.key_name(code))
	return "  /  ".join(names) if not names.is_empty() else "UNBOUND"


func _open_rebind() -> void:
	var page := SettingsPage.new()
	add_child(page)
	page.closed.connect(_refresh_after_rebind)


## Rebuild so the table shows whatever the player just changed.
func _refresh_after_rebind() -> void:
	for child in get_children():
		if child is SettingsPage:
			continue
		child.queue_free()
	_build()


func _input(event: InputEvent) -> void:
	# While the Settings page is open on top, it owns the input.
	for child in get_children():
		if child is SettingsPage:
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()

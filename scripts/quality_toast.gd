class_name QualityToast
extends CanvasLayer
## "The frame rate is low. Lower the graphics?" A small offer in the corner, never a popup that
## stops the game. YES lowers the preset (visual settings only); NO or the timeout leaves it.

signal answered(lower_it: bool)

const SHOW_TIME := 14.0

var suggested: int = GraphicsQuality.Preset.LOW
var _left: float = SHOW_TIME
var _done: bool = false
var _yes: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 160
	var panel := PanelContainer.new()
	panel.theme = UITheme.build()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -560.0
	panel.offset_right = -24.0
	panel.offset_top = -250.0
	panel.offset_bottom = -100.0
	add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	m.add_child(col)
	var title := Label.new()
	title.text = "FRAME RATE IS LOW"
	title.add_theme_color_override("font_color", UITheme.AMBER)
	title.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	col.add_child(title)
	var body := Label.new()
	body.text = "LOWER THE GRAPHICS TO %s? ONLY LOOKS CHANGE, NEVER THE LEVELS." % GraphicsQuality.NAMES[suggested]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	col.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_yes = Button.new()
	_yes.text = "YES, LOWER IT"
	_yes.pressed.connect(func(): _answer(true))
	row.add_child(_yes)
	var no := Button.new()
	no.text = "NO"
	no.pressed.connect(func(): _answer(false))
	row.add_child(no)
	var hint := Label.new()
	hint.text = "ENTER = YES    BACKSPACE = NO"
	hint.add_theme_font_size_override("font_size", UITheme.sz(12))
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col.add_child(hint)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_answer(false)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code: int = int((event as InputEventKey).keycode)
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_answer(true)
	elif code == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		_answer(false)


func _answer(lower_it: bool) -> void:
	if _done:
		return
	_done = true
	answered.emit(lower_it)
	queue_free()

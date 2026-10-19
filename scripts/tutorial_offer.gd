class_name TutorialOffer
extends CanvasLayer
## PIP offers the tutorial once, right after the opening story on a first launch. Two clear
## choices, the safe one first, and Escape / B always skips: nobody is ever forced through it.
##
## `chosen(play_it)` is emitted exactly once.

signal chosen(play_it: bool)

var _play: Button
var _skip: Button
var _decided: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 235
	add_child(PixelBackdrop.new())
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.theme = UITheme.build()
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	frame.add_child(margin)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var who := Label.new()
	who.text = "PIP"
	who.add_theme_color_override("font_color", UITheme.AMBER)
	who.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	col.add_child(who)
	var title := Label.new()
	title.text = "NEW TO THE SUIT?"
	title.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING + 6)
	title.add_theme_color_override("font_color", UITheme.accent)
	col.add_child(title)
	var body := Label.new()
	body.text = "I CAN SHOW YOU THE CONTROLS FIRST. IT TAKES ABOUT A MINUTE, NOTHING IN IT CAN HURT YOU, AND YOU CAN SKIP IT NOW OR LEAVE IT ANY TIME. YOU CAN PLAY IT LATER FROM THE TITLE SCREEN."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	col.add_child(body)

	_play = Button.new()
	_play.text = "SHOW ME  (TUTORIAL)"
	_play.custom_minimum_size = Vector2(0, 52)
	_play.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_play.pressed.connect(func(): _decide(true))
	col.add_child(_play)
	_skip = Button.new()
	_skip.text = "SKIP  -  I KNOW THE BASICS"
	_skip.custom_minimum_size = Vector2(0, 52)
	_skip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_skip.pressed.connect(func(): _decide(false))
	col.add_child(_skip)
	var hint := Label.new()
	hint.text = "ESC / B  SKIP"
	hint.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col.add_child(hint)
	_play.call_deferred("grab_focus")


func _decide(play_it: bool) -> void:
	if _decided:
		return
	_decided = true
	chosen.emit(play_it)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_decide(false)

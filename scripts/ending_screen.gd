class_name EndingScreen
extends CanvasLayer
## Shown when the last level is cleared. What it says depends on the cores
## (orbs) the player has banked:
##
##   100 or more   THE GATE OPENS: the true ending.
##   90 to 99      so close: the gate stays shut, and it says how many are missing.
##   anything less the gate needs 100: go back for more.
##
## It never blocks anything: the campaign is complete either way, and CONTINUE
## simply closes it. Level Select always lets the player go back for cores.

signal closed

enum Result { OPEN, CLOSE, SHUT }

const PX := 3.0
const GATE_SCALE := 12.0

var total: int = 0
var goal: int = 100
var result: Result = Result.SHUT
var skip_animation: bool = false   # tests set this to land on the final state at once

var _counter: Label
var _headline: Label
var _line: Label
var _door: TextureRect
var _rays: Control
var _button: Button
var _time: float = 0.0
var _opened: float = 0.0           # 0..1, how far the gate has swung open
var _shown: int = 0


static func result_for(cores: int, target: int) -> Result:
	if cores >= target:
		return Result.OPEN
	if cores >= target - 10:
		return Result.CLOSE
	return Result.SHUT


func headline_text() -> String:
	match result:
		Result.OPEN:
			return "THE GATE OPENS"
		Result.CLOSE:
			var missing := goal - total
			return "ONE CORE SHORT" if missing == 1 else "%d CORES SHORT" % missing
		_:
			return "THE GATE STAYS SHUT"


func pip_text() -> String:
	match result:
		Result.OPEN:
			return "THAT IS ONE HUNDRED. TREVOR... THE GATE IS OPEN. LET US GO HOME."
		Result.CLOSE:
			return "SO CLOSE. THE SPIRE IS STILL KEEPING A FEW. GO BACK FOR THEM."
		_:
			return "THE GATE NEEDS ONE HUNDRED CORES. THE SPIRE STILL HAS PLENTY. LEVEL SELECT WILL TAKE YOU BACK."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 235
	result = result_for(total, goal)
	_build()
	if skip_animation:
		_shown = total
		_opened = 1.0 if result == Result.OPEN else 0.0
		_refresh()
		_button.visible = true


func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.08, 0.94)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var col := VBoxContainer.new()
	col.theme = UITheme.build()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(760, 0)
	centre.add_child(col)

	# The gate: door art on a dark doorway, with rays that grow as it opens.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 26.0 * GATE_SCALE)
	col.add_child(stage)
	_rays = Control.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.draw.connect(_draw_rays)
	stage.add_child(_rays)
	_door = TextureRect.new()
	_door.texture = load("res://assets/pixel/door.png") as Texture2D
	_door.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_door.stretch_mode = TextureRect.STRETCH_SCALE
	_door.custom_minimum_size = Vector2(16.0 * GATE_SCALE, 26.0 * GATE_SCALE)
	_door.size = _door.custom_minimum_size
	_door.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_door.position = Vector2(380.0 - 8.0 * GATE_SCALE, 0.0)
	stage.add_child(_door)

	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", 40)
	col.add_child(_counter)
	_headline = Label.new()
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	_headline.text = headline_text()
	_headline.modulate.a = 0.0
	col.add_child(_headline)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_color_override("font_color", UITheme.AMBER)
	_line.text = pip_text()
	_line.modulate.a = 0.0
	col.add_child(_line)
	_button = Button.new()
	_button.text = "CONTINUE"
	_button.custom_minimum_size = Vector2(0, 52)
	_button.visible = false
	_button.pressed.connect(close)
	col.add_child(_button)
	_refresh()


func _draw_rays() -> void:
	if _opened <= 0.0:
		return
	var c := Vector2(380.0, 26.0 * GATE_SCALE * 0.5)
	var length := 360.0 * _opened
	for i in 11:
		var ang := -PI * 0.5 + (float(i) - 5.0) * 0.16
		var a := 0.28 * _opened * (1.0 - absf(float(i) - 5.0) / 7.0)
		var p := c + Vector2(cos(ang), sin(ang)) * length
		_rays.draw_line(c, p, Color(1.0, 0.85, 0.45, a), 18.0)


func _refresh() -> void:
	if _counter == null:
		return
	_counter.text = "%d / %d CORES" % [_shown, goal]
	var full := _shown >= goal
	_counter.add_theme_color_override("font_color", UITheme.AMBER if full else UITheme.TEXT)
	_headline.add_theme_color_override("font_color",
		UITheme.AMBER if result == Result.OPEN else (UITheme.DANGER if result == Result.SHUT else UITheme.accent))
	# The gate brightens and the doorway lights up as it opens.
	_door.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.4, 0.9), _opened)
	_rays.queue_redraw()


func _process(delta: float) -> void:
	if skip_animation:
		return
	_time += delta
	# Count up over ~2 s, then reveal the headline, then the gate and PIP.
	var count_t := clampf(_time / 2.0, 0.0, 1.0)
	_shown = int(round(float(total) * count_t))
	if _time > 2.2:
		_headline.modulate.a = clampf((_time - 2.2) / 0.6, 0.0, 1.0)
	if result == Result.OPEN and _time > 2.6:
		_opened = clampf((_time - 2.6) / 1.6, 0.0, 1.0)
	if _time > 3.2:
		_line.modulate.a = clampf((_time - 3.2) / 0.6, 0.0, 1.0)
	if _time > 4.4 and not _button.visible:
		_button.visible = true
		_button.grab_focus()
	_refresh()


func _input(event: InputEvent) -> void:
	# Any key or click finishes the animation; a second press continues.
	if not _button.visible and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_time = maxf(_time, 4.5)
		get_viewport().set_input_as_handled()
	elif _button.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()

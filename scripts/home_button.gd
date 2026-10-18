class_name HomeButton
extends Button
## A small pixel house in the corner of the screen: click it to go back to the
## title screen. The game stays exactly where it was, and PLAY there resumes it.
##
## It takes mouse clicks only. Keyboard focus is off on purpose: Space and Enter
## are gameplay keys, and a focused button would fire on every jump.

const PX := 3.0

var _hover: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(54, 54)
	flat = true
	text = ""
	tooltip_text = "MAIN MENU"
	mouse_entered.connect(func():
		_hover = true
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())


func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x * PX, y * PX, w * PX, h * PX), c)


func _draw() -> void:
	# Plate
	var edge := UITheme.accent if _hover else UITheme.LINE
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.09, 0.82))
	draw_rect(Rect2(Vector2.ZERO, size), edge, false, PX)
	var body := Color(0.92, 0.95, 1.0) if _hover else Color(0.72, 0.78, 0.9)
	var roof := UITheme.accent
	# A 12x11 art-pixel house centred in the plate.
	var ox := (size.x / PX - 12.0) * 0.5
	var oy := (size.y / PX - 11.0) * 0.5
	var _o := func(x: float, y: float, w: float, h: float, c: Color):
		draw_rect(Rect2((ox + x) * PX, (oy + y) * PX, w * PX, h * PX), c)
	# Roof: stepped triangle
	_o.call(5.0, 0.0, 2.0, 1.0, roof)
	_o.call(4.0, 1.0, 4.0, 1.0, roof)
	_o.call(3.0, 2.0, 6.0, 1.0, roof)
	_o.call(2.0, 3.0, 8.0, 1.0, roof)
	_o.call(1.0, 4.0, 10.0, 1.0, roof)
	_o.call(0.0, 5.0, 12.0, 1.0, roof)
	# Walls and door
	_o.call(1.0, 6.0, 10.0, 5.0, body)
	_o.call(5.0, 7.0, 2.0, 4.0, Color(0.1, 0.12, 0.2))

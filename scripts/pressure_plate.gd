class_name PressurePlate
extends StaticBody2D
## Stand on it to open a gate elsewhere. The gate stays open for `hold_time`
## after you step off, so the plate is a timer you start rather than a switch
## you hold — which is what makes it a route problem instead of a wait.
##
## The countdown is drawn on the plate itself. A timed gate whose remaining
## time is invisible is a guess, and a guess is not a skill.

signal activated(id: int)
signal expired(id: int)

@export var size: Vector2 = Vector2(90.0, 14.0)
@export var color: Color = Color(0.30, 0.26, 0.18, 1.0)
@export var lit_color: Color = Color(1.0, 0.78, 0.30, 1.0)
@export var hold_time: float = 4.0
## Links this plate to its gate. Both carry the same id.
@export var link_id: int = 0

var _poly: Polygon2D
var _fill: Polygon2D
var _sensor: Area2D
var _remaining: float = 0.0
var _pressed: bool = false


func _ready() -> void:
	_build_visual()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	collision_layer = 3

	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var ss := CollisionShape2D.new()
	var sr := RectangleShape2D.new()
	sr.size = Vector2(size.x - 4.0, 8.0)
	ss.shape = sr
	ss.position = Vector2(0.0, -size.y * 0.5 - 3.0)
	_sensor.add_child(ss)
	_sensor.body_entered.connect(_on_entered)
	add_child(_sensor)


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy),
	])
	_poly.color = color
	add_child(_poly)
	# Drains left to right as the hold expires — the countdown, made visible.
	_fill = Polygon2D.new()
	_fill.color = lit_color
	add_child(_fill)
	_set_fill(0.0)


func _set_fill(frac: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var w := size.x * clampf(frac, 0.0, 1.0)
	if w <= 0.5:
		_fill.polygon = PackedVector2Array()
		return
	_fill.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(-hx + w, -hy),
		Vector2(-hx + w, -hy + 4.0), Vector2(-hx, -hy + 4.0),
	])


func _on_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	_remaining = hold_time
	if not _pressed:
		_pressed = true
		activated.emit(link_id)


func _physics_process(delta: float) -> void:
	if not _pressed:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	_set_fill(_remaining / maxf(hold_time, 0.001))
	if _remaining <= 0.0:
		_pressed = false
		expired.emit(link_id)


func is_pressed() -> bool:
	return _pressed

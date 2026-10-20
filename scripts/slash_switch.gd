class_name SlashSwitch
extends Area2D
## A lever that only a slash flips. It works like a pressure plate: it opens its linked gate for
## `hold_time` seconds and shows the countdown on its face.

signal activated(id: int)
signal expired(id: int)

@export var hold_time: float = 5.0
@export var link_id: int = 0

var _face: Polygon2D
var _fill: Polygon2D
var _remaining: float = 0.0
var _on: bool = false


func _ready() -> void:
	collision_layer = PlayerAttack.SLASH_LAYER
	collision_mask = 0
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([Vector2(-16, -22), Vector2(16, -22), Vector2(16, 22), Vector2(-16, 22)])
	base.color = Color(0.16, 0.18, 0.26)
	add_child(base)
	_face = Polygon2D.new()
	_face.polygon = PackedVector2Array([Vector2(-11, -17), Vector2(11, -17), Vector2(11, 17), Vector2(-11, 17)])
	_face.color = Color(0.24, 0.50, 0.55)
	add_child(_face)
	_fill = Polygon2D.new()
	_fill.color = Color(0.55, 1.0, 0.95)
	add_child(_fill)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 56)
	shape.shape = rect
	add_child(shape)
	_set_fill(0.0)


func _set_fill(frac: float) -> void:
	var h := 34.0 * clampf(frac, 0.0, 1.0)
	if h < 0.5:
		_fill.polygon = PackedVector2Array()
		return
	_fill.polygon = PackedVector2Array([Vector2(-11, 17 - h), Vector2(11, 17 - h), Vector2(11, 17), Vector2(-11, 17)])


func slash_hit(_dir: Vector2, _attacker: Node) -> void:
	_remaining = hold_time
	if not _on:
		_on = true
		activated.emit(link_id)


func is_on() -> bool:
	return _on


func _physics_process(delta: float) -> void:
	if not _on:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	_set_fill(_remaining / maxf(hold_time, 0.001))
	if _remaining <= 0.0:
		_on = false
		expired.emit(link_id)

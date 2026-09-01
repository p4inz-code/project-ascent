class_name TimedGate
extends StaticBody2D
## A solid barrier that opens while its PressurePlate is held. Same link_id
## pairs them.
##
## Drawn as a barred column so it reads as a gate rather than as terrain — a
## barrier that looks like a platform is a barrier the player tries to land on.

@export var size: Vector2 = Vector2(26.0, 150.0)
@export var color: Color = Color(0.42, 0.30, 0.18, 1.0)
@export var link_id: int = 0

var _poly: Polygon2D
var _bars: Array[Polygon2D] = []
var _shape: CollisionShape2D
var _open: bool = false


func _ready() -> void:
	_build_visual()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	collision_layer = 3


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy),
	])
	_poly.color = color
	add_child(_poly)
	var count := 4
	for i in count:
		var bar := Polygon2D.new()
		var y := -hy + size.y * (float(i) + 0.5) / float(count)
		bar.polygon = PackedVector2Array([
			Vector2(-hx, y - 3.0), Vector2(hx, y - 3.0),
			Vector2(hx, y + 3.0), Vector2(-hx, y + 3.0),
		])
		bar.color = Color(0, 0, 0, 0.35)
		add_child(bar)
		_bars.append(bar)


func open() -> void:
	if _open:
		return
	_open = true
	_shape.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.18, 0.2)


func close() -> void:
	if not _open:
		return
	_open = false
	_shape.set_deferred("disabled", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func is_open() -> bool:
	return _open

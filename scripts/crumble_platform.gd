class_name CrumblePlatform
extends StaticBody2D
## A platform that shakes and gives way shortly after the player lands on it,
## then silently reforms after a cooldown. Reused across Act II+ to force
## "don't linger" decisions instead of pure jump-distance judgment — the
## precision-platformer staple (Celeste's crumbling blocks, Super Meat Boy's
## collapsing floors) this project's greybox platforms never had a version of.
##
## Self-contained: it resets on its own timer rather than listening for the
## level's respawn signal, so a player who falls through it and respawns at
## the level start will always find it solid again long before they return.

@export var size: Vector2 = Vector2(120.0, 24.0)
@export var color: Color = Color(0.42, 0.20, 0.16, 1.0)
@export var edge_color: Color = Color(0.85, 0.42, 0.30, 1.0)
## Time standing on it before it gives way.
@export var crumble_delay: float = 0.35
## Time collapsed before it silently reforms.
@export var respawn_delay: float = 2.2

var _poly: Polygon2D
var _edge: Polygon2D
var _shape: CollisionShape2D
var _sensor: Area2D
var _triggered: bool = false
var _base_pos: Vector2


func _ready() -> void:
	_base_pos = position
	_build_visual()

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)

	# A thin sensor hugging the top face triggers on contact — a StaticBody2D
	# has no contact signal of its own, and checking the player's floor state
	# every frame would need a reference this node doesn't otherwise have.
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(size.x - 6.0, 6.0)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0.0, -size.y * 0.5 - 2.0)
	_sensor.add_child(sensor_shape)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	_poly.color = color
	add_child(_poly)

	_edge = Polygon2D.new()
	var edge_h := minf(5.0, size.y * 0.5)
	_edge.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy + edge_h), Vector2(-hx, -hy + edge_h)
	])
	_edge.color = edge_color
	add_child(_edge)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is Player):
		return
	_triggered = true
	_shake_then_fall()


func _shake_then_fall() -> void:
	var shake := create_tween()
	var steps := 6
	for i in steps:
		var offset := Vector2((i % 2) * 2 - 1, 0.0) * 3.0
		shake.tween_property(self, "position", _base_pos + offset, crumble_delay / (steps * 2.0))
		shake.tween_property(self, "position", _base_pos, crumble_delay / (steps * 2.0))
	await shake.finished
	if not is_instance_valid(self):
		return
	_shape.set_deferred("disabled", true)
	_sensor.monitoring = false
	var fall := create_tween()
	fall.tween_property(self, "modulate:a", 0.0, 0.2)
	fall.tween_property(self, "position:y", position.y + 40.0, 0.2)
	await fall.finished
	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(self):
		return
	position = _base_pos
	modulate.a = 1.0
	_shape.set_deferred("disabled", false)
	_sensor.monitoring = true
	_triggered = false

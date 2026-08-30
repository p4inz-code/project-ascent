class_name BouncePad
extends StaticBody2D
## A solid platform that launches the player upward on contact — the
## "bumper/spring" verb almost every genre peer has (Celeste's bumpers, the
## spring pads in Super Meat Boy and the Mario series) and this project never
## had: a way to gain height beyond the jump/wall-jump/dash budget, used
## sparingly in the endgame acts to open up taller single-bound climbs
## without inventing a new player input.
##
## Solid like any platform (the player can also just stand on it — the
## launch only fires on a downward landing), so it never creates a gap a
## missed timing turns into an unrecoverable fall.

@export var size: Vector2 = Vector2(90.0, 20.0)
@export var color: Color = Color(0.18, 0.30, 0.24, 1.0)
@export var edge_color: Color = Color(0.42, 0.92, 0.62, 1.0)
## Upward speed imparted on contact (px/s). The player's own jump is ~-460
## px/s (96 px height); this is deliberately stronger.
@export var bounce_velocity: float = -720.0
## Re-trigger cooldown so one landing can't double-fire across two frames.
@export var retrigger_cooldown: float = 0.25

var _poly: Polygon2D
var _edge: Polygon2D
var _shape: CollisionShape2D
var _sensor: Area2D
var _cooling_down: bool = false


func _ready() -> void:
	_build_visual()

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)

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
	if _cooling_down or not (body is Player):
		return
	if body.velocity.y < 0.0:
		return  # Rising into the underside — not a landing, don't launch.
	body.apply_external_launch(bounce_velocity)
	_cooling_down = true
	var pulse := create_tween()
	pulse.tween_property(self, "scale:y", 0.7, 0.06)
	pulse.tween_property(self, "scale:y", 1.0, 0.12)
	await get_tree().create_timer(retrigger_cooldown).timeout
	if not is_instance_valid(self):
		return
	_cooling_down = false

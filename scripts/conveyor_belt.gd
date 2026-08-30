class_name ConveyorBelt
extends StaticBody2D
## A platform that pushes the player horizontally while they stand on it —
## a classic obby staple this project never had: doing nothing on a conveyor
## still loses (or gains) ground, so crossing one is a held decision, not a
## single jump. Solid like any platform; the push is additive positioning on
## top of normal movement, so jump/dash/wall-jump all still work unmodified.

@export var size: Vector2 = Vector2(140.0, 20.0)
@export var color: Color = Color(0.22, 0.24, 0.20, 1.0)
@export var edge_color: Color = Color(0.62, 0.70, 0.35, 1.0)
## World-space push speed (px/s) applied as a direct position offset each
## physics frame, not a velocity change — same reasoning as wind_zone.gd:
## the player's own controller actively decelerates any un-driven velocity,
## which would cancel a velocity-based push within a frame or two.
@export var push_speed: float = 120.0
## +1 pushes toward +x (right), -1 pushes toward -x (left).
@export_range(-1, 1, 2) var direction: int = 1

var _poly: Polygon2D
var _edge: Polygon2D
var _shape: CollisionShape2D
var _sensor: Area2D
var _riders: Array[Player] = []


func _ready() -> void:
	_build_visual()

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)

	# A thin sensor hugging the top face detects who's actually standing on
	# the belt, same pattern as crumble_platform.gd's contact trigger.
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(size.x - 4.0, 6.0)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0.0, -size.y * 0.5 - 2.0)
	_sensor.add_child(sensor_shape)
	_sensor.body_entered.connect(_on_body_entered)
	_sensor.body_exited.connect(_on_body_exited)
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

	# Chevrons along the top face pointing in the push direction — the same
	# cheap, readable "this is moving" cue wind_zone.gd uses for its air.
	var chevron_count := maxi(2, int(size.x / 40.0))
	for i in chevron_count:
		var t := (float(i) + 0.5) / float(chevron_count)
		var cx := -hx + size.x * t
		var chevron := Polygon2D.new()
		var tip := Vector2(cx + 6.0 * direction, -hy + edge_h * 0.5)
		var back := Vector2(cx - 6.0 * direction, -hy + edge_h * 0.5)
		chevron.polygon = PackedVector2Array([
			tip, back + Vector2(0, 4.0), back - Vector2(0, 4.0)
		])
		chevron.color = Color(edge_color.r, edge_color.g, edge_color.b, 0.7)
		add_child(chevron)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _riders.has(body):
		_riders.append(body)


func _on_body_exited(body: Node2D) -> void:
	# Guard the type check: the sensor's collision_mask overlaps every body on
	# layer 1, not just the player. Without this, a non-Player exit tries to
	# erase into a TypedArray[Player] and Godot throws a container-type-
	# validation error every time (see wind_zone.gd's identical fix).
	if body is Player:
		_riders.erase(body)


func _physics_process(delta: float) -> void:
	for rider in _riders:
		if is_instance_valid(rider) and rider.is_on_floor():
			rider.global_position.x += direction * push_speed * delta

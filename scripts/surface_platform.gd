class_name SurfacePlatform
extends StaticBody2D
## A solid platform that changes how the ground FEELS while you stand on it.
##
## Two variants, both long-standing obby staples this project never had:
##
##   ICE    — grip far below 1: you keep sliding after you stop steering, and
##            you accelerate sluggishly. Overshooting a landing becomes the
##            failure mode rather than mistiming a jump.
##   STICKY — speed scale below 1: you wade. It makes a short run-up genuinely
##            short, which is how a gap that is trivially clearable elsewhere
##            becomes a real problem here.
##
## Neither is lethal and neither takes control away. They change the numbers
## the player's own controller uses, so every verb — jump, dash, wall-jump,
## slide — keeps working exactly as learned. That is the whole design rule for
## these: a surface may change the cost of a move, never remove the move.
##
## The modifiers are applied by the platform and cleared on exit, with the
## player also clearing them in reset_state() — a respawn that happens while
## standing here would otherwise never fire body_exited and would leave the
## player permanently on ice.

enum Kind { ICE, STICKY }

@export var kind: Kind = Kind.ICE
@export var size: Vector2 = Vector2(160.0, 22.0)
@export var color: Color = Color(0.20, 0.30, 0.38, 1.0)
@export var edge_color: Color = Color(0.60, 0.85, 1.0, 1.0)

## Multiplier on the player's ground accel/decel TIMES. Above 1 means every
## change of speed takes longer — which is exactly what ice is.
@export var ice_slip: float = 5.5
## Multiplier on the player's top speed while on a sticky surface.
@export var sticky_speed_scale: float = 0.52

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
	# Layer 2 alongside layer 1, matching platform.gd/conveyor_belt.gd: chasers
	# treat this as solid ground without treating the player as ground.
	collision_layer = 3

	# Thin sensor hugging the top face — same contact pattern as the conveyor.
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


## The tell has to be readable at a glance and from a distance, because the
## player commits to a landing before they can feel the surface. Ice reads as
## a pale sheen with a bright rim; sticky reads as a dark, matte, heavier slab.
func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy),
	])
	_poly.color = color
	add_child(_poly)

	# The lit top edge is the game's universal "you can land here" cue and must
	# survive on every surface type, so it is drawn the same way here.
	var edge_h := minf(5.0, hy)
	_edge = Polygon2D.new()
	_edge.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy),
		Vector2(hx, -hy + edge_h), Vector2(-hx, -hy + edge_h),
	])
	_edge.color = edge_color
	add_child(_edge)

	if kind == Kind.ICE:
		# Two diagonal glints. Cheap, and unmistakably "slippery" at a glance.
		for i in 2:
			var glint := Polygon2D.new()
			var gx := -hx * 0.45 + i * hx * 0.7
			glint.polygon = PackedVector2Array([
				Vector2(gx, -hy + edge_h), Vector2(gx + 10.0, -hy + edge_h),
				Vector2(gx + 3.0, hy), Vector2(gx - 7.0, hy),
			])
			glint.color = Color(edge_color.r, edge_color.g, edge_color.b, 0.28)
			add_child(glint)
	else:
		# Sticky: a row of drips hanging off the underside.
		for i in 4:
			var drip := Polygon2D.new()
			var dx := -hx + (i + 0.5) * (size.x / 4.0)
			drip.polygon = PackedVector2Array([
				Vector2(dx - 4.0, hy - 1.0), Vector2(dx + 4.0, hy - 1.0),
				Vector2(dx, hy + 7.0),
			])
			drip.color = color.darkened(0.25)
			add_child(drip)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _riders.has(body):
		_riders.append(body)
		_apply(body)


func _on_body_exited(body: Node2D) -> void:
	# Same container-type guard as conveyor_belt.gd: the sensor's mask covers
	# every body on layer 1, and erasing a non-Player from a TypedArray[Player]
	# throws.
	if body is Player:
		_riders.erase(body)
		body.clear_surface_modifiers()


func _apply(body: Player) -> void:
	if kind == Kind.ICE:
		body.set_surface_modifiers(ice_slip, 1.0)
	else:
		body.set_surface_modifiers(1.0, sticky_speed_scale)

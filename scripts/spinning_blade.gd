class_name SpinningBlade
extends Node2D
## A rotating hazard bar — this project's first instant-death obstacle.
## Every hazard before this one (bounce pad, wind zone, crumble platform)
## bumps or repositions the player; touching this ends the run immediately,
## respawning exactly like falling off the level or a boss catch. Lives in
## the Hazards container alongside wind zones, for the same reason: it's not
## part of the landable route, so route-walking code (terrain builders,
## reachability checks) that iterates Terrain's children in order must never
## see it.

## Half-length of the bar from the center pivot to each tip (px).
@export var radius: float = 80.0
@export var blade_width: float = 14.0
## Rotation speed in radians/sec. Sign controls spin direction.
@export var rotation_speed: float = 3.0
@export var color: Color = Color(0.85, 0.42, 0.30, 1.0)
@export var hub_color: Color = Color(0.42, 0.20, 0.16, 1.0)
## Seconds before the blade can trigger again after a hit. main_scene.gd
## rebuilds terrain once per level load, not per respawn, so this same
## instance keeps rotating across every life — without a cooldown reset,
## _triggered would stay true forever after the first hit and the blade
## would go harmless for the rest of the attempt. Long enough for the
## respawn teleport to clear the sensor before it re-arms.
@export var retrigger_cooldown: float = 1.0

## Emitted the instant either blade tip touches the player. main_scene.gd
## connects this to the same respawn path used for falling/boss catches —
## this hazard only needs to signal "the run just ended," not decide what
## happens next.
signal player_hit

var _blade: Polygon2D
var _hub: Polygon2D
var _sensor: Area2D
var _angle: float = 0.0
## Guards against firing player_hit twice for one contact — the sensor stays
## overlapping for several frames while the respawn teleport takes effect.
var _triggered: bool = false


func _ready() -> void:
	_build_visual()

	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = blade_width * 0.5
	capsule.height = radius * 2.0
	shape.shape = capsule
	# CapsuleShape2D's long axis is vertical by default; rotate it to match
	# the blade polygon's horizontal orientation before the whole sensor
	# starts sweeping in _physics_process.
	shape.rotation = PI * 0.5
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _build_visual() -> void:
	# A bare spinning bar reads as floating debris — an obstacle with no reason
	# to be where it is. These ARE anchored in gameplay terms (they punish a
	# missed jump and are placed below the route's surface line, which
	# test_hazard_placement enforces), but nothing on screen said so.
	#
	# A static mounting ring behind the blade fixes that: it does not rotate,
	# so it reads as the fixed point the blade is bolted to, and it makes the
	# pivot legible from across the screen — which also tells the player
	# exactly where the sweep is centred before they commit to a jump.
	var mount := Polygon2D.new()
	mount.polygon = _circle_points(blade_width * 1.5, 12)
	mount.color = Color(hub_color.r, hub_color.g, hub_color.b, 0.55)
	add_child(mount)
	var mount_inner := Polygon2D.new()
	mount_inner.polygon = _circle_points(blade_width * 1.05, 12)
	mount_inner.color = Color(0, 0, 0, 0.45)
	add_child(mount_inner)

	_hub = Polygon2D.new()
	_hub.polygon = _circle_points(blade_width * 0.6, 10)
	_hub.color = hub_color
	add_child(_hub)

	var hw := blade_width * 0.5
	_blade = Polygon2D.new()
	_blade.polygon = PackedVector2Array([
		Vector2(-radius, -hw), Vector2(radius, -hw),
		Vector2(radius, hw), Vector2(-radius, hw)
	])
	_blade.color = color
	add_child(_blade)


func _circle_points(r: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(Vector2(cos(a), sin(a)) * r)
	return points


func _physics_process(delta: float) -> void:
	_angle += rotation_speed * delta
	_blade.rotation = _angle
	_sensor.rotation = _angle


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is Player):
		return
	# A well-timed spin phases through. Checked here rather than in each
	# hazard's own way so every lethal obstacle honours it identically.
	if (body as Player).is_invulnerable():
		return
	_triggered = true
	player_hit.emit()
	await get_tree().create_timer(retrigger_cooldown).timeout
	if not is_instance_valid(self):
		return
	_triggered = false

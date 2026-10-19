class_name Pendulum
extends Node2D
## A swinging instant-death hazard — a chain and bob arcing back and forth
## from a fixed pivot, distinct from SpinningBlade's full rotation: a
## pendulum has a predictable rhythm (dwelling near the ends of its arc) that
## rewards watching before crossing, rather than a blade's constant threat.
## Lives in the Hazards container alongside wind zones, spinning blades, and
## lava pits, for the same reason: it's not part of the landable route, so
## route-walking code that iterates Terrain's children in order must never
## see it.

## Pivot-to-bob distance (px).
@export var arm_length: float = 220.0
## Half-width of the swing, in degrees from straight down (0 = motionless).
@export var max_angle_deg: float = 55.0
## Angular speed of the swing cycle (radians/sec fed into sin()) — higher is
## faster, not wider; width comes from max_angle_deg.
@export var swing_speed: float = 1.6
## Shifts where in its cycle the pendulum starts, so multiple pendulums in
## one level don't all swing in lockstep.
@export var phase_offset: float = 0.0
@export var bob_radius: float = 26.0
@export var chain_color: Color = Color(0.42, 0.42, 0.48, 1.0)
@export var bob_color: Color = Color(0.85, 0.30, 0.30, 1.0)
## Same reasoning as SpinningBlade.retrigger_cooldown and Lava.retrigger_cooldown.
@export var retrigger_cooldown: float = 1.0

signal player_hit

var _chain: Polygon2D
var _bob: Polygon2D
var _sensor: Area2D
var _time: float = 0.0
var _triggered: bool = false
var _mount: Polygon2D
const LINK_COUNT := 9
var _links: Array[Polygon2D] = []


func _ready() -> void:
	_build_mount()

	# The chain is a row of links, not a line, so it reads as a real chain.
	for i in LINK_COUNT:
		var link := Polygon2D.new()
		link.polygon = PackedVector2Array([Vector2(-4, -6), Vector2(4, -6), Vector2(4, 6), Vector2(-4, 6)])
		link.color = chain_color.lightened(0.1 if i % 2 == 0 else -0.1)
		add_child(link)
		_links.append(link)

	# The bob is a spiked ball: it is clearly the part that kills.
	_bob = Polygon2D.new()
	var spikes := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		spikes.append(Vector2(cos(a), sin(a)) * (bob_radius * (1.35 if i % 2 == 0 else 0.95)))
	_bob.polygon = spikes
	_bob.color = bob_color
	add_child(_bob)
	var shine := Polygon2D.new()
	shine.polygon = _circle_points(bob_radius * 0.45, 8)
	shine.position = Vector2(-4, -4)
	shine.color = Color(1.0, 0.7, 0.6, 0.85)
	_bob.add_child(shine)

	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = bob_radius
	shape.shape = circle
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)

	_update_pose(0.0)


## A pendulum swings from open space with nothing else drawn at its pivot -
## the same "floating with no visible anchor" problem spinning blades had
## before their mount-ring fix. A small fixed bracket at the pivot (drawn
## once, never animated - it is the one point that does not move) reads as
## "this chain is bolted to something", matching that fix's intent.
func _build_mount() -> void:
	_mount = Polygon2D.new()
	_mount.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(9, 0), Vector2(9, 10), Vector2(-9, 10),
	])
	_mount.color = Color(chain_color.r, chain_color.g, chain_color.b, 0.9)
	add_child(_mount)
	var bolt := Polygon2D.new()
	bolt.polygon = _circle_points(3.5, 8)
	bolt.position = Vector2(0, 5)
	bolt.color = Color(0.1, 0.1, 0.12, 1.0)
	add_child(bolt)


func _circle_points(r: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(Vector2(cos(a), sin(a)) * r)
	return points


func _physics_process(delta: float) -> void:
	_time += delta * HazardSpeed.scale
	_update_pose(_time)


func _update_pose(t: float) -> void:
	var angle := deg_to_rad(max_angle_deg) * sin(swing_speed * t + phase_offset)
	var bob_pos := Vector2(sin(angle), cos(angle)) * arm_length
	_bob.position = bob_pos
	_sensor.position = bob_pos
	var dir := bob_pos.normalized()
	for i in _links.size():
		var frac := (float(i) + 0.5) / float(_links.size())
		var along := bob_pos * frac * (1.0 - bob_radius / maxf(bob_pos.length(), 1.0) * 0.6)
		_links[i].position = along
		_links[i].rotation = dir.angle() - PI * 0.5


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

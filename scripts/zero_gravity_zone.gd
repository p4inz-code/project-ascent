class_name ZeroGravityZone
extends Area2D
## A region where gravity nearly vanishes and the player drifts.
##
## Non-lethal, like wind zones and conveyors — it changes how you move rather
## than ending the run. Lives in the Hazards container for the same reason
## every other non-solid does: route-walking code that iterates Terrain's
## children in order must never see it.
##
## Implemented by damping velocity from outside rather than by touching the
## player's gravity constants, so nothing here can leave the controller in a
## bad state if the player is removed mid-zone (a death inside the zone, for
## instance). Whatever this does stops the instant the body stops overlapping.

@export var size: Vector2 = Vector2(300.0, 260.0):
	set(value):
		size = value
		_rebuild()

## How much of normal gravity still applies inside. 0 is true weightlessness,
## which is disorienting; a little residual pull keeps the player oriented.
@export_range(0.0, 1.0) var gravity_scale: float = 0.12

## Extra drag so a player entering fast drifts to a controllable speed rather
## than sailing straight through untouched.
@export var drag: float = 1.4

## Ceiling on drift speed inside the field, in px/s. Everything here works by
## clamping to this rather than by adjusting gravity, so the zone behaves the
## same no matter how the player's jump arc is tuned.
@export var max_drift_speed: float = 190.0

@export var tint: Color = Color(0.62, 0.45, 1.0, 1.0)

var _bodies: Array[Player] = []
var _field: Polygon2D
var _motes: Array[Polygon2D] = []
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for m in _motes:
		if is_instance_valid(m):
			m.queue_free()
	_motes.clear()
	if _field != null and is_instance_valid(_field):
		_field.queue_free()

	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_field = Polygon2D.new()
	_field.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	_field.color = Color(tint.r, tint.g, tint.b, 0.10)
	add_child(_field)

	# Slowly drifting motes make the zone read as a *field* rather than as a
	# flat coloured rectangle, which is the only cue the player gets that
	# physics are different in here.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size.x) * 31 + int(size.y)
	for _i in 14:
		var mote := Polygon2D.new()
		var r := rng.randf_range(1.5, 3.0)
		mote.polygon = PackedVector2Array([
			Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r)])
		mote.color = Color(tint.r, tint.g, tint.b, rng.randf_range(0.3, 0.7))
		mote.position = Vector2(rng.randf_range(-hx, hx), rng.randf_range(-hy, hy))
		add_child(mote)
		_motes.append(mote)


func _on_entered(body: Node2D) -> void:
	if body is Player and not _bodies.has(body):
		_bodies.append(body)


func _on_exited(body: Node2D) -> void:
	# Type-guarded: the mask covers every body on layer 1, and erasing a
	# non-Player into a TypedArray[Player] throws a container-type error
	# every time (see wind_zone.gd / conveyor_belt.gd for the same fix).
	if body is Player:
		_bodies.erase(body)


func _physics_process(delta: float) -> void:
	_time += delta
	var hy := size.y * 0.5
	for i in _motes.size():
		var m := _motes[i]
		m.position.y -= 9.0 * delta
		m.position.x += sin(_time * 0.8 + float(i)) * 5.0 * delta
		if m.position.y < -hy:
			m.position.y = hy

	for body in _bodies:
		if not is_instance_valid(body):
			continue
		# CLAMP the resulting speed rather than trying to cancel gravity by
		# subtracting a constant. The first version assumed 980 px/s^2, but
		# player.gd derives its falling gravity from jump_height and
		# jump_time_to_descent (~2133), so it cancelled less than half and the
		# player still hit 555 px/s inside a "weightless" field. Clamping is
		# immune to the controller retuning its jump arc later.
		var max_fall := max_drift_speed * (0.35 + gravity_scale)
		if body.velocity.y > max_fall:
			body.velocity.y = max_fall
		if absf(body.velocity.x) > max_drift_speed:
			body.velocity.x = signf(body.velocity.x) * max_drift_speed
		body.velocity = body.velocity.lerp(Vector2.ZERO, clampf(drag * delta, 0.0, 1.0))

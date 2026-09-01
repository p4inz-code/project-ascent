class_name MinionEntity
extends CharacterBody2D
## Minion entity for the chase sequences.
##
## Minions follow set paths or pursue the player with basic movement.
## Each minion has a route offset to create flanking behavior.

@export var base_speed: float = 195.0
@export var acceleration: float = 500.0
@export var gravity: float = 980.0
@export var chase_speed_increase: float = 10.0
@export var max_speed: float = 350.0
@export var catch_distance: float = 36.0

var _player: Player = null
var _active: bool = false
var _chase_time: float = 0.0
var _route_offset: Vector2 = Vector2.ZERO
var _minion_body: Polygon2D
var _eye_left: Polygon2D
var _eye_right: Polygon2D
var _shadow: Polygon2D
var _inner_detail: Polygon2D = null
var _eye_glows: Array = []

# Stuck detection
var _last_x: float = 0.0
var _stuck_timer: float = 0.0
const STUCK_TIMEOUT: float = 1.5
const UNSTUCK_JUMP_VELOCITY: float = -540.0

## How far ahead of the body to probe for ground before taking a step.
const LEDGE_PROBE_AHEAD: float = 34.0
## How far down to probe. Deeper than a step so a shallow drop still counts as
## ground and the chaser does not freeze at every minor lip.
const LEDGE_PROBE_DOWN: float = 60.0
## Furthest gap a chaser will attempt to jump, matched to how far it actually
## travels during GAP_JUMP_VELOCITY's airtime.
const MAX_GAP_JUMP: float = 240.0
const GAP_JUMP_VELOCITY: float = -520.0


func _ready() -> void:
	# Shadow
	_shadow = Polygon2D.new()
	_shadow.color = Color(0.0, 0.0, 0.0, 0.25)
	_shadow.polygon = PackedVector2Array([
		Vector2(-16, 22), Vector2(16, 22), Vector2(12, 25), Vector2(-12, 25)
	])
	_shadow.z_index = -1
	add_child(_shadow)

	# Body — smaller, darker red than boss, with angular shape
	_minion_body = Polygon2D.new()
	_minion_body.color = Color(0.65, 0.22, 0.28, 1.0)
	_minion_body.polygon = PackedVector2Array([
		Vector2(-16, 20), Vector2(16, 20), Vector2(18, 8),
		Vector2(14, -6), Vector2(8, -16), Vector2(0, -22),
		Vector2(-8, -16), Vector2(-14, -6), Vector2(-18, 8)
	])
	add_child(_minion_body)

	# Inner detail
	_inner_detail = Polygon2D.new()
	_inner_detail.color = Color(0.50, 0.15, 0.20, 0.5)
	_inner_detail.polygon = PackedVector2Array([
		Vector2(-10, 16), Vector2(10, 16), Vector2(12, 5),
		Vector2(8, -6), Vector2(0, -14), Vector2(-8, -6),
		Vector2(-12, 5)
	])
	add_child(_inner_detail)

	# Eyes — smaller, menacing orange
	_eye_left = Polygon2D.new()
	_eye_left.color = Color(1.0, 0.7, 0.2, 1.0)
	_eye_left.polygon = PackedVector2Array([
		Vector2(-8, -14), Vector2(-2, -14), Vector2(-2, -9), Vector2(-8, -9)
	])
	add_child(_eye_left)

	_eye_right = Polygon2D.new()
	_eye_right.color = Color(1.0, 0.7, 0.2, 1.0)
	_eye_right.polygon = PackedVector2Array([
		Vector2(2, -14), Vector2(8, -14), Vector2(8, -9), Vector2(2, -9)
	])
	add_child(_eye_right)

	# Eye glow
	for eye in [_eye_left, _eye_right]:
		var glow = Polygon2D.new()
		glow.color = Color(1.0, 0.9, 0.5, 0.7)
		glow.polygon = PackedVector2Array([
			Vector2(eye.polygon[0].x + 1, eye.polygon[0].y + 1),
			Vector2(eye.polygon[1].x - 1, eye.polygon[1].y + 1),
			Vector2(eye.polygon[2].x - 1, eye.polygon[2].y - 1),
			Vector2(eye.polygon[3].x + 1, eye.polygon[3].y - 1)
		])
		add_child(glow)
		_eye_glows.append(glow)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 40)
	col.shape = shape
	add_child(col)

	# Own layer, excluding the player's default layer (1) — see boss.gd's
	# identical fix for the full explanation. Without this a minion is
	# physically indistinguishable from a platform and gets knocked off
	# ledges by the player standing/landing on it. Mask is layer 2 (terrain
	# only, not the player's layer 1) — a mask of 1 still let the minion's
	# OWN chase movement treat the player as solid ground, and an active
	# chase constantly walking into the player was enough to deflect a
	# minion off a ledge on its own, independent of the player standing on it.
	collision_layer = 4
	collision_mask = 2

	z_index = 3
	visible = false


func activate(start_pos: Vector2, player: Player, speed: float,
		route_offset: Vector2 = Vector2.ZERO) -> void:
	global_position = start_pos
	_player = player
	base_speed = speed
	_route_offset = route_offset
	_active = true
	visible = true
	_chase_time = 0.0
	_stuck_timer = 0.0
	_last_x = start_pos.x


## Move an already-active chaser back into the fight after it fell out of the
## level, WITHOUT going through activate(). activate() resets chase_time (and
## on the boss, replays the 1.5s warning telegraph), which is wrong for a
## mid-chase recovery — and critically, the caller must place the entity far
## enough away that the recovery itself isn't an instant catch.
func reposition(new_pos: Vector2) -> void:
	global_position = new_pos
	velocity = Vector2.ZERO
	_stuck_timer = 0.0
	_last_x = new_pos.x


func deactivate() -> void:
	_active = false
	visible = false
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not _active or _player == null:
		return

	_chase_time += delta
	var current_speed := minf(base_speed + _chase_time * chase_speed_increase, max_speed)

	var target := _player.global_position + _route_offset
	var dx := target.x - global_position.x
	var dy := target.y - global_position.y
	var dir_x := signf(dx)
	var dist := absf(dx)

	var speed_scale := 1.0
	if dist > 400.0:
		speed_scale = 1.3
	elif dist < 200.0:
		speed_scale = 0.85

	velocity.x = move_toward(velocity.x, dir_x * current_speed * speed_scale,
		acceleration * delta)

	# Ledge check — the actual remaining cause of "enemies falling".
	#
	# Earlier fixes addressed collision layers (the player knocking a chaser
	# off) and a recovery teleport for anything that fell. Neither stopped a
	# minion simply WALKING off an edge while chasing sideways: nothing ever
	# looked at whether there was ground ahead. Recovery only triggered 400px
	# down, so the visible result was a chaser falling into the void and then
	# snapping back — which reads as broken even though it self-corrects.
	if is_on_floor() and not _ground_ahead(dir_x):
		if _can_clear_gap(dir_x):
			velocity.y = GAP_JUMP_VELOCITY
		else:
			# No ground and no way across: hold the edge rather than stepping
			# off it. Still faces and tracks the player, so it stays menacing
			# instead of suicidal.
			velocity.x = 0.0

	# Stuck detection
	if is_on_floor():
		if absf(global_position.x - _last_x) > 5.0:
			_stuck_timer = 0.0
			_last_x = global_position.x
		else:
			_stuck_timer += delta
			if _stuck_timer > STUCK_TIMEOUT:
				velocity.y = UNSTUCK_JUMP_VELOCITY
				_stuck_timer = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Only jump when the player is above AND we're roughly under them.
		# Jumping on vertical offset alone (the previous behaviour) fired on
		# almost every frame of an ascending level, launching minions off
		# ledges into the void — the "enemies falling" bug, whose real cause
		# was this AI, not collision layers. Requiring horizontal proximity
		# means a jump is an actual attempt to follow the player up a step,
		# not a blind hop taken from anywhere on the map.
		if dy < -50.0 and absf(dx) < 220.0:
			velocity.y = -500.0

	move_and_slide()

	var face_dir := 1.0 if dx >= 0.0 else -1.0
	if _minion_body != null:
		_minion_body.scale.x = face_dir
	if _inner_detail != null:
		_inner_detail.scale.x = face_dir
	if _eye_left != null:
		_eye_left.scale.x = face_dir
	if _eye_right != null:
		_eye_right.scale.x = face_dir
	for glow in _eye_glows:
		if glow != null:
			glow.scale.x = face_dir



## Is there solid ground just ahead in `dir`? Uses a direct-space ray against
## the terrain layer only (mask 2), the same layer this body already collides
## with, so it can never be fooled by the player or another chaser.
func _ground_ahead(dir: float) -> bool:
	if is_zero_approx(dir):
		return true  # not moving: nothing to step off
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(LEDGE_PROBE_AHEAD * signf(dir), 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, LEDGE_PROBE_DOWN))
	query.collision_mask = 2
	query.exclude = [self]
	return not space.intersect_ray(query).is_empty()


## Is there ground on the far side of this gap, close enough to jump to?
## Probes outward in steps rather than assuming — a chaser that leaps into a
## bottomless pit is the bug this whole check exists to prevent.
func _can_clear_gap(dir: float) -> bool:
	if is_zero_approx(dir):
		return false
	var space := get_world_2d().direct_space_state
	var step := 40.0
	var d := LEDGE_PROBE_AHEAD + step
	while d <= MAX_GAP_JUMP:
		var from := global_position + Vector2(d * signf(dir), -40.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 140.0))
		query.collision_mask = 2
		query.exclude = [self]
		if not space.intersect_ray(query).is_empty():
			return true
		d += step
	return false


func has_caught_player() -> bool:
	if not _active or _player == null:
		return false
	if global_position.distance_to(_player.global_position) >= catch_distance:
		return false
	# A raw distance check kills the player THROUGH SOLID GROUND: standing
	# still on a ledge with a chaser passing directly underneath is within
	# catch_distance, so the player dies to something they cannot see, cannot
	# reach, and did nothing to deserve. A chase should only ever be lost to a
	# chaser that actually got to you.
	#
	# Terrain is layer 2 (see platform.gd), so anything solid between the two
	# blocks the catch.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, _player.global_position)
	query.collision_mask = 2
	query.exclude = [self, _player]
	return space.intersect_ray(query).is_empty()


func is_active() -> bool:
	return _active

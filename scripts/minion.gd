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
	# ledges by the player standing/landing on it.
	collision_layer = 4
	collision_mask = 1

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
		# Jump whenever the player is above — no horizontal distance restriction
		if dy < -50.0:
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


func has_caught_player() -> bool:
	if not _active or _player == null:
		return false
	return global_position.distance_to(_player.global_position) < catch_distance


func is_active() -> bool:
	return _active

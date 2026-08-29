class_name MinionEntity
extends CharacterBody2D
## Minion entity for the Level 5 chase sequence.
##
## Minions are simpler than the boss: they follow set paths or pursue
## the player with basic movement. Each minion is assigned a route
## offset to create the feeling of being surrounded/flanked.

@export var base_speed: float = 195.0
@export var acceleration: float = 500.0
@export var gravity: float = 980.0
@export var chase_speed_increase: float = 10.0
@export var max_speed: float = 350.0
## Distance at which the minion catches the player (death radius).
@export var catch_distance: float = 36.0

var _player: Player = null
var _active: bool = false
var _chase_time: float = 0.0
var _route_offset: Vector2 = Vector2.ZERO
var _minion_body: Polygon2D


func _ready() -> void:
	_minion_body = Polygon2D.new()
	_minion_body.color = Color(0.75, 0.35, 0.40, 1.0)
	_minion_body.polygon = PackedVector2Array([
		Vector2(-14, 20), Vector2(14, 20), Vector2(16, 5),
		Vector2(12, -12), Vector2(6, -20), Vector2(-6, -20),
		Vector2(-12, -12), Vector2(-16, 5)
	])
	add_child(_minion_body)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 40)
	col.shape = shape
	add_child(col)

	z_index = 3
	visible = false


func activate(start_pos: Vector2, player: Player, speed: float,
		route_offset: Vector2) -> void:
	global_position = start_pos
	_player = player
	base_speed = speed
	_route_offset = route_offset
	_active = true
	visible = true
	_chase_time = 0.0


func deactivate() -> void:
	_active = false
	visible = false
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not _active or _player == null:
		return

	_chase_time += delta
	var current_speed := minf(base_speed + _chase_time * chase_speed_increase, max_speed)

	# Pursue player + route offset (creates flanking behavior)
	var target := _player.global_position + _route_offset
	var dx := target.x - global_position.x
	var dir_x := signf(dx)
	var dist := absf(dx)

	var speed_scale := 1.0
	if dist > 400.0:
		speed_scale = 1.3
	elif dist < 200.0:
		speed_scale = 0.85

	velocity.x = move_toward(velocity.x, dir_x * current_speed * speed_scale,
		acceleration * delta)

	# Gravity + simple jumping
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if target.y < global_position.y - 60.0 and dist < 250.0:
			velocity.y = -480.0

	move_and_slide()

	if _minion_body != null:
		_minion_body.scale.x = 1.0 if dx >= 0.0 else -1.0


## Check if this minion has caught the player.
func has_caught_player() -> bool:
	if not _active or _player == null:
		return false
	return global_position.distance_to(_player.global_position) < catch_distance


func is_active() -> bool:
	return _active

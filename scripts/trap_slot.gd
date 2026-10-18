class_name TrapSlot
extends Node2D
## One position in a TrapGroup. When ARMED it is a strip of lethal spikes; when
## not, a flat riveted plate you can walk straight over.
##
## Fairness is by construction, not by luck (see TrapGroup and the subset proof
## in tests/test_trap_groups.gd): slots are spaced so that a jump over each one is
## always possible, and every slot is telegraphed. An armed slot stays flat and
## quiet until the player is within REVEAL_DISTANCE, then its spikes rise, so the
## player reads the room rather than the dice roll.
##
## The node sits on the platform surface: its origin is the centre of the slot's
## footprint at surface height, spikes grow upward.

signal player_hit

const WIDTH := 45.0
const HEIGHT := 30.0
## Armed spikes start rising when the player is this close (horizontally).
const REVEAL_DISTANCE := 560.0
const RISE_TIME := 0.18
const PX := 3.0

var armed: bool = false:
	set(value):
		armed = value
		if is_node_ready():
			_apply_armed()

var _spikes: Node2D
var _plate: Node2D
var _sensor: Area2D
var _shape: CollisionShape2D
var _rise: float = 0.0
var _hit_lock: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	_build()
	_apply_armed()


func _build() -> void:
	# The plate: always there, the safe state and the base of the spikes.
	_plate = Node2D.new()
	add_child(_plate)
	var plate := Polygon2D.new()
	plate.polygon = _quad(-WIDTH * 0.5, -PX, WIDTH * 0.5, 0.0)
	plate.color = Color(0.22, 0.24, 0.30)
	_plate.add_child(plate)
	for rx in [-WIDTH * 0.5 + PX * 2.0, WIDTH * 0.5 - PX * 3.0]:
		var rivet := Polygon2D.new()
		rivet.polygon = _quad(rx, -PX, rx + PX, 0.0)
		rivet.color = Color(0.45, 0.50, 0.62)
		_plate.add_child(rivet)

	# The spikes: three teeth, hot tips. Scaled from the base so they "rise".
	_spikes = Node2D.new()
	_spikes.scale = Vector2(1.0, 0.0)
	add_child(_spikes)
	var teeth := 3
	var tw := WIDTH / float(teeth)
	for i in teeth:
		var x0 := -WIDTH * 0.5 + tw * float(i)
		var tooth := Polygon2D.new()
		tooth.polygon = PackedVector2Array([
			Vector2(x0, -PX), Vector2(x0 + tw, -PX), Vector2(x0 + tw * 0.5, -HEIGHT)])
		tooth.color = Color(0.78, 0.80, 0.88)
		_spikes.add_child(tooth)
		var tip := Polygon2D.new()
		tip.polygon = PackedVector2Array([
			Vector2(x0 + tw * 0.25, -HEIGHT * 0.55), Vector2(x0 + tw * 0.75, -HEIGHT * 0.55),
			Vector2(x0 + tw * 0.5, -HEIGHT)])
		tip.color = Color(1.0, 0.32, 0.25)
		_spikes.add_child(tip)

	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# A touch narrower and shorter than the picture: a graze is not a death.
	rect.size = Vector2(WIDTH - 10.0, HEIGHT - 8.0)
	_shape.shape = rect
	_shape.position = Vector2(0.0, -HEIGHT * 0.5 - 2.0)
	_sensor.add_child(_shape)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)


func _quad(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func _apply_armed() -> void:
	_rise = 0.0
	if _spikes != null:
		_spikes.scale = Vector2(1.0, 0.0)
	# Only a RAISED armed slot can hurt. Disabling the shape (deferred: this can
	# be called from a physics callback) keeps unarmed slots completely inert.
	_set_lethal(false)


func _set_lethal(on: bool) -> void:
	if _shape != null:
		_shape.set_deferred("disabled", not on)


## How far up the spikes are, 0..1. Exposed so tests can assert the telegraph.
func raised() -> float:
	return _rise


## The player to measure approach against. Resolved lazily from the tree.
func _find_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


func _physics_process(delta: float) -> void:
	_hit_lock = maxf(_hit_lock - delta, 0.0)
	if not armed:
		return
	var player := _find_player()
	var near := false
	if player != null:
		near = absf(player.global_position.x - global_position.x) <= REVEAL_DISTANCE
	_rise = move_toward(_rise, 1.0 if near else 0.0, delta / RISE_TIME)
	_spikes.scale = Vector2(1.0, _rise)
	# Lethal only once the spikes are essentially all the way up.
	_set_lethal(_rise >= 0.85)


func _on_body_entered(body: Node2D) -> void:
	if not armed or _hit_lock > 0.0 or not (body is Player):
		return
	# A well-timed spin phases through, like every other hazard.
	if (body as Player).is_invulnerable():
		return
	_hit_lock = 1.0
	player_hit.emit()

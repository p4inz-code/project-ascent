class_name Drone
extends Node2D
## A small hovering enemy. It patrols a stretch, drifts toward the player when they come close, and
## costs a cell on contact (chip damage, never instant death). One slash kills it; it comes back
## when the player respawns, like everything else.
##
## Fair by construction: the eye glows and the drone stops for a beat (the wind-up) before it
## drifts at the player, it is slower than a run, and one slash always kills it.

signal player_hit
signal killed

const SENSE_RANGE := 300.0
const DRIFT_SPEED := 70.0
const PATROL_SPEED := 55.0
const WINDUP := 0.5

var home: Vector2 = Vector2.ZERO
var patrol_range: float = 140.0
var alive: bool = true

var _t: float = 0.0
var _area: Area2D = null
var _body: Polygon2D = null
var _eye: Polygon2D = null
var _windup: float = 0.0
var _dead_t: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	add_to_group("enemy")
	home = position
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-18, 0), Vector2(-9, -13), Vector2(9, -13), Vector2(18, 0), Vector2(9, 12), Vector2(-9, 12)])
	_body.color = Color(0.30, 0.32, 0.42)
	add_child(_body)
	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-12, -2), Vector2(-6, -9), Vector2(6, -9), Vector2(12, -2), Vector2(6, 6), Vector2(-6, 6)])
	rim.color = Color(0.20, 0.21, 0.30)
	add_child(rim)
	_eye = Polygon2D.new()
	_eye.polygon = PackedVector2Array([Vector2(-5, -4), Vector2(5, -4), Vector2(5, 2), Vector2(-5, 2)])
	_eye.color = Color(1.0, 0.55, 0.25)
	add_child(_eye)
	for sx in [-1.0, 1.0]:
		var fin := Polygon2D.new()
		fin.polygon = PackedVector2Array([
			Vector2(sx * 18, -2), Vector2(sx * 28, -10), Vector2(sx * 26, 4)])
		fin.color = Color(0.45, 0.47, 0.60)
		add_child(fin)
	_area = Area2D.new()
	_area.collision_layer = PlayerAttack.SLASH_LAYER
	_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if not alive:
		_dead_t += delta
		_body.modulate.a = clampf(1.0 - _dead_t / 0.35, 0.0, 1.0)
		scale = Vector2.ONE * (1.0 + _dead_t * 1.6)
		if _dead_t > 0.35:
			visible = false
		return
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var target := home + Vector2(sin(_t * PATROL_SPEED / maxf(patrol_range, 1.0)) * patrol_range,
		sin(_t * 2.1) * 9.0)
	var near := _player != null and global_position.distance_to(_player.global_position) < SENSE_RANGE \
		and absf(_player.global_position.y - global_position.y) < 220.0
	if near:
		if _windup < WINDUP:
			_windup += delta
			_eye.color = Color(1.0, 0.9, 0.5)
			target = position
		else:
			_eye.color = Color(1.0, 0.3, 0.2)
			target = position + (_player.global_position - global_position).normalized() * 40.0
			position = position.move_toward(target, DRIFT_SPEED * delta)
			_check_contact()
			return
	else:
		_windup = maxf(_windup - delta * 2.0, 0.0)
		_eye.color = Color(1.0, 0.55, 0.25)
	position = position.move_toward(target, PATROL_SPEED * delta)
	_check_contact()


func _check_contact() -> void:
	if not alive or not _area.monitoring:
		return
	for b in _area.get_overlapping_bodies():
		if b is Player:
			player_hit.emit()
			return


func slash_hit(_dir: Vector2, _attacker: Node) -> void:
	if not alive:
		return
	alive = false
	_dead_t = 0.0
	_area.set_deferred("monitoring", false)
	_area.set_deferred("monitorable", false)
	killed.emit()


## Back to life at the home position (a respawn).
func reset() -> void:
	alive = true
	_dead_t = 0.0
	_windup = 0.0
	visible = true
	scale = Vector2.ONE
	_body.modulate.a = 1.0
	position = home
	_area.set_deferred("monitoring", true)
	_area.set_deferred("monitorable", true)

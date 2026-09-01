class_name ShooterTrap
extends Node2D
## A wall emitter that fires a slow projectile across the route on a fixed
## interval. Instant death on contact, like every other hazard here.
##
## Two rules make this fair rather than noise:
##
##  1. The interval is FIXED and the muzzle telegraphs before each shot. A
##     projectile that appears without warning is not a dodge, it is a tax.
##  2. Projectiles are SLOW — slower than the player's run. You are meant to
##     walk through the gaps between them, not react to them. That turns the
##     obstacle into a rhythm problem, which is the same skill the rest of the
##     game asks for.
##
## This is the groundwork for the spear-throwing NPCs on the v2 wishlist: same
## projectile, an actor firing it instead of a wall.

signal player_hit

@export var direction: Vector2 = Vector2(-1, 0)
@export var interval: float = 2.2
@export var projectile_speed: float = 190.0
@export var range_px: float = 620.0
@export var color: Color = Color(1.0, 0.45, 0.30, 1.0)
## How long the muzzle glows before firing.
@export var telegraph: float = 0.5

var _t: float = 0.0
var _muzzle: Polygon2D
var _shots: Array = []


func _ready() -> void:
	_muzzle = Polygon2D.new()
	_muzzle.polygon = PackedVector2Array([
		Vector2(-9, -13), Vector2(9, -13), Vector2(9, 13), Vector2(-9, 13),
	])
	_muzzle.color = Color(0.30, 0.22, 0.20)
	add_child(_muzzle)
	var lip := Polygon2D.new()
	var d := direction.normalized()
	lip.polygon = PackedVector2Array([
		d * 9.0 + Vector2(-d.y, d.x) * 7.0,
		d * 18.0 + Vector2(-d.y, d.x) * 4.0,
		d * 18.0 - Vector2(-d.y, d.x) * 4.0,
		d * 9.0 - Vector2(-d.y, d.x) * 7.0,
	])
	lip.color = color.darkened(0.35)
	add_child(lip)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= interval:
		_t = 0.0
		_fire()
	# Telegraph: the muzzle brightens as the shot approaches.
	var until := interval - _t
	if until <= telegraph:
		var f := 1.0 - (until / maxf(telegraph, 0.001))
		_muzzle.color = Color(0.30, 0.22, 0.20).lerp(color, f)
	else:
		_muzzle.color = Color(0.30, 0.22, 0.20)

	for shot in _shots.duplicate():
		if not is_instance_valid(shot):
			_shots.erase(shot)
			continue
		shot.position += direction.normalized() * projectile_speed * delta
		if shot.position.length() > range_px:
			_shots.erase(shot)
			shot.queue_free()


func _fire() -> void:
	var shot := Area2D.new()
	shot.collision_layer = 0
	shot.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 7.0
	shape.shape = circ
	shot.add_child(shape)

	var body := Polygon2D.new()
	var d := direction.normalized()
	var side := Vector2(-d.y, d.x)
	# Drawn as a dart pointing the way it travels, so its direction is legible
	# the instant it appears.
	body.polygon = PackedVector2Array([
		d * 11.0, side * 5.0 - d * 6.0, -d * 3.0, -side * 5.0 - d * 6.0,
	])
	body.color = color
	shot.add_child(body)

	shot.body_entered.connect(func(b: Node2D) -> void:
		if b is Player:
			player_hit.emit())
	add_child(shot)
	_shots.append(shot)


func live_shot_count() -> int:
	var n := 0
	for s in _shots:
		if is_instance_valid(s):
			n += 1
	return n

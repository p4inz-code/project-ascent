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

## A dart never appears closer than this to the player.
const MIN_SPAWN_CLEARANCE := 90.0

@export var direction: Vector2 = Vector2(-1, 0)
@export var interval: float = 2.2
@export var projectile_speed: float = 190.0
@export var range_px: float = 620.0
@export var color: Color = Color(1.0, 0.45, 0.30, 1.0)
## How long the muzzle glows before firing.
@export var telegraph: float = 0.5

var _t: float = 0.0
var _muzzle: Polygon2D
var _lamp: Polygon2D
var _shots: Array = []


func _ready() -> void:
	# A turret housing: a dark frame with the glowing muzzle plate set into it, and a
	# lamp on top that blinks while it is armed.
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([
		Vector2(-13, -17), Vector2(13, -17), Vector2(13, 17), Vector2(-13, 17),
	])
	frame.color = Color(0.14, 0.15, 0.22)
	add_child(frame)
	var plate := Polygon2D.new()
	plate.polygon = PackedVector2Array([
		Vector2(-9, -12), Vector2(9, -12), Vector2(9, 12), Vector2(-9, 12),
	])
	plate.color = Color(0.22, 0.24, 0.34)
	add_child(plate)
	_muzzle = Polygon2D.new()
	_muzzle.polygon = PackedVector2Array([
		Vector2(-6, -9), Vector2(6, -9), Vector2(6, 9), Vector2(-6, 9),
	])
	_muzzle.color = Color(0.30, 0.22, 0.20)
	add_child(_muzzle)
	_lamp = Polygon2D.new()
	_lamp.polygon = PackedVector2Array([Vector2(-3, -24), Vector2(3, -24), Vector2(3, -18), Vector2(-3, -18)])
	_lamp.color = Color(1.0, 0.3, 0.25)
	add_child(_lamp)
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
	_t += delta * HazardSpeed.scale
	if _t >= interval:
		# Never fire a dart into the space the player is standing in: a shot that appears
		# on top of someone is a spawn kill, not a dodge. Hold the shot until they clear.
		if _player_too_close():
			_t = interval
		else:
			_t = 0.0
			_fire()
	# Telegraph: the muzzle brightens as the shot approaches.
	var until := interval - _t
	if _lamp != null:
		_lamp.color.a = 1.0 if until <= telegraph else 0.35
	if until <= telegraph:
		var f := 1.0 - (until / maxf(telegraph, 0.001))
		_muzzle.color = Color(0.30, 0.22, 0.20).lerp(color, f)
	else:
		_muzzle.color = Color(0.30, 0.22, 0.20)

	for shot in _shots.duplicate():
		if not is_instance_valid(shot):
			_shots.erase(shot)
			continue
		shot.position += _shot_dir(shot) * projectile_speed * delta
		if shot.position.length() > range_px:
			_shots.erase(shot)
			shot.queue_free()


## Is the player within MIN_SPAWN_CLEARANCE of the muzzle?
func _player_too_close() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	return player != null and player.global_position.distance_to(global_position) < MIN_SPAWN_CLEARANCE


## A dart flies along the shooter's direction until a slash deflects it (then it flies back).
func _shot_dir(shot: Node) -> Vector2:
	if shot.has_meta("dir"):
		return shot.get_meta("dir")
	return direction.normalized()


## Reverse a dart. A deflected dart no longer hurts the player and can still be struck by enemies.
func deflect(shot: Node, new_dir: Vector2) -> void:
	shot.set_meta("dir", new_dir.normalized())
	shot.set_meta("deflected", true)
	var body := shot.get_node_or_null("DartBody") as Polygon2D
	if body != null:
		body.color = Color(0.55, 1.0, 0.95)


func _fire() -> void:
	var shot := Dart.new()
	shot.shooter = self
	shot.collision_layer = PlayerAttack.SLASH_LAYER
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
	body.name = "DartBody"
	shot.add_child(body)

	shot.body_entered.connect(func(b: Node2D) -> void:
		if b is Player and not shot.has_meta("deflected"):
			player_hit.emit())
	add_child(shot)
	_shots.append(shot)


func live_shot_count() -> int:
	var n := 0
	for s in _shots:
		if is_instance_valid(s):
			n += 1
	return n

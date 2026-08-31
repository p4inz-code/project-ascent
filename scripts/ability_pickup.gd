class_name AbilityPickup
extends Area2D
## A one-charge ability the player collects in-level and spends with the
## Ability key.
##
## One charge, consumed on use, gone when spent — chosen over a permanent
## unlock or a recharging meter because it keeps level design honest: at any
## point in a level I know exactly what the player has, so no gap can become
## accidentally trivial. A permanent unlock would force re-validating every
## level built before it.

enum Kind { SUPER_JUMP, GLIDE }

@export var kind: Kind = Kind.SUPER_JUMP:
	set(value):
		kind = value
		_rebuild()

## Seconds before a collected pickup returns, so a player who spends a charge
## and then dies is not permanently locked out of the route it was placed for.
@export var respawn_time: float = 6.0

signal collected(kind: Kind)

var _visual: Polygon2D
var _ring: Polygon2D
var _time: float = 0.0
var _available: bool = true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child is Polygon2D:
			child.queue_free()

	var col := _color_for_kind()

	_ring = Polygon2D.new()
	_ring.polygon = _circle_points(19.0, 18)
	_ring.color = Color(col.r, col.g, col.b, 0.22)
	add_child(_ring)

	_visual = Polygon2D.new()
	_visual.color = col
	match kind:
		Kind.SUPER_JUMP:
			# Upward chevron — reads as "up" without needing a label.
			_visual.polygon = PackedVector2Array([
				Vector2(0, -12), Vector2(10, 2), Vector2(4, 2),
				Vector2(4, 11), Vector2(-4, 11), Vector2(-4, 2), Vector2(-10, 2)])
		Kind.GLIDE:
			# Wing silhouette.
			_visual.polygon = PackedVector2Array([
				Vector2(-13, 3), Vector2(0, -9), Vector2(13, 3),
				Vector2(6, 3), Vector2(0, -2), Vector2(-6, 3)])
	add_child(_visual)


func _color_for_kind() -> Color:
	match kind:
		Kind.SUPER_JUMP:
			return Color(0.45, 1.0, 0.62)
		Kind.GLIDE:
			return Color(0.55, 0.85, 1.0)
	return Color.WHITE


func _circle_points(r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _physics_process(delta: float) -> void:
	_time += delta
	if _visual != null:
		# Bob and pulse so it reads as collectable rather than as scenery.
		_visual.position.y = sin(_time * 2.4) * 4.0
		var s := 1.0 + sin(_time * 3.1) * 0.06
		_visual.scale = Vector2(s, s)
	if _ring != null:
		_ring.scale = Vector2.ONE * (1.0 + sin(_time * 2.0) * 0.12)


func _on_body_entered(body: Node2D) -> void:
	if not _available or not (body is Player):
		return
	var player := body as Player
	if not player.has_method("grant_ability"):
		return
	player.grant_ability(int(kind))
	collected.emit(kind)
	_set_available(false)
	await get_tree().create_timer(respawn_time).timeout
	if is_instance_valid(self):
		_set_available(true)


func _set_available(v: bool) -> void:
	_available = v
	visible = v
	# Disable the shape rather than the node, so the pending respawn timer
	# above keeps running on a node that is still in the tree.
	set_deferred("monitoring", v)

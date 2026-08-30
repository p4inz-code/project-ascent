class_name WindZone
extends Area2D
## A zone that constantly pushes the player while they're inside it — the
## Act IV signature mechanic (Celeste's Golden Ridge wind), giving traversal
## a dimension beyond jump/dash timing: you're now also fighting or riding a
## constant force. Purely additive to velocity each physics frame while
## overlapping; the player's own controller (jump/dash/wall-jump) all still
## work normally on top of it.

@export var size: Vector2 = Vector2(160.0, 300.0)
## World-space push speed (px/s), applied as a direct position offset each
## physics frame rather than a velocity change. The player's own controller
## actively decelerates any un-driven velocity at 2000+ px/s^2 (by design,
## for crisp platforming control) — a velocity-based push gets completely
## cancelled within a frame or two at any force small enough to still feel
## fair. A position nudge composes with the player's normal movement (jump,
## dash, wall-jump all still work unmodified) without fighting it.
@export var force: Vector2 = Vector2(220.0, 0.0)
@export var tint: Color = Color(0.55, 0.85, 0.95, 0.10)

var _bodies: Array[Player] = []
var _poly: Polygon2D
var _chevrons: Array[Polygon2D] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)

	_build_visual()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	_poly.color = tint
	_poly.z_index = -1
	add_child(_poly)

	# A few chevrons pointing in the push direction — cheap, readable "this
	# is moving air" cue without a particle system.
	var dir := force.normalized() if force.length() > 0.0 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var chevron_count := maxi(2, int(size.length() / 90.0))
	for i in chevron_count:
		var chevron := Polygon2D.new()
		var t := (float(i) + 0.5) / float(chevron_count)
		var center := Vector2(-hx, -hy) + Vector2(size.x, size.y) * t
		var back := center - dir * 14.0
		chevron.polygon = PackedVector2Array([
			center, back + perp * 8.0, back - perp * 8.0
		])
		chevron.color = Color(tint.r, tint.g, tint.b, 0.35)
		add_child(chevron)
		_chevrons.append(chevron)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	# Guard the type check: the zone's collision_mask overlaps every body on
	# layer 1, including nearby terrain StaticBody2Ds, not just the player.
	# Without this, a non-Player exit tries to erase into a TypedArray[Player]
	# and Godot throws a container-type-validation error every time.
	if body is Player:
		_bodies.erase(body)


func _physics_process(delta: float) -> void:
	for body in _bodies:
		if is_instance_valid(body):
			body.global_position += force * delta

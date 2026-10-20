class_name AirJet
extends Area2D
## An upward column of air: a player inside is lifted toward `speed` px/s. Stand in it and you rise
## through the gap in the deck above; step out the top moving sideways to land on the upper lane.
## Matches MachineWorld.apply_zones.

@export var size: Vector2 = Vector2(MachinePieces.JET_W, 200.0)
@export var speed: float = MachinePieces.JET_SPEED
@export var accel: float = MachinePieces.JET_ACCEL

var _streaks: Array[Polygon2D] = []
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size * 0.5
	add_child(shape)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	glow.color = Color(0.55, 0.85, 1.0, 0.10)
	glow.z_index = -1
	add_child(glow)
	for i in 6:
		var s := Polygon2D.new()
		var x := 10.0 + float(i) * ((size.x - 20.0) / 5.0)
		s.polygon = PackedVector2Array([Vector2(x - 2, 0), Vector2(x + 2, 0), Vector2(x + 1, 30), Vector2(x - 1, 30)])
		s.color = Color(0.75, 0.93, 1.0, 0.45)
		add_child(s)
		_streaks.append(s)
	# The base grate it blows from.
	var grate := Polygon2D.new()
	grate.polygon = PackedVector2Array([Vector2(0, size.y), Vector2(size.x, size.y), Vector2(size.x, size.y + 6), Vector2(0, size.y + 6)])
	grate.color = Color(0.40, 0.55, 0.65)
	add_child(grate)


func _physics_process(delta: float) -> void:
	_t += delta
	for i in _streaks.size():
		_streaks[i].position.y = fposmod(size.y - fposmod(_t * 220.0 + float(i) * 47.0, size.y), size.y)
	for b in get_overlapping_bodies():
		var p := b as Player
		if p != null and p.velocity.y > -speed:
			p.apply_external_launch(maxf(p.velocity.y - accel * delta, -speed))

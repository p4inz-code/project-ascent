class_name FakeGoal
extends Area2D
## A door that is not the End. It looks right from far away and wrong up close (cracked frame, dead
## core, a faint flicker). Touching it is harmless: it only pops a scare and a laugh. It never sits on
## the way to the real door, only in a place a hopeful player would detour to.

signal touched

var _done: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([Vector2(-28, -96), Vector2(28, -96), Vector2(28, 0), Vector2(-28, 0)])
	frame.color = Color(0.16, 0.17, 0.24)
	add_child(frame)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(-20, -88), Vector2(20, -88), Vector2(20, -6), Vector2(-20, -6)])
	glow.color = Color(0.95, 0.75, 0.3, 0.55)
	add_child(glow)
	var crack := Line2D.new()
	crack.points = PackedVector2Array([Vector2(-14, -88), Vector2(-2, -62), Vector2(-10, -44), Vector2(4, -20)])
	crack.width = 2.0
	crack.default_color = Color(0.05, 0.04, 0.08)
	add_child(crack)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 96)
	shape.shape = rect
	shape.position = Vector2(0, -48)
	add_child(shape)
	body_entered.connect(func(b: Node2D) -> void:
		if b is Player and not _done:
			_done = true
			touched.emit())


func _physics_process(_delta: float) -> void:
	modulate.a = 0.8 + 0.2 * float(int(Time.get_ticks_msec() / 90) % 2)

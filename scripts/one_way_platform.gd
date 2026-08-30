class_name OneWayPlatform
extends StaticBody2D
## A platform solid from above only — land on top, jump up through it from
## below, walk off either side freely. Godot's built-in one-way collision
## (CollisionShape2D.one_way_collision) does the actual physics; this class
## only builds the visual and collider, same shape as platform.gd's default
## solid but with a distinct look (dashed underside) so the player can tell
## at a glance which platforms they can rise through.

@export var size: Vector2 = Vector2(140.0, 20.0)
@export var color: Color = Color(0.24, 0.26, 0.32, 1.0)
@export var edge_color: Color = Color(0.55, 0.68, 0.85, 1.0)

var _poly: Polygon2D
var _edge: Polygon2D
var _shape: CollisionShape2D


func _ready() -> void:
	_build_visual()

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.one_way_collision = true
	add_child(_shape)
	# Layer 2, alongside the default layer 1 — see platform.gd's identical
	# comment: lets boss/minion treat this as solid ground without also
	# treating the player as solid ground.
	collision_layer = 3


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	_poly.color = color
	add_child(_poly)

	_edge = Polygon2D.new()
	var edge_h := minf(5.0, size.y * 0.5)
	_edge.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy + edge_h), Vector2(-hx, -hy + edge_h)
	])
	_edge.color = edge_color
	add_child(_edge)

	# Dashed underside strip — the visual cue that this platform is
	# pass-through from below, distinct from a normal solid's flat bottom.
	var dash_count := maxi(2, int(size.x / 24.0))
	for i in dash_count:
		if i % 2 != 0:
			continue
		var dash := Polygon2D.new()
		var dw := size.x / float(dash_count)
		var dx := -hx + dw * float(i)
		dash.polygon = PackedVector2Array([
			Vector2(dx, hy - 3.0), Vector2(dx + dw * 0.6, hy - 3.0),
			Vector2(dx + dw * 0.6, hy), Vector2(dx, hy)
		])
		dash.color = Color(edge_color.r, edge_color.g, edge_color.b, 0.6)
		add_child(dash)

@tool
class_name GreyboxPlatform
extends StaticBody2D
## Reusable greybox solid for prototyping levels. Set `size` in the inspector
## and the collision box and the visual polygon resize together. `@tool` so the
## visual updates live while editing a level scene.
##
## The RectangleShape2D is created in code (never stored in the scene) so every
## instance owns a unique collider — resizing one platform can't mutate another.

@export var size: Vector2 = Vector2(128.0, 32.0):
	set(value):
		size = value
		_apply()

@export var color: Color = Color(0.212, 0.231, 0.302, 1.0):
	set(value):
		color = value
		_apply()

## Height of the lit strip along the top face (px). This is the single most
## load-bearing readability cue in the level: it tells the player at a glance
## which faces they can land on, and it separates a platform from the dark
## parallax ridges behind it. 0 disables it.
@export var edge_thickness: float = 5.0:
	set(value):
		edge_thickness = maxf(value, 0.0)
		_apply()

@export var edge_color: Color = Color(0.42, 0.58, 0.76, 1.0):
	set(value):
		edge_color = value
		_apply()

@onready var _poly: Polygon2D = $Polygon2D
@onready var _edge: Polygon2D = $TopEdge
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# Always give every instance its OWN collider. The scene file ships a shared
	# RectangleShape2D sub-resource; without this, all platforms would mutate the
	# same resource and collapse to whichever size was applied last.
	_shape.shape = RectangleShape2D.new()
	_apply()


func _apply() -> void:
	# _poly/_edge/_shape are @onready, so they are null until _ready has assigned
	# them. Guarding on that (rather than is_node_ready(), which is not yet
	# true while _ready is still running) lets the initial _apply() from
	# _ready() actually size the collider.
	if _poly == null or _edge == null or _shape == null:
		return
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	_poly.color = color
	# Clamp the strip so a thin slab never ends up entirely highlight.
	var edge := minf(edge_thickness, size.y * 0.5)
	_edge.visible = edge > 0.0
	_edge.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy + edge), Vector2(-hx, -hy + edge)
	])
	_edge.color = edge_color
	(_shape.shape as RectangleShape2D).size = size
	# Subtle glow line below the top edge for atmospheric depth
	if not has_node("GlowLine"):
		var glow := Polygon2D.new()
		glow.name = "GlowLine"
		glow.z_index = -1
		add_child(glow)
	var glow_line = get_node("GlowLine") as Polygon2D
	if glow_line != null:
		var glow_h := minf(edge * 0.5, 3.0)
		glow_line.polygon = PackedVector2Array([
			Vector2(-hx, -hy + edge), Vector2(hx, -hy + edge),
			Vector2(hx, -hy + edge + glow_h), Vector2(-hx, -hy + edge + glow_h)
		])
		glow_line.color = Color(edge_color.r, edge_color.g, edge_color.b, 0.15)

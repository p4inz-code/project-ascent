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

@export var color: Color = Color(0.20, 0.22, 0.28, 1.0):
	set(value):
		color = value
		_apply()

@onready var _poly: Polygon2D = $Polygon2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# Always give every instance its OWN collider. The scene file ships a shared
	# RectangleShape2D sub-resource; without this, all platforms would mutate the
	# same resource and collapse to whichever size was applied last.
	_shape.shape = RectangleShape2D.new()
	_apply()


func _apply() -> void:
	# _poly/_shape are @onready, so they are null until _ready has assigned
	# them. Guarding on that (rather than is_node_ready(), which is not yet
	# true while _ready is still running) lets the initial _apply() from
	# _ready() actually size the collider.
	if _poly == null or _shape == null:
		return
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	_poly.color = color
	(_shape.shape as RectangleShape2D).size = size

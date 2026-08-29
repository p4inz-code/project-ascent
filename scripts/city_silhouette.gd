@tool
class_name CitySilhouette
extends Polygon2D
## Procedurally generates a city/building silhouette for the backdrop.
##
## Creates a skyline of rectangular buildings with varied heights and widths,
## giving the environment depth and structure. Used as a parallax layer.

## Total width of the silhouette band.
@export var span: float = 6000.0

## Base Y position (bottom of the silhouette).
@export var base_y: float = 800.0

## Maximum building height above base_y.
@export var max_height: float = 400.0

## Minimum building height.
@export var min_height: float = 80.0

## Width of each building segment.
@export var building_width: float = 60.0

## Gap between buildings (0 = no gap).
@export var gap: float = 8.0

## Random seed for deterministic generation.
@export var rng_seed: int = 42

## Whether to add window-like details (small brighter rectangles).
@export var add_windows: bool = false

## Window color (slightly brighter than the building).
var _window_color: Color = Color(0.3, 0.4, 0.6, 0.3)


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var points := PackedVector2Array()
	var x := -span * 0.5

	while x < span * 0.5:
		var w := building_width + rng.randf_range(-15, 15)
		var h := rng.randf_range(min_height, max_height)

		# Building body
		points.append(Vector2(x, base_y))
		points.append(Vector2(x, base_y - h))
		points.append(Vector2(x + w, base_y - h))
		points.append(Vector2(x + w, base_y))

		# Optional: antenna/spire on tall buildings
		if h > max_height * 0.7 and rng.randf() > 0.5:
			var antenna_h := rng.randf_range(20, 60)
			var antenna_x := x + w * 0.5
			points.append(Vector2(antenna_x - 2, base_y - h))
			points.append(Vector2(antenna_x, base_y - h - antenna_h))
			points.append(Vector2(antenna_x + 2, base_y - h))

		x += w + gap

	polygon = points

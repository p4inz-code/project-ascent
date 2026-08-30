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
	# Every sibling backdrop script (star_field.gd, parallax_ridge.gd,
	# floating_particles.gd) rebuilds unconditionally in _ready(). This was
	# the only one gated behind Engine.is_editor_hint() — meaning it looked
	# correct in the editor (where the hint is true) and silently built an
	# empty polygon in the actual shipped game (where it's always false).
	# The FarCity/MidCity skyline layers were invisible in every real
	# playthrough of all 25 levels until this fix.
	_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var points := PackedVector2Array()
	var window_points := PackedVector2Array()
	var window_polys: Array[PackedInt32Array] = []
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

		if add_windows:
			_add_windows(window_points, window_polys, rng, x, w, h)

		x += w + gap

	polygon = points

	var window_layer := get_node_or_null("Windows") as Polygon2D
	if add_windows:
		if window_layer == null:
			window_layer = Polygon2D.new()
			window_layer.name = "Windows"
			add_child(window_layer)
			if Engine.is_editor_hint():
				window_layer.owner = get_tree().edited_scene_root
		window_layer.color = _window_color
		window_layer.polygon = window_points
		window_layer.polygons = window_polys
	elif window_layer != null:
		window_layer.queue_free()


## Small brighter rectangles dotted across one building's face, as a single
## multi-contour addition to the shared Windows polygon (Polygon2D supports
## disjoint sub-shapes via `polygons`, indexing into one shared point array —
## far cheaper than a separate node per window).
func _add_windows(window_points: PackedVector2Array, window_polys: Array[PackedInt32Array],
		rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	var rows := int(h / 40.0)
	var cols := maxi(1, int(w / 25.0))
	for row in rows:
		for col in cols:
			if rng.randf() > 0.6:
				continue  # Not every window is lit — reads as a real building, not a grid.
			var wx := x + 6.0 + col * (w / cols)
			var wy := base_y - 14.0 - row * 40.0
			var ww := 8.0
			var wh := 12.0
			var base_idx := window_points.size()
			window_points.append(Vector2(wx, wy))
			window_points.append(Vector2(wx + ww, wy))
			window_points.append(Vector2(wx + ww, wy - wh))
			window_points.append(Vector2(wx, wy - wh))
			window_polys.append(PackedInt32Array([base_idx, base_idx + 1, base_idx + 2, base_idx + 3]))

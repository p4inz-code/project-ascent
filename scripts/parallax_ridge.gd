@tool
class_name ParallaxRidge
extends Polygon2D
## Procedurally generated mountain-ridge silhouette for the parallax backdrop.
##
## Draws one solid band: a jagged skyline along the top, filled straight down.
## Layers of these at different `Parallax2D` scroll scales, colours and heights
## give depth without shipping a single image file — which keeps the web payload
## at ~23 KB and means nothing has to be re-imported or licence-checked.
##
## The skyline is derived from `rng_seed`, so a given seed always produces the
## same mountains: the backdrop is stable across runs, and a screenshot taken by
## `tools/capture_run.gd` is comparable to the next one.

## Total width of the band. Made wide enough to cover the level at this layer's
## scroll scale, which avoids the seam a tiling `repeat_size` would introduce.
@export var span: float = 5200.0:
	set(value):
		span = value
		_rebuild()

## Horizontal distance between skyline vertices. Smaller = more detail.
@export var segment: float = 130.0:
	set(value):
		segment = maxf(value, 8.0)
		_rebuild()

## Height of the tallest peak above the baseline (px).
@export var peak_height: float = 240.0:
	set(value):
		peak_height = value
		_rebuild()

## How far the fill extends below the baseline (px). Just needs to reach past the
## bottom of the view.
@export var depth: float = 1400.0:
	set(value):
		depth = value
		_rebuild()

## 0 = smooth rolling hills, 1 = raw noise. Controls how much the per-vertex
## random heights are averaged with their neighbours.
@export_range(0.0, 1.0) var jaggedness: float = 0.55:
	set(value):
		jaggedness = value
		_rebuild()

## Changing this reshapes the whole ridge deterministically.
@export var rng_seed: int = 1:
	set(value):
		rng_seed = value
		_rebuild()


func _ready() -> void:
	_rebuild()


## Build the silhouette: random heights per vertex, smoothed toward their
## neighbours so peaks read as mountains rather than television static, then
## closed off with two bottom corners into a single convex-agnostic polygon.
func _rebuild() -> void:
	var count := int(span / segment) + 1
	if count < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(count)
	for i in count:
		raw[i] = rng.randf()

	# One smoothing pass. `jaggedness` blends between the smoothed and raw value,
	# so a single knob spans soft hills to sharp crags.
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(count + 2)
	var half_span := span * 0.5
	for i in count:
		var prev: float = raw[maxi(i - 1, 0)]
		var next: float = raw[mini(i + 1, count - 1)]
		var smoothed: float = (prev + raw[i] * 2.0 + next) * 0.25
		var height: float = lerpf(smoothed, raw[i], jaggedness)
		points[i] = Vector2(-half_span + float(i) * segment, -height * peak_height)
	points[count] = Vector2(-half_span + float(count - 1) * segment, depth)
	points[count + 1] = Vector2(-half_span, depth)
	polygon = points

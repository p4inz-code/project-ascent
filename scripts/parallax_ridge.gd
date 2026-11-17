# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
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
	var half_span := span * 0.5
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(count)
	for i in count:
		var prev: float = raw[maxi(i - 1, 0)]
		var next: float = raw[mini(i + 1, count - 1)]
		var smoothed: float = (prev + raw[i] * 2.0 + next) * 0.25
		heights[i] = lerpf(smoothed, raw[i], jaggedness) * peak_height
	# Pixel-art skyline: the slope between two vertices is walked in STEP_X columns and every height is snapped
	# to the art grid, so the ridge is a staircase of flat tops and vertical risers (no smooth diagonals, which
	# are what made the old ridges read as thin vector lines over a flat fill).
	var tops: Array = []      # [x0, x1, y] runs
	var x := -half_span
	while x < half_span:
		var f := (x + half_span) / segment
		var i0 := clampi(int(f), 0, count - 1)
		var i1 := mini(i0 + 1, count - 1)
		var t := f - float(i0)
		t = t * t * (3.0 - 2.0 * t)
		var y := -snappedf(lerpf(heights[i0], heights[i1], t), GRID)
		tops.append([x, minf(x + STEP_X, half_span), y])
		x += STEP_X
	var points := PackedVector2Array()
	for r in tops:
		points.append(Vector2(r[0], r[2]))
		points.append(Vector2(r[1], r[2]))
	points.append(Vector2(half_span, depth))
	points.append(Vector2(-half_span, depth))
	polygon = points
	_update_rim(tops)


## Art grid of the backdrop (two world art pixels; the backdrop is far away, so its pixels read a touch larger).
const GRID := 6.0
const STEP_X := 18.0


## The lit edge of every ridge as pixel blocks: a bright cap on each flat top and a mid-tone band under it.
## It separates each layer from the one behind it the way a rim light does in hand-drawn pixel backdrops.
func _update_rim(tops: Array) -> void:
	var old := get_node_or_null("Rim")
	if old != null and not (old is Polygon2D):
		old.free()
	for nm in ["Rim", "RimBand"]:
		var n := get_node_or_null(nm)
		if n == null:
			n = Polygon2D.new()
			n.name = nm
			add_child(n)
	var cap := get_node("Rim") as Polygon2D
	var band := get_node("RimBand") as Polygon2D
	var cap_pts := PackedVector2Array()
	var cap_polys: Array[PackedInt32Array] = []
	var band_pts := PackedVector2Array()
	var band_polys: Array[PackedInt32Array] = []
	for k in tops.size():
		var r: Array = tops[k]
		var y0: float = r[2]
		_quad(cap_pts, cap_polys, r[0], y0, r[1], y0 + GRID * 0.5)
		_quad(band_pts, band_polys, r[0], y0 + GRID * 0.5, r[1], y0 + GRID * 2.0)
		# a riser down to a lower neighbour catches light on its face too
		if k + 1 < tops.size() and float(tops[k + 1][2]) > y0:
			_quad(cap_pts, cap_polys, r[1] - GRID * 0.5, y0, r[1], float(tops[k + 1][2]))
	cap.polygon = cap_pts
	cap.polygons = cap_polys
	cap.color = Color(color.r, color.g, color.b, 1.0).lightened(0.30)
	band.polygon = band_pts
	band.polygons = band_polys
	band.color = Color(color.r, color.g, color.b, 1.0).lightened(0.12)


func _quad(pts: PackedVector2Array, polys: Array[PackedInt32Array], x0: float, y0: float, x1: float, y1: float) -> void:
	var b := pts.size()
	pts.append(Vector2(x0, y0))
	pts.append(Vector2(x1, y0))
	pts.append(Vector2(x1, y1))
	pts.append(Vector2(x0, y1))
	polys.append(PackedInt32Array([b, b + 1, b + 2, b + 3]))

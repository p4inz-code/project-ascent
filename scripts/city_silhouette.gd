# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
@tool
class_name CitySilhouette
extends Polygon2D
## The distant landmark skyline of a biome, as a pixel-art silhouette. Each act has its own `style`, so the sky
## tells you where you are before any platform does:
##   towers    blocks with antennas (the Spire's outskirts)
##   cranes    scrapyard cranes: a mast, a jib and a hanging hook
##   shards    ice or crystal shards, stepped triangles
##   rods      storm masts with cross-bars and a lit tip
##   chimneys  forge stacks with lit vents
##   pipes     great vertical pipes with elbows and flanges
##   core      stepped ziggurat towers with a glowing slit
## Everything is snapped to the backdrop grid. Lit windows (vents, tips) use `window_color`.

@export var span: float = 6000.0
## Base Y position (bottom of the silhouette).
@export var base_y: float = 800.0
@export var max_height: float = 400.0
@export var min_height: float = 80.0
## Width of each structure.
@export var building_width: float = 60.0
@export var gap: float = 8.0
@export var rng_seed: int = 42
@export var add_windows: bool = false
@export var style: String = "towers"
var window_color: Color = Color(0.3, 0.4, 0.6, 0.3)

const GRID := 6.0

var _pts := PackedVector2Array()
var _polys: Array[PackedInt32Array] = []
var _wpts := PackedVector2Array()
var _wpolys: Array[PackedInt32Array] = []


func _ready() -> void:
	# Must build in the game too (it was once gated on the editor hint and drew nothing in every playthrough).
	_rebuild()


func _s(v: float) -> float:
	return snappedf(v, GRID)


func _rect(x0: float, y0: float, x1: float, y1: float, lit: bool = false) -> void:
	var pts := _wpts if lit else _pts
	var polys := _wpolys if lit else _polys
	var b := pts.size()
	pts.append(Vector2(_s(x0), _s(y0)))
	pts.append(Vector2(_s(x1), _s(y0)))
	pts.append(Vector2(_s(x1), _s(y1)))
	pts.append(Vector2(_s(x0), _s(y1)))
	polys.append(PackedInt32Array([b, b + 1, b + 2, b + 3]))


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_pts = PackedVector2Array()
	_polys = []
	_wpts = PackedVector2Array()
	_wpolys = []
	var x := -span * 0.5
	while x < span * 0.5:
		var w := building_width + rng.randf_range(-15.0, 15.0)
		var h := rng.randf_range(min_height, max_height)
		match style:
			"cranes": _crane(rng, x, w, h)
			"shards": _shard(rng, x, w, h)
			"rods": _rod(rng, x, w, h)
			"chimneys": _chimney(rng, x, w, h)
			"pipes": _pipe(rng, x, w, h)
			"core": _ziggurat(rng, x, w, h)
			_: _tower(rng, x, w, h)
		x += w + gap + (rng.randf_range(0.0, w * 1.5) if style in ["cranes", "rods", "chimneys"] else 0.0)
	polygon = _pts
	polygons = _polys
	var lights := get_node_or_null("Windows") as Polygon2D
	if lights == null:
		lights = Polygon2D.new()
		lights.name = "Windows"
		add_child(lights)
	lights.color = window_color
	lights.polygon = _wpts
	lights.polygons = _wpolys
	lights.visible = add_windows


func _tower(rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	_rect(x, base_y - h, x + w, base_y)
	_rect(x + w * 0.2, base_y - h - 18.0, x + w * 0.8, base_y - h)
	if h > max_height * 0.7 and rng.randf() > 0.5:
		_rect(x + w * 0.5 - 3.0, base_y - h - 18.0 - rng.randf_range(24.0, 60.0), x + w * 0.5 + 3.0, base_y - h - 18.0)
	var rows := int(h / 36.0)
	for r in rows:
		for c in maxi(1, int(w / 24.0)):
			if rng.randf() < 0.3:
				_rect(x + 6.0 + c * 24.0, base_y - 24.0 - r * 36.0, x + 12.0 + c * 24.0, base_y - 12.0 - r * 36.0, true)


func _crane(rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	var mx := x + w * 0.5
	_rect(mx - 6.0, base_y - h, mx + 6.0, base_y)
	_rect(x - 10.0, base_y - 30.0, x + w + 10.0, base_y)
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var jib := rng.randf_range(90.0, 180.0)
	_rect(minf(mx, mx + dir * jib), base_y - h, maxf(mx, mx + dir * jib), base_y - h + 12.0)
	_rect(mx - dir * 30.0 - 12.0, base_y - h - 6.0, mx - dir * 30.0 + 12.0, base_y - h + 18.0)
	var hook_x := mx + dir * jib * 0.8
	var drop := rng.randf_range(40.0, 140.0)
	_rect(hook_x - 3.0, base_y - h + 12.0, hook_x + 3.0, base_y - h + 12.0 + drop)
	_rect(hook_x - 9.0, base_y - h + 12.0 + drop, hook_x + 9.0, base_y - h + 24.0 + drop)
	_rect(mx - 3.0, base_y - h - 12.0, mx + 3.0, base_y - h - 6.0, true)


func _shard(rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	# a stepped triangle, slightly leaning, with a smaller shard at its foot
	var steps := maxi(3, int(h / GRID / 3.0))
	var lean := rng.randf_range(-0.3, 0.3)
	for i in steps:
		var f := float(i) / float(steps)
		var half := w * 0.5 * (1.0 - f)
		var cxs := x + w * 0.5 + lean * h * f
		_rect(cxs - half, base_y - h * (f + 1.0 / steps), cxs + half, base_y - h * f + 1.0)
	_rect(x + w * 0.5 + lean * h - 3.0, base_y - h * 0.85, x + w * 0.5 + lean * h + 3.0, base_y - h * 0.7, true)
	if rng.randf() < 0.6:
		var sw := w * 0.5
		var sh := h * 0.4
		for i in 3:
			var f2 := float(i) / 3.0
			_rect(x + w - sw * 0.2 + sw * 0.5 * f2, base_y - sh * (f2 + 0.34), x + w + sw * (1.0 - 0.5 * f2), base_y - sh * f2 + 1.0)


func _rod(rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	var mx := x + w * 0.5
	_rect(mx - 4.0, base_y - h, mx + 4.0, base_y)
	_rect(mx - 18.0, base_y - 24.0, mx + 18.0, base_y)
	var y := base_y - h * 0.35
	while y > base_y - h + 30.0:
		var arm := rng.randf_range(12.0, 30.0)
		_rect(mx - arm, y, mx + arm, y + 6.0)
		y -= rng.randf_range(48.0, 80.0)
	_rect(mx - 3.0, base_y - h - 12.0, mx + 3.0, base_y - h, true)


func _chimney(rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	_rect(x, base_y - h, x + w, base_y)
	_rect(x - 6.0, base_y - h - 12.0, x + w + 6.0, base_y - h)
	_rect(x - 20.0, base_y - h * 0.3, x, base_y)
	var vy := base_y - h + 40.0
	while vy < base_y - 30.0:
		_rect(x + w * 0.3, vy, x + w * 0.7, vy + 6.0, true)
		vy += rng.randf_range(50.0, 90.0)


func _pipe(rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	var pw := maxf(18.0, w * 0.4)
	_rect(x, base_y - h, x + pw, base_y)
	# elbow across to the next pipe position, then a flange
	var run := rng.randf_range(40.0, 120.0)
	_rect(x, base_y - h, x + pw + run, base_y - h + pw)
	_rect(x + pw + run - pw, base_y - h, x + pw + run, base_y - h + pw + rng.randf_range(30.0, 90.0))
	var fy := base_y - 40.0
	while fy > base_y - h + 30.0:
		_rect(x - 6.0, fy, x + pw + 6.0, fy + 6.0)
		fy -= rng.randf_range(70.0, 120.0)
	_rect(x + pw * 0.4, base_y - h * 0.5, x + pw * 0.6, base_y - h * 0.5 + 6.0, true)


func _ziggurat(rng: RandomNumberGenerator, x: float, w: float, h: float) -> void:
	var tiers := 4
	for i in tiers:
		var f := float(i) / float(tiers)
		var inset := w * 0.18 * float(i)
		_rect(x + inset, base_y - h * (f + 1.0 / tiers), x + w - inset, base_y - h * f + 1.0)
	_rect(x + w * 0.5 - 3.0, base_y - h * 0.9, x + w * 0.5 + 3.0, base_y - h * 0.35, true)
	if rng.randf() < 0.5:
		_rect(x + w * 0.5 - 2.0, base_y - h - 40.0, x + w * 0.5 + 2.0, base_y - h)

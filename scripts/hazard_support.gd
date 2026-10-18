class_name HazardSupport
extends Node2D
## Draws what holds each hazard up: steel cables from a blade's hub or a pendulum's
## pivot to the platform edges either side of it, a strut and bracket under a shooter,
## and guy-wires for a timing gate. Nothing in the world should float with no reason
## to be there; this is the reason.
##
## Pure decoration (never collides, never moves), drawn behind the terrain, in the
## same pixel grid as everything else. Built once per level from the level data.

const PX := 3.0
const MAX_REACH := 460.0
const STEEL := Color(0.66, 0.72, 0.86)
const STEEL_DARK := Color(0.16, 0.18, 0.26)
const BOLT := Color(0.78, 0.82, 0.92)

## Each entry: {"kind": String, "points": Array[Vector2] (hazard attachment points),
## "anchors": Array[Vector2] (platform points it is tied to)}.
var _runs: Array = []


static func build(parent: Node, def, platform_rects: Array[Rect2]) -> HazardSupport:
	var node := HazardSupport.new()
	node.name = "HazardSupport"
	node.z_index = 0
	for b in def.spinning_blades:
		node._add("blade", [b.position], platform_rects, 2)
	for p in def.pendulums:
		node._add("pendulum", [p.position], platform_rects, 2)
	for s in def.shooters:
		node._add("shooter", [s.position], platform_rects, 1)
	for g in def.gates:
		var base: Vector2 = g[0]
		node._add("gate", [base, base + Vector2(0.0, -TimedGate.ZONE_HEIGHT)], platform_rects, 2)
	parent.add_child(node)
	# Behind the hazards themselves, on the same layer.
	parent.move_child(node, 0)
	return node


## Nearest top-edge points of platforms to the left and right of `from` (and one
## directly under/over it if a platform spans its x), within reach.
static func anchors_for(from: Vector2, rects: Array[Rect2], max_count: int) -> Array[Vector2]:
	var left_best := INF
	var left_pt := Vector2.ZERO
	var right_best := INF
	var right_pt := Vector2.ZERO
	var under_best := INF
	var under_pt := Vector2.ZERO
	for r in rects:
		var top_y := r.position.y
		if from.x >= r.position.x and from.x <= r.end.x:
			var d := absf(top_y - from.y)
			if d < under_best:
				under_best = d
				under_pt = Vector2(from.x, top_y)
			continue
		if r.end.x < from.x:
			var pt := Vector2(r.end.x - 6.0, top_y)
			var d2 := pt.distance_to(from)
			if d2 < left_best:
				left_best = d2
				left_pt = pt
		else:
			var pt2 := Vector2(r.position.x + 6.0, top_y)
			var d3 := pt2.distance_to(from)
			if d3 < right_best:
				right_best = d3
				right_pt = pt2
	var out: Array[Vector2] = []
	if left_best <= MAX_REACH:
		out.append(left_pt)
	if right_best <= MAX_REACH:
		out.append(right_pt)
	if out.size() < max_count and under_best <= MAX_REACH:
		out.append(under_pt)
	while out.size() > max_count:
		out.pop_back()
	return out


func _add(kind: String, points: Array, rects: Array[Rect2], max_count: int) -> void:
	for pt in points:
		var anchors := anchors_for(pt, rects, max_count)
		_runs.append({"kind": kind, "point": pt, "anchors": anchors})
	queue_redraw()


func _ready() -> void:
	queue_redraw()


func run_count() -> int:
	return _runs.size()


## Whether every run found at least one anchor (tests use this: nothing may float).
func all_supported() -> bool:
	for r in _runs:
		if (r["anchors"] as Array).is_empty():
			return false
	return true


func _snap(v: float) -> float:
	return roundf(v / PX) * PX


## A cable between two points with a gentle sag, drawn as short pixel segments.
func _cable(a: Vector2, b: Vector2, sag: float, width: float) -> void:
	var steps := 14
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		p.y += sin(t * PI) * sag
		p = Vector2(_snap(p.x), _snap(p.y))
		draw_line(prev + Vector2(0, 1), p + Vector2(0, 1), STEEL_DARK, width + 1.0)
		draw_line(prev, p, STEEL, width)
		prev = p


func _bolt(p: Vector2) -> void:
	var q := Vector2(_snap(p.x), _snap(p.y))
	draw_rect(Rect2(q - Vector2(PX * 3.0, PX * 3.0), Vector2(PX * 6.0, PX * 6.0)), STEEL_DARK)
	draw_rect(Rect2(q - Vector2(PX * 1.5, PX * 1.5), Vector2(PX * 3.0, PX * 3.0)), BOLT)


func _draw() -> void:
	for run in _runs:
		var pt: Vector2 = run["point"]
		var anchors: Array = run["anchors"]
		var kind: String = run["kind"]
		for a in anchors:
			match kind:
				"shooter":
					# A stiff strut with a brace, not a cable.
					draw_line(pt, a, STEEL_DARK, PX * 3.0)
					draw_line(pt, a, STEEL, PX * 2.0)
					var mid: Vector2 = pt.lerp(a, 0.5)
					draw_line(mid, Vector2(a.x, mid.y), STEEL, PX)
				"gate":
					_cable(pt, a, 6.0, PX * 2.0)
				"pendulum":
					# The pivot hangs from a gantry: two short stiff arms.
					_cable(pt, a, 10.0, PX * 2.0)
				_:
					_cable(pt, a, 10.0, PX * 2.0)
			_bolt(a)
		_bolt(pt)

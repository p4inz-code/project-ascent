class_name PipeRules
extends RefCounted
## Where a PipeTube may bridge a gap, and the automatic placement used by the levels.
##
## A pipe only ever ADDS floor, so it can never make a gap harder to cross; the rules
## are about it looking and feeling right: both ends flush with their platforms, a
## gap long enough to be worth a pipe and short enough that a gust never strands you,
## and plenty of clear space from every other obstacle.

const MIN_GAP := 170.0
const MAX_GAP := 320.0
const MAX_RISE := 70.0           # the ramp may climb (or fall) at most this over the gap
const MIN_RISE := 0.0
const CLEAR_FROM_OTHERS := 110.0
const OVERLAP := 10.0            # the pipe reaches this far onto each platform


## Reasons a pipe over this gap is NOT valid (empty = fine).
static func problems(left_rect: Rect2, right_rect: Rect2) -> Array[String]:
	var out: Array[String] = []
	var gap := right_rect.position.x - left_rect.end.x
	if gap < MIN_GAP:
		out.append("gap %d is narrower than %d" % [int(gap), int(MIN_GAP)])
	if gap > MAX_GAP:
		out.append("gap %d is wider than %d" % [int(gap), int(MAX_GAP)])
	if absf(left_rect.position.y - right_rect.position.y) > MAX_RISE:
		out.append("surfaces differ by %d (max %d)" % [int(absf(left_rect.position.y - right_rect.position.y)), int(MAX_RISE)])
	return out


## Automatic placement. Returns Array of [Vector2 left_end_at_floor_height, float length, float phase, float rise].
static func auto_place(level_number: int, platforms: Array, other_spans: Array,
		rng: RandomNumberGenerator = null) -> Array:
	var placed: Array = []
	if level_number < 9:
		return placed
	var route: Array = []
	for p in platforms:
		if String(p.name).contains("Wall"):
			continue
		if GateRules.is_stationary_solid(String(p.kind)):
			route.append(p)
	var candidates: Array = []
	for i in range(1, route.size() - 1):
		var a = route[i]
		var b = route[i + 1]
		var ra := Rect2(a.position - a.size * 0.5, a.size)
		var rb := Rect2(b.position - b.size * 0.5, b.size)
		if not problems(ra, rb).is_empty():
			continue
		var mid_x := (ra.end.x + rb.position.x) * 0.5
		var crowded := false
		for sp in other_spans:
			if absf(mid_x - float(sp[0])) < float(sp[1]) + CLEAR_FROM_OTHERS:
				crowded = true
				break
		if crowded:
			continue
		# The ramp starts on the left platform's surface and ends on the right one's.
		candidates.append([Vector2(ra.end.x - OVERLAP, ra.position.y),
			rb.position.x - ra.end.x + OVERLAP * 2.0, ra.position.y - rb.position.y])
	var want := clampi(1 + (level_number - 9) / 5, 1, 3)
	if candidates.size() < want + 1:
		want = maxi(candidates.size() - 1, 0)
	if want <= 0:
		return placed
	var usable: Array = candidates.slice(0, candidates.size() - 1)
	if rng != null:
		var order: Array = range(usable.size())
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]
			order[i] = order[j]
			order[j] = t
		var chosen: Array = []
		for idx in order:
			var ok := true
			for c in chosen:
				if absf((usable[idx][0] as Vector2).x - (usable[c][0] as Vector2).x) < 520.0:
					ok = false
					break
			if ok:
				chosen.append(idx)
			if chosen.size() >= want:
				break
		chosen.sort()
		if chosen.size() == want:
			for k in chosen.size():
				placed.append([usable[chosen[k]][0], usable[chosen[k]][1], rng.randf() * 4.0, usable[chosen[k]][2]])
			return placed
	for k in want:
		var idx := int(float(k) * float(usable.size()) / float(want))
		placed.append([usable[idx][0], usable[idx][1], float(k) * 0.9, usable[idx][2]])
	return placed

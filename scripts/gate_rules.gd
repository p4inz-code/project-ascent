class_name GateRules
extends RefCounted
## Where a TimedGate may stand, and the automatic placement used by the levels.
##
## A gate goes in the middle of a real gap, far enough from both flanking platforms
## that the player can stand on either one and wait, and the gap must be a jump the
## player already makes in this level (so a gate adds timing, never distance).

const MIN_GAP := 150.0        # narrower gaps leave no room for the beam and a clean landing
const MAX_GAP := 300.0
const EDGE_CLEARANCE := 45.0  # gate centre to either platform edge
const MAX_RISE := 90.0        # the two surfaces may differ by at most this
const MIN_CENTRE_DISTANCE := 300.0   # two gates: room for a platform to stand on between them
const CLEAR_FROM_HAZARD := 170.0   # horizontal room between a gate and any other lethal obstacle

## Reasons a gate at `pos` (centre x, surface y) is NOT safe. `platforms` are the
## level's solid, stationary platform rects (Rect2 each, top edge = surface).
static func problems(pos: Vector2, platforms: Array[Rect2]) -> Array[String]:
	var out: Array[String] = []
	var left := -INF
	var left_y := 0.0
	var right := INF
	var right_y := 0.0
	for r in platforms:
		if r.end.x <= pos.x and r.end.x > left:
			left = r.end.x
			left_y = r.position.y
		if r.position.x >= pos.x and r.position.x < right:
			right = r.position.x
			right_y = r.position.y
		# Never over a platform body.
		if pos.x > r.position.x - 10.0 and pos.x < r.end.x + 10.0:
			var hit_y := r.position.y - 5.0
			if pos.y >= hit_y - TimedGate.ZONE_HEIGHT and pos.y <= r.end.y:
				out.append("overlaps a platform")
	if left == -INF or right == INF:
		out.append("no platform on both sides")
		return out
	var gap := right - left
	if gap < MIN_GAP:
		out.append("gap %d is narrower than %d" % [int(gap), int(MIN_GAP)])
	if gap > MAX_GAP:
		out.append("gap %d is wider than %d" % [int(gap), int(MAX_GAP)])
	if pos.x - left < EDGE_CLEARANCE or right - pos.x < EDGE_CLEARANCE:
		out.append("closer than %d to a platform edge" % int(EDGE_CLEARANCE))
	if absf(left_y - right_y) > MAX_RISE:
		out.append("surfaces differ by %d" % int(absf(left_y - right_y)))
	# The gate stands at the higher of the two surfaces' height, so its base never
	# sinks below the platform the player takes off from.
	if pos.y > minf(left_y, right_y) + 1.0:
		out.append("base below the higher surface")
	return out


static func is_stationary_solid(kind: String) -> bool:
	return kind == "solid" or kind == "ice" or kind == "sticky"


## Automatic gate placement for a level: gaps between consecutive route platforms
## that satisfy problems(). Returns Array of [Vector2 pos, int kind, float phase].
static func auto_place(level_number: int, platforms: Array, hazard_spans: Array = [],
		rng: RandomNumberGenerator = null) -> Array:
	var placed: Array = []
	if level_number < 7:
		return placed
	var rects: Array[Rect2] = []
	var route: Array = []
	for p in platforms:
		if String(p.name).contains("Wall"):
			continue
		if is_stationary_solid(String(p.kind)):
			rects.append(Rect2(p.position - p.size * 0.5, p.size))
			route.append(p)
	var candidates: Array = []
	for i in range(1, route.size() - 1):
		var a = route[i]
		var b = route[i + 1]
		var left: float = a.position.x + a.size.x * 0.5
		var right: float = b.position.x - b.size.x * 0.5
		var gap := right - left
		if gap < MIN_GAP or gap > MAX_GAP:
			continue
		var surf_a: float = a.position.y - a.size.y * 0.5
		var surf_b: float = b.position.y - b.size.y * 0.5
		var pos := Vector2((left + right) * 0.5, minf(surf_a, surf_b))
		# Never on top of another lethal obstacle: keep the whole gap clear of them.
		var crowded := false
		for hs in hazard_spans:
			if absf(pos.x - float(hs[0])) < float(hs[1]) + CLEAR_FROM_HAZARD:
				crowded = true
				break
		if crowded:
			continue
		if problems(pos, rects).is_empty():
			candidates.append(pos)
	var want := clampi(1 + (level_number - 7) / 3, 1, 6)
	if candidates.size() < want + 3:
		want = maxi(candidates.size() - 3, 0)
	if want <= 0:
		return placed
	# Evenly spaced, skipping the opening and closing few gaps.
	var usable: Array = candidates.slice(2, candidates.size() - 1)
	if rng != null:
		var picked := _random_pick(level_number, usable, want, rng)
		if picked.size() == want:
			return picked
		# Too few gaps to keep them apart at random: fall back to the fixed, evenly spaced choice.
	for k in want:
		var idx := int(float(k) * float(usable.size()) / float(want))
		var kind := TimedGate.Kind.LASER if (level_number <= 10 or k % 2 == 0) else TimedGate.Kind.CRUSHER
		placed.append([usable[idx], kind, float(k) * 0.7])
	return placed


## The random version: the same number of gates, but in any of the valid gaps (never two in
## neighbouring gaps), with a random mix of kinds and a random starting phase. Every candidate
## has already passed problems(), so every choice is as safe as the fixed one.
static func _random_pick(level_number: int, usable: Array, want: int, rng: RandomNumberGenerator) -> Array:
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
			# Neighbouring gaps are fine when the platform between them is a real place to stand:
			# gate centres at least MIN_CENTRE_DISTANCE apart.
			if absf((usable[idx] as Vector2).x - (usable[c] as Vector2).x) < MIN_CENTRE_DISTANCE:
				ok = false
				break
		if ok:
			chosen.append(idx)
		if chosen.size() >= want:
			break
	chosen.sort()
	var placed: Array = []
	for k in chosen.size():
		var kind := TimedGate.Kind.LASER
		if level_number > 10 and rng.randf() < 0.5:
			kind = TimedGate.Kind.CRUSHER
		placed.append([usable[chosen[k]], kind, rng.randf() * 4.0])
	return placed

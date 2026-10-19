class_name TileRules
extends RefCounted
## Tile randomness for the hand-built levels: on every level load a few ordinary platforms turn
## into crumbling ones, a different few each time, so no two runs stand on the same tiles.
##
## Safety comes from where it is allowed, not from luck:
##  - the geometry never changes, so every jump that was possible still is;
##  - a crumbling tile gives the player almost a full second after landing, so it is only used
##    where nothing else demands a pause: wide enough to land and go, nowhere near a gate,
##    pipe, blade, pendulum, dart, lava or checkpoint, never near the start, the goal or a wall
##    section, and never two in a row.

const MIN_WIDTH := 100.0
const CLEAR_FROM_HAZARD := 260.0
const CLEAR_FROM_CHECKPOINT := 260.0
const CLEAR_FROM_WALL := 320.0
const SKIP_ENDS := 4                  # route platforms at either end are never changed
const FIRST_LEVEL := 6                # the early acts stay plain: they are teaching
const COLLAPSE_BUDGET := 9           # level 25


## How many tiles to change in a level (0 for the early acts).
static func count_for(level_number: int) -> int:
	if level_number < FIRST_LEVEL:
		return 0
	# The dawn gate (the last level) is the collapsing one: many more tiles give way.
	if level_number == 25:
		return COLLAPSE_BUDGET
	return clampi(1 + (level_number - FIRST_LEVEL) / 5, 1, 4)


## Turn some eligible solid platforms into "crumble". Returns the names changed.
static func jitter(level_number: int, def, hazard_spans: Array, rng: RandomNumberGenerator) -> Array[String]:
	var changed: Array[String] = []
	var want := count_for(level_number)
	if want <= 0 or rng == null:
		return changed
	var route: Array = []
	for p in def.platforms:
		var n := String(p.name)
		if n.contains("Wall") or n.contains("Decoy"):
			continue
		route.append(p)
	var walls: Array = []
	for p in def.platforms:
		if String(p.name).contains("Wall"):
			walls.append(p)
	var eligible: Array = []
	for i in range(SKIP_ENDS, route.size() - SKIP_ENDS):
		var p = route[i]
		if String(p.kind) != "solid" or p.size.x < MIN_WIDTH:
			continue
		if _near(p.position.x, hazard_spans, CLEAR_FROM_HAZARD, p.size.x * 0.5):
			continue
		var near_checkpoint := false
		for c in def.checkpoints:
			if absf(c.position.x - p.position.x) < CLEAR_FROM_CHECKPOINT + p.size.x * 0.5:
				near_checkpoint = true
				break
		if near_checkpoint:
			continue
		var near_wall := false
		for w in walls:
			if absf(w.position.x - p.position.x) < CLEAR_FROM_WALL + w.size.x * 0.5 + p.size.x * 0.5 \
					and w.position.y - w.size.y * 0.5 < p.position.y and w.position.y + w.size.y * 0.5 > p.position.y - 400.0:
				near_wall = true
				break
		if near_wall:
			continue
		for g in def.gates:
			if absf((g[0] as Vector2).x - p.position.x) < CLEAR_FROM_HAZARD + p.size.x * 0.5:
				near_checkpoint = true
		for pp in def.pipes:
			if absf((pp[0] as Vector2).x - p.position.x) < CLEAR_FROM_HAZARD + p.size.x * 0.5:
				near_checkpoint = true
		if near_checkpoint:
			continue
		eligible.append(i)
	# Random picks, never two neighbouring route platforms.
	for k in range(eligible.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = eligible[k]
		eligible[k] = eligible[j]
		eligible[j] = t
	var chosen: Array[int] = []
	for idx in eligible:
		var clash := false
		for c in chosen:
			if absi(int(idx) - c) < 2:
				clash = true
				break
		if clash:
			continue
		chosen.append(int(idx))
		if chosen.size() >= want:
			break
	for idx in chosen:
		route[idx].kind = "crumble"
		changed.append(String(route[idx].name))
	return changed


static func _near(x: float, spans: Array, clearance: float, half_width: float) -> bool:
	for s in spans:
		if absf(x - float(s[0])) < float(s[1]) + clearance + half_width:
			return true
	return false

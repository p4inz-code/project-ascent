class_name TrapGroup
extends Node2D
## A set of N trap slots of which exactly K are armed at any time, re-rolled on
## every attempt. Die and restart: the same group arms a different subset.
##
## "Random but always passable" is enforced two ways:
##
##  1. CONSTRUCTION. validate() only accepts a group whose slots all sit well
##     inside one platform with run-up and landing room on both sides, and are
##     spaced far enough apart that a jump over each one is always possible.
##  2. PROOF. A jump timed for EVERY slot works whether a slot is armed or not,
##     because spikes never change the player's trajectory. So if the all-armed
##     case is passable with that policy, every K-subset is. tests/test_trap_groups.gd
##     runs that policy on the real controller for every authored group, and
##     separately enumerates every K-subset to check the arming logic itself.

signal slot_hit

const MIN_PITCH := 230.0        # centre-to-centre; leaves >= ~185 of floor between spikes
const MIN_RUN_UP := 130.0       # floor before the first slot / after the last one
const MAX_SLOTS := 5            # keeps exhaustive checking trivially cheap

var arm_count: int = 1
var slots: Array[TrapSlot] = []
var rng := RandomNumberGenerator.new()
## The armed subset right now, as slot indices (for tests and the HUD-less debug view).
var armed_indices: Array[int] = []


## Build the slot nodes at these positions (centres, at surface height).
func setup(positions: Array[Vector2], p_arm_count: int) -> void:
	arm_count = clampi(p_arm_count, 0, positions.size())
	for pos in positions:
		var slot := TrapSlot.new()
		slot.position = pos
		slot.player_hit.connect(func(): slot_hit.emit())
		add_child(slot)
		slots.append(slot)
	rng.randomize()
	reroll()


## Choose a fresh random subset of exactly arm_count slots and arm only those.
func reroll() -> void:
	armed_indices = pick_subset(slots.size(), arm_count, rng)
	for i in slots.size():
		slots[i].armed = i in armed_indices


## K distinct indices out of N, uniformly. A partial Fisher-Yates, so it is exactly
## uniform over subsets (no rejection loop that could spin).
static func pick_subset(n: int, k: int, random: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for i in n:
		pool.append(i)
	var out: Array[int] = []
	for _step in clampi(k, 0, n):
		var j := random.randi_range(0, pool.size() - 1)
		out.append(pool[j])
		pool.remove_at(j)
	out.sort()
	return out


## Every K-subset of range(n), for exhaustive checks. n is capped at MAX_SLOTS.
static func all_subsets(n: int, k: int) -> Array:
	var out: Array = []
	if n > MAX_SLOTS or k < 0 or k > n:
		return out
	for mask in range(1 << n):
		var bits := 0
		for i in n:
			if mask & (1 << i):
				bits += 1
		if bits != k:
			continue
		var subset: Array[int] = []
		for i in n:
			if mask & (1 << i):
				subset.append(i)
		out.append(subset)
	return out


## Reasons a group is NOT safe to ship, given the level's solid platform rectangles
## (Rect2 each, in world space). Empty means valid.
static func problems(positions: Array[Vector2], p_arm_count: int, platforms: Array[Rect2]) -> Array[String]:
	var out: Array[String] = []
	if positions.is_empty():
		out.append("no slots")
		return out
	if positions.size() > MAX_SLOTS:
		out.append("more than %d slots" % MAX_SLOTS)
	if p_arm_count < 1 or p_arm_count > positions.size():
		out.append("arm_count %d is outside 1..%d" % [p_arm_count, positions.size()])
	# Every slot must sit on ONE platform surface, with room either side.
	var host := -1
	for i in positions.size():
		var found := false
		for pi in platforms.size():
			var r := platforms[pi]
			if absf(positions[i].y - r.position.y) > 1.0:
				continue
			var half := TrapSlot.WIDTH * 0.5
			if positions[i].x - half - MIN_RUN_UP >= r.position.x \
					and positions[i].x + half + MIN_RUN_UP <= r.end.x:
				found = true
				if host == -1:
					host = pi
				elif host != pi:
					out.append("slots span more than one platform")
				break
		if not found:
			out.append("slot %d lacks %d px of floor on both sides" % [i, int(MIN_RUN_UP)])
	var xs: Array[float] = []
	for p in positions:
		xs.append(p.x)
	xs.sort()
	for i in range(1, xs.size()):
		if xs[i] - xs[i - 1] < MIN_PITCH:
			out.append("slots %d and %d are closer than %d px" % [i - 1, i, int(MIN_PITCH)])
	return out

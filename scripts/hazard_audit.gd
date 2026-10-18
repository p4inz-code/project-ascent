class_name HazardAudit
extends RefCounted
## The rules that keep lethal obstacles meaningful instead of messy: hard and
## rage-inducing, but never random, stacked, or impossible to read.
##
##  1. NO STACKING. Two lethal things never share the same patch of screen. A blade
##     with a dart lane through it, or a pendulum on top of a laser, is noise.
##  2. EVERY HAZARD HAS A LANE. Shooters fire along a lane that no other hazard crosses.
##  3. THEY PUNISH A MISTAKE OR GUARD A GAP. Blades and pendulums hang close under the
##     surface line (see test_hazard_placement) so they read as "do not fall here".
##  4. THEY ARE VISIBLY HELD UP (HazardSupport draws cables, struts and brackets).
##
## repair() fixes a level's definitions in place, deterministically, and reports
## what it did, so the data files can stay readable and the result is always clean.

const CLEARANCE := 50.0       # empty space kept between two lethal footprints
const LANE_HALF := 16.0       # half-height of a shooter's dart lane
const SHIFT_STEP := 30.0
const MAX_SHIFT := 180.0


## A lethal footprint as a circle: [kind, centre, radius].
static func footprints(def) -> Array:
	var out: Array = []
	for b in def.spinning_blades:
		out.append(["blade", b.position, b.radius + 8.0])
	for p in def.pendulums:
		# The bob sweeps an arc; cover the lower half of it.
		var half_span: float = p.arm_length * sin(deg_to_rad(p.max_angle_deg))
		var drop: float = p.arm_length * 0.8
		out.append(["pendulum", p.position + Vector2(0.0, drop * 0.6), maxf(half_span, drop * 0.5) + 26.0])
	for l in def.lava_pits:
		out.append(["lava", l.position, maxf(l.size.x, 60.0) * 0.5])
	return out


static func _dist_to_circle(p: Vector2, c: Vector2, r: float) -> float:
	return p.distance_to(c) - r


## True if the horizontal dart lane of `shooter` passes through any footprint.
static func lane_blocked(shooter, prints: Array) -> bool:
	var dir: Vector2 = shooter.direction.normalized()
	var start: Vector2 = shooter.position
	var length := 620.0
	for f in prints:
		var c: Vector2 = f[1]
		# Distance from the circle's centre to the lane segment.
		var t := clampf((c - start).dot(dir), 0.0, length)
		var closest := start + dir * t
		if closest.distance_to(c) < float(f[2]) + LANE_HALF + CLEARANCE * 0.5:
			return true
	return false


## Problems in a level's lethal layout (empty = clean).
static func problems(def) -> Array[String]:
	var out: Array[String] = []
	var prints := footprints(def)
	for i in prints.size():
		for j in range(i + 1, prints.size()):
			var gap: float = (prints[i][1] as Vector2).distance_to(prints[j][1]) - float(prints[i][2]) - float(prints[j][2])
			if gap < 0.0:
				out.append("%s %d overlaps %s %d" % [prints[i][0], i, prints[j][0], j])
	for k in def.shooters.size():
		if lane_blocked(def.shooters[k], prints):
			out.append("shooter %d fires through another hazard" % k)
	return out


## Fix the level in place. Returns human-readable notes of every change.
static func repair(def, platforms: Array) -> Array[String]:
	var notes: Array[String] = []
	var rects: Array[Rect2] = []
	for p in platforms:
		if String(p.name).contains("Wall"):
			continue
		rects.append(Rect2(p.position - p.size * 0.5, p.size))

	# Overlapping blades / pendulums / lava: keep the first, drop the later one.
	var changed := true
	while changed:
		changed = false
		var prints := footprints(def)
		for i in prints.size():
			for j in range(i + 1, prints.size()):
				var gap: float = (prints[i][1] as Vector2).distance_to(prints[j][1]) - float(prints[i][2]) - float(prints[j][2])
				if gap < 0.0 and prints[j][0] != "lava":
					notes.append("removed overlapping %s at %s" % [prints[j][0], prints[j][1]])
					_remove_footprint(def, String(prints[j][0]), j)
					changed = true
					break
			if changed:
				break

	# Shooters: slide the dart lane clear of other hazards, or drop the shooter.
	var prints2 := footprints(def)
	var keep: Array = []
	for s in def.shooters:
		var original_y: float = s.position.y
		var fixed := not lane_blocked(s, prints2)
		if not fixed:
			var offsets: Array[float] = []
			var d := SHIFT_STEP
			while d <= MAX_SHIFT:
				offsets.append(d)
				offsets.append(-d)
				d += SHIFT_STEP
			for off in offsets:
				s.position.y = original_y + off
				if not lane_blocked(s, prints2) and not _inside_platform(s.position, rects):
					fixed = true
					notes.append("moved a shooter's lane by %d" % int(off))
					break
		if fixed:
			keep.append(s)
		else:
			s.position.y = original_y
			notes.append("removed a shooter at %s (no clear lane)" % s.position)
	def.shooters.clear()
	for kept in keep:
		def.shooters.append(kept)
	return notes


static func _inside_platform(p: Vector2, rects: Array[Rect2]) -> bool:
	for r in rects:
		if r.grow(10.0).has_point(p):
			return true
	return false


## Remove footprint index `idx` (indexing as footprints() lists them).
static func _remove_footprint(def, kind: String, idx: int) -> void:
	var nb: int = def.spinning_blades.size()
	var np: int = def.pendulums.size()
	if kind == "blade":
		def.spinning_blades.remove_at(idx)
	elif kind == "pendulum":
		def.pendulums.remove_at(idx - nb)
	else:
		def.lava_pits.remove_at(idx - nb - np)

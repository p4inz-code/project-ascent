class_name MachineWorld
extends RefCounted
## The scene-free description of a machine, as MachineSim sees it: solid rectangles, belts, air
## jets and timed hazards. The same MachineSpec builds both this and the real nodes, and
## tests/test_machine_build.gd checks the two agree.

const COL := 256.0

## Solid rectangles (the player stands on and bumps into these).
var solids: Array[Rect2] = []
## Conveyor tops: {rect: Rect2 (the standing surface strip), speed: float (px/s, signed)}.
var belts: Array = []
## Slippery floor strips: {rect, slip} (a multiplier on the ground accel/decel times, like ice).
var slips: Array = []
## Air jets: {rect, speed (px/s up, positive number), accel, period, on_time, phase} where period 0
## means always on. A jet only acts while ON.
var jets: Array = []
## Hazards: {rect, kind: "chip"|"kill", period, active, phase, name}. period 0 = always active.
## A cyclic hazard is dangerous in the last `active` seconds of each period (the tell sits just
## before, see MachinePieces).
var hazards: Array = []
var kill_y: float = 2400.0
var goal: Rect2 = Rect2()

var _grid: Dictionary = {}
var _built: bool = false


func add_solid(r: Rect2) -> void:
	solids.append(r)
	_built = false


func finalize() -> void:
	_grid.clear()
	for i in solids.size():
		var r := solids[i]
		var c0 := int(floor(r.position.x / COL))
		var c1 := int(floor(r.end.x / COL))
		for c in range(c0, c1 + 1):
			if not _grid.has(c):
				_grid[c] = []
			_grid[c].append(i)
	_built = true


func first_solid_overlap(rect: Rect2) -> Rect2:
	if not _built:
		finalize()
	var c0 := int(floor(rect.position.x / COL))
	var c1 := int(floor(rect.end.x / COL))
	for c in range(c0, c1 + 1):
		var list = _grid.get(c)
		if list == null:
			continue
		for i in list:
			var s: Rect2 = solids[i]
			if rect.position.x < s.end.x and rect.end.x > s.position.x \
					and rect.position.y < s.end.y and rect.end.y > s.position.y:
				return s
	return Rect2()


func belt_under(box: Rect2) -> float:
	for b in belts:
		var r: Rect2 = b["rect"]
		# The strip sits on the belt top; the box feet are on it when they overlap in x and touch in y.
		if box.end.x > r.position.x and box.position.x < r.end.x \
				and absf(box.end.y - r.position.y) < 2.5:
			return float(b["speed"])
	return 0.0


func slip_under(box: Rect2) -> float:
	for b in slips:
		var r: Rect2 = b["rect"]
		if box.end.x > r.position.x + 2.0 and box.position.x < r.end.x - 2.0 				and absf(box.end.y - r.position.y) < 2.5:
			return float(b["slip"])
	return 1.0


static func cyclic_active(h: Dictionary, t: float) -> bool:
	var period: float = h.get("period", 0.0)
	if period <= 0.0:
		return true
	var ph := fposmod(t + float(h.get("phase", 0.0)), period)
	return ph >= period - float(h.get("active", 0.5))


static func cyclic_telling(h: Dictionary, t: float) -> bool:
	var period: float = h.get("period", 0.0)
	if period <= 0.0:
		return false
	var ph := fposmod(t + float(h.get("phase", 0.0)), period)
	var tell: float = h.get("tell", 0.8)
	var active: float = h.get("active", 0.5)
	return ph >= period - active - tell and ph < period - active


func apply_zones(sim: MachineSim) -> void:
	var box := sim.box()
	for j in jets:
		var r: Rect2 = j["rect"]
		if not (box.position.x < r.end.x and box.end.x > r.position.x \
				and box.position.y < r.end.y and box.end.y > r.position.y):
			continue
		var period: float = j.get("period", 0.0)
		if period > 0.0:
			var ph := fposmod(sim.t + float(j.get("phase", 0.0)), period)
			if ph >= float(j.get("on_time", period)):
				continue
		var speed: float = j["speed"]
		var accel: float = j.get("accel", 4200.0)
		if sim.vel.y > -speed:
			sim.vel.y = maxf(sim.vel.y - accel * MachineSim.DT, -speed)
			sim.on_floor = false


func check_hazards(sim: MachineSim) -> void:
	if sim.dead:
		return
	var box := sim.box()
	for h in hazards:
		var r: Rect2 = h["rect"]
		if h.has("vx"):
			# a moving hazard (the collapse front): its rect slides right with the sim clock
			r.position.x += float(h["vx"]) * sim.t
		if not (box.position.x < r.end.x and box.end.x > r.position.x \
				and box.position.y < r.end.y and box.end.y > r.position.y):
			continue
		if not cyclic_active(h, sim.t):
			continue
		if h["kind"] == "kill":
			sim.kill(String(h.get("name", "hazard")))
			return
		sim.chip(r.get_center().x)
		if sim.dead:
			return

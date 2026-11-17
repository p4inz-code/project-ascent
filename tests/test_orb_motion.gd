extends SceneTree
## Moving cores: placements differ from roll to roll, most cores move, the motion function is bounded, every
## core stays under the roof, and each one can actually be caught (the simulator jumps for it from its ledge).

var _failures: int = 0
const RADIUS := 20.9      # Orb.RADIUS * 1.9


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _touches(box: Rect2, c: Vector2) -> bool:
	var nx := clampf(c.x, box.position.x, box.end.x)
	var ny := clampf(c.y, box.position.y, box.end.y)
	return Vector2(nx, ny).distance_to(c) <= RADIUS


## Can a player starting on the ledge catch this core? Tries waits, both directions, and standing jumps.
func _catchable(world: MachineWorld, nk: Dictionary) -> bool:
	var r: Rect2 = nk["rect"]
	var base: Vector2 = nk["orb"]
	var drift: Vector2 = nk.get("drift", Vector2.ZERO)
	var period: float = float(nk.get("period", 2.6))
	var phase: float = float(nk.get("phase", 0.0))
	for wait in range(0, 40, 2):
		for dir in [0.0, 1.0, -1.0]:
			var sim := MachineSim.new(world, Vector2(r.get_center().x, r.position.y - MachineSim.HALF.y - 1.0), 0.0)
			var jumped := false
			for f in 150:
				var move := 0.0
				var jp := false
				if f >= wait:
					move = dir
					var at_edge: bool = (dir > 0.0 and sim.pos.x >= r.end.x - 6.0) or (dir < 0.0 and sim.pos.x <= r.position.x + 6.0) or dir == 0.0
					if not jumped and at_edge and sim.on_floor:
						jumped = true
						jp = true
				sim.step(move, jp, jumped, false)
				if _touches(sim.box(), base + Orb.offset_at(sim.t, drift, period, phase)):
					return true
				if sim.dead:
					break
	return false


func _run() -> void:
	_check("a still core does not move", Orb.offset_at(1.3, Vector2.ZERO, 2.6, 0.0) == Vector2.ZERO)
	var far := 0.0
	for i in 200:
		far = maxf(far, absf(Orb.offset_at(float(i) * 0.05, Vector2(130.0, 0.0), 2.6, 0.7).x))
	_check("a sweeping core never leaves its sweep (max %.0f of 130)" % far, far <= 130.0 and far > 120.0)
	var kinds := {}
	var total := 0
	var uncatchable: Array = []
	var roof_bad := 0
	var places := {}
	for level in [7, 12, 18, 23, 28, 37]:
		for sd in 6:
			var spec := MachineGen.roll(level, 300 + sd * 11)
			var world := MachinePieces.build_world(spec)
			var sig := ""
			for nk in spec["nooks"]:
				total += 1
				kinds[nk["kind"]] = int(kinds.get(nk["kind"], 0)) + 1
				sig += "%d:%s " % [int(nk["cell"]), nk["kind"]]
				var top: float = float(nk["orb"].y) - absf(float(nk["drift"].y)) - 11.0
				if top < MachinePieces.CEIL_Y + 4.0:
					roof_bad += 1
				if not _catchable(world, nk):
					uncatchable.append("L%d s%d %s" % [level, sd, nk["kind"]])
			places["%d|%s" % [level, sig]] = true
	_check("every core can be caught from its ledge (%d of %d) %s" % [total - uncatchable.size(), total, str(uncatchable.slice(0, 4))], uncatchable.is_empty())
	_check("no core pokes into the roof", roof_bad == 0)
	_check("cores come in all three kinds %s" % str(kinds), kinds.has("still") and kinds.has("sweep") and kinds.has("bob"))
	_check("most cores move (%d of %d are not still)" % [total - int(kinds.get("still", 0)), total], float(int(kinds.get("still", 0))) / float(total) < 0.35)
	_check("placements differ from roll to roll (%d different layouts in 36 rolls)" % places.size(), places.size() >= 30)
	# (control) a core 200 px above its ledge is out of reach, so the check can fail
	var spec2 := MachineGen.roll(12, 300)
	var nk2: Dictionary = spec2["nooks"][0].duplicate()
	nk2["orb"] = Vector2(nk2["orb"].x, float(nk2["rect"].position.y) - 200.0)
	nk2["drift"] = Vector2.ZERO
	_check("(control) a core 200 px above its ledge cannot be caught", not _catchable(MachinePieces.build_world(spec2), nk2))
	print("[test_orb_motion] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)

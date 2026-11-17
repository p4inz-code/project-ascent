extends SceneTree
## The machine kit and its probe table.
##
##   * every piece the generator can draw has a table entry (a roll is lookups, never sweeps)
##   * every entry has a real window (the piece is passable) and the window obeys the physics:
##     wider obstacles leave narrower windows
##   * the table is not stale: a deterministic sample is re-derived from the sim and must match
##   * the nominal plan really clears the piece, noiselessly, in the simulator
## Negative controls: a spike row wider than a jump can span has no window at all, and a plan nudged
## outside the window fails.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _boot() -> void:
	await physics_frame
	_table()
	_physics_sanity()
	_stale_sample()
	_controls()
	_plans_clear()
	_probabilities()
	print("[test_machine_pieces] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _table() -> void:
	var table := MachineProbe.table()
	var sigs := MachineKit.all_signatures()
	var missing: Array = []
	var dead: Array = []
	for s in sigs:
		var k := MachineProbe.key_of(s["piece"], s["belt"])
		if not table.has(k):
			missing.append(k)
		elif float((table[k] as Dictionary).get("half", 0.0)) <= 0.0:
			dead.append(k)
	_check("the table has an entry for every piece the generator can draw (%d signatures)" % sigs.size(), missing.is_empty())
	if not missing.is_empty():
		print("  missing: ", missing.slice(0, 6))
	_check("every kit piece is passable (has a window): %s" % str(dead.slice(0, 6)), dead.is_empty())
	# No frame-perfect pieces: the kit may hold a few tight ones (the generator downgrades them where a belt
	# makes them tighter), but never one under 3 frames wide at the speed it is crossed at.
	var tight: Array = []
	var below_five := 0
	for s in sigs:
		var frames := MachineProbe.window_frames(s["piece"], s["belt"])
		if frames < 3.0:
			tight.append("%s (%.1f frames)" % [MachineProbe.key_of(s["piece"], s["belt"]), frames])
		if frames < MachineGen.MIN_WINDOW_FRAMES:
			below_five += 1
	_check("no piece has a window under 3 frames %s" % str(tight.slice(0, 4)), tight.is_empty())
	print("[test_machine_pieces] %d of %d kit entries are under %.0f frames (the generator never draws those)" % [below_five, sigs.size(), MachineGen.MIN_WINDOW_FRAMES])
	_check("the table holds no entries outside the kit (nothing stale left behind)", table.size() == sigs.size())


func _plan(piece: Dictionary, belt: Variant = null) -> Dictionary:
	return MachineProbe.plan_for(piece, belt)


func _physics_sanity() -> void:
	# Wider spike rows leave a narrower window to jump in.
	var last := 1e9
	var mono := true
	for w in MachineKit.SPIKE_WIDTHS:
		var half: float = float(_plan(MachineKit.spikes("L", w))["half"])
		if half > last + 0.01:
			mono = false
		last = half
	_check("wider spike rows give narrower windows", mono)
	var w_narrow: float = float(_plan(MachineKit.spikes("L", 80.0))["half"])
	var w_wide: float = float(_plan(MachineKit.spikes("L", MachineKit.SPIKE_WIDTHS[MachineKit.SPIKE_WIDTHS.size() - 1]))["half"])
	_check("the widest row is genuinely tight (%.0f px half window vs %.0f for the narrowest) yet never frame-perfect (>= 7 px, about 3 frames in all)" % [w_wide, w_narrow],
		w_wide <= 15.0 and w_wide >= 7.0 and w_narrow > w_wide)
	# A belt against the player makes the same obstacle easier or harder in a way the table records.
	var with_belt := MachineProbe.window_frames(MachineKit.spikes("L", 135.0), MachineKit.belt_of(160.0))
	var against := MachineProbe.window_frames(MachineKit.spikes("L", 135.0), MachineKit.belt_of(-160.0))
	_check("a belt changes how long the window lasts: a belt carrying you faster leaves fewer frames (with %.1f, against %.1f)" % [with_belt, against], against > with_belt * 2.0)
	# q is a probability and falls as the player gets sloppier.
	var piece := MachineKit.spikes("L", 135.0)
	var qe := MachineProbe.q_piece(piece, null, MachineBot.SIGMA_EXPERT)
	var qm := MachineProbe.q_piece(piece, null, MachineBot.SIGMA_MEDIAN)
	var qn := MachineProbe.q_piece(piece, null, MachineBot.SIGMA_NOVICE)
	_check("q is in [0,1] and expert >= median >= novice (%.3f / %.3f / %.3f)" % [qe, qm, qn], qe >= qm and qm >= qn and qn >= 0.0 and qe <= 1.0)


func _stale_sample() -> void:
	# Re-derive a spread of entries from the sim and compare with the table.
	var sigs := MachineKit.all_signatures()
	var picks := [0, 7, 13, 21, 34, 45, 58, 66, 79, 90, sigs.size() - 1]
	var stale: Array = []
	var table := MachineProbe.table()
	for i in picks:
		if i >= sigs.size():
			continue
		var s: Dictionary = sigs[i]
		var fresh := MachineProbe.sweep(s["piece"], s["belt"])
		var k := MachineProbe.key_of(s["piece"], s["belt"])
		var cached: Dictionary = table.get(k, {})
		for field in ["half", "lead", "delta", "offset"]:
			if fresh.has(field) and (not cached.has(field) or absf(float(fresh[field]) - float(cached[field])) > 0.001):
				stale.append("%s.%s" % [k, field])
	_check("the table matches a fresh sweep of %d sampled pieces (stale: %s)" % [picks.size(), str(stale.slice(0, 4))], stale.is_empty())


func _controls() -> void:
	# A spike row wider than a jump can span has no clean window.
	var impossible := MachineProbe.sweep(MachineKit.spikes("L", 300.0), null)
	_check("(control) a 300 px spike row has no window: the sweep can fail", float(impossible["half"]) <= 0.0)
	# A plan outside the window fails in the sim.
	var piece := MachineKit.spikes("L", 135.0)
	var plan := _plan(piece)
	var spec := MachineProbe.probe_spec(piece, null)
	var lo_plan := {"lead": float(plan["lo"]) - 14.0, "hold": 22.0}
	var bad := MachineProbe.trial(spec, spec["cells"][1]["L"], lo_plan)
	var good := MachineProbe.trial(spec, spec["cells"][1]["L"], {"lead": float(plan["lead"]), "hold": 22.0})
	_check("the centred plan is clean and a plan 14 px outside the window is not", bool(good["clean"]) and not bool(bad["clean"]))


func _plans_clear() -> void:
	var cases := [
		MachineKit.spikes("L", 135.0), MachineKit.hump("L", MachineKit.HUMPS[1]), MachineKit.pit(170.0),
		MachineKit.flame(MachineKit.FLAMES[1], 0.0), MachineKit.jet(), MachineKit.gap(150.0),
		MachineKit.rspike(MachineKit.RSPIKE[1]), MachineKit.spikes("U", 100.0),
	]
	var all_ok := true
	for p in cases:
		var spec := MachineProbe.probe_spec(p, null)
		var lane: String = String(p.get("lane", "L"))
		var piece: Dictionary = (spec["cells"][1]["L"] if lane == "L" or p["k"] == "jet" else spec["cells"][1]["U"])
		var plan := _plan(p)
		var r := MachineProbe.trial(spec, piece, plan)
		if not bool(r["passed"]):
			all_ok = false
			print("  did not clear: ", MachineProbe.key_of(p, null), " -> ", r)
	_check("the nominal plan of every kind of piece clears it, noiselessly, in the sim", all_ok)


func _probabilities() -> void:
	# A hand-built level made only of the tightest spike rows must fall under the 3% floor, which is
	# exactly the case the generator rejects.
	var cells: Array = []
	for i in 40:
		var cx := MachinePieces.START_X + float(i) * MachinePieces.CELL_W
		cells.append({"x": cx, "L": {"k": "spikes", "lane": "L", "w": 150.0, "x": cx + 150.0}, "U": {"k": "none"}, "belt": null})
	var spec := {"cells": cells, "end_x": MachinePieces.START_X + 40.0 * MachinePieces.CELL_W}
	var med := MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)
	_check("(control) forty of the widest spike rows in a row are under the 3%% floor (p = %.4f)" % float(med["p"]),
		float(med["p"]) < MachineGen.P_FLOOR_MEDIAN)
	var easy: Array = []
	for i in 14:
		var cx2 := MachinePieces.START_X + float(i) * MachinePieces.CELL_W
		easy.append({"x": cx2, "L": {"k": "spikes", "lane": "L", "w": 80.0, "x": cx2 + 200.0}, "U": {"k": "none"}, "belt": null})
	var spec2 := {"cells": easy, "end_x": MachinePieces.START_X + 14.0 * MachinePieces.CELL_W}
	var med2 := MachineGen.best_route(spec2, MachineBot.SIGMA_MEDIAN)
	_check("fourteen of the easiest rows are comfortably above it (p = %.3f)" % float(med2["p"]), float(med2["p"]) > 0.3)

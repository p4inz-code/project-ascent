extends SceneTree
## Compares the table's pass probability q of every kit piece with the measured clean-clear rate of
## the noisy bot over many runs. A big gap means the probability model is optimistic or pessimistic
## for that piece. Not part of the suite (slow).   Godot --headless --path <project> --script res://tools/check_q_model.gd
func _initialize() -> void:
	var sig := 0.04
	var sigs := MachineKit.all_signatures()
	var total_dev := 0.0
	var n := 0
	for s in sigs:
		var piece: Dictionary = s["piece"]
		var belt = s["belt"]
		var q := MachineProbe.q_piece(piece, belt, sig)
		if q > 0.995 and String(piece["k"]) != "rspike_gap":
			continue
		var m := measure(piece, belt, sig, 250)
		total_dev += absf(q - m)
		n += 1
		print("%-36s q=%.3f measured=%.3f  %s" % [MachineProbe.key_of(piece, belt), q, m, "<<<" if absf(q - m) > 0.05 else ""])
	print("mean abs deviation over %d pieces: %.4f" % [n, total_dev / maxf(float(n), 1.0)])
	quit(0)

static func measure(piece: Dictionary, belt: Variant, sig: float, runs: int) -> float:
	var spec := MachineProbe.probe_spec(piece, belt)
	var lane: String = String(piece.get("lane", "L"))
	var start_lane := "U" if lane == "U" else "L"
	var events: Array = []
	for e in MachineBot.events_for(spec, [start_lane, start_lane, start_lane], start_lane):
		if int(e["cell"]) == 1:
			events.append(e)
	var wins := 0
	for k in runs:
		var world := MachinePieces.build_world(spec)
		var start_y := (MachinePieces.DECK_Y if start_lane == "U" else MachinePieces.FLOOR_Y) - MachineSim.HALF.y - 0.01
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + k
		var bot := MachineBot.new(world, events.duplicate(true), Vector2(MachineProbe.PROBE_X0 + 140.0, start_y), float(spec["end_x"]) - 120.0, sig, rng)
		var res := bot.run(30.0)
		var feet := bot.sim.pos.y + MachineSim.HALF.y
		var lane_ok := absf(feet - (MachinePieces.DECK_Y if start_lane == "U" else MachinePieces.FLOOR_Y)) < 6.0
		if bool(res["finished"]) and int(res["hits"]) == 0 and lane_ok:
			wins += 1
	return float(wins) / float(runs)

extends SceneTree
## DAWN's collapse front: it is built into the roll, the perfect bot outruns it on every sampled forge
## roll (so it only punishes waiting), and a player who stands still is caught (negative control).

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	await physics_frame
	var total := 0
	var caught: Array = []
	for sd in 20:
		var spec := MachineGen.roll(25, 700 + sd, 0.6)
		total += 1
		if not spec.has("front"):
			caught.append("s%d has no front" % sd)
			continue
		var world := MachinePieces.build_world(spec)
		var med := MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)
		var events := MachineBot.events_for(spec, med["route"], "L")
		var goal: Rect2 = spec["goal"]
		var bot := MachineBot.new(world, events, Vector2(200.0, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01), goal.position.x, 0.0, null, 0.0)
		var res := bot.run(200.0)
		if not bool(res["finished"]):
			caught.append("s%d %s at x=%.0f" % [sd, str(res["cause"]), float(res["x"])])
	_check("a perfect run outruns the collapse on %d forge rolls %s" % [total, str(caught.slice(0, 3))], caught.is_empty())
	# control: standing still is fatal
	var spec2 := MachineGen.roll(25, 700, 0.6)
	var world2 := MachinePieces.build_world(spec2)
	var sim := MachineSim.new(world2, Vector2(200.0, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01), 0.0)
	sim.on_floor = true
	for i in 1500:
		sim.step(0.0, false, false, false)
		if sim.dead:
			break
	_check("(control) a player who stands still is caught (%s)" % sim.death_cause, sim.dead and sim.death_cause == "collapse")
	_check("the front is slower than a slowed player (224 px/s) by more than 15 percent", 170.0 * 1.15 < 320.0 * 0.7)
	# the real node moves
	MachineRuntime.fixed_seed = 99
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 25)
	root.add_child(main)
	for i in 4:
		await physics_frame
	var machine := main.get_node("Machine") as MachineRuntime
	var cf: CollapseFront = null
	for c in machine.get_children():
		if c is CollapseFront:
			cf = c
	_check("level 25 builds a collapse front", cf != null)
	var player := main.get_node("Player") as Player
	player.global_position = Vector2(200.0, MachinePieces.FLOOR_Y - 30.0)
	player.velocity = Vector2(100.0, 0.0)
	await physics_frame
	var x0 := cf.position.x
	for i in 60:
		await physics_frame
	_check("it advances once the player moves (%.0f px in a second)" % (cf.position.x - x0), cf.position.x - x0 > 100.0)
	# heat vents: on the calm hinge cells, a slow of 30 percent while blowing, a gap never within 1.5 s of one
	var vents: Array = machine.spec.get("vents", [])
	_check("level 25 has heat vents (%d)" % vents.size(), vents.size() > 0)
	var vent_node: HeatVent = null
	for c in machine.get_children():
		if c is HeatVent:
			vent_node = c
	_check("the vents are built as real nodes", vent_node != null)
	var spacing_ok := true
	var hinge_ok := true
	for sd in 20:
		var sp := MachineGen.roll(25, 700 + sd, 0.6)
		for v in sp["vents"]:
			var ci := int((float(v["x"]) - MachinePieces.START_X) / MachinePieces.CELL_W)
			if ci % MachineGen.HINGE_EVERY != 0:
				hinge_ok = false
			var vend: float = float(v["x"]) + float(v["w"])
			var next_x: float = MachinePieces.START_X + float(ci + 1) * MachinePieces.CELL_W
			if (next_x - vend) / (320.0 * 0.7) < 1.5:
				spacing_ok = false
	_check("every vent sits on a calm hinge cell", hinge_ok)
	_check("the next cell is at least 1.5 s of slowed running past the vent", spacing_ok)
	vent_node._t = 0.0
	vent_node.phase = vent_node.period - vent_node.active + 0.2      # blowing now
	player.global_position = vent_node.global_position + Vector2(80.0, -30.0)
	player.velocity = Vector2.ZERO
	for i in 6:
		await physics_frame
	_check("(real player) standing in live heat caps speed at 70 percent (%.0f)" % player.effective_max_speed(), absf(player.effective_max_speed() - 224.0) < 1.0)
	player.global_position = vent_node.global_position + Vector2(900.0, -300.0)
	for i in 6:
		await physics_frame
	_check("(control) leaving the vent restores full speed (%.0f)" % player.effective_max_speed(), absf(player.effective_max_speed() - 320.0) < 1.0)
	main.queue_free()
	MachineRuntime.fixed_seed = 0
	print("[test_machine_front] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)

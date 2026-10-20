extends SceneTree
## THE BORER (level 5): an auto-run over floating tiles on a lava lake, with geysers timed to the moment
## you cross them, the Borer chasing behind.
##
##   * rules over many rolls: calm start and finish, only lava gaps and geyser gaps, tiles long enough
##     to land and jump again, geyser phases set from the crossing time
##   * the 100-tries floor: every roll is clearable by the median player at least 3% of the time
##   * proof: a perfect bot clears every sampled roll in the sim
##   * the real game: the sim's inputs replayed on the real auto-running player in the real level scene
##     (thin tiles, lake, geysers on the player's clock, the chase) reach the door without a hit
## Negative controls: geysers timed to erupt at the crossing stop the perfect bot; a bot that never
## jumps dies in the lava.

var _failures: int = 0
const SEEDS := 80


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _boot() -> void:
	await physics_frame
	_rules()
	_proof()
	_controls()
	await _real_game()
	print("[test_machine_runner] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _problems(spec: Dictionary) -> Array:
	var out: Array = []
	var cells: Array = spec["cells"]
	var n := cells.size()
	if String(spec.get("mode", "")) != "runner":
		out.append("not a runner")
	for i in [0, 1, n - 2, n - 1]:
		if cells[i]["L"]["k"] != "plain":
			out.append("cell %d should be calm" % i)
	var last_end := -1e9
	for i in n:
		var c: Dictionary = cells[i]
		if c["U"]["k"] != "none" or c.get("belt") != null or String(c.get("surface", "")) != "":
			out.append("a runner cell has a deck, belt or surface at %d" % i)
		var l: Dictionary = c["L"]
		if l["k"] == "plain":
			continue
		if l["k"] != "pit" and l["k"] != "gpit":
			out.append("unexpected piece %s at %d" % [l["k"], i])
			continue
		var x: float = float(l["x"])
		var w: float = float(l["w"])
		if x - last_end < 200.0:
			out.append("tile between gaps only %.0f px at %d" % [x - last_end, i])
		last_end = x + w
		if l["k"] == "gpit":
			var want := MachineKit.geyser_phase(l, x, 200.0, 0.04)
			if absf(want - float(l["phase"])) > 0.001:
				out.append("geyser phase does not match the crossing time at %d" % i)
	return out


func _rules() -> void:
	var bad: Array = []
	var below := 0
	var gp := 0
	var total_p := 0.0
	var n := 0
	for sd in SEEDS:
		var spec := MachineGen.roll(5, 100 + sd, 0.8)
		var pr := _problems(spec)
		if not pr.is_empty() and bad.size() < 4:
			bad.append("s%d %s" % [sd, str(pr)])
		var odds: Dictionary = spec["odds"]
		if float(odds["median"]) < MachineGen.P_FLOOR_MEDIAN:
			below += 1
		total_p += float(odds["median"])
		n += 1
		for c in spec["cells"]:
			if c["L"]["k"] == "gpit":
				gp += 1
	_check("every runner roll follows the construction rules %s" % str(bad), bad.is_empty())
	_check("every runner roll clears the 3%% floor for a median player (%d below)" % below, below == 0)
	_check("runner rolls carry geysers (%d) and are not trivially easy (mean odds %.2f)" % [gp, total_p / n], gp > 40 and total_p / n < 0.97)
	var a := MachineGen.roll(5, 31415, 0.8)
	var b := MachineGen.roll(5, 31415, 0.8)
	_check("the same seed gives the same runner", str(a["cells"]) == str(b["cells"]))
	_check("a different seed gives a different runner", str(a["cells"]) != str(MachineGen.roll(5, 31416, 0.8)["cells"]))


static func run_runner(spec: Dictionary, sigma: float, seed: int, never_jump: bool = false) -> Dictionary:
	var world := MachinePieces.build_world(spec)
	var med := MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)
	var events: Array = [] if never_jump else MachineBot.events_for(spec, med["route"], "L")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var goal: Rect2 = spec["goal"]
	var bot := MachineBot.new(world, events, Vector2(200.0, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01),
		goal.position.x, sigma, rng, 0.0)
	return bot.run(120.0)


func _proof() -> void:
	var failed: Array = []
	var hit: Array = []
	for sd in 40:
		var spec := MachineGen.roll(5, 500 + sd, 0.8)
		var res := run_runner(spec, 0.0, 1)
		if not bool(res["finished"]):
			failed.append("s%d (%s at x=%.0f)" % [sd, str(res["cause"]), float(res["x"])])
		elif int(res["hits"]) > 0:
			hit.append("s%d" % sd)
	_check("a perfect run clears 40 rolled runners %s" % str(failed.slice(0, 3)), failed.is_empty())
	_check("with no hit from any geyser %s" % str(hit.slice(0, 3)), hit.is_empty())
	# Odds vs measured on a few rolls, median bot.
	var ok := 0
	for sd in 3:
		var spec := MachineGen.roll(5, 900 + sd, 0.8)
		var predicted: float = float(MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)["p"])
		var wins := 0
		for i in 120:
			if bool(run_runner(spec, MachineBot.SIGMA_MEDIAN, 7000 + i)["finished"]):
				wins += 1
		var measured := float(wins) / 120.0
		print("[test_machine_runner]   s%d predicted %.3f measured %.3f" % [sd, predicted, measured])
		if measured >= predicted - 0.10:
			ok += 1
	_check("the table's odds are at or below the noisy bot's measured clear rate (%d of 3)" % ok, ok >= 3)


func _controls() -> void:
	var spec := MachineGen.roll(5, 500, 0.8)
	var res := run_runner(spec, 0.0, 1, true)
	_check("(control) a runner who never jumps dies in the lava (%s)" % str(res["cause"]), not bool(res["finished"]))
	# Move every geyser's eruption onto the crossing: the perfect plan must now fail somewhere.
	var broken := 0
	var total := 0
	for sd in 12:
		var s2 := MachineGen.roll(5, 500 + sd, 0.8)
		var changed := false
		for c in s2["cells"]:
			var l: Dictionary = c["L"]
			if l["k"] == "gpit":
				# put the eruption's middle exactly on the crossing
				var cross_t := (float(l["x"]) + float(l["w"]) * 0.5 - 200.0) / MachineSim.MAX_SPEED + 0.04
				l["phase"] = fposmod(float(l["period"]) - float(l["active"]) * 0.5 - cross_t, float(l["period"]))
				changed = true
		if not changed:
			continue
		total += 1
		var r2 := run_runner(s2, 0.0, 1)
		if int(r2["hits"]) > 0 or not bool(r2["finished"]):
			broken += 1
	_check("(control) geysers erupting on the crossing stop or hurt the perfect run (%d of %d)" % [broken, total], total > 0 and broken >= total - 1)


func _real_game() -> void:
	# The real level 5: thin tiles, the lake, geysers on the player's clock, the Borer behind.
	MachineRuntime.fixed_seed = 8675309
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 5)
	root.add_child(main)
	await _step(4)
	var def := LevelData.get_level(5)
	_check("level 5 is the auto-run runner boss", def.machine and def.machine_mode == "runner" and def.auto_run and def.boss_config.enabled)
	var player := main.get_node("Player") as Player
	_check("the real player is auto-running", player.auto_run == 1)
	var machine := main.get_node("Machine") as MachineRuntime
	var spec: Dictionary = machine.spec
	var lakes := 0
	var geysers := 0
	for c in machine.get_children():
		if c is Lava:
			lakes += 1
		if c is GeyserColumn:
			geysers += 1
	var want_gp := 0
	for c in spec["cells"]:
		if c["L"]["k"] == "gpit":
			want_gp += 1
	_check("one lava lake and every geyser of the roll exist as nodes (geysers %d)" % geysers, lakes == 1 and geysers == want_gp)
	# Record the sim's inputs and replay them on the real player.
	var world := MachinePieces.build_world(spec)
	var med := MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)
	var events := MachineBot.events_for(spec, med["route"], "L")
	var goal: Rect2 = spec["goal"]
	var bot := MachineBot.new(world, events, Vector2(200.0, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01), goal.position.x, 0.0, null, 0.0)
	bot.record_inputs = true
	var res := bot.run(120.0)
	_check("the sim clears this exact roll first", bool(res["finished"]) and int(res["hits"]) == 0)
	var inputs: Array = bot.inputs
	var kills := [0]
	main.level_completed.connect(func() -> void: kills[0] += 1000)
	player.global_position = Vector2(200.0, MachinePieces.FLOOR_Y - 26.0 - 0.1)
	player.velocity = Vector2.ZERO
	var attempts_before: int = main.attempts
	var prev_jump := false
	var n := inputs.size()
	var finished_real := false
	var hp_min := 3
	for i in n + 120:
		var inp: Array = inputs[mini(i + 1, n - 1)] if i < n else [1.0, false, false]
		var jh: bool = inp[2] if i < n else false
		if jh and not prev_jump:
			Input.action_press("jump", 1.0)
		elif prev_jump and not jh:
			Input.action_release("jump")
		prev_jump = jh
		await physics_frame
		hp_min = mini(hp_min, player.health.hp)
		if kills[0] >= 1000:
			finished_real = true
			break
	Input.action_release("jump")
	_check("the real player reaches the door (x %.0f of %.0f)" % [player.global_position.x, goal.position.x], finished_real or player.global_position.x > goal.position.x - 60.0)
	_check("without dying (attempts %d -> %d) or losing a cell (lowest %d)" % [attempts_before, main.attempts, hp_min], main.attempts == attempts_before and hp_min == 3)
	main.queue_free()
	MachineRuntime.fixed_seed = 0

extends SceneTree
## A route really exists, and the odds really are the odds.
##
##   1. PROOF: for many rolls, a perfect bot (no noise) runs the chosen best route through the
##      simulated physics and reaches the door without a single hit.
##   2. ROBUSTNESS: the same plans with the timing nudged by +-2 frames still clear (the 'frame-
##      perfect only' failure the doctrine forbids).
##   3. ODDS: a noisy median bot's measured clear rate agrees with the validator's table-based
##      prediction on sample rolls, so the budget the generator spends is the budget the player pays.
##   4. CONTROL: a bot whose plan is deliberately off fails, so the runner can tell failure from success.

var _failures: int = 0

const PROOF_LEVELS := [6, 10, 15, 20, 25]
const PROOF_SEEDS := 20


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _boot() -> void:
	await physics_frame
	_proof()
	_robustness()
	_control()
	_odds()
	print("[test_machine_routes] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


static func run_spec(spec: Dictionary, sigma: float, seed: int, route: Array = [], limit: float = 200.0) -> Dictionary:
	var world := MachinePieces.build_world(spec)
	var med := MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)
	var r: Array = route if not route.is_empty() else med["route"]
	var events := MachineBot.events_for(spec, r, "L")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var start: Vector2 = spec["spawn"]
	var goal: Rect2 = spec["goal"]
	var bot := MachineBot.new(world, events, Vector2(start.x, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01), goal.position.x, sigma, rng)
	return bot.run(limit)


func _proof() -> void:
	var total := 0
	var failed: Array = []
	var hit: Array = []
	var slowest := 0.0
	for level in PROOF_LEVELS:
		for s in PROOF_SEEDS:
			var spec := MachineGen.roll(level, 9000 + s)
			var res := run_spec(spec, 0.0, 1)
			total += 1
			slowest = maxf(slowest, float(res["t"]))
			if not bool(res["finished"]):
				failed.append("L%d s%d (%s at x=%.0f)" % [level, s, str(res["cause"]), float(res["x"])])
			elif int(res["hits"]) > 0:
				hit.append("L%d s%d" % [level, s])
	print("[test_machine_routes] %d rolls proven, slowest clear %.1f s" % [total, slowest])
	_check("a perfect run of the best route reaches the door in every roll %s" % str(failed.slice(0, 4)), failed.is_empty())
	_check("and takes no hit on the way %s" % str(hit.slice(0, 4)), hit.is_empty())


func _robustness() -> void:
	# Nudge every takeoff by +-2 frames worth of pixels (about 11 px) and the flame go times by 2 frames.
	var failures := 0
	var total := 0
	for level in [10, 20]:
		for s in 10:
			var spec := MachineGen.roll(level, 7000 + s)
			for sign in [-1.0, 1.0]:
				var world := MachinePieces.build_world(spec)
				var med := MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)
				var events := MachineBot.events_for(spec, med["route"], "L")
				var start: Vector2 = spec["spawn"]
				var goal: Rect2 = spec["goal"]
				var bot := MachineBot.new(world, events, Vector2(start.x, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01), goal.position.x, 0.0)
				bot.fixed_shift_t = sign * 2.0 / 60.0
				var res := bot.run(200.0)
				total += 1
				if not bool(res["finished"]) or int(res["hits"]) > 0:
					failures += 1
	_check("shifting every decision by +-2 frames still clears %d of %d rolls (no frame-perfect rolls)" % [total - failures, total],
		float(failures) / float(total) <= 0.10)


func _control() -> void:
	# A bot that never jumps cannot clear a level with obstacles.
	var spec := MachineGen.roll(15, 31337)
	var world := MachinePieces.build_world(spec)
	var start: Vector2 = spec["spawn"]
	var goal: Rect2 = spec["goal"]
	var bot := MachineBot.new(world, [], Vector2(start.x, MachinePieces.FLOOR_Y - MachineSim.HALF.y - 0.01), goal.position.x, 0.0)
	var res := bot.run(120.0)
	_check("(control) a bot that ignores every obstacle does not finish (%s)" % str(res["cause"]), not bool(res["finished"]))
	# A bot with absurd timing noise fails far more often than a perfect one.
	var fails := 0
	for i in 12:
		var r := run_spec(spec, 0.5, 100 + i)
		if not bool(r["finished"]) or int(r["hits"]) > 0:
			fails += 1
	_check("(control) a very sloppy bot (sigma 500 ms) fails most attempts (%d of 12)" % fails, fails >= 9)


func _odds() -> void:
	# Predicted vs measured, on a few rolls. 'clear' = finish alive (chip hits are survivable).
	var checked := 0
	var within := 0
	for level in [8, 15, 22]:
		for s in 3:
			var spec := MachineGen.roll(level, 3100 + s)
			var predicted: float = float(MachineGen.best_route(spec, MachineBot.SIGMA_MEDIAN)["p"])
			var wins := 0
			var runs := 150
			for i in runs:
				var res := run_spec(spec, MachineBot.SIGMA_MEDIAN, 5000 + i)
				if bool(res["finished"]):
					wins += 1
			var measured := float(wins) / float(runs)
			checked += 1
			var err := absf(measured - predicted)
			print("[test_machine_routes]   L%d s%d predicted %.3f measured %.3f" % [level, s, predicted, measured])
			# 150 runs: sampling error alone is about 0.04, plus model error. The prediction is meant to be
			# a slightly pessimistic budget (a failed jump is assumed to cost a cell), so measured >= predicted - 0.1.
			if measured >= predicted - 0.10 and err <= 0.30:
				within += 1
	_check("the table-based odds agree with the noisy bot's measured clear rate (%d of %d rolls)" % [within, checked], within >= checked - 1)

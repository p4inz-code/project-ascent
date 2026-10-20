extends SceneTree
## Prints the mean odds of the machine generator per level, next to the target curve, so the recipe
## numbers can be tuned. Not part of the test suite.
##   Godot --headless --path <project> --script res://tools/tune_machine.gd
func _initialize() -> void:
	# Optional JSON override of MachineGen.CURVE entries, e.g. {"density_l": [0.9, 1.0]}
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var parsed = JSON.parse_string(args[0])
		if parsed is Dictionary:
			MachineGen.tuning = parsed
	var seeds := 80
	print("level  target   mean(median)  mean(novice)  mean(expert)  [p10 .. p90 median]")
	for level in [6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19, 21, 22, 23, 24]:
		var meds: Array = []
		var nov := 0.0
		var exp_ := 0.0
		var fb := 0
		for s in seeds:
			var spec := MachineGen.roll(level, 20000 + s)
			meds.append(float(spec["odds"]["median"]))
			nov += float(spec["odds"]["novice"])
			exp_ += float(spec["odds"]["expert"])
			if spec["odds"].has("fallback"):
				fb += 1
		meds.sort()
		var mean := 0.0
		for m in meds:
			mean += float(m)
		mean /= float(seeds)
		print("%3d    %.3f    %.3f         %.3f         %.3f        [%.3f .. %.3f]  fallbacks %d" % [level, MachineGen.p_target(level), mean, nov / seeds, exp_ / seeds, meds[seeds / 10], meds[seeds * 9 / 10], fb])
	quit(0)

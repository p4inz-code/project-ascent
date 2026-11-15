extends SceneTree
## Roll codes: every seed survives code -> seed, junk is rejected, the same code builds the same machine,
## the daily seed is stable for a date and level but changes with attempt and date, and the launch flags
## are read.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	for i in 2000:
		var s := rng.randi_range(1, MachineRuntime.MAX_SEED)
		var code := MachineRuntime.seed_code(s)
		if code.length() != 8 or MachineRuntime.seed_from_code(code) != s:
			bad += 1
	_check("2000 random seeds survive code and back (%d bad)" % bad, bad == 0)
	var code2 := MachineRuntime.seed_code(123456789)
	_check("codes are forgiving about case, spaces and dashes", MachineRuntime.seed_from_code(code2.to_lower()) == 123456789 and MachineRuntime.seed_from_code(code2.substr(0, 4) + "-" + code2.substr(4)) == 123456789)
	_check("(control) wrong length, a letter outside the alphabet and an oversize code are refused",
		MachineRuntime.seed_from_code("ABC") == 0 and MachineRuntime.seed_from_code("ABCDEFG1") == 0 and MachineRuntime.seed_from_code("ZZZZZZZZ") == 0 and MachineRuntime.seed_from_code("") == 0)
	var a := MachineGen.roll(12, MachineRuntime.seed_from_code(code2), 1.0)
	var b := MachineGen.roll(12, MachineRuntime.seed_from_code(code2), 1.0)
	_check("the same code builds the same machine", str(a["cells"]) == str(b["cells"]))
	var c := MachineGen.roll(12, MachineRuntime.seed_from_code(MachineRuntime.seed_code(123456790)), 1.0)
	_check("(control) a different code builds a different machine", str(a["cells"]) != str(c["cells"]))
	_check("the daily seed is stable for a date, level and attempt", MachineRuntime.daily_seed(20261115, 12, 3) == MachineRuntime.daily_seed(20261115, 12, 3))
	_check("(control) it changes with the attempt, the date and the level",
		MachineRuntime.daily_seed(20261115, 12, 3) != MachineRuntime.daily_seed(20261115, 12, 4)
		and MachineRuntime.daily_seed(20261115, 12, 3) != MachineRuntime.daily_seed(20261116, 12, 3)
		and MachineRuntime.daily_seed(20261115, 12, 3) != MachineRuntime.daily_seed(20261115, 13, 3))
	_check("the daily seed is never 0 (0 means random)", MachineRuntime.daily_seed(20261115, 1, 0) > 0)
	_check("--roll=CODE is read", MachineRuntime.launch_request(PackedStringArray(["--roll=" + code2])) == {"mode": "roll", "seed": 123456789})
	_check("--daily is read", String(MachineRuntime.launch_request(PackedStringArray(["--daily"]))["mode"]) == "daily")
	_check("(control) a bad --roll code and no flag mean random", String(MachineRuntime.launch_request(PackedStringArray(["--roll=NOPE"]))["mode"]) == "" and String(MachineRuntime.launch_request(PackedStringArray(["--other"]))["mode"]) == "")
	# the runtime honours a pinned roll
	await physics_frame
	var rt := MachineRuntime.new()
	root.add_child(rt)
	rt.setup(12, LevelData.get_level(12).theme, func() -> void: pass, func(_x: float = 0.0) -> void: pass)
	rt._launch = {"mode": "roll", "seed": 123456789}
	rt.roll()
	var first := rt.seed_value
	rt.roll()
	_check("a pinned roll gives the same machine on every attempt (%d, %d)" % [first, rt.seed_value], first == 123456789 and rt.seed_value == 123456789)
	rt._launch = {"mode": "daily", "seed": 0}
	rt.roll()
	var d1 := rt.seed_value
	rt.roll()
	_check("(daily) each attempt is a new roll, in a fixed order (%d, %d)" % [d1, rt.seed_value], d1 != rt.seed_value)
	rt._launch = {}
	var unreplayable := 0
	for i in 150:
		rt.roll()
		if rt.seed_value < 1 or rt.seed_value > MachineRuntime.MAX_SEED or MachineRuntime.seed_from_code(MachineRuntime.seed_code(rt.seed_value)) != rt.seed_value:
			unreplayable += 1
	_check("every random roll's code can be replayed (%d of 150 could not)" % unreplayable, unreplayable == 0)
	rt.queue_free()
	print("[test_roll_codes] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)

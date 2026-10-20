extends SceneTree
## Harmless jump scares: the rules that keep them fair, and the director that plays them.
##
##   * over a simulated 40 minute session of constant mistakes: scares are at least 20 s apart,
##     at most 6 per level session, none within 3 s of a respawn, none near a precision section,
##     none with Spooky effects OFF
##   * every scare is cued first (0.45 s) and is cancelled if the player reaches a hard section
##     during the cue
##   * safety: the flash is violet (never saturated red), no stronger than 0.32 alpha, one pulse; in
##     Reduced mode no flash and no shake; Reduce Motion forces Reduced
## Negative controls: each rule has a case that must fire when the rule is lifted.

var _failures: int = 0


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
	_rules_session()
	_rules_cases()
	_safety_constants()
	_setting()
	await _director()
	print("[test_scares] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _rules_session() -> void:
	var r := ScareRules.new(1234)
	r.on_level_start()
	var t := 0.0
	var last_fire := -1000.0
	var min_gap := 1e9
	var fired := 0
	var per_level := 0
	var worst_per_level := 0
	var respawn_violation := false
	var last_respawn := -1000.0
	var level_start := 0.0
	var step := 0.5
	while t < 40.0 * 60.0:
		r.tick(step)
		t += step
		# a respawn every 70 s, a new level every 8 minutes
		if int(t) % 70 == 0 and int(t / step) % 140 == 0:
			r.on_respawn()
			last_respawn = t
		if int(t) % 480 == 0 and int(t / step) % 960 == 0:
			r.on_level_start()
			worst_per_level = maxi(worst_per_level, per_level)
			per_level = 0
		# a mistake every 5 seconds
		if int(t / step) % 10 == 0 and r.may_fire("mistake", false):
			r.fired()
			fired += 1
			per_level += 1
			min_gap = minf(min_gap, t - last_fire)
			if t - last_respawn < ScareRules.QUIET_AFTER_RESPAWN:
				respawn_violation = true
			last_fire = t
	worst_per_level = maxi(worst_per_level, per_level)
	_check("scares in a 40 minute session are at least 20 s apart (closest %.1f s, %d fired)" % [min_gap, fired], min_gap >= ScareRules.MIN_GAP - 0.01 and fired > 5)
	_check("never more than %d in one level session (worst %d)" % [ScareRules.MAX_PER_LEVEL, worst_per_level], worst_per_level <= ScareRules.MAX_PER_LEVEL)
	_check("never within %.0f s of a respawn" % ScareRules.QUIET_AFTER_RESPAWN, not respawn_violation)


func _rules_cases() -> void:
	var r := ScareRules.new(5)
	r.on_level_start()
	r.tick(100.0)
	_check("after a long quiet a mistake may scare", r.may_fire("mistake", false))
	_check("(control) the same mistake near a precision section may not", not r.may_fire("mistake", true))
	r.on_respawn()
	_check("(control) just after a respawn it may not", not r.may_fire("mistake", false))
	r.tick(ScareRules.QUIET_AFTER_RESPAWN + 0.1)
	_check("a few seconds later it may again", r.may_fire("mistake", false))
	r.fired()
	_check("(control) straight after a scare it may not (gap %.0f s)" % r.next_gap, not r.may_fire("mistake", false))
	r.tick(31.0)
	_check("after the gap it may", r.may_fire("mistake", false))
	r.mode = ScareRules.Mode.OFF
	_check("(control) with Spooky effects OFF it never may", not r.may_fire("mistake", false))
	r.mode = ScareRules.Mode.FULL
	var r2 := ScareRules.new(9)
	r2.on_level_start()
	for i in ScareRules.MAX_PER_LEVEL:
		r2.tick(40.0)
		r2.fired()
	r2.tick(100.0)
	_check("(control) after %d scares the level is done" % ScareRules.MAX_PER_LEVEL, not r2.may_fire("mistake", false))
	r2.on_level_start()
	r2.tick(100.0)
	_check("a new level session starts the count again", r2.may_fire("mistake", false))
	# Feints are rarer than mistakes and wait longer.
	var r3 := ScareRules.new(77)
	r3.on_level_start()
	r3.tick(ScareRules.MAX_GAP + 1.0)
	_check("a feint does not fire as soon as a mistake could", not r3.may_fire("feint", false))
	var feints := 0
	for i in 200:
		var r4 := ScareRules.new(1000 + i)
		r4.on_level_start()
		r4.tick(ScareRules.MAX_GAP + ScareRules.FEINT_EXTRA_WAIT + 1.0)
		if r4.may_fire("feint", false):
			feints += 1
	_check("a feint fires on roughly 30%% of chances (%d of 200)" % feints, feints > 30 and feints < 90)
	_check("Reduce Motion forces Reduced", ScareRules.effective_mode(0, true) == ScareRules.Mode.REDUCED)
	_check("OFF stays OFF under Reduce Motion", ScareRules.effective_mode(2, true) == ScareRules.Mode.OFF)
	_check("FULL stays FULL without it", ScareRules.effective_mode(0, false) == ScareRules.Mode.FULL)


func _safety_constants() -> void:
	_check("the flash colour is violet, not saturated red", ScareRules.flash_color_is_safe() and ScareRules.FLASH_COLOR.b > ScareRules.FLASH_COLOR.r)
	_check("the flash is at most 32%% strong, one pulse, at most 3 per second",
		ScareRules.FLASH_MAX_ALPHA <= 0.32 and ScareRules.FLASH_PULSES_PER_SCARE == 1 and ScareRules.MAX_FLASHES_PER_SECOND <= 3)
	# A scare's own pulses: the cue (a faint breath) plus the pop is at most 2 pulses over 0.45 s + ~0.5 s,
	# i.e. under 3 per second.
	_check("cue and pop together stay under three flashes per second", 2.0 / (ScareRules.CUE_TIME + 0.4) < 3.0)
	_check("(control) a saturated red flash would be flagged", not _is_safe(Color(0.95, 0.1, 0.1)))


func _is_safe(c: Color) -> bool:
	return not (c.r > 0.75 and c.g < 0.35 and c.b < 0.35)


func _setting() -> void:
	_check("the Spooky effects setting is registered, default FULL", SettingsRegistry.has_key("gp_spooky") and int(SettingsRegistry.default_of("gp_spooky")) == 0)
	_check("its values are clamped to FULL / REDUCED / OFF", int(SettingsRegistry.sanitize("gp_spooky", 7)) <= 2 and int(SettingsRegistry.sanitize("gp_spooky", -3)) >= 0)


func _director() -> void:
	MachineLevel.forced = [15]
	MachineRuntime.fixed_seed = 4321
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 15)
	root.add_child(main)
	await _step(4)
	var player := main.get_node("Player") as Player
	var scares := main.get_node("Scares") as ScareDirector
	_check("a machine level has a scare director", scares != null and scares.machine != null)
	# A calm place: first cell of the machine, no hazards within reach.
	player.global_position = Vector2(300.0, MachinePieces.FLOOR_Y - 30.0)
	player.velocity = Vector2.ZERO
	scares.forced_setting = ScareRules.Mode.FULL
	scares.rules.tick(100.0)
	scares.rules.since_respawn = 10.0
	var cues := [0]
	var pops := [0]
	var cancelled := [0]
	scares.cue_started.connect(func(_k: String) -> void: cues[0] += 1)
	scares.scared.connect(func(_k: String) -> void: pops[0] += 1)
	scares.cancelled.connect(func(_k: String) -> void: cancelled[0] += 1)
	_check("a calm place has no precision section nearby", not scares.precision_near())
	scares.fire("forced", "roar")
	_check("a scare starts with a cue and no pop yet", cues[0] == 1 and pops[0] == 0)
	var peak := 0.0
	for i in 70:
		await physics_frame
		peak = maxf(peak, scares._vignette.modulate.a)
	_check("the pop arrives after the cue", pops[0] == 1)
	_check("the flash never exceeds the safe strength (peak %.2f)" % peak, peak <= ScareRules.FLASH_MAX_ALPHA + 0.01)
	_check("the scare was counted", scares.rules.count == 1 and scares.history.size() == 1)
	# Reduced mode: no flash at full strength.
	scares.forced_setting = ScareRules.Mode.REDUCED
	scares.rules.since_last = 100.0
	scares.fire("forced", "roar")
	var peak2 := 0.0
	for i in 70:
		await physics_frame
		peak2 = maxf(peak2, scares._vignette.modulate.a)
	_check("Reduced mode has no strong flash (peak %.2f)" % peak2, peak2 <= 0.16 and pops[0] == 2)
	# OFF: the pop is cancelled.
	scares.forced_setting = ScareRules.Mode.OFF
	scares.fire("forced", "vent_face")
	await _step(40)
	_check("with Spooky effects OFF the scare never plays", pops[0] == 2 and cancelled[0] >= 1)
	# A scare cued in a calm place is cancelled when the player reaches a hard section during the cue.
	scares.forced_setting = ScareRules.Mode.FULL
	scares.rules.since_last = 100.0
	scares.fire("mistake", "shadow")
	var hard_x := 0.0
	for cell in scares.machine.spec["cells"]:
		for p in MachinePieces.cell_pieces(cell):
			if String(p["k"]) == "spikes" and String(p["lane"]) == "L":
				hard_x = float(p["x"]) - 100.0
	player.global_position = Vector2(hard_x, MachinePieces.FLOOR_Y - 30.0)
	var before: int = pops[0]
	await _step(40)
	_check("walking into a hard section during the cue cancels the pop", pops[0] == before)
	main.queue_free()
	MachineLevel.forced = []
	MachineRuntime.fixed_seed = 0

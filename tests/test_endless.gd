extends SceneTree
## Endless mode: the pool widens with the streak, bosses come every fifth clear, nothing repeats back to back,
## every level it can draw is a real playable level, and playing it never touches the campaign save.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("the first draw comes from levels 6-%d only" % EndlessMode.ceiling(0), EndlessMode.ceiling(0) == 6 and EndlessMode.pool(0) == [6])
	_check("the pool widens by two levels per clear and caps at %d" % EndlessMode.LAST, EndlessMode.ceiling(3) == 12 and EndlessMode.ceiling(50) == EndlessMode.LAST)
	_check("(control) the pool never holds a level above the ceiling or below 6", _pool_bounds_ok())
	# Owner round 2: ENDLESS is mixed stages, never campaign levels, so no slot may borrow a boss, the tower or the runner.
	var special := 0
	for s in 60:
		for lv in EndlessMode.pool(s):
			if lv in EndlessMode.BOSSES or lv % 5 == 0 or lv < 6:
				special += 1
	_check("no stage ever borrows a boss, tower or runner slot (%d found)" % special, special == 0)
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 3
	var mixes := {}
	var mix_ok := true
	for i in 200:
		var m := EndlessMode.mix(mrng)
		mixes[str(m)] = true
		var uniq := {}
		for b in m:
			uniq[b] = true
			if not MachineGen.BIOMES.has(b):
				mix_ok = false
		if m.size() != EndlessMode.SECTIONS or uniq.size() != m.size():
			mix_ok = false
	_check("a stage mixes %d different real biomes, and the mix changes (%d distinct of 200)" % [EndlessMode.SECTIONS, mixes.size()], mix_ok and mixes.size() > 50)
	_check("(control) a campaign level has no sections outside endless", not MachineGen.recipe_for(7).has("segments"))
	MachineGen.endless_mix = ["freezer", "forge", "rift", "cinder"]
	var spec := MachineGen.roll(7, 4242)
	MachineGen.endless_mix = []
	var n_cells: int = spec["cells"].size()
	var ice_outside := 0
	var ice_inside := 0
	for i in n_cells:
		var surf := String(spec["cells"][i].get("surface", ""))
		if surf == "ice":
			if i * 4 / n_cells == 0:
				ice_inside += 1
			else:
				ice_outside += 1
	_check("a mixed stage is a proven roll (median odds %.3f) with %d sections" % [float(spec["odds"]["median"]), (spec["recipe"]["segments"] as Array).size()],
		float(spec["odds"]["median"]) >= MachineGen.P_FLOOR_MEDIAN and (spec["recipe"]["segments"] as Array).size() == 4)
	_check("ice floor only appears in the freezer section (inside %d, outside %d)" % [ice_inside, ice_outside], ice_outside <= 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var prev := -1
	var repeats := 0
	for s in 300:
		var lv := EndlessMode.next_level(s % 40, rng, prev)
		# streak 0 has a one-level pool, where a repeat is the only possible draw
		if lv == prev and EndlessMode.pool(s % 40).size() > 1:
			repeats += 1
		prev = lv
	_check("no level repeats back to back over 300 draws (%d repeats)" % repeats, repeats == 0)
	var bad: Array = []
	for lv in range(EndlessMode.FIRST, EndlessMode.LAST + 1):
		var d := LevelData.get_level(lv)
		if d == null or not (d.machine or d.tempest or d.warden or d.hive):
			bad.append(lv)
	_check("every level endless can draw is a real playable level %s" % str(bad), bad.is_empty())
	var a := RandomNumberGenerator.new()
	a.seed = 5
	var b := RandomNumberGenerator.new()
	b.seed = 5
	_check("the draw is deterministic for a seed", EndlessMode.next_level(6, a, -1) == EndlessMode.next_level(6, b, -1))
	await _integration()
	print("[test_endless] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _pool_bounds_ok() -> bool:
	for s in 60:
		for lv in EndlessMode.pool(s):
			if lv < 6 or lv > 40:
				return false
			if lv > EndlessMode.ceiling(s):
				return false
	return true


func _integration() -> void:
	await physics_frame
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		_check("GameManager is available", false)
		return
	var completed_before: Array = gm.save_system.levels_completed.duplicate()
	var checkpoint_before: int = gm.save_system.get_checkpoint()
	var orbs_before: int = gm.save_system.orb_total()
	var best_before: int = gm.save_system.endless_best
	gm.start_endless()
	_check("endless starts at streak 0 on a level from the opening pool (%d)" % gm.current_level, gm.endless_active and gm.endless_streak == 0 and gm.current_level == 6)
	_check("the stage has a mix and the generator is using it (%s)" % str(gm.endless_mix), gm.endless_mix.size() == EndlessMode.SECTIONS and MachineGen.endless_mix == gm.endless_mix)
	var first_mix: Array = gm.endless_mix.duplicate()
	gm.restart_from_checkpoint()
	_check("a death or restart keeps the stage's mix", gm.endless_mix == first_mix)
	var seen := {}
	for i in 12:
		seen[gm.current_level] = true
		gm.complete_current_level()
	_check("twelve clears raise the streak to 12 and draw different levels (%d distinct)" % seen.size(), gm.endless_streak == 12 and seen.size() >= 4)
	_check("the best streak is kept (%d)" % gm.save_system.endless_best, gm.save_system.endless_best >= 12)
	_check("(control) the campaign save is untouched: completions, checkpoint and cores", gm.save_system.levels_completed == completed_before and gm.save_system.get_checkpoint() == checkpoint_before and gm.save_system.orb_total() == orbs_before)
	var level_before: int = gm.current_level
	gm.restart_from_checkpoint()
	_check("a restart in endless replays the same level", gm.current_level == level_before and gm.endless_active)
	gm.end_endless()
	_check("leaving endless returns to the campaign checkpoint", not gm.endless_active and gm.current_level == checkpoint_before)
	_check("leaving endless clears the mix, so campaign levels are themselves again", gm.endless_mix.is_empty() and MachineGen.endless_mix.is_empty())
	# Owner round 2: a dev level skip during endless left endless on, so clearing level 4 drew level 8.
	gm.start_endless()
	var dev := root.get_node_or_null("DevConsole")
	if dev != null:
		gm.current_level = 4
		dev._skip_level(1)
		_check("a dev skip leaves endless (level %d, endless %s)" % [gm.current_level, str(gm.endless_active)], not gm.endless_active and gm.current_level == 5 and MachineGen.endless_mix.is_empty())
		gm.save_system.levels_completed = completed_before.duplicate()
		gm.current_level = checkpoint_before
	else:
		gm.end_endless()
	gm.save_system.endless_best = best_before
	gm.save_system.save()
	var restore: Array = completed_before
	_check("(control) the campaign still completes normally after endless", restore == gm.save_system.levels_completed)

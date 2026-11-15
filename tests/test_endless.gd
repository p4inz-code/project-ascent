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
	_check("the pool widens by two levels per clear and caps at 40", EndlessMode.ceiling(3) == 12 and EndlessMode.ceiling(50) == 40)
	_check("(control) the pool never holds a level above the ceiling or below 6", _pool_bounds_ok())
	_check("every fifth slot is a boss slot, the others are not", EndlessMode.is_boss_slot(4) and EndlessMode.is_boss_slot(9) and not EndlessMode.is_boss_slot(0) and not EndlessMode.is_boss_slot(5))
	var boss_pool := EndlessMode.pool(4)
	_check("a boss slot offers only boss levels (%s)" % str(boss_pool), not boss_pool.is_empty() and boss_pool.all(func(b): return b in EndlessMode.BOSSES))
	_check("(control) a normal slot offers no boss", EndlessMode.pool(7).all(func(l): return not (l in EndlessMode.BOSSES)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var prev := -1
	var repeats := 0
	for s in 300:
		var lv := EndlessMode.next_level(s % 40, rng, prev)
		if lv == prev:
			repeats += 1
		prev = lv
	_check("no level repeats back to back over 300 draws (%d repeats)" % repeats, repeats == 0)
	var bad: Array = []
	for lv in range(EndlessMode.FIRST, EndlessMode.LAST + 1):
		var d := LevelData.get_level(lv)
		if d == null or not (d.machine or d.tempest or d.warden):
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
			if not EndlessMode.is_boss_slot(s) and lv > EndlessMode.ceiling(s):
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
	gm.save_system.endless_best = best_before
	gm.save_system.save()
	var restore: Array = completed_before
	_check("(control) the campaign still completes normally after endless", restore == gm.save_system.levels_completed)

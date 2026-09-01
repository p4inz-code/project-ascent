extends SceneTree
## Trevor's orbs: the arithmetic, the persistence, and the final door.
##
## Three things can quietly ruin a collectible economy, and each has a check
## here:
##
##   1. The totals not adding up. If the game contains 99 orbs and the door
##      costs 100, the game is unfinishable and nothing else will say so.
##   2. Replaying a level banking the same orb twice, which makes the door
##      payable without playing the content.
##   3. The final door refusing a player who HAS paid, or opening for one who
##      has not.
##
## Run with:
##   Godot --headless --path <project> --script res://tests/test_orbs.gd

var _failures: int = 0
## Member, not a local: GDScript lambdas capture locals by value, so a signal
## flag written inside a closure never reaches the outer scope.
var _banked: int = -1


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	# --- 1. The economy must be exact -------------------------------------
	var total := 0
	var per_level_wrong := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var defs: Array = LevelData.orbs_for(n)
		var expect_orbs: bool = (n >= SaveSystem.FIRST_ORB_LEVEL
			and n <= SaveSystem.LAST_ORB_LEVEL)
		if expect_orbs and defs.size() != SaveSystem.ORBS_PER_LEVEL:
			per_level_wrong += 1
		if not expect_orbs and not defs.is_empty():
			per_level_wrong += 1
		total += defs.size()
	_check("every orb level carries exactly %d orbs" % SaveSystem.ORBS_PER_LEVEL,
		per_level_wrong == 0)
	# One orb per orb-bearing level. The 100 target belongs to the finished
	# 100-level game; today's 25 levels cannot reach it, which is exactly why
	# the final door must NOT check it.
	var expected_total: int = (SaveSystem.LAST_ORB_LEVEL
		- SaveSystem.FIRST_ORB_LEVEL + 1) * SaveSystem.ORBS_PER_LEVEL
	_check("the game contains one orb per level (%d of an eventual %d)"
		% [total, SaveSystem.ORB_GOAL], total == expected_total)
	_check("the target is not yet reachable, so the door must not gate on it",
		expected_total < SaveSystem.ORB_GOAL)

	# --- The single orb must be OPTIONAL ----------------------------------
	# With one orb per level there is no room for a freebie: an orb on the
	# route collects itself and is no decision at all.
	var all_optional := true
	for n2 in range(SaveSystem.FIRST_ORB_LEVEL, SaveSystem.LAST_ORB_LEVEL + 1):
		for d in LevelData.orbs_for(n2):
			if d.kind != 1:
				all_optional = false
	_check("every orb sits off the walking line", all_optional)

	# --- Deterministic placement ------------------------------------------
	# The save record is keyed by index, so a position that moved between runs
	# would make it meaningless.
	var a: Array = LevelData.orbs_for(9)
	var b: Array = LevelData.orbs_for(9)
	var same := true
	for i in a.size():
		if a[i].position != b[i].position or a[i].kind != b[i].kind:
			same = false
	_check("placement is deterministic across calls", same)

	# --- 2. Persistence must not double-count -----------------------------
	var save := SaveSystem.new()
	save.collected_orbs.clear()
	_check("a fresh save has no orbs", save.orb_total() == 0)
	_check("first pickup banks", save.collect_orb(7, 2))
	_check("the same orb refuses to bank twice", not save.collect_orb(7, 2))
	_check("total counts it once (%d)" % save.orb_total(), save.orb_total() == 1)
	save.collect_orb(7, 3)
	save.collect_orb(8, 0)
	_check("total across levels (%d)" % save.orb_total(), save.orb_total() == 3)
	_check("remaining is derived (%d)" % save.orbs_remaining(),
		save.orbs_remaining() == SaveSystem.ORB_GOAL - 3)
	_check("has_orb reports accurately",
		save.has_orb(7, 2) and not save.has_orb(7, 4))

	# --- Orbs exist in a real level, and collecting one banks it ----------
	# This writes through the REAL GameManager.save_system (it's an autoload,
	# not a throwaway instance), so a second run of this suite in the same
	# save file finds level 9's orb already collected, mark_already_taken()
	# correctly hides it, and _banked never fires - the test then fails
	# looking exactly like a broken pickup. Clearing this one save slot
	# before the check is what makes the suite idempotent across reruns
	# without touching anything else in the save.
	# GameManager's own _ready()/load_save() may not have run yet on the very
	# first frame of a --script SceneTree: erasing before that finishes would
	# operate on the default empty dict, and load_save() then overwrites it
	# moments later with whatever is on disk, silently undoing the erase.
	await _step(3)
	var gm0 := root.get_node_or_null("GameManager")
	if gm0 != null and gm0.save_system != null:
		gm0.save_system.collected_orbs.erase(9)

	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 9)
	get_root().add_child(scene)
	await _step(8)
	var orb0 = scene.get_node_or_null("Hazards/Orb_0")
	_check("a level builds its orbs", orb0 != null)
	if orb0 != null:
		_banked = -1
		scene.orb_collected.connect(func(t: int) -> void: _banked = t)
		var player: Player = scene.get_node("Player")
		player.global_position = orb0.global_position
		player.velocity = Vector2.ZERO
		await _step(6)
		_check("touching an orb banks it (total now %d)" % _banked, _banked > 0)
	scene.queue_free()
	if gm0 != null and gm0.save_system != null:
		gm0.save_system.collected_orbs.erase(9)
	await process_frame

	# --- 3. The final door must NOT gate ----------------------------------
	# This is the check that matters most right now. Gating on 100 when only
	# 25 orbs exist would make the game unfinishable, and nothing else in the
	# suite would say so.
	var gm := root.get_node_or_null("GameManager")
	if gm != null and gm.save_system != null:
		var backup: Dictionary = gm.save_system.collected_orbs.duplicate(true)
		gm.save_system.collected_orbs.clear()

		# The restore below is NOT inside a try/finally - GDScript has none -
		# so it only ran on the success path. get_node("Player") (not
		# get_node_or_null) throws and aborts this coroutine outright if
		# Player construction ever regresses on the last level, which is
		# exactly the class of bug this check exists to catch. That would
		# skip the restore and leave the REAL autoload's collected_orbs
		# cleared in memory for the rest of the process - and the next
		# real level completion or save() call would persist the wipe to
		# the actual user://save_data.json. Guarded with get_node_or_null
		# and an explicit early-restore-and-fail instead.
		var last: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		last.set("level_number", LevelData.TOTAL_LEVELS)
		get_root().add_child(last)
		await _step(8)
		var p2: Node = last.get_node_or_null("Player")
		if p2 == null:
			_check("the last level builds a player", false)
			gm.save_system.collected_orbs = backup
			last.queue_free()
			await process_frame
		else:
			p2.global_position = LevelData.get_level(LevelData.TOTAL_LEVELS).goal_position
			await _step(10)
			_check("the final level completes with zero orbs (the game is finishable)",
				bool(last.get("_level_complete")))
			last.queue_free()
			await process_frame
			gm.save_system.collected_orbs = backup

	print("[test_orbs] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)

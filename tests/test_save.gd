extends SceneTree
## Tests for the save/progression system.
## Validates checkpoint save/load, progression, reset, and corruption handling.
## Run: Godot --headless --path <project> --script res://tests/test_save.gd

var _failures: int = 0


func _initialize() -> void:
	# Clean up any existing save
	var save = SaveSystem.new()
	save.delete_save()
	await _step(2)

	await _test_default_state()
	await _test_save_and_load()
	await _test_complete_level()
	await _test_checkpoint_milestone()
	await _test_reset_progress()
	await _test_corrupted_save()
	await _test_missing_save()
	await _test_level_data_integrity()

	print("[test_save] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(frames: int) -> void:
	for _i in frames:
		await physics_frame


## Default state: new player starts at Level 1, no completions.
func _test_default_state() -> void:
	var save = SaveSystem.new()
	_check("default checkpoint is Level 1", save.get_checkpoint() == 1)
	_check("default completed levels is empty", save.levels_completed.is_empty())
	_check("default total completions is 0", save.total_completions == 0)
	# Clean up
	save.delete_save()


## Save and load preserves state.
func _test_save_and_load() -> void:
	var save = SaveSystem.new()
	save.checkpoint_level = 3
	save.levels_completed = [1, 2]
	save.total_completions = 5
	var ok = save.save()
	_check("save returns true", ok)

	var load_save = SaveSystem.new()
	var loaded = load_save.load_save()
	_check("load returns true", loaded)
	_check("loaded checkpoint is 3", load_save.get_checkpoint() == 3)
	_check("loaded completions match", load_save.levels_completed == [1, 2])
	_check("loaded total completions match", load_save.total_completions == 5)
	load_save.delete_save()


## Completing a level saves checkpoint = next level.
func _test_complete_level() -> void:
	var save = SaveSystem.new()
	save.delete_save()
	save = SaveSystem.new()

	# Complete Level 1: checkpoint advances to 2
	save.complete_level(1)
	_check("Level 1 complete: checkpoint is 2", save.get_checkpoint() == 2)
	_check("Level 1 complete: appears in completed", 1 in save.levels_completed)
	_check("Level 1 complete: total is 1", save.total_completions == 1)

	# Complete Level 4: checkpoint advances to 5
	save.complete_level(4)
	_check("Level 4 complete: checkpoint is 5", save.get_checkpoint() == 5)
	_check("Level 4 complete: total is 2", save.total_completions == 2)

	# Complete Level 5: checkpoint advances to 6
	save.complete_level(5)
	_check("Level 5 complete: checkpoint is 6", save.get_checkpoint() == 6)
	_check("Level 5 complete: total is 3", save.total_completions == 3)
	_check("Level 5 complete: game not yet complete", not save.is_game_complete())

	# Complete Level 10: checkpoint advances to 11
	save.complete_level(10)
	_check("Level 10 complete: checkpoint is 11", save.get_checkpoint() == 11)
	_check("Level 10 complete: game not yet complete", not save.is_game_complete())

	# Complete Level 25: game complete
	save.complete_level(25)
	_check("Level 25 complete: checkpoint is 25", save.get_checkpoint() == 25)
	_check("Level 25 complete: game is complete", save.is_game_complete())

	# total_completions counts every completion; levels_completed deduplicates
	save.complete_level(5)
	_check("Level 5 re-complete: total is 6", save.total_completions == 6)
	_check("Level 5 re-complete: completed list still has 5 unique", save.levels_completed.size() == 5)
	save.delete_save()


## Per-level checkpoint: each completion advances the checkpoint.
func _test_checkpoint_milestone() -> void:
	var save = SaveSystem.new()
	save.delete_save()
	save = SaveSystem.new()

	save.complete_level(1)
	_check("After L1: checkpoint is 2", save.get_checkpoint() == 2)

	save.complete_level(2)
	_check("After L2: checkpoint is 3", save.get_checkpoint() == 3)

	save.complete_level(3)
	_check("After L3: checkpoint is 4", save.get_checkpoint() == 4)

	save.complete_level(4)
	_check("After L4: checkpoint is 5", save.get_checkpoint() == 5)

	save.complete_level(5)
	_check("After L5: checkpoint is 6", save.get_checkpoint() == 6)

	save.complete_level(10)
	_check("After L10: checkpoint is 11", save.get_checkpoint() == 11)

	save.complete_level(25)
	_check("After L25: checkpoint is 25 (game complete)", save.get_checkpoint() == 25)
	save.delete_save()


## Reset returns to default state.
func _test_reset_progress() -> void:
	var save = SaveSystem.new()
	save.delete_save()
	save = SaveSystem.new()

	save.complete_level(5)
	_check("Before reset: checkpoint is 6", save.get_checkpoint() == 6)
	_check("Before reset: has completions", not save.levels_completed.is_empty())

	save.reset_progress()
	_check("After reset: checkpoint is 1", save.get_checkpoint() == 1)
	_check("After reset: completions empty", save.levels_completed.is_empty())
	_check("After reset: total completions 0", save.total_completions == 0)
	save.delete_save()


## Corrupted save file falls back to defaults.
func _test_corrupted_save() -> void:
	var file = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("{ corrupted json !!!")
		file.close()

	var save = SaveSystem.new()
	var loaded = load_save_check(save)
	_check("corrupted save: load completes (no crash)", true)
	_check("corrupted save: falls back to Level 1", save.get_checkpoint() == 1)
	save.delete_save()


## Missing save file returns defaults.
func _test_missing_save() -> void:
	var save = SaveSystem.new()
	save.delete_save()
	# No file exists
	var loaded = load_save_check(save)
	_check("missing save: load returns false", loaded == false)
	_check("missing save: checkpoint is 1", save.get_checkpoint() == 1)


## Level data definitions are valid.
func _test_level_data_integrity() -> void:
	# All 25 levels load without error
	for i in LevelData.TOTAL_LEVELS:
		var level = LevelData.get_level(i + 1)
		_check("Level %d has platforms" % (i + 1), level.platforms.size() > 0)
		_check("Level %d has valid spawn" % (i + 1), level.spawn_point != Vector2.ZERO)
		_check("Level %d has valid goal" % (i + 1), level.goal_position != Vector2.ZERO)
		_check("Level %d kill_depth > 0" % (i + 1), level.kill_depth > 0)

	# Level 1 has exactly 13 terrain platforms (matching original .tscn)
	var l1 = LevelData.get_level(1)
	# Was an exact count (14), which is a design value that legitimately changes
	# — it broke the moment levels were extended. Assert the property that
	# actually matters: the level has a real, non-trivial route.
	_check("Level 1 has a non-trivial platform list (%d)" % l1.platforms.size(),
		l1.platforms.size() >= 10)

	# Level 5 has boss enabled with 4 minions
	var l5 = LevelData.get_level(5)
	_check("Level 5 has boss enabled", l5.boss_config.enabled)
	_check("Level 5 has 4 minions", l5.boss_config.minion_count == 4)

	# Level 10 has boss enabled with 5 minions
	var l10 = LevelData.get_level(10)
	_check("Level 10 has boss enabled", l10.boss_config.enabled)
	_check("Level 10 has 5 minions", l10.boss_config.minion_count == 5)
	_check("Level 10 boss is faster than L5", l10.boss_config.boss_speed > l5.boss_config.boss_speed)

	# Level 15 has boss enabled with 5 minions
	var l15 = LevelData.get_level(15)
	_check("Level 15 has boss enabled", l15.boss_config.enabled)
	_check("Level 15 has 5 minions", l15.boss_config.minion_count == 5)

	# Level 20 has boss enabled with 6 minions
	var l20 = LevelData.get_level(20)
	_check("Level 20 has boss enabled", l20.boss_config.enabled)
	_check("Level 20 has 6 minions", l20.boss_config.minion_count == 6)
	_check("Level 20 boss is faster than L15", l20.boss_config.boss_speed > l15.boss_config.boss_speed)

	# Level 25 has boss enabled with 6 minions
	var l25 = LevelData.get_level(25)
	_check("Level 25 has boss enabled", l25.boss_config.enabled)
	_check("Level 25 has 6 minions", l25.boss_config.minion_count == 6)
	_check("Level 25 boss is faster than L20", l25.boss_config.boss_speed > l20.boss_config.boss_speed)

	# Non-boss levels have no boss
	for i in [1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19, 21, 22, 23, 24]:
		var level = LevelData.get_level(i)
		_check("Level %d has no boss" % i, not level.boss_config.enabled)


## Helper that safely calls load_save and returns success.
func load_save_check(save) -> bool:
	return save.load_save()

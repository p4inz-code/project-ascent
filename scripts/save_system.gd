class_name SaveSystem
extends RefCounted
## File-based save/load for Project Ascent progression.
##
## Saves to user://save_data.json so progress persists between launches.
## Handles: checkpoint level, completion history, corrupted saves.

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1

## Default save state (new player).
var checkpoint_level: int = 1
var levels_completed: Array[int] = []
var total_attempts: int = 0
var total_completions: int = 0


func save() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"checkpoint_level": checkpoint_level,
		"levels_completed": levels_completed,
		"total_attempts": total_attempts,
		"total_completions": total_completions,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: cannot write to %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveSystem: corrupted save, resetting to Level 1")
		_reset()
		return false
	var data: Dictionary = json.data
	if not data.has("version") or not data.has("checkpoint_level"):
		push_warning("SaveSystem: incomplete save, resetting to Level 1")
		_reset()
		return false
	checkpoint_level = int(data["checkpoint_level"])
	levels_completed = []
	for v in data.get("levels_completed", []):
		levels_completed.append(int(v))
	total_attempts = int(data.get("total_attempts", 0))
	total_completions = int(data.get("total_completions", 0))
	# Sanity: checkpoint must be a valid level
	if checkpoint_level < 1 or checkpoint_level > 5:
		push_warning("SaveSystem: invalid checkpoint %d, resetting" % checkpoint_level)
		checkpoint_level = 1
	return true


func complete_level(level_num: int) -> void:
	if level_num not in levels_completed:
		levels_completed.append(level_num)
	total_completions += 1
	# Checkpoint: completing any level sets checkpoint to the next level
	# so the player resumes from there on death or relaunch.
	var next_level: int = level_num + 1
	if next_level <= LevelData.TOTAL_LEVELS:
		checkpoint_level = next_level
	else:
		# Game complete — stay on final level
		checkpoint_level = LevelData.TOTAL_LEVELS
	save()


func get_checkpoint() -> int:
	return checkpoint_level


func get_highest_unlocked() -> int:
	# Highest level the player has reached (checkpoint level)
	return checkpoint_level


func is_game_complete() -> bool:
	return LevelData.TOTAL_LEVELS in levels_completed


func reset_progress() -> void:
	_reset()
	save()


func _reset() -> void:
	checkpoint_level = 1
	levels_completed = []
	total_attempts = 0
	total_completions = 0


func delete_save() -> void:
	_reset()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

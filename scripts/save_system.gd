class_name SaveSystem
extends RefCounted
## File-based save/load for Project Ascent progression.
##
## Saves to user://save_data.json so progress persists between launches.
## Handles: checkpoint level, completion history, corrupted saves.

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1

## ONE orb per level. The 100-orb target belongs to the finished game, which
## is planned at 100 levels — 25 now, 75 later. One per level is what makes
## that arithmetic work at both sizes, and it is why the final door is NOT
## gated on the target today: 25 levels cannot produce 100 orbs, so gating on
## it now would make the game unfinishable.
const ORBS_PER_LEVEL := 1
## The first level that contains orbs, and the last.
const FIRST_ORB_LEVEL := 5
const LAST_ORB_LEVEL := TOTAL_ORB_LEVELS_END
## Orbs run to the last level that exists. When levels are added, they extend
## automatically rather than needing this constant edited.
const TOTAL_ORB_LEVELS_END := 25
## The eventual target, for display only. The door does not check it — see
## main_scene.gd's goal handler and docs/STORY_AND_ORBS.md.
const ORB_GOAL := 100

## Default save state (new player).
var checkpoint_level: int = 1
var levels_completed: Array = []
var total_attempts: int = 0
var total_completions: int = 0
## Orbs collected, keyed by level number -> Array of orb indices.
##
## Stored per level AND per index rather than as a running total for one
## reason: a player who replays a level to pick up orbs they missed must not be
## able to bank the same orb twice. The total is derived, never stored.
var collected_orbs: Dictionary = {}


func save() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"checkpoint_level": checkpoint_level,
		"levels_completed": levels_completed,
		"total_attempts": total_attempts,
		"total_completions": total_completions,
		"collected_orbs": collected_orbs,
	}
	var abs_path = ProjectSettings.globalize_path(SAVE_PATH)
	print("[SaveSystem] Writing to: %s (abs: %s)" % [SAVE_PATH, abs_path])
	# Write to a temp file and rename over the real one instead of writing
	# SAVE_PATH directly — a crash, power loss, or force-quit mid-store()
	# would otherwise leave a truncated, unparseable save file (load_save()
	# would then hit the corrupted-JSON path and wipe all progress). The
	# rename is a single filesystem operation, so there's no window where
	# the file exists half-written.
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: cannot write to %s" % tmp_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null or dir.rename(tmp_path, SAVE_PATH) != OK:
		push_warning("SaveSystem: failed to finalize save to %s" % SAVE_PATH)
		return false
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
	var loaded_checkpoint: int = int(data["checkpoint_level"])
	# Sanity: checkpoint must be a valid level. A corrupted checkpoint means
	# the whole file is untrustworthy — resetting only checkpoint_level while
	# keeping levels_completed/total_completions from the same corrupted file
	# left them internally inconsistent (e.g. checkpoint reset to 1 while
	# levels_completed still listed all 25 as done, so is_game_complete()
	# stayed true right after a "fresh start"). Reset everything together.
	if loaded_checkpoint < 1 or loaded_checkpoint > LevelData.TOTAL_LEVELS:
		push_warning("SaveSystem: invalid checkpoint %d, resetting" % loaded_checkpoint)
		_reset()
		save()
		return false
	checkpoint_level = loaded_checkpoint
	levels_completed.clear()
	collected_orbs.clear()
	for v in data.get("levels_completed", []):
		var lvl: int = int(v)
		if lvl >= 1 and lvl <= LevelData.TOTAL_LEVELS and lvl not in levels_completed:
			levels_completed.append(lvl)
	total_attempts = maxi(0, int(data.get("total_attempts", 0)))
	total_completions = maxi(0, int(data.get("total_completions", 0)))

	# Orbs. Validated key by key: JSON turns integer keys into strings, and a
	# hand-edited or corrupted save must not be able to inflate the total past
	# what the game actually contains.
	collected_orbs.clear()
	var raw = data.get("collected_orbs", {})
	if raw is Dictionary:
		for k in raw:
			var lvl := int(str(k))
			if lvl < 1 or lvl > LevelData.TOTAL_LEVELS:
				continue
			var seen: Array = []
			for v in raw[k]:
				var idx := int(v)
				if idx >= 0 and idx < ORBS_PER_LEVEL and idx not in seen:
					seen.append(idx)
			if not seen.is_empty():
				collected_orbs[lvl] = seen
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
	levels_completed.clear()
	total_attempts = 0
	total_completions = 0


func delete_save() -> void:
	_reset()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## True if this orb has already been banked on this save.
func has_orb(level_num: int, index: int) -> bool:
	return collected_orbs.get(level_num, []).has(index)


## Bank an orb. Returns false if it was already collected, so callers can tell
## a fresh pickup from a replay.
func collect_orb(level_num: int, index: int) -> bool:
	if has_orb(level_num, index):
		return false
	if not collected_orbs.has(level_num):
		collected_orbs[level_num] = []
	collected_orbs[level_num].append(index)
	return true


## Derived, never stored — so it cannot drift from the per-level record.
func orb_total() -> int:
	var n := 0
	for lvl in collected_orbs:
		n += collected_orbs[lvl].size()
	return n


## Orbs still out there. What the player needs to go back for.
func orbs_remaining() -> int:
	return maxi(0, ORB_GOAL - orb_total())

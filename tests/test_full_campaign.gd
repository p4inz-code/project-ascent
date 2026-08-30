extends SceneTree
## The actual proof a fresh player needs: boots the REAL entry point
## (game_scene.tscn) exactly once, then completes all 25 levels in sequence
## within that ONE continuous instance — never re-instantiating game_scene
## between levels.
##
## This is deliberately different from every other test in this project:
## test_all_levels_reachable.gd and the debug diagnostics used during
## development each verify ONE level (or one transition) in isolation, with
## a fresh game_scene instance per check. That isolation is exactly what let
## a real, severe bug ship undetected this session: game_scene.gd's
## _completion_pending flag was never reset during normal play, so every
## level completion after the FIRST was silently swallowed — the game was
## stuck after level 2 in any real, continuous session, but every isolated
## per-transition check (which always started with a fresh flag) passed.
##
## Run: Godot --headless --path <project> --script res://tests/test_full_campaign.gd

const TOTAL_LEVELS := 25
const MAX_FRAMES_PER_TRANSITION := 600  # generous; a real transition takes ~170

var _failures: int = 0
var _game: Node = null


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene := load("res://scenes/game_scene.tscn") as PackedScene
	_game = scene.instantiate()
	root.add_child(_game)
	await process_frame
	await process_frame

	var gm := root.get_node("/root/GameManager")
	gm.current_level = 1
	gm.save_system.checkpoint_level = 1
	gm.save_system.levels_completed.clear()
	_game.call("_load_current_level")
	await process_frame
	await process_frame
	await physics_frame

	for level_num in range(1, TOTAL_LEVELS + 1):
		await _complete_and_verify_advance(level_num)
		if _failures > 0:
			break

	print("[test_full_campaign] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _complete_and_verify_advance(level_num: int) -> void:
	var container := _game.get_node("LevelContainer")
	if container.get_child_count() == 0 or not is_instance_valid(container.get_child(0)):
		_check("Level %d: level scene present before completing" % level_num, false)
		return
	var level := container.get_child(0)
	var cur_num = level.get("level_number")
	if int(cur_num) != level_num:
		_check("Level %d: expected to be current, but LevelContainer holds level %s" % [
			level_num, cur_num], false)
		return

	var player := level.get_node("Player") as CharacterBody2D
	var goal := level.get_node("Goal") as Area2D
	player.global_position = goal.global_position
	player.velocity = Vector2.ZERO

	var is_last := level_num == TOTAL_LEVELS
	for i in MAX_FRAMES_PER_TRANSITION:
		await physics_frame
		if container.get_child_count() == 0 or not is_instance_valid(container.get_child(0)):
			continue
		var now_num = container.get_child(0).get("level_number")
		if now_num == null:
			continue
		if is_last:
			# Level 25 never advances — success is the victory banner
			# staying up and visible, not a level swap.
			var hud = container.get_child(0).get_node_or_null("Hud")
			var banner = hud.get_node_or_null("Banner") if hud else null
			if banner != null and banner.visible and banner.modulate.a > 0.9:
				_check("Level %d (final): victory banner shown and held" % level_num, true)
				return
		elif int(now_num) == level_num + 1:
			_check("Level %d -> %d: advanced correctly" % [level_num, level_num + 1], true)
			return

	if is_last:
		_check("Level %d (final): victory banner shown and held" % level_num, false)
	else:
		_check("Level %d -> %d: advanced correctly" % [level_num, level_num + 1], false)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1

extends SceneTree
## One-shot diagnostic: boot the real entry point, force-complete Level 2 by
## teleporting the player onto the goal, then watch GameManager.current_level
## and LevelContainer's actual child across the whole completion+transition
## sequence to see exactly what happens and when.
## Run: Godot --headless --path <project> --script res://tools/debug_level_transition.gd

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
	gm.current_level = 2
	gm.save_system.checkpoint_level = 2
	_game.call("_load_current_level")
	await process_frame
	await process_frame
	await physics_frame

	var container := _game.get_node("LevelContainer")
	var level := container.get_child(0)
	print("Loaded level_number=%s  GameManager.current_level=%d" % [level.get("level_number"), gm.current_level])

	var player := level.get_node("Player") as CharacterBody2D
	var goal := level.get_node("Goal") as Area2D
	print("Teleporting player onto the goal...")
	player.global_position = goal.global_position
	player.velocity = Vector2.ZERO

	for i in 300:
		await physics_frame
		if i % 10 == 0:
			var cur_child_name := "?"
			var cur_child_level: Variant = "?"
			if container.get_child_count() > 0 and is_instance_valid(container.get_child(0)):
				cur_child_name = String(container.get_child(0).name)
				cur_child_level = container.get_child(0).get("level_number")
			print("  t=%3d  GameManager.current_level=%d  LevelContainer.child0=%s(level_number=%s)  player.pos=%s" % [
				i, gm.current_level, cur_child_name, cur_child_level,
				player.global_position if is_instance_valid(player) else "freed"
			])

	print("\nFinal: GameManager.current_level=%d" % gm.current_level)
	if container.get_child_count() > 0 and is_instance_valid(container.get_child(0)):
		print("Final LevelContainer child: %s (level_number=%s)" % [container.get_child(0).name, container.get_child(0).get("level_number")])
	quit(0)

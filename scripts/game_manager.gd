extends Node
## Autoload singleton managing game-wide state: current level, pause,
## progression, and level transitions.
##
## Registered as "GameManager" in project.godot.
## Persists across scene changes via the autoload mechanism.

signal level_changed(level_number: int)
signal game_paused
signal game_resumed
signal game_over
signal checkpoint_reached(level: int)

var current_level: int = 1
var is_paused: bool = false
var save_system = SaveSystem.new()
var boss_active: bool = false

# Pause menu reference (set by game_scene.gd)
var pause_menu = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_system.load_save()
	current_level = save_system.get_checkpoint()
	print("[GameManager] Loaded checkpoint: Level %d" % current_level)


func start_game() -> void:
	current_level = save_system.get_checkpoint()
	level_changed.emit(current_level)


func restart_from_checkpoint() -> void:
	current_level = save_system.get_checkpoint()
	get_tree().paused = false
	is_paused = false
	level_changed.emit(current_level)


## Save progress and checkpoint WITHOUT emitting level_changed.
## game_scene.gd handles the timed transition after the completion banner.
func complete_current_level() -> void:
	save_system.complete_level(current_level)
	checkpoint_reached.emit(current_level)
	var next: int = current_level + 1
	if next > LevelData.TOTAL_LEVELS:
		# Game complete — don't advance, game_scene shows victory
		print("[GameManager] ALL LEVELS COMPLETE!")
		return
	# Advance to next level (transition handled by game_scene.gd)
	current_level = next


func reset_progress() -> void:
	save_system.reset_progress()
	current_level = 1
	level_changed.emit(current_level)


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	game_paused.emit()
	if pause_menu != null:
		pause_menu.visible = true


func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	game_resumed.emit()
	if pause_menu != null:
		pause_menu.visible = false


func quit_to_desktop() -> void:
	get_tree().paused = false
	get_tree().quit()


func get_completed_levels() -> int:
	return save_system.levels_completed.size()


func is_level_completed(level_num: int) -> bool:
	return level_num in save_system.levels_completed

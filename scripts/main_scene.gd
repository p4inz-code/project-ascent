extends Node2D
## Level controller for the Project Ascent greybox proving ground.
##
## Level responsibilities are intentionally small: remember the player's spawn
## point, catch falls off the bottom of the world, offer an instant manual
## restart, and own the completion-to-next-attempt loop. Fast, reliable restarts
## are a core game-feel goal, so they live here rather than being bolted on later.

## World-space Y below which the player is considered to have fallen out of the
## level and is respawned. Set generously below the lowest platform.
@export var kill_depth: float = 1400.0

## Change that led to a respawn, so the audio layer can play the right cue.
enum RespawnCause { FALL, MANUAL, COMPLETE }

@onready var _player: Player = $Player

var _spawn_point: Vector2

## Seconds elapsed on the current attempt. Starts on the player's first input so
## the clock does not run while they are reading the controls panel, and freezes
## once the goal is reached.
var run_time: float = 0.0
## Time on the clock when the level was last completed, so the HUD can show the
## finishing time after the respawn has already reset `run_time`.
var last_run_time: float = 0.0
## 1-based current-attempt counter, incremented by every fall-death, manual
## restart, and completion loop. Completion starts the next attempt immediately;
## the HUD banner and `last_run_time` preserve the run that just ended.
var attempts: int = 1

var _clock_running: bool = false

## Emitted when the player reaches the level goal. Feedback/UI can hook this
## later; for now the level simply logs and loops back to the spawn.
signal level_completed


func _ready() -> void:
	_spawn_point = _player.global_position


func _physics_process(delta: float) -> void:
	# The clock starts on the first real input, not on load.
	if not _clock_running and (Input.is_action_pressed("move_left")
			or Input.is_action_pressed("move_right")
			or Input.is_action_pressed("jump") or Input.is_action_pressed("dash")):
		_clock_running = true
		# First real input is also the browser-activation-safe moment to start the
		# music on HTML5, and a clean "music starts with the run" cue natively.
		var audio := get_node_or_null("Audio")
		if audio != null:
			audio.unlock_audio()
	if _clock_running:
		run_time += delta

	if _player.global_position.y > kill_depth:
		_respawn(RespawnCause.FALL)
		return

	if Input.is_action_just_pressed("restart"):
		_respawn(RespawnCause.MANUAL)


## Return the player to the spawn point with all transient movement state
## cleared. Kept as one path so a fall-death and a manual restart behave
## identically — and so a new life never resumes a dash or lockout from the old.
## `cause` tells the audio layer which cue to play (death vs restart vs none for
## the completion loop, whose goal cue is already played by `level_completed`).
func _respawn(cause: RespawnCause = RespawnCause.FALL) -> void:
	var audio := get_node_or_null("Audio")
	if audio != null:
		match cause:
			RespawnCause.FALL:
				audio.play_death()
			RespawnCause.MANUAL:
				audio.play_restart()
		# A player that died mid-slide would otherwise leave the hiss looping.
		audio.stop_wall_slide()
	_player.global_position = _spawn_point
	_player.reset_state()
	var visuals := _player.get_node_or_null("Visuals")
	if visuals != null:
		visuals.reset_state()
	attempts += 1
	run_time = 0.0
	_clock_running = false


func _on_goal_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	last_run_time = run_time
	level_completed.emit()
	print("[Main] Level complete in %.2fs (attempt %d)" % [last_run_time, attempts])
	# Greybox loop: start the next attempt at spawn. The HUD keeps the finishing
	# time visible while the completion banner is up; there is no results screen
	# in this intentionally small First Playable.
	_respawn(RespawnCause.COMPLETE)

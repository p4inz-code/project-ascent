extends Node2D
## Level controller for the Project Ascent greybox proving ground.
##
## Milestone 1 responsibilities are intentionally small: remember the player's
## spawn point, catch falls off the bottom of the world, and offer an instant
## manual restart. Fast, reliable restarts are a core game-feel goal, so they
## live here from the start rather than being bolted on later.

## World-space Y below which the player is considered to have fallen out of the
## level and is respawned. Set generously below the lowest platform.
@export var kill_depth: float = 1400.0

@onready var _player: Player = $Player

var _spawn_point: Vector2

## Emitted when the player reaches the level goal. Feedback/UI can hook this
## later; for now the level simply logs and loops back to the spawn.
signal level_completed


func _ready() -> void:
	_spawn_point = _player.global_position


func _physics_process(_delta: float) -> void:
	if _player.global_position.y > kill_depth:
		_respawn()

	if Input.is_action_just_pressed("restart"):
		_respawn()


## Return the player to the spawn point with cleared momentum. Kept as one path
## so a fall-death and a manual restart behave identically.
func _respawn() -> void:
	_player.global_position = _spawn_point
	_player.velocity = Vector2.ZERO


func _on_goal_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	level_completed.emit()
	print("[Main] Level complete")
	# Greybox loop: restart from spawn. Real completion feedback/UI is a later
	# milestone (see docs/ARCHITECTURE.md).
	_respawn()

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

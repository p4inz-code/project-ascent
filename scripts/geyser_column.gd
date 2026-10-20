class_name GeyserColumn
extends Area2D
## A geyser in a lava gap. It erupts on a fixed cycle: a rumble and a glowing swell for `tell` seconds,
## then a column of lava for `active` seconds. Touching the column costs one cell.
##
## The cycle clock starts when the player first moves after a respawn, because the level is built around
## the moment an auto-running player reaches each geyser (MachineKit.geyser_phase): the same clock as
## the simulator that proved it passable.

signal player_hit

@export var width: float = 140.0
@export var period: float = 4.8
@export var active: float = 1.2
@export var tell: float = 1.0
@export var phase: float = 0.0
@export var height: float = MachinePieces.GEYSER_H

var _t: float = 0.0
var _started: bool = false
var _player: Player = null
var _swell: Polygon2D
var _column: Polygon2D
var _shape: CollisionShape2D
var _rumbled: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	# local origin: the floor-top line at the gap's left edge; the lava surface sits 12 px below it.
	_swell = Polygon2D.new()
	_swell.polygon = PackedVector2Array([Vector2(6, 12), Vector2(width - 6, 12), Vector2(width - 20, -10), Vector2(20, -10)])
	_swell.color = Color(1.0, 0.45, 0.1, 0.0)
	add_child(_swell)
	_column = Polygon2D.new()
	_column.polygon = PackedVector2Array([Vector2(14, 20), Vector2(width - 14, 20), Vector2(width - 26, -height), Vector2(26, -height)])
	_column.color = Color(1.0, 0.55, 0.15, 0.0)
	add_child(_column)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 12.0, height + 40.0)
	_shape.shape = rect
	_shape.position = Vector2(width * 0.5, (-height + 40.0) * 0.5)
	_shape.disabled = true
	add_child(_shape)


func is_active() -> bool:
	return fposmod(_t + phase, period) >= period - active


func is_telling() -> bool:
	var ph := fposmod(_t + phase, period)
	return ph >= period - active - tell and ph < period - active


func _physics_process(delta: float) -> void:
	if not _started:
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Player
		if _player != null and absf(_player.velocity.x) > 1.0:
			_started = true
		else:
			return
	_t += delta * HazardSpeed.scale
	var on := is_active()
	_shape.set_deferred("disabled", not on)
	_column.color.a = 0.85 if on else 0.0
	if is_telling():
		var ph := fposmod(_t + phase, period)
		var f := (ph - (period - active - tell)) / maxf(tell, 0.001)
		_swell.color.a = 0.2 + 0.7 * f
		_swell.scale.y = 1.0 + 0.8 * f
		if not _rumbled:
			_rumbled = true
			SfxHub.play(get_tree(), "vent")
	else:
		_swell.color.a = 0.0
		_swell.scale.y = 1.0
		if not on:
			_rumbled = false
	if on:
		for b in get_overlapping_bodies():
			if b is Player:
				player_hit.emit()
				return


## A respawn starts the cycle again from the first step.
func restart() -> void:
	_t = 0.0
	_started = false
	_rumbled = false

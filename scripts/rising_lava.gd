class_name RisingLava
extends Node2D
## Lava that climbs after the player passes a trigger. The chase mechanic
## rendered as terrain rather than as an enemy.
##
## It rises SLOWER than a competent climb and stops at a ceiling, so it is a
## pace-setter rather than an execution. The failure it creates is hesitating,
## which is the right thing for a game about committing to a jump — and unlike
## a chaser it cannot corner you, because it only ever comes from below.
##
## It resets on death. A player who dies late and respawns into lava already at
## the ceiling would be dead on arrival.

signal player_hit

@export var width: float = 2400.0
@export var rise_speed: float = 34.0
@export var start_y: float = 0.0
## How far above start_y it will climb before stopping.
@export var climb_height: float = 900.0
@export var color: Color = Color(0.85, 0.25, 0.08, 1.0)
@export var crest_color: Color = Color(1.0, 0.55, 0.15, 1.0)

var _surface: Polygon2D
var _crest: Polygon2D
var _sensor: Area2D
var _shape: CollisionShape2D
var _rising: bool = false
var _y: float = 0.0
var _time: float = 0.0
const BODY_DEPTH: float = 1400.0


func _ready() -> void:
	_y = start_y
	_build_visual()
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 30.0)
	_shape.shape = rect
	_sensor.add_child(_shape)
	_sensor.body_entered.connect(func(b: Node2D) -> void:
		if b is Player:
			player_hit.emit())
	add_child(_sensor)
	_refresh()


func _build_visual() -> void:
	_surface = Polygon2D.new()
	_surface.color = color
	add_child(_surface)
	_crest = Polygon2D.new()
	_crest.color = crest_color
	add_child(_crest)


func start_rising() -> void:
	_rising = true


func reset() -> void:
	_rising = false
	_y = start_y
	_refresh()


func _physics_process(delta: float) -> void:
	_time += delta
	if _rising:
		_y = maxf(_y - rise_speed * delta, start_y - climb_height)
	_refresh()


func _refresh() -> void:
	var hw := width * 0.5
	_surface.polygon = PackedVector2Array([
		Vector2(-hw, _y), Vector2(hw, _y),
		Vector2(hw, _y + BODY_DEPTH), Vector2(-hw, _y + BODY_DEPTH),
	])
	var pts := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var x := -hw + width * float(i) / float(steps)
		pts.append(Vector2(x, _y + sin(x * 0.01 + _time * 1.4) * 7.0))
	for i in range(steps, -1, -1):
		var x := -hw + width * float(i) / float(steps)
		pts.append(Vector2(x, _y + sin(x * 0.01 + _time * 1.4) * 7.0 + 9.0))
	_crest.polygon = pts
	if _shape != null:
		_shape.position = Vector2(0.0, _y + 12.0)


func surface_y() -> float:
	return _y


func is_rising() -> bool:
	return _rising

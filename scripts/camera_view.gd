class_name CameraView
extends Node
## The player's own view of the world: a zoom preset (Close / Default / Wide), a follow speed,
## and hold-to-peek (look around without moving). Lives beside CameraShake under the Player.
##
## Fairness rules, because the view changes what a player can see coming:
##  - Wide never applies in pressure levels (a boss chase or a rising floor): there it falls
##    back to Default. Close is always allowed (it shows LESS).
##  - Peek is switched off in pressure levels, so it can never be used to scout while running.
##  - Zoom steps are the same for everyone, so a level is validated against one worst case.

const ZOOM_NAMES: Array[String] = ["CLOSE", "DEFAULT", "WIDE"]
const ZOOMS: Array[float] = [1.2, 1.0, 0.8]
## How far a full peek moves the view, in world units.
const PEEK_X := 520.0
const PEEK_Y := 360.0
const PEEK_SPEED := 7.0
const ZOOM_SPEED := 5.0

## Added to the camera offset by CameraShake (which owns the final offset).
var peek_offset: Vector2 = Vector2.ZERO

var _camera: Camera2D = null
var _settings: Node = null
var _level: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings = get_node_or_null("/root/GameSettings")
	_camera = get_parent().get_node_or_null("Camera2D") as Camera2D
	_level = get_parent().get_parent()


## Whether this level is a pressure level (boss chase or rising floor).
func pressure_level() -> bool:
	if _level == null:
		return false
	var data = _level.get("_level_data")
	return data != null and bool(data.boss_config.enabled)


## The zoom that actually applies: the chosen preset, capped in pressure levels.
func effective_zoom() -> float:
	var idx := 1
	if _settings != null and _settings.has_method("get_reg"):
		idx = clampi(int(_settings.get_reg("cam_zoom")), 0, ZOOMS.size() - 1)
	if idx == 2 and pressure_level():
		idx = 1
	return ZOOMS[idx]


func peek_enabled() -> bool:
	if pressure_level():
		return false
	if _settings != null and _settings.has_method("get_reg"):
		return bool(_settings.get_reg("cam_peek"))
	return true


## The peek direction asked for right now: each axis -1..1.
func peek_input() -> Vector2:
	if not peek_enabled():
		return Vector2.ZERO
	return Input.get_vector("look_left", "look_right", "look_up", "look_down")


func _process(delta: float) -> void:
	if _camera == null:
		return
	var z := effective_zoom()
	_camera.zoom = _camera.zoom.lerp(Vector2(z, z), clampf(ZOOM_SPEED * delta, 0.0, 1.0))
	var want := peek_input() * Vector2(PEEK_X, PEEK_Y)
	peek_offset = peek_offset.lerp(want, clampf(PEEK_SPEED * delta, 0.0, 1.0))
	if peek_offset.length() < 0.2 and want == Vector2.ZERO:
		peek_offset = Vector2.ZERO
	if _settings != null and _settings.has_method("get_reg"):
		_camera.position_smoothing_speed = float(_settings.get_reg("cam_follow"))

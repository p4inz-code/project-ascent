class_name MovingPlatform
extends AnimatableBody2D
## A platform that rides back and forth between two points — the Act III
## signature mechanic (Celeste's triggered/guided platforms, and the classic
## "ride it across the gap" verb almost every platformer has, which this
## project never had until now).
##
## Uses AnimatableBody2D with sync_to_physics so Godot's own CharacterBody2D
## moving-platform support carries the player automatically during
## move_and_slide() — no custom velocity-transfer code needed on the player
## side, and the already-heavily-tested player controller stays untouched.
## Movement happens in _physics_process specifically (not a Tween on the
## default idle-frame process, and not _process) because sync_to_physics
## expects the transform to already reflect the current physics step.

@export var size: Vector2 = Vector2(120.0, 24.0)
@export var color: Color = Color(0.20, 0.26, 0.34, 1.0)
@export var edge_color: Color = Color(0.55, 0.72, 0.90, 1.0)
## Offset (world-space delta) from the spawn position to the far end of the
## patrol, e.g. Vector2(220, 0) for a horizontal ride.
@export var travel: Vector2 = Vector2(220.0, 0.0)
## Full one-way travel speed (px/s). Distance / speed gives the one-way time.
@export var speed: float = 90.0
## Pause at each end before reversing (s) — gives the player a stable window
## to commit to jumping on/off rather than a platform that never stops.
@export var pause_at_ends: float = 0.4

var _poly: Polygon2D
var _edge: Polygon2D
var _start: Vector2
## Deliberately NOT reset on player respawn/restart — this cycle runs on its
## own real-world clock independent of the player's life, the same way a
## conveyor belt or patrolling platform never resets in other platformers.
## Respawning mid-cycle just means waiting for it to swing back around, which
## is itself part of the timing puzzle; resetting it here would let a player
## "reroll" the platform's position by dying on purpose, and would desync it
## from any other player standing on it if this ever became coop.
var _t: float = 0.0
var _one_way_time: float = 1.0
## 0 = at start, 1 = at start+travel. Ping-pongs with a pause held at each end.
var _forward: bool = true
var _pause_timer: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	_start = position
	_one_way_time = maxf(travel.length() / maxf(speed, 1.0), 0.01)
	_build_visual()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)


func _build_visual() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	_poly.color = color
	add_child(_poly)

	_edge = Polygon2D.new()
	var edge_h := minf(5.0, size.y * 0.5)
	_edge.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy + edge_h), Vector2(-hx, -hy + edge_h)
	])
	_edge.color = edge_color
	add_child(_edge)


func _physics_process(delta: float) -> void:
	if _pause_timer > 0.0:
		_pause_timer = maxf(_pause_timer - delta, 0.0)
		return

	var step := delta / _one_way_time
	if _forward:
		_t = minf(_t + step, 1.0)
		if _t >= 1.0:
			_forward = false
			_pause_timer = pause_at_ends
	else:
		_t = maxf(_t - step, 0.0)
		if _t <= 0.0:
			_forward = true
			_pause_timer = pause_at_ends

	position = _start + travel * _t

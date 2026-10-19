class_name TimedGate
extends Node2D
## An obby-style timing obstacle that stands in a gap between two platforms:
##
##   LASER    a vertical beam between two emitter posts, spanning the jump zone
##   CRUSHER  a heavy slab that slams down through the jump zone
##
## Both run the same repeating cycle:
##
##   SAFE    nothing happens (long: the player waits here and reads the room)
##   WARN    the telegraph: the beam flickers / the slab shakes (still safe)
##   ACTIVE  lethal for a short time
##
## Fairness is by construction. SAFE + WARN is always at least MIN_SAFE_WINDOW,
## more than twice the airtime of a jump across the gap, so a player who waits on
## the take-off platform and jumps right after the hazard goes quiet always clears
## it. Placement rules (GateRules.problems) keep the gate in the middle of the gap,
## never over a platform, so waiting is always possible. See tests/test_timed_gates.gd.
##
## Origin: the centre of the gap, at the height of the flanking platform surface.

signal player_hit

enum Kind { LASER, CRUSHER }
enum Phase { SAFE, WARN, ACTIVE }

const MIN_SAFE_WINDOW := 2.0
const ZONE_HEIGHT := 230.0      # how far above the surface the hazard reaches
const BEAM_WIDTH := 10.0
const SLAB_WIDTH := 92.0
const SLAB_THICK := 36.0
const PX := 3.0
## Crusher geometry: the slab's bottom edge rests at REST_Y and slams to SLAM_Y,
## which sits in the middle of the jump arc (a jump peaks about 96 up), so a player
## crossing mid-gap is struck while one who waits is not.
const REST_Y := -230.0
const SLAM_Y := -85.0
const DROP_TIME := 0.10
const RISE_TIME := 0.20

## Test hook: when true no gate is ever lethal. The reachability suites drive the
## controller through every gap with a simple autopilot that cannot wait for a gate.
static var suspended: bool = false

@export var kind: Kind = Kind.LASER
@export var safe_time: float = 2.0
@export var warn_time: float = 0.6
@export var active_time: float = 0.55
@export var phase_offset: float = 0.0
## Crusher slab heights (bottom edge, relative to the gate origin). The default slam sits in
## the middle of a jump arc; on a flat road it is lowered to catch a runner.
@export var slam_y: float = -85.0
@export var rest_y: float = -230.0

var _time: float = 0.0
var _sensor: Area2D
var _shape: CollisionShape2D
var _beam: Polygon2D
var _slab: Node2D
var _hit_lock: float = 0.0
var _last_phase: int = -1


func period() -> float:
	return safe_time + warn_time + active_time


## The window during which a waiting player is completely safe.
func safe_window() -> float:
	return safe_time + warn_time


## Phase at an absolute cycle time (pure function, used by tests).
func phase_at(t: float) -> Phase:
	var c := fposmod(t + phase_offset, period())
	if c < safe_time:
		return Phase.SAFE
	if c < safe_time + warn_time:
		return Phase.WARN
	return Phase.ACTIVE


## Slab bottom edge `t` seconds into the ACTIVE phase: drop, hold, then rise.
func _slab_y_in_active(t: float) -> float:
	if t < DROP_TIME:
		return lerpf(rest_y, slam_y, clampf(t / DROP_TIME, 0.0, 1.0))
	var rise_start := active_time - RISE_TIME
	if t < rise_start:
		return slam_y
	return lerpf(slam_y, rest_y, clampf((t - rise_start) / RISE_TIME, 0.0, 1.0))


## Seconds until this gate next becomes lethal (0 while it already is).
func seconds_until_active() -> float:
	var c := fposmod(_time + phase_offset, period())
	if c >= safe_time + warn_time:
		return 0.0
	return safe_time + warn_time - c


func current_phase() -> Phase:
	return phase_at(_time)


func is_lethal() -> bool:
	return not suspended and current_phase() == Phase.ACTIVE


func _ready() -> void:
	_build()


func _build() -> void:
	var post := Color(0.30, 0.34, 0.5)
	if kind == Kind.LASER:
		# Emitter posts on the platform line and at the top of the zone.
		for y in [0.0, -ZONE_HEIGHT]:
			var p := Polygon2D.new()
			p.polygon = _quad(-PX * 4.0, y - PX * 2.0, PX * 4.0, y + PX * 2.0)
			p.color = post
			add_child(p)
			var lamp := Polygon2D.new()
			lamp.polygon = _quad(-PX, y - PX, PX, y + PX)
			lamp.color = Color(1.0, 0.35, 0.3)
			lamp.name = "Lamp%d" % int(y)
			add_child(lamp)
		_beam = Polygon2D.new()
		_beam.polygon = _quad(-BEAM_WIDTH * 0.5, -ZONE_HEIGHT, BEAM_WIDTH * 0.5, 0.0)
		_beam.color = Color(1.0, 0.3, 0.25, 0.0)
		add_child(_beam)
	else:
		# Guide rails, and the slab that rides them.
		for sx in [-SLAB_WIDTH * 0.5 - PX * 2.0, SLAB_WIDTH * 0.5 + PX]:
			var rail := Polygon2D.new()
			rail.polygon = _quad(sx, -ZONE_HEIGHT - SLAB_THICK, sx + PX, 0.0)
			rail.color = post
			add_child(rail)
		_slab = Node2D.new()
		var body := Polygon2D.new()
		body.polygon = _quad(-SLAB_WIDTH * 0.5, -SLAB_THICK, SLAB_WIDTH * 0.5, 0.0)
		body.color = Color(0.36, 0.38, 0.50)
		_slab.add_child(body)
		var stripe := Polygon2D.new()
		stripe.polygon = _quad(-SLAB_WIDTH * 0.5, -PX * 3.0, SLAB_WIDTH * 0.5, 0.0)
		stripe.color = Color(1.0, 0.8, 0.15)
		_slab.add_child(stripe)
		add_child(_slab)

	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_sensor.add_child(_shape)
	_sensor.body_entered.connect(_on_body_entered)
	add_child(_sensor)
	_pose()


func _quad(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func _physics_process(delta: float) -> void:
	_time += delta * HazardSpeed.scale
	_hit_lock = maxf(_hit_lock - delta, 0.0)
	_pose()


## Where the visuals and the sensor are for the current phase.
func _pose() -> void:
	var phase := current_phase()
	var lethal := is_lethal()
	if kind == Kind.LASER:
		if _beam != null:
			var flicker := 0.35 + 0.35 * sin(_time * 40.0)
			match phase:
				Phase.SAFE:
					_beam.color.a = 0.0
				Phase.WARN:
					_beam.color.a = flicker * 0.5      # a faint, flickering guide line
				Phase.ACTIVE:
					_beam.color.a = 0.95
		if _shape != null:
			(_shape.shape as RectangleShape2D).size = Vector2(BEAM_WIDTH, ZONE_HEIGHT)
			_shape.position = Vector2(0.0, -ZONE_HEIGHT * 0.5)
	else:
		var slab_y := rest_y
		var shake := 0.0
		if phase == Phase.WARN:
			shake = sin(_time * 55.0) * 2.0
		elif phase == Phase.ACTIVE:
			slab_y = _slab_y_in_active(fposmod(_time + phase_offset, period()) - safe_time - warn_time)
		if _slab != null:
			_slab.position = Vector2(shake, slab_y)
		if _shape != null:
			# Only the slab itself is dangerous, wherever it is right now.
			(_shape.shape as RectangleShape2D).size = Vector2(SLAB_WIDTH - 10.0, SLAB_THICK - 6.0)
			_shape.position = Vector2(0.0, slab_y - SLAB_THICK * 0.5)
	if _shape != null:
		_shape.set_deferred("disabled", not lethal)
	if _last_phase != int(phase):
		_last_phase = int(phase)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if not is_lethal() or _hit_lock > 0.0 or not (body is Player):
		return
	if (body as Player).is_invulnerable():
		return
	_hit_lock = 1.0
	player_hit.emit()


## A player already standing in the column when it goes ACTIVE has not "entered"
## anything: check overlaps while lethal so an active gate always catches them.
func _process(_delta: float) -> void:
	if _sensor != null and is_lethal() and _hit_lock <= 0.0:
		for body in _sensor.get_overlapping_bodies():
			_try_hit(body)

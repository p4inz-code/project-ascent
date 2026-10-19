class_name PipeTube
extends Node2D
## A steel pipe the player runs through, bridging a gap between two platforms, with
## pressure vents inside that blow high-pressure air against the way forward in
## bursts. Nothing in a pipe kills you; it just makes you wait, and mistime it and
## you are blown back out the way you came. The roof is solid too, so you can run
## along the top instead: the choice is the obstacle.
##
## Each vent runs the same cycle:
##
##   IDLE   still, you run straight through
##   HISS   steam leaks from the grate (the telegraph, still harmless)
##   BLAST  a high-pressure gust pushes you back
##
## IDLE + HISS is always at least MIN_CALM, long enough to cross the longest pipe at
## walking pace, so there is always a window. See tests/test_pipes.gd.
##
## Origin: the left end of the floor, at floor height. The pipe runs to +x.

enum Phase { IDLE, HISS, BLAST }

const PX := 3.0
const HEIGHT := 112.0            # clear height inside the pipe
const WALL := 15.0               # thickness of the roof and floor plates
const MIN_CALM := 2.0
const GUST := 560.0              # displacement per second against the player in a blast
const VENT_SPACING := 150.0
## How far the pipe reaches onto each platform (matches PipeRules.OVERLAP).
const OVERLAP := 10.0

## Test hook: when true, levels build no pipes and vents never push. The autopilot
## suites cannot wait for a vent and their jumps assume an open gap.
static var suspended: bool = false

## Horizontal span of the pipe, and how much higher its right end is than its left
## (negative if it runs downhill). Climbing levels mean almost every gap rises, so
## the pipe is a ramp: its floor meets both platform surfaces flush.
@export var length: float = 240.0
@export var rise: float = 0.0
@export var idle_time: float = 1.6
@export var hiss_time: float = 0.6
@export var blast_time: float = 0.8
@export var phase_offset: float = 0.0
## -1 pushes toward -x (back toward where you came from); +1 pushes forward.
@export var gust_direction: float = -1.0

var _time: float = 0.0
var _vents: Array[float] = []        # x of each vent along the pipe
var _shell: Node2D                   # everything that tilts with the ramp
var _axis_length: float = 240.0      # length along the slope
var _roof_body: StaticBody2D
var _floor_body: StaticBody2D
var _player: Node2D = null


func period() -> float:
	return idle_time + hiss_time + blast_time


func calm_window() -> float:
	return idle_time + hiss_time


func phase_at(t: float) -> Phase:
	var c := fposmod(t + phase_offset, period())
	if c < idle_time:
		return Phase.IDLE
	if c < idle_time + hiss_time:
		return Phase.HISS
	return Phase.BLAST


## Seconds of calm left (0 once the blast has begun).
func calm_remaining() -> float:
	var c := fposmod(_time + phase_offset, period())
	if c >= idle_time + hiss_time:
		return 0.0
	return idle_time + hiss_time - c


func current_phase() -> Phase:
	return phase_at(_time)


func vent_count() -> int:
	return _vents.size()


func _ready() -> void:
	_build()


func _build() -> void:
	# The ramp runs a little steeper than the gap needs, so at the high platform's edge
	# its surface is a few pixels ABOVE that platform's top. The player then steps down
	# onto the platform instead of walking into a one-pixel wall.
	var built_rise := rise
	if absf(rise) > 0.01 and length > OVERLAP * 3.0:
		built_rise = (rise + signf(rise) * 3.0) * length / (length - OVERLAP)
	_axis_length = sqrt(length * length + built_rise * built_rise)
	_shell = Node2D.new()
	_shell.name = "Shell"
	_shell.rotation = atan2(-built_rise, length)
	add_child(_shell)
	# Vents: one near the middle of short pipes, two in long ones.
	_vents.clear()
	var n := 1 if _axis_length < 240.0 else 2
	for i in n:
		_vents.append(_axis_length * (float(i) + 1.0) / (float(n) + 1.0))

	# Collision: a floor under the run and a roof over it. Both are ordinary solid
	# ground (layer 3, like platforms) so the player can stand on the roof too.
	_floor_body = _slab(Vector2(_axis_length * 0.5, WALL * 0.5), Vector2(_axis_length, WALL))
	_roof_body = _slab(Vector2(_axis_length * 0.5, -HEIGHT - WALL * 0.5), Vector2(_axis_length, WALL))

	var shell := Color(0.30, 0.34, 0.46)
	var shell_hi := Color(0.50, 0.56, 0.74)
	var shell_lo := Color(0.12, 0.14, 0.22)
	# Roof and floor plates.
	for y in [-HEIGHT - WALL, 0.0]:
		var plate := Polygon2D.new()
		plate.polygon = _quad(0.0, y, _axis_length, y + WALL)
		plate.color = shell
		_shell.add_child(plate)
		var hi := Polygon2D.new()
		hi.polygon = _quad(0.0, y, _axis_length, y + PX)
		hi.color = shell_hi
		_shell.add_child(hi)
	# The tube interior: dark, with a faint inner glow.
	var inside := Polygon2D.new()
	inside.polygon = _quad(0.0, -HEIGHT, _axis_length, 0.0)
	inside.color = Color(0.04, 0.05, 0.09, 0.82)
	inside.z_index = -1
	_shell.add_child(inside)
	# Collars at the four corners of each mouth (short, so the opening stays clear).
	for x in [0.0, _axis_length - PX * 5.0]:
		for y in [-HEIGHT - WALL - PX * 2.0, WALL - PX * 2.0]:
			var collar := Polygon2D.new()
			collar.polygon = _quad(x, y, x + PX * 5.0, y + PX * 4.0)
			collar.color = shell_lo
			_shell.add_child(collar)
			var ch := Polygon2D.new()
			ch.polygon = _quad(x, y, x + PX * 5.0, y + PX)
			ch.color = shell_hi
			_shell.add_child(ch)
	var rx := PX * 9.0
	while rx < _axis_length - PX * 9.0:
		for y in [-HEIGHT - WALL + PX * 2.0, PX * 3.0]:
			var rivet := Polygon2D.new()
			rivet.polygon = _quad(rx, y, rx + PX * 2.0, y + PX * 2.0)
			rivet.color = shell_lo
			_shell.add_child(rivet)
		rx += PX * 14.0
	# Vent grates in the floor.
	for vx in _vents:
		var grate := Polygon2D.new()
		grate.polygon = _quad(vx - PX * 6.0, -PX * 2.0, vx + PX * 6.0, PX)
		grate.color = shell_lo
		_shell.add_child(grate)
		for k in 4:
			var slat := Polygon2D.new()
			slat.polygon = _quad(vx - PX * 5.0 + float(k) * PX * 3.0, -PX * 2.0, vx - PX * 4.0 + float(k) * PX * 3.0, PX)
			slat.color = Color(0.55, 0.62, 0.8)
			_shell.add_child(slat)
	queue_redraw()


func _slab(centre: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 3
	body.position = centre
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	_shell.add_child(body)
	return body


func _quad(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## Is a world-space point inside the tube's interior (between floor and roof)?
func contains_world(p: Vector2) -> bool:
	if _shell == null:
		return false
	var local := _shell.to_local(p)
	return local.x >= 0.0 and local.x <= _axis_length and local.y >= -HEIGHT and local.y <= 0.0


func _physics_process(delta: float) -> void:
	_time += delta * HazardSpeed.scale
	queue_redraw()
	if suspended or current_phase() != Phase.BLAST:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null or not contains_world(_player.global_position):
		return
	# Only near a vent: a gust is local, so a player past the last vent is clear of it.
	var local_x := _shell.to_local(_player.global_position).x
	for vx in _vents:
		if absf(local_x - vx) <= VENT_SPACING * 0.75:
			# Displacement, the way wind zones push: the controller's own
			# deceleration would cancel a velocity change within a frame.
			_player.global_position.x += GUST * gust_direction * delta
			return


func _draw() -> void:
	var phase := current_phase()
	if phase == Phase.IDLE or _shell == null:
		return
	draw_set_transform_matrix(_shell.transform)
	for vx in _vents:
		var strength := 0.35 if phase == Phase.HISS else 1.0
		# Steam streaming out of the grate: short stepped streaks along the gust.
		for i in 7:
			var t := fposmod(_time * (1.5 if phase == Phase.BLAST else 0.6) + float(i) * 0.31, 1.0)
			var sy := -PX * 3.0 - t * (HEIGHT - PX * 6.0)
			var sx := vx + sin(t * 9.0 + float(i)) * PX * 4.0 + gust_direction * t * 60.0 * strength
			var a := (1.0 - t) * 0.6 * strength
			draw_rect(Rect2(floorf(sx / PX) * PX, floorf(sy / PX) * PX, PX * (2.0 + strength * 2.0), PX * 2.0),
				Color(0.85, 0.92, 1.0, a))
		if phase == Phase.BLAST:
			# Pressure streaks across the whole tube at the vent.
			for k in 4:
				var yy := -HEIGHT * (0.2 + 0.2 * float(k))
				var dx := fposmod(_time * 700.0 * -gust_direction + float(k) * 40.0, 140.0)
				draw_rect(Rect2(vx - 70.0 + dx, yy, PX * 8.0, PX), Color(1, 1, 1, 0.5))

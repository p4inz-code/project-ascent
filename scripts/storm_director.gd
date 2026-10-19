class_name StormDirector
extends Node2D
## Lightning for the storm level. Every few seconds a column is chosen on a platform near the
## player, shown for a full second and a bit, and then struck for a fraction of a second.
##
## Fairness, because lightning is the easiest hazard to make cheap:
##  - TELEGRAPH: every bolt is announced for TELEGRAPH seconds (never less than 1.0) by a
##    flickering warning line and a glow on the ground. There is no bolt without one.
##  - ROOM: a column is only chosen on a platform wide enough to step out of the beam, and
##    never the same place twice in a row.
##  - SPACING: one bolt at a time, a pause after each, and a long quiet spell after every
##    respawn, so a restart never begins inside a storm.
##  - A well-timed spin (the invulnerability window) passes through, like every other hazard.
##  - The assist that slows hazards slows the whole storm, so every window only gets longer.

signal player_hit

enum Phase { QUIET, WARNING, STRIKE }

const TELEGRAPH := 1.25
const STRIKE_TIME := 0.22
const MIN_PAUSE := 1.1                 # between a bolt ending and the next warning
const MAX_PAUSE := 2.4
const FIRST_STRIKE_DELAY := 4.0        # after the level starts or the player respawns
const MIN_PLATFORM_WIDTH := 110.0      # room to step out of a beam
const BEAM_HALF_WIDTH := 26.0
const PLAYER_HALF_WIDTH := 14.0
const MIN_SPACING := 380.0             # between consecutive columns
const AHEAD_MIN := -260.0              # columns are chosen from this far behind...
const AHEAD_MAX := 760.0               # ...to this far ahead of the player
const BEAM_HEIGHT := 1400.0            # how far the bolt reaches above the surface

var phase: int = Phase.QUIET
var column_x: float = 0.0
var column_y: float = 0.0              # surface height at the column
var strikes_fired: int = 0

var _rects: Array[Rect2] = []
var _player: Node2D = null
var _rng := RandomNumberGenerator.new()
var _timer: float = FIRST_STRIKE_DELAY
var _last_x: float = -99999.0
var _hit_this_strike: bool = false
var _time: float = 0.0
var enabled: bool = true


func setup(platform_rects: Array[Rect2], player: Node2D, rng_seed: int = -1) -> void:
	_rects = platform_rects
	_player = player
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	z_index = 3
	reset()


## Back to calm, with a long quiet before the first bolt (called on every respawn).
func reset() -> void:
	phase = Phase.QUIET
	_timer = FIRST_STRIKE_DELAY
	_hit_this_strike = false
	_last_x = -99999.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not enabled or _player == null or not is_instance_valid(_player):
		return
	step(delta * HazardSpeed.scale)


## Advance the storm by `dt` seconds of storm time. Public so tests can run it exactly.
func step(dt: float) -> void:
	_time += dt
	_timer -= dt
	match phase:
		Phase.QUIET:
			if _timer <= 0.0 and _choose_column():
				phase = Phase.WARNING
				_timer = TELEGRAPH
				_hit_this_strike = false
		Phase.WARNING:
			if _timer <= 0.0:
				phase = Phase.STRIKE
				_timer = STRIKE_TIME
				strikes_fired += 1
				_shake()
		Phase.STRIKE:
			_check_hit()
			if _timer <= 0.0:
				phase = Phase.QUIET
				_timer = _rng.randf_range(MIN_PAUSE, MAX_PAUSE)
	queue_redraw()


## Pick a column on a wide platform near the player. False when there is nowhere suitable
## (the storm simply waits).
func _choose_column() -> bool:
	var px := _player.global_position.x
	var options: Array = []
	for r in _rects:
		if r.size.x < MIN_PLATFORM_WIDTH:
			continue
		# Keep the whole beam over the platform, with room to stand either side of it.
		var lo := maxf(r.position.x + MIN_PLATFORM_WIDTH * 0.5, px + AHEAD_MIN)
		var hi := minf(r.end.x - MIN_PLATFORM_WIDTH * 0.5, px + AHEAD_MAX)
		if hi < lo:
			continue
		var cx := _rng.randf_range(lo, hi)
		if absf(cx - _last_x) < MIN_SPACING:
			# Try the far end of the range before giving up on this platform.
			cx = hi if absf(hi - _last_x) >= MIN_SPACING else lo
			if absf(cx - _last_x) < MIN_SPACING:
				continue
		options.append([cx, r.position.y])
	if options.is_empty():
		return false
	var pick: Array = options[_rng.randi_range(0, options.size() - 1)]
	column_x = float(pick[0])
	column_y = float(pick[1])
	_last_x = column_x
	return true


func is_lethal() -> bool:
	return phase == Phase.STRIKE


## Whether a body at (x, y) is inside the bolt right now.
func hits(x: float, y: float) -> bool:
	if phase != Phase.STRIKE:
		return false
	return absf(x - column_x) < BEAM_HALF_WIDTH + PLAYER_HALF_WIDTH and y < column_y + 40.0 and y > column_y - BEAM_HEIGHT


func _check_hit() -> void:
	if _hit_this_strike or _player == null:
		return
	if not hits(_player.global_position.x, _player.global_position.y):
		return
	if _player.has_method("is_invulnerable") and _player.is_invulnerable():
		return
	_hit_this_strike = true
	player_hit.emit()


func _shake() -> void:
	var shake := _player.get_node_or_null("CameraShake") if _player != null else null
	if shake != null and shake.has_method("add_trauma"):
		shake.add_trauma(0.35)


func _draw() -> void:
	if phase == Phase.QUIET:
		return
	var x := column_x - global_position.x
	var y := column_y - global_position.y
	var top := y - BEAM_HEIGHT
	if phase == Phase.WARNING:
		# A flickering dashed line, faster as the strike nears, and a glow on the ground.
		var left := _timer / TELEGRAPH
		var flicker := 0.45 + 0.4 * sin(_time * (14.0 + 26.0 * (1.0 - left)))
		var col := Color(1.0, 0.82, 0.35, clampf(flicker, 0.2, 0.95))
		var seg := 34.0
		var yy := y
		while yy > top:
			draw_line(Vector2(x, yy), Vector2(x, maxf(yy - seg * 0.55, top)), col, 3.0)
			yy -= seg
		draw_rect(Rect2(x - 44.0, y - 6.0, 88.0, 6.0), Color(1.0, 0.82, 0.35, 0.35 + 0.4 * (1.0 - left)))
	else:
		# The bolt: a jagged line from the sky to the surface, with a wide soft glow behind it.
		var pts := PackedVector2Array()
		var steps := 22
		for i in steps + 1:
			var f := float(i) / steps
			var jag := sin(f * 37.0 + float(strikes_fired) * 1.7) * 18.0 * (1.0 - absf(f - 0.5) * 0.4)
			pts.append(Vector2(x + jag, lerpf(top, y, f)))
		draw_polyline(pts, Color(0.55, 0.75, 1.0, 0.35), 34.0)
		draw_polyline(pts, Color(0.85, 0.93, 1.0, 0.9), 12.0)
		draw_polyline(pts, Color(1, 1, 1, 1), 4.0)
		draw_rect(Rect2(x - 60.0, y - 10.0, 120.0, 10.0), Color(0.85, 0.93, 1.0, 0.7))

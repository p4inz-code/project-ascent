class_name MachineSim
extends RefCounted
## A fast, scene-free mirror of the player's movement, used to PROVE machine levels passable.
##
## The real controller (player.gd) is a CharacterBody2D and runs about as fast as real time, which
## is far too slow to test thousands of rolls. This class re-implements the same equations
## (acceleration, asymmetric gravity, coyote time, jump buffer, variable jump height, dash, chip
## damage) on axis-aligned rectangles, one fixed 1/60 s step at a time. tests/test_machine_sim.gd
## keeps it honest by driving the REAL player and this mirror with the same inputs and comparing
## where they end up.
##
## What is deliberately NOT mirrored (so the sim is never easier than the game): ledge grab, corner
## correction, wall movement. Wall contact just stops the body.

const DT := 1.0 / 60.0
const HALF := Vector2(14.0, 26.0)       # the player's 28 x 52 box

# Movement numbers: player.gd defaults after the SNAPPY feel preset (the shipped default).
const MAX_SPEED := 320.0
const GROUND_ACCEL := 0.08
const GROUND_DECEL := 0.06
const AIR_ACCEL := 0.12
const AIR_DECEL := 0.16
const JUMP_HEIGHT := 96.0
const T_UP := 0.36
const T_DOWN := 0.30
const MAX_FALL := 900.0
const COYOTE := 0.12
const BUFFER := 0.12
const RELEASE_DAMPING := 0.5
const DASH_SPEED := 640.0
const DASH_TIME := 0.14
const DASH_GROUND_COOLDOWN := 0.45
const CHIP_KNOCK_X := 260.0
const CHIP_KNOCK_Y := -300.0
const CHIP_INVULN := 1.0

const JUMP_V := -(2.0 * JUMP_HEIGHT) / T_UP
const G_UP := (2.0 * JUMP_HEIGHT) / (T_UP * T_UP)
const G_DOWN := (2.0 * JUMP_HEIGHT) / (T_DOWN * T_DOWN)

# --- state -------------------------------------------------------------------------
var pos: Vector2 = Vector2.ZERO          # centre of the box
var vel: Vector2 = Vector2.ZERO
var on_floor: bool = false
var facing: int = 1
var t: float = 0.0
var hp: int = 3
var invuln: float = 0.0
var dead: bool = false
var death_cause: String = ""
var chip_hits: int = 0

var _coyote: float = 0.0
var _buffer: float = 0.0
var _dashing: bool = false
var _dash_t: float = 0.0
var _dash_dir: int = 1
var _dash_avail: bool = true
var _dash_ground_t: float = 0.0
var _jump_was_held: bool = false
var _knock_lock: float = 0.0
var _floor_belt: float = 0.0             # belt push (px/s) applied this step
var _floor_slip: float = 1.0            # ground accel/decel time multiplier applied this step (ice)
var _slip_seen: float = 1.0
var _belt_seen: float = 0.0              # belt under the box after the last move; reaches _floor_belt a step later (the real sensor reports with that lag)

# --- world -------------------------------------------------------------------------
var world: MachineWorld = null


func _init(p_world: MachineWorld, start: Vector2, start_speed: float = 0.0) -> void:
	world = p_world
	pos = start
	vel = Vector2(start_speed, 0.0)


## Advance one step. move is -1..1, jump_pressed is the press edge, jump_held the held state,
## dash_pressed the press edge.
func step(move: float, jump_pressed: bool, jump_held: bool, dash_pressed: bool = false) -> void:
	if dead:
		return
	t += DT
	invuln = maxf(invuln - DT, 0.0)
	_knock_lock = maxf(_knock_lock - DT, 0.0)
	# timers
	if on_floor:
		_coyote = COYOTE
	else:
		_coyote = maxf(_coyote - DT, 0.0)
	if jump_pressed:
		_buffer = BUFFER
	else:
		_buffer = maxf(_buffer - DT, 0.0)
	var dash_buf := dash_pressed

	# dash owns the body while active
	if _dashing:
		_dash_t -= DT
		var blocked := false
		if _dash_t <= 0.0 or blocked:
			_dashing = false
			_dash_ground_t = DASH_GROUND_COOLDOWN
			vel.x = clampf(vel.x, -MAX_SPEED, MAX_SPEED)
		else:
			vel = Vector2(_dash_dir * DASH_SPEED, 0.0)
			var hit_wall := _move_and_collide()
			if hit_wall:
				_dashing = false
				_dash_ground_t = DASH_GROUND_COOLDOWN
			_after_move()
			return
	if not _dash_avail and on_floor:
		_dash_ground_t = maxf(_dash_ground_t - DT, 0.0)
		if _dash_ground_t <= 0.0:
			_dash_avail = true
	if dash_buf and _dash_avail:
		_dash_dir = signi(int(signf(move))) if not is_zero_approx(move) else facing
		facing = _dash_dir
		_dashing = true
		_dash_t = DASH_TIME
		_dash_avail = false
		vel = Vector2(_dash_dir * DASH_SPEED, 0.0)
		_move_and_collide()
		_after_move()
		return

	# gravity
	if not on_floor:
		var g := G_UP if vel.y < 0.0 else G_DOWN
		vel.y = minf(vel.y + g * DT, MAX_FALL)

	# jump
	var released := _jump_was_held and not jump_held
	if _buffer > 0.0 and _coyote > 0.0:
		vel.y = JUMP_V
		_buffer = 0.0
		_coyote = 0.0
	if released and vel.y < 0.0:
		vel.y *= RELEASE_DAMPING
	_jump_was_held = jump_held

	# horizontal
	if not is_zero_approx(move):
		facing = signi(int(signf(move)))
	if _knock_lock <= 0.0:
		var target := move * MAX_SPEED
		var speeding_up := absf(target) > absf(vel.x) and not is_zero_approx(move)
		var time: float
		if on_floor:
			time = (GROUND_ACCEL if speeding_up else GROUND_DECEL) * _floor_slip
		else:
			time = AIR_ACCEL if speeding_up else AIR_DECEL
		vel.x = move_toward(vel.x, target, (MAX_SPEED / maxf(time, 0.0001)) * DT)

	_move_and_collide()
	_after_move()


## Move on x then y against the solids. Returns true when the x move hit something.
func _move_and_collide() -> bool:
	var hit_x := false
	# horizontal
	var nx := pos.x + vel.x * DT
	var rect := _box(Vector2(nx, pos.y))
	var blocker := world.first_solid_overlap(rect)
	if blocker.size != Vector2.ZERO:
		if vel.x > 0.0:
			nx = blocker.position.x - HALF.x - 0.01
		else:
			nx = blocker.end.x + HALF.x + 0.01
		vel.x = 0.0
		hit_x = true
	pos.x = nx
	# belt push is a position offset, like the real conveyor
	if on_floor and _floor_belt != 0.0:
		var bx := pos.x + _floor_belt * DT
		if world.first_solid_overlap(_box(Vector2(bx, pos.y))).size == Vector2.ZERO:
			pos.x = bx
	# vertical
	var ny := pos.y + vel.y * DT
	var vrect := _box(Vector2(pos.x, ny))
	var vb := world.first_solid_overlap(vrect)
	var landed := false
	if vb.size != Vector2.ZERO:
		if vel.y > 0.0:
			ny = vb.position.y - HALF.y - 0.01
			landed = true
		else:
			ny = vb.end.y + HALF.y + 0.01
		vel.y = 0.0
	pos.y = ny
	var was_floor := on_floor
	on_floor = landed or (vel.y >= 0.0 and world.first_solid_overlap(_box(Vector2(pos.x, pos.y + 1.0))).size != Vector2.ZERO)
	if on_floor and not was_floor:
		_dash_avail = true
	return hit_x


func _after_move() -> void:
	_floor_belt = _belt_seen
	_belt_seen = world.belt_under(_box(pos)) if on_floor else 0.0
	# Surface modifiers stay set while the player is over the platform, like the real riders list.
	_floor_slip = _slip_seen
	_slip_seen = world.slip_under(_box(pos)) if on_floor else _slip_seen
	# zones (jets) act on velocity after the body has moved, like their own physics process
	world.apply_zones(self)
	world.check_hazards(self)
	if pos.y > world.kill_y and not dead:
		dead = true
		death_cause = "void"


func _box(centre: Vector2) -> Rect2:
	return Rect2(centre - HALF, HALF * 2.0)


func box() -> Rect2:
	return _box(pos)


## A chip hazard touched the body. Returns true when it was the killing hit.
func chip(source_x: float) -> bool:
	if invuln > 0.0 or dead:
		return false
	hp -= 1
	chip_hits += 1
	if hp <= 0:
		dead = true
		death_cause = "chip"
		return true
	invuln = CHIP_INVULN
	var away := signf(pos.x - source_x)
	if away == 0.0:
		away = -float(facing)
	_dashing = false
	vel = Vector2(away * CHIP_KNOCK_X, CHIP_KNOCK_Y)
	_knock_lock = 0.15
	return false


func kill(cause: String) -> void:
	if not dead:
		dead = true
		death_cause = cause

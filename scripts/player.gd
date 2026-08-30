class_name Player
extends CharacterBody2D
## Precision-platformer player controller for Project Ascent.
##
## Current First Playable scope: responsive run + jump with the game-feel
## affordances that precision platformers depend on — acceleration/deceleration,
## air control, coyote time, jump buffering, and variable jump height — plus wall
## movement and a single air dash.
##
## All tunables are @export vars so they can be adjusted live in the inspector
## without touching code. Values are in pixels and seconds unless noted.

# --- Horizontal movement ---
## Top horizontal speed while running (px/s).
@export var max_speed: float = 320.0
## Time to accelerate from rest to max_speed while grounded (s).
@export var ground_accel_time: float = 0.08
## Time to decelerate from max_speed to rest while grounded (s).
@export var ground_decel_time: float = 0.06
## Time to accelerate to max_speed while airborne (s). Slightly slower than
## ground for a touch of commitment without feeling floaty.
@export var air_accel_time: float = 0.12
## Time to decelerate while airborne (s). Longer than ground so momentum
## carries through jumps.
@export var air_decel_time: float = 0.16

# --- Jump / gravity ---
## Peak jump height in pixels. Gravity and jump velocity are derived from this
## plus the two timing values below so height stays intuitive to tune. The
## setters below recompute the derived physics immediately so these three
## stay live-tunable from the Inspector while the game is running, not just
## at boot — _physics_ready guards against the setter firing during the
## script's own field initialization, before the other two defaults below
## have been assigned yet (which would divide by a still-zero timing value).
@export var jump_height: float = 96.0:
	set(value):
		jump_height = value
		if _physics_ready:
			_recalculate_physics()
## Time from leaving the ground to the apex of the jump (s).
@export var jump_time_to_peak: float = 0.36:
	set(value):
		jump_time_to_peak = value
		if _physics_ready:
			_recalculate_physics()
## Time from the apex back down to the launch height (s). Shorter than the rise
## gives a snappy, weighty fall that precision players prefer.
@export var jump_time_to_descent: float = 0.30:
	set(value):
		jump_time_to_descent = value
		if _physics_ready:
			_recalculate_physics()
## Terminal fall speed clamp (px/s).
@export var max_fall_speed: float = 900.0

# --- Game feel affordances ---
## Grace period after walking off a ledge during which a jump still fires (s).
@export var coyote_time: float = 0.10
## Window before landing during which a jump press is remembered and auto-fired
## on touchdown (s).
@export var jump_buffer_time: float = 0.10
## When the jump button is released while still rising, upward velocity is cut
## by this factor to give short/long jumps (0 = hard cut, 1 = no cut).
@export_range(0.0, 1.0) var jump_release_damping: float = 0.5

# --- Wall movement ---
## Maximum downward speed while sliding against a wall (px/s). Much slower than
## a free fall so walls read as "grippable".
@export var wall_slide_speed: float = 130.0
## Horizontal launch speed away from the wall on a wall jump (px/s).
@export var wall_jump_push: float = 340.0
## Wall-jump vertical launch as a multiple of the normal jump velocity.
@export var wall_jump_up_scale: float = 1.0
## Time after a wall jump during which horizontal input is ignored, so the push
## away from the wall reads instead of being cancelled instantly (s).
@export var wall_jump_lock_time: float = 0.12

# --- Dash ---
## Dash speed (px/s). One dash per grounding; refreshed on landing.
@export var dash_speed: float = 640.0
## How long the dash lasts (s).
@export var dash_time: float = 0.14
## Seconds a dash press is remembered so a near-landing input can fire as the
## dash refreshes. This is intentionally shorter than jump buffering.
@export var dash_buffer_time: float = 0.08

# --- Derived physics (computed from the tunables above) ---
var _jump_velocity: float
var _gravity_rising: float
var _gravity_falling: float
var _physics_ready: bool = false

# --- Runtime state ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _facing: int = 1
var _wall_jump_lock_timer: float = 0.0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_available: bool = true
var _dash_buffer_timer: float = 0.0
## Non-authoritative wall-slide state (fed to the wall_slide_started/ended
## signals so feedback layers can mirror it without duplicating the physics).
var _wall_sliding: bool = false
## Brief window after an external launch (e.g. a bounce pad) during which
## jump-release damping is suppressed. Without this, _handle_jump()'s
## "Input.is_action_just_released('jump') and velocity.y < 0.0" check fires
## on ANY negative velocity.y, including one just set by something that
## isn't the player's own jump — a bounce launch lands at roughly half its
## intended height any time the player happens to not be freshly holding
## jump, which is the ordinary case (nobody holds jump while walking onto a
## bounce pad).
var _external_launch_lock_timer: float = 0.0
const EXTERNAL_LAUNCH_LOCK_TIME := 0.15

## Emitted the frame the player lands after being airborne. Carries the impact
## fall speed so feedback systems (dust, squash, sfx) can scale to it later.
signal landed(fall_speed: float)

## Emitted when a ground/coyote jump fires, for non-authoritative feedback.
signal jumped
## Emitted when a wall jump fires, for non-authoritative feedback.
signal wall_jumped
## Emitted the frame a dash begins, for non-authoritative feedback.
signal dashed
## Emitted when the player begins pressing down a wall (the slide clamps fall
## speed). Drives the continuous wall-slide audio/feedback layer.
signal wall_slide_started
## Emitted when the wall slide stops (lands, leaves, or jumps away).
signal wall_slide_ended


func _ready() -> void:
	_recalculate_physics()
	_physics_ready = true


## Read-only view of the dash state, for feedback systems that must not touch
## controller internals (see scripts/player_visuals.gd).
func is_dashing() -> bool:
	return _is_dashing


## Read-only facing direction (-1 left, 1 right), for the same reason.
func facing() -> int:
	return _facing


## Clear all transient movement state. Called on respawn/restart so a new life
## never inherits a dash, wall-jump lockout, buffered jump, or coyote grace from
## the previous one (e.g. dying mid-dash would otherwise resume the dash — with
## velocity already zeroed — freezing the player for the rest of dash_time).
func reset_state() -> void:
	velocity = Vector2.ZERO
	_is_dashing = false
	_dash_timer = 0.0
	_dash_available = true
	_dash_buffer_timer = 0.0
	_wall_jump_lock_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_facing = 1
	if _wall_sliding:
		# Dying/respawning mid-wall-slide must still emit the matching
		# "ended" signal — audio.gd (and any future listener) mirrors
		# _started/_ended into its own state and would otherwise believe
		# the slide is still active for the rest of the level.
		_wall_sliding = false
		wall_slide_ended.emit()


## Recompute jump velocity and asymmetric gravity from the height/time tunables.
## Kinematics: h = 0.5 * g * t^2 with v0 = g * t_up, so g = 2h/t^2, v0 = 2h/t.
func _recalculate_physics() -> void:
	# Floored so a designer zeroing either timing value in the Inspector
	# (or a live-tune slider passing through 0) gets an extremely snappy
	# jump instead of a divide-by-zero producing NaN/inf velocity and
	# gravity that then propagates into move_and_slide() every frame.
	var t_up := maxf(jump_time_to_peak, 0.01)
	var t_down := maxf(jump_time_to_descent, 0.01)
	_jump_velocity = -(2.0 * jump_height) / t_up
	_gravity_rising = (2.0 * jump_height) / (t_up * t_up)
	_gravity_falling = (2.0 * jump_height) / (t_down * t_down)


func _physics_process(delta: float) -> void:
	var was_airborne := not is_on_floor()
	_update_timers(delta)

	# A dash overrides normal locomotion, gravity, and wall behaviour while it
	# is active. When it ends we fall through to the normal loop the same frame.
	if _handle_dash(delta):
		var dash_impact := velocity.y
		move_and_slide()
		_detect_landing(was_airborne, dash_impact)
		return

	_apply_gravity(delta)
	_apply_wall_slide()
	_handle_jump()
	_handle_horizontal(delta)

	# Capture the fall speed before move_and_slide resolves the floor collision
	# and zeroes velocity.y — otherwise the landing signal always reports ~0.
	var impact_speed := velocity.y
	move_and_slide()
	_detect_landing(was_airborne, impact_speed)


func _update_timers(delta: float) -> void:
	# Coyote timer refills while grounded, drains in the air.
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# Buffer a jump press so it survives the frames just before touchdown.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if Input.is_action_just_pressed("dash"):
		_dash_buffer_timer = dash_buffer_time
	else:
		_dash_buffer_timer = maxf(_dash_buffer_timer - delta, 0.0)

	_wall_jump_lock_timer = maxf(_wall_jump_lock_timer - delta, 0.0)
	_external_launch_lock_timer = maxf(_external_launch_lock_timer - delta, 0.0)


## Public entry point for anything outside the player's own controller that
## needs to set velocity directly — a bounce pad, a future spring/cannon,
## etc. Goes through here (not a raw `player.velocity.y = ...`) so the
## jump-release-damping window below can tell an external launch apart from
## the player's own jump and not silently cut it in half.
func apply_external_launch(new_velocity_y: float) -> void:
	velocity.y = new_velocity_y
	_external_launch_lock_timer = EXTERNAL_LAUNCH_LOCK_TIME


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	# Asymmetric gravity: heavier on the way down for a snappy arc.
	var g := _gravity_rising if velocity.y < 0.0 else _gravity_falling
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _handle_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		# Still allow variable-height trimming even without a fresh press —
		# but not immediately after an external launch (apply_external_launch),
		# which is not the player's own jump and shouldn't be cut in half by
		# a jump button that merely happens to not be freshly held.
		if _external_launch_lock_timer <= 0.0 \
				and Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= jump_release_damping
		return

	# Ground (or coyote) jump takes priority over a wall jump.
	if _coyote_timer > 0.0:
		velocity.y = _jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		jumped.emit()
	elif is_on_wall_only():
		# Launch up and away from the wall; lock horizontal input briefly so the
		# push is not immediately cancelled by holding toward the wall.
		var normal := get_wall_normal()
		velocity.x = normal.x * wall_jump_push
		velocity.y = _jump_velocity * wall_jump_up_scale
		_facing = signi(normal.x)
		_wall_jump_lock_timer = wall_jump_lock_time
		_jump_buffer_timer = 0.0
		wall_jumped.emit()

	# Variable height: releasing early trims the remaining rise. Same
	# external-launch exemption as above — a buffered jump press can still be
	# pending (this branch) on the exact frame a bounce pad fires, and a
	# release landing in that window must not cut the bounce in half either.
	if _external_launch_lock_timer <= 0.0 \
			and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_release_damping


func _handle_horizontal(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(direction):
		_facing = signi(direction)

	# During the wall-jump lockout, preserve the launch momentum instead of
	# letting input steer straight back into the wall.
	if _wall_jump_lock_timer > 0.0:
		return

	var target := direction * max_speed

	# Choose accel or decel time based on whether we're speeding up toward the
	# input direction or slowing down, and whether we're grounded.
	var speeding_up := absf(target) > absf(velocity.x) and not is_zero_approx(direction)
	var time: float
	if is_on_floor():
		time = ground_accel_time if speeding_up else ground_decel_time
	else:
		time = air_accel_time if speeding_up else air_decel_time

	# Convert the "time to cover full speed range" into a per-frame rate.
	var rate := max_speed / maxf(time, 0.0001)
	velocity.x = move_toward(velocity.x, target, rate * delta)


## Clamp fall speed while sliding down a wall. Only engages when airborne,
## pressing into the wall, and already descending.
func _apply_wall_slide() -> void:
	var sliding := _is_wall_slide_active()
	if sliding != _wall_sliding:
		_wall_sliding = sliding
		if sliding:
			wall_slide_started.emit()
		else:
			wall_slide_ended.emit()
	if sliding:
		velocity.y = minf(velocity.y, wall_slide_speed)


## The exact condition under which the player is considered to be wall sliding:
## airborne, against a wall only, already descending, and pressing into the wall.
## Kept in one place so the clamp and the feedback/lifecycle signals agree.
func _is_wall_slide_active() -> bool:
	if is_on_floor() or not is_on_wall_only() or velocity.y <= 0.0:
		return false
	var direction := Input.get_axis("move_left", "move_right")
	return not is_zero_approx(direction) \
		and signi(direction) == -signi(get_wall_normal().x)


## Drive an active dash and start a new one on request. Returns true while the
## dash owns the player's velocity this frame.
func _handle_dash(delta: float) -> bool:
	if _is_dashing:
		_dash_timer -= delta
		# End on timeout or when a wall stops the dash dead.
		if _dash_timer <= 0.0 or is_on_wall():
			_is_dashing = false
			# Bleed excess horizontal speed back to the normal cap so the dash
			# doesn't hand the player permanent extra momentum.
			velocity.x = clampf(velocity.x, -max_speed, max_speed)
			return false
		return true

	if _dash_buffer_timer > 0.0 and _dash_available:
		var direction := Input.get_axis("move_left", "move_right")
		var dash_dir := signi(direction) if not is_zero_approx(direction) else _facing
		_facing = dash_dir
		_is_dashing = true
		_dash_timer = dash_time
		_dash_available = false
		_dash_buffer_timer = 0.0
		velocity = Vector2(dash_dir * dash_speed, 0.0)
		dashed.emit()
		return true

	return false


func _detect_landing(was_airborne: bool, impact_speed: float) -> void:
	if was_airborne and is_on_floor():
		# One dash per grounding, refreshed exactly on the landing transition.
		# This used to be a level check ("if is_on_floor(): _dash_available =
		# true") run every physics frame, not just on landing — since it's
		# true for the ENTIRE duration of a dash performed from a standstill
		# on flat ground (is_on_floor() stays true throughout), the very
		# first physics tick of that dash re-armed the next one, giving
		# unlimited chained ground dashes well before dash_time expired.
		_dash_available = true
		landed.emit(impact_speed)

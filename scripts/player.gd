class_name Player
extends CharacterBody2D
## Precision-platformer player controller for Project Ascent.
##
## Milestone 1 scope: responsive run + jump with the game-feel affordances that
## precision platformers depend on — acceleration/deceleration, air control,
## coyote time, jump buffering, and variable jump height. Wall movement and
## dash are added in later milestones on top of this foundation.
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
## plus the two timing values below so height stays intuitive to tune.
@export var jump_height: float = 96.0
## Time from leaving the ground to the apex of the jump (s).
@export var jump_time_to_peak: float = 0.36
## Time from the apex back down to the launch height (s). Shorter than the rise
## gives a snappy, weighty fall that precision players prefer.
@export var jump_time_to_descent: float = 0.30
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

# --- Derived physics (computed from the tunables above) ---
var _jump_velocity: float
var _gravity_rising: float
var _gravity_falling: float

# --- Runtime state ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false

## Emitted the frame the player lands after being airborne. Carries the impact
## fall speed so feedback systems (dust, squash, sfx) can scale to it later.
signal landed(fall_speed: float)


func _ready() -> void:
	_recalculate_physics()


## Recompute jump velocity and asymmetric gravity from the height/time tunables.
## Kinematics: h = 0.5 * g * t^2 with v0 = g * t_up, so g = 2h/t^2, v0 = 2h/t.
func _recalculate_physics() -> void:
	_jump_velocity = -(2.0 * jump_height) / jump_time_to_peak
	_gravity_rising = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	_gravity_falling = (2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta)

	var was_airborne := not is_on_floor()
	move_and_slide()
	_detect_landing(was_airborne)


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


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	# Asymmetric gravity: heavier on the way down for a snappy arc.
	var g := _gravity_rising if velocity.y < 0.0 else _gravity_falling
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _handle_jump() -> void:
	# Fire when a buffered press meets a grounded-or-coyote state.
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = _jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Variable height: releasing early trims the remaining rise.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_release_damping


func _handle_horizontal(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
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


func _detect_landing(was_airborne: bool) -> void:
	if was_airborne and is_on_floor():
		landed.emit(velocity.y)
	_was_on_floor = is_on_floor()

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

# --- Spin (air mobility) ---
## Upward velocity granted by a spin (px/s) — a partial jump's worth of
## reach, giving airborne recovery beyond dash's horizontal-only burst.
## Deliberately weaker than the main jump (see jump_height/jump_time_to_peak)
## so it reads as a genuine assist, not a second full jump.
@export var spin_boost_velocity: float = -380.0
## Seconds the spin's visual flourish plays for (player_visuals.gd reads
## is_spinning() for this). Purely cosmetic — the physics effect is the
## single instantaneous velocity change above, not a timed state.
@export var spin_time: float = 0.25
## Seconds between two jump presses for the second to count as a double-tap
## and trigger spin (the second press must also land while airborne).
@export var spin_double_tap_window: float = 0.3
## Seconds before spin can be used again. Without this, spin being usable in
## mid-air with no grounding requirement AND granting invulnerability would let
## a player mash straight through every blade, pendulum and lava pit in the
## game — deleting the hazards this campaign is built on.
@export var spin_cooldown: float = 1.0
## Fraction of the spin during which hazards are ignored. Deliberately only the
## opening third: enough to reward a well-timed read through a hazard, not
## enough to ignore one.
@export_range(0.0, 1.0) var spin_iframe_fraction: float = 0.34

# ── Slide ───────────────────────────────────────────────────────────
## Ground slide: a burst of speed that also shrinks the player, for ducking
## under low hazards. Its own key (S / Ctrl / Down).
@export var slide_speed: float = 470.0
@export var slide_time: float = 0.34
@export var slide_cooldown: float = 0.45

# ── Ground pound ────────────────────────────────────────────────────
## Down + Jump while airborne. No new binding: a downward verb the kit
## completely lacked, and the input reads naturally as "slam down".
@export var ground_pound_speed: float = 1150.0

# ── Wall run ────────────────────────────────────────────────────────
## Triggered by running into a wall with speed, never by a button. Briefly
## holds the player against the wall with almost no gravity so they can carry
## momentum along it.
@export var wall_run_time: float = 0.32
@export var wall_run_gravity_scale: float = 0.12

# ── Ledge grab ──────────────────────────────────────────────────────
## Fully automatic. Pure forgiveness: catches a jump that just barely missed
## the lip and pulls the player up, which removes a large share of near-miss
## rage across all 25 levels without making anything easier to master.
@export var ledge_grab_enabled: bool = true
@export var ledge_grab_reach: float = 30.0

# ── Abilities ───────────────────────────────────────────────────────
## One-charge pickups spent with the Ability key (G / F). Held as a single
## slot, not an inventory: the player either has a charge or does not, which
## keeps both the HUD and the level design simple to reason about.
@export var super_jump_velocity: float = -620.0
## Downward speed while gliding, and how long a glide can last.
@export var glide_fall_speed: float = 90.0
@export var glide_time: float = 1.6

# ── Grapple ─────────────────────────────────────────────────────────
## Fires toward the aim direction and, if it finds terrain, reels the player
## in. Its own key (E / K / RB) — the one genuinely new traversal verb, as
## opposed to the derived ones that reuse inputs the player already knows.
@export var grapple_range: float = 340.0
## Reel speed. Fast enough to feel like being pulled, slow enough to read.
@export var grapple_pull_speed: float = 780.0
## Stop reeling once this close, so the player is never yanked into geometry.
@export var grapple_arrive_distance: float = 34.0
@export var grapple_cooldown: float = 0.55

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
## One spin per grounding, refreshed on landing — same rule as dash, using
## the same _detect_landing() edge-trigger (a level check here would re-arm
## it every grounded frame; see dash's own _detect_landing() comment for the
## infinite-refresh bug that pattern caused before it was fixed).
var _spin_available: bool = true
## Counts down after a spin; spin is unavailable until it reaches zero.
var _spin_cooldown_timer: float = 0.0
var _is_sliding: bool = false
var _slide_timer: float = 0.0
var _slide_cooldown_timer: float = 0.0
var _is_ground_pounding: bool = false
var _wall_run_timer: float = 0.0
var _ledge_grab_lock: float = 0.0
## -1 = none. Otherwise an AbilityPickup.Kind value.
var _held_ability: int = -1
var _is_gliding: bool = false
var _glide_timer: float = 0.0
var _grapple_target: Vector2 = Vector2.ZERO
var _is_grappling: bool = false
var _grapple_cooldown_timer: float = 0.0
## Non-authoritative visual-flourish state; the physics effect is a single
## instantaneous velocity change, not a timed state, so this only exists for
## player_visuals.gd/audio.gd to know the flourish window is active.
var _is_spinning: bool = false
var _spin_timer: float = 0.0
## Counts down after an airborne jump press; a second press before it hits
## zero is the double-tap that triggers spin. See _handle_spin().
var _jump_press_recent_timer: float = 0.0
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
## Emitted the frame a spin fires, for non-authoritative feedback.
signal spun
signal slid
signal ground_pounded
signal wall_ran
signal ledge_grabbed
signal ability_granted(kind: int)
signal ability_used(kind: int)
signal grappled(target: Vector2)
signal grapple_released
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


## Read-only view of the spin visual-flourish window, for the same reason.
func is_spinning() -> bool:
	return _is_spinning


## Read-only spin progress (0.0 the instant it fires, 1.0 when the flourish
## window ends), so player_visuals.gd can drive a rotation animation without
## reaching into the timer/duration directly.
func spin_progress() -> float:
	return 1.0 - _spin_timer / maxf(spin_time, 0.001)


## True while a spin is granting hazard immunity. Hazards check this rather
## than is_spinning(), so the invulnerable window can be a fraction of the
## visual spin instead of the whole of it.
func is_invulnerable() -> bool:
	if not _is_spinning:
		return false
	return spin_progress() <= spin_iframe_fraction


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
	_spin_available = true
	_spin_cooldown_timer = 0.0
	_is_sliding = false
	_slide_timer = 0.0
	_slide_cooldown_timer = 0.0
	_is_ground_pounding = false
	_wall_run_timer = 0.0
	_ledge_grab_lock = 0.0
	_held_ability = -1
	_is_grappling = false
	_grapple_cooldown_timer = 0.0
	_is_gliding = false
	_glide_timer = 0.0
	_is_spinning = false
	_spin_timer = 0.0
	_jump_press_recent_timer = 0.0
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

	# Ground pound and slide are exclusive states, like dash: while either is
	# active it owns movement. Checked before gravity so the pound can hold a
	# constant slam speed instead of accelerating past it.
	if _handle_ground_pound(delta):
		var gp_impact := velocity.y
		move_and_slide()
		_detect_landing(was_airborne, gp_impact)
		return
	if _handle_slide(delta):
		move_and_slide()
		_detect_landing(was_airborne, 0.0)
		return

	_apply_gravity(delta)
	_apply_wall_run(delta)
	_apply_wall_slide()
	_handle_jump()
	_handle_spin()
	_handle_ability(delta)
	if _handle_grapple(delta):
		move_and_slide()
		_detect_landing(was_airborne, 0.0)
		return
	_handle_horizontal(delta)
	_try_ledge_grab(delta)

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

	_spin_timer = maxf(_spin_timer - delta, 0.0)
	_spin_cooldown_timer = maxf(_spin_cooldown_timer - delta, 0.0)
	_slide_cooldown_timer = maxf(_slide_cooldown_timer - delta, 0.0)
	_grapple_cooldown_timer = maxf(_grapple_cooldown_timer - delta, 0.0)
	if _spin_timer <= 0.0:
		_is_spinning = false
	_jump_press_recent_timer = maxf(_jump_press_recent_timer - delta, 0.0)


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


## Air-mobility move: a single upward boost usable once per grounding while
## airborne — a second traversal tool alongside jump/wall-jump/dash, for
## recovering reach on a missed jump rather than for combat or obstacles.
## Grounded presses do nothing; the boost only serves a purpose in the air.
##
## Triggered by double-tapping Jump (not a dedicated button) — playtest
## feedback asked for this over the original dedicated "spin" key. Does NOT
## gate registering the first tap on is_on_floor(): a normal grounded jump
## and its own liftoff happen on the SAME physics frame the press is read,
## and is_on_floor() only reflects the result of the LAST move_and_slide()
## call — it's still stale-true for the rest of this frame's processing,
## before move_and_slide() runs again to reflect the jump that just fired.
## Gating on it here silently dropped every first tap that started a jump
## from the ground (the overwhelmingly common case). Only the SECOND press
## needs to actually be airborne, which is the real gameplay requirement.
func _handle_spin() -> void:
	if not Input.is_action_just_pressed("jump"):
		return
	# `_spin_available` used to require a landing to refresh. It now only
	# requires the cooldown to have elapsed, so a spin is usable in mid-air
	# repeatedly — but the cooldown is what stops it becoming an infinite
	# phase-through-anything button now that it also grants i-frames.
	if _jump_press_recent_timer > 0.0 and not is_on_floor() and _spin_cooldown_timer <= 0.0:
		# Routed through apply_external_launch() (not a raw velocity.y set)
		# so _handle_jump()'s jump-release damping can't silently halve it
		# the same way it once did to bounce pads — the bug that fix exists for.
		apply_external_launch(spin_boost_velocity)
		_spin_cooldown_timer = spin_cooldown
		_is_spinning = true
		_spin_timer = spin_time
		_jump_press_recent_timer = 0.0
		# This same press also armed the normal jump buffer in
		# _update_timers() (it has no idea this press was the second half of
		# a double-tap) — clear it, or landing right after a spin fires a
		# surprise extra jump from the buffered press that never actually
		# got used for a jump.
		_jump_buffer_timer = 0.0
		spun.emit()
	else:
		# Not a qualifying second tap (too late, still grounded, or spin
		# already used this air time) — this press becomes the new
		# reference point for a future double-tap instead.
		_jump_press_recent_timer = spin_double_tap_window



## ── Slide ───────────────────────────────────────────────────────────
## Returns true while sliding, meaning the caller should skip normal
## locomotion this frame.
func _handle_slide(delta: float) -> bool:
	if _is_sliding:
		_slide_timer -= delta
		# Cancel early if we leave the ground, otherwise a slide off a ledge
		# would float the player horizontally through the air.
		if _slide_timer <= 0.0 or not is_on_floor():
			_is_sliding = false
			_slide_cooldown_timer = slide_cooldown
			return false
		velocity.x = float(_facing) * slide_speed
		velocity.y += _gravity_falling * delta
		return true

	if not Input.is_action_just_pressed("slide"):
		return false
	if not is_on_floor() or _slide_cooldown_timer > 0.0:
		return false
	# Needs some speed to slide from — sliding from standstill reads as a
	# teleport rather than as momentum.
	if absf(velocity.x) < max_speed * 0.35:
		return false
	_is_sliding = true
	_slide_timer = slide_time
	slid.emit()
	return true


## ── Ground pound ────────────────────────────────────────────────────
## Down + Jump in the air. Returns true while slamming.
func _handle_ground_pound(delta: float) -> bool:
	if _is_ground_pounding:
		if is_on_floor():
			_is_ground_pounding = false
			return false
		velocity = Vector2(0.0, ground_pound_speed)
		return true

	if is_on_floor():
		return false
	if not Input.is_action_just_pressed("jump"):
		return false
	# `slide` doubles as the Down input, so Down+Jump needs no new binding.
	if not Input.is_action_pressed("slide"):
		return false
	_is_ground_pounding = true
	ground_pounded.emit()
	return true


## ── Wall run ────────────────────────────────────────────────────────
## No button: running into a wall with real speed briefly suspends most of
## gravity so momentum carries along the surface.
func _apply_wall_run(delta: float) -> void:
	if is_on_floor() or not is_on_wall_only():
		_wall_run_timer = 0.0
		return
	var direction := Input.get_axis("move_left", "move_right")
	var pressing_in := not is_zero_approx(direction) 		and signi(int(signf(direction))) == -signi(int(signf(get_wall_normal().x)))
	if not pressing_in or absf(velocity.x) < max_speed * 0.5:
		_wall_run_timer = 0.0
		return
	if _wall_run_timer <= 0.0:
		_wall_run_timer = wall_run_time
		wall_ran.emit()
	_wall_run_timer -= delta
	if _wall_run_timer > 0.0 and velocity.y > 0.0:
		# Undo most of the gravity applied this frame.
		velocity.y -= _gravity_falling * delta * (1.0 - wall_run_gravity_scale)


## ── Ledge grab ──────────────────────────────────────────────────────
## Automatic. If we are rising or barely falling beside a wall and there is
## floor just above the head, snap up onto it. Pure forgiveness for a jump
## that came up a few pixels short.
func _try_ledge_grab(delta: float) -> void:
	_ledge_grab_lock = maxf(_ledge_grab_lock - delta, 0.0)
	if not ledge_grab_enabled or is_on_floor() or _ledge_grab_lock > 0.0:
		return
	if _is_dashing or _is_ground_pounding:
		return
	# Only when moving roughly level or falling gently — a fast fall past a
	# ledge should read as a miss, not a magnet.
	if velocity.y < -40.0 or velocity.y > 320.0:
		return
	if not is_on_wall_only():
		return

	var dir := -signf(get_wall_normal().x)
	if is_zero_approx(dir):
		return
	var space := get_world_2d().direct_space_state
	# Probe just above head height, on the far side of the wall.
	var probe := global_position + Vector2(dir * ledge_grab_reach, -30.0)
	var down := PhysicsRayQueryParameters2D.create(probe, probe + Vector2(0.0, 46.0))
	down.collision_mask = 3
	down.exclude = [self]
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		return
	# And the space the player would occupy must be clear.
	var head := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -30.0), probe + Vector2(0.0, -10.0))
	head.collision_mask = 3
	head.exclude = [self]
	if not space.intersect_ray(head).is_empty():
		return

	global_position = Vector2(hit["position"].x + dir * 14.0, hit["position"].y - 27.0)
	velocity = Vector2(velocity.x * 0.3, 0.0)
	_ledge_grab_lock = 0.25
	ledge_grabbed.emit()


## True while a slide is active — used by the visuals layer to squash the body.
func is_sliding() -> bool:
	return _is_sliding


func is_ground_pounding() -> bool:
	return _is_ground_pounding



## ── Abilities ───────────────────────────────────────────────────────
## Collect a charge. Replaces any charge already held rather than queuing:
## one slot keeps "what does the player have right now" answerable at a
## glance, both for the HUD and for level design.
func grant_ability(kind: int) -> void:
	_held_ability = kind
	ability_granted.emit(kind)


func held_ability() -> int:
	return _held_ability


func is_gliding() -> bool:
	return _is_gliding


func _handle_ability(delta: float) -> void:
	# An active glide keeps clamping fall speed until it expires or we land.
	if _is_gliding:
		_glide_timer -= delta
		if _glide_timer <= 0.0 or is_on_floor():
			_is_gliding = false
		elif velocity.y > glide_fall_speed:
			velocity.y = glide_fall_speed

	if not Input.is_action_just_pressed("ability") or _held_ability < 0:
		return

	match _held_ability:
		0:  # SUPER_JUMP
			# Through apply_external_launch() so _handle_jump()'s release
			# damping cannot halve it — the bug bounce pads already hit once.
			apply_external_launch(super_jump_velocity)
		1:  # GLIDE
			# Only meaningful in the air; spending it on the ground would
			# waste the charge for nothing.
			if is_on_floor():
				return
			_is_gliding = true
			_glide_timer = glide_time
	ability_used.emit(_held_ability)
	_held_ability = -1



## ── Grapple ─────────────────────────────────────────────────────────
## Returns true while reeling, meaning the caller skips normal locomotion.
##
## Aims in the facing direction with an upward bias, because the game is an
## ascent: a purely horizontal grapple would be nearly useless here, and a
## free-aim version needs a cursor this game does not have.
func _handle_grapple(delta: float) -> bool:
	if _is_grappling:
		var to_target := _grapple_target - global_position
		if to_target.length() <= grapple_arrive_distance or is_on_wall():
			_release_grapple()
			return false
		velocity = to_target.normalized() * grapple_pull_speed
		# Cancel on a second press, so the player is never a passenger.
		if Input.is_action_just_pressed("grapple"):
			_release_grapple()
			return false
		return true

	if not Input.is_action_just_pressed("grapple") or _grapple_cooldown_timer > 0.0:
		return false

	var space := get_world_2d().direct_space_state
	# Three rays: level-ish, and two steeper. First terrain hit wins.
	for angle_deg in [-32.0, -55.0, -12.0]:
		var dir := Vector2(float(_facing), 0.0).rotated(deg_to_rad(angle_deg))
		var query := PhysicsRayQueryParameters2D.create(
			global_position, global_position + dir * grapple_range)
		query.collision_mask = 2   # terrain only, never the player or chasers
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			_grapple_target = hit["position"]
			_is_grappling = true
			# Reel from THIS frame. Returning true hands the frame straight to
			# move_and_slide(), so without setting velocity here the player
			# spends one frame still falling at gravity speed before the pull
			# takes over — a visible hitch right at the moment of latching.
			var to_hit := _grapple_target - global_position
			if to_hit.length() > 0.001:
				velocity = to_hit.normalized() * grapple_pull_speed
			grappled.emit(_grapple_target)
			return true
	# A miss still costs the cooldown, so it cannot be spammed as a free probe.
	_grapple_cooldown_timer = grapple_cooldown * 0.5
	return false


func _release_grapple() -> void:
	if not _is_grappling:
		return
	_is_grappling = false
	# Start the cooldown on RELEASE, not on fire. Charged at fire it ticks
	# away during the reel itself, so a max-range grapple (0.44s of travel)
	# would leave barely a tenth of the intended gap before the next one.
	_grapple_cooldown_timer = grapple_cooldown
	# Keep a little of the reel momentum so arriving feels like an arc rather
	# than a dead stop. The lock is what makes that survive: _handle_horizontal
	# runs later in the same frame and would otherwise recompute velocity.x
	# from the input axis, discarding the horizontal half immediately.
	velocity *= 0.45
	# _wall_jump_lock_timer is the existing "preserve launch momentum, ignore
	# steering" gate in _handle_horizontal — exactly the behaviour needed here.
	_wall_jump_lock_timer = maxf(_wall_jump_lock_timer, 0.12)
	grapple_released.emit()


func is_grappling() -> bool:
	return _is_grappling


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
		_spin_available = true
		landed.emit(impact_speed)

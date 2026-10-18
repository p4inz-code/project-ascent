class_name ChaserSurge
extends RefCounted
## The rhythm of a chaser: it winds up, then lunges.
##
##   CHASE    normal speed (the clock runs)
##   WIND_UP  it slows and flashes with a "!" (the telegraph; 0.7 s)
##   SURGE    a short burst of speed (0.9 s)
##
## Fair by construction: the surge never starts without the wind-up first, never
## while the player is far away (they cannot be caught by something out of sight),
## and the burst is brief. The interval is randomised a little so a pack of chasers
## does not lunge in unison, but every timing stays inside fixed bounds.

enum State { CHASE, WIND_UP, SURGE }

const WIND_UP_TIME := 0.7
const SURGE_TIME := 0.9
const WIND_UP_SPEED := 0.55
const SURGE_SPEED := 1.45
const MIN_INTERVAL := 4.5
const MAX_INTERVAL := 7.5
## Only lunge at a player closer than this (world px).
const TRIGGER_RANGE := 760.0

var state: State = State.CHASE
var _clock: float = 0.0
var _next_at: float
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_next_at = _roll_interval()


func _roll_interval() -> float:
	return _rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)


## Advance by `delta`. `player_distance` gates the lunge. Returns the speed
## multiplier to apply this frame.
func update(delta: float, player_distance: float) -> float:
	_clock += delta
	match state:
		State.CHASE:
			if _clock >= _next_at and player_distance <= TRIGGER_RANGE:
				state = State.WIND_UP
				_clock = 0.0
		State.WIND_UP:
			if _clock >= WIND_UP_TIME:
				state = State.SURGE
				_clock = 0.0
		State.SURGE:
			if _clock >= SURGE_TIME:
				state = State.CHASE
				_clock = 0.0
				_next_at = _roll_interval()
	match state:
		State.WIND_UP:
			return WIND_UP_SPEED
		State.SURGE:
			return SURGE_SPEED
	return 1.0


func is_winding_up() -> bool:
	return state == State.WIND_UP


func is_surging() -> bool:
	return state == State.SURGE


## Back to a calm chase (a new attempt).
func reset() -> void:
	state = State.CHASE
	_clock = 0.0
	_next_at = _roll_interval()

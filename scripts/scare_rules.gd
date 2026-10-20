class_name ScareRules
extends RefCounted
## When a harmless jump scare may fire. Pure rules with no scene, so they are testable over a
## simulated session. The doctrine (docs/PLAN_v2_big_run_2026-10-20.md, round 8):
##   * scares are CUED: a cue first, the pop only after CUE_TIME, and the pop is cancelled if the
##     player has walked into a precision section meanwhile
##   * 20-30 s apart, at most MAX_PER_LEVEL per level session, never within QUIET_AFTER_RESPAWN
##     seconds of a respawn, never during a precision section
##   * they follow the player's mistakes (a hit, a fall from the deck); a few feints in safe places
##   * FIXED safety limits: at most MAX_FLASHES_PER_SECOND, one flash pair per scare, no saturated red,
##     no strobes; Reduced mode has no flash at all

enum Mode { FULL = 0, REDUCED = 1, OFF = 2 }

const MIN_GAP := 20.0
const MAX_GAP := 30.0
const MAX_PER_LEVEL := 6
const QUIET_AFTER_RESPAWN := 3.0
const CUE_TIME := 0.45
const MAX_FLASHES_PER_SECOND := 3
## One scare shows at most this many bright pulses (a pulse is one rise and fall).
const FLASH_PULSES_PER_SCARE := 1
## The colour of the only flash a scare may use (violet-white): red must stay below this share.
const FLASH_COLOR := Color(0.62, 0.42, 1.0)
const FLASH_MAX_ALPHA := 0.32
const FEINT_EXTRA_WAIT := 15.0
const FEINT_CHANCE := 0.3

var mode: int = Mode.FULL
var count: int = 0
var since_last: float = 0.0
var since_respawn: float = 99.0
var next_gap: float = 25.0
var rng := RandomNumberGenerator.new()


func _init(seed: int = 0) -> void:
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	since_last = 0.0
	next_gap = rng.randf_range(MIN_GAP, MAX_GAP)


func tick(delta: float) -> void:
	since_last += delta
	since_respawn += delta


func on_respawn() -> void:
	since_respawn = 0.0


## A fresh level session: the count starts again, and the first scare is at least a gap away.
func on_level_start() -> void:
	count = 0
	since_last = 0.0
	since_respawn = 0.0
	next_gap = rng.randf_range(MIN_GAP, MAX_GAP)


## Effective mode: Reduce Motion (no death flash) caps it at REDUCED.
static func effective_mode(setting: int, reduce_motion: bool) -> int:
	if setting == Mode.OFF:
		return Mode.OFF
	if reduce_motion:
		return Mode.REDUCED
	return setting


## May a scare of this kind start now? `trigger` is "mistake" or "feint".
func may_fire(trigger: String, precision_near: bool) -> bool:
	if mode == Mode.OFF or count >= MAX_PER_LEVEL:
		return false
	if precision_near or since_respawn < QUIET_AFTER_RESPAWN:
		return false
	if since_last < next_gap:
		return false
	if trigger == "feint":
		if since_last < next_gap + FEINT_EXTRA_WAIT:
			return false
		return rng.randf() < FEINT_CHANCE
	return trigger == "mistake"


## Record that one fired.
func fired() -> void:
	count += 1
	since_last = 0.0
	next_gap = rng.randf_range(MIN_GAP, MAX_GAP)


## True when the flash colour is far from saturated red (the safety rule).
static func flash_color_is_safe() -> bool:
	var c := FLASH_COLOR
	return not (c.r > 0.75 and c.g < 0.35 and c.b < 0.35) and FLASH_MAX_ALPHA <= 0.35

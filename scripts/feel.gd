class_name Feel
extends RefCounted
## Control-feel presets: how quickly the character answers the stick, and how
## forgiving the timing windows are. "Sensitivity" in one setting.
##
## Reference: Celeste's published player code reaches full run speed in ~0.09 s
## but takes ~0.225 s to stop, with 65% air control and a 0.1 s jump grace.
## Ours used to stop in 0.06 s, which reads as abrupt, so PRECISE is the
## Celeste-like feel, SNAPPY is the long-standing default (with slightly wider
## windows), and INSTANT removes nearly all ramp for the most direct response.
##
## Pure data + one apply function, so the numbers are unit-testable without a
## scene and a preset can never half-apply.

enum Preset { PRECISE = 0, SNAPPY = 1, INSTANT = 2 }

const NAMES: Array[String] = ["PRECISE", "SNAPPY", "INSTANT"]
const DESCRIPTIONS: Array[String] = [
	"Weighty and exact. Slides a little when you let go.",
	"The default. Quick to start, quick to stop.",
	"Nearly no ramp. The character goes where you point, now.",
]

const VALUES: Array[Dictionary] = [
	{"ground_accel_time": 0.09, "ground_decel_time": 0.18, "air_accel_time": 0.14,
		"air_decel_time": 0.20, "coyote_time": 0.10, "jump_buffer_time": 0.10,
		"corner_correction": 8.0},
	{"ground_accel_time": 0.08, "ground_decel_time": 0.06, "air_accel_time": 0.12,
		"air_decel_time": 0.16, "coyote_time": 0.12, "jump_buffer_time": 0.12,
		"corner_correction": 12.0},
	{"ground_accel_time": 0.03, "ground_decel_time": 0.03, "air_accel_time": 0.06,
		"air_decel_time": 0.10, "coyote_time": 0.14, "jump_buffer_time": 0.16,
		"corner_correction": 16.0},
]


static func clamp_preset(p: int) -> int:
	return clampi(p, 0, VALUES.size() - 1)


static func values_for(preset: int) -> Dictionary:
	return VALUES[clamp_preset(preset)]


## Write a preset's numbers onto a Player. Missing properties are skipped rather
## than assumed, so a stripped-down test player can't crash this.
static func apply(player: Object, preset: int) -> void:
	var v := values_for(preset)
	for key in v:
		if key in player:
			player.set(key, v[key])

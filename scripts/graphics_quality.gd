class_name GraphicsQuality
extends RefCounted
## Graphics quality presets and the rules that pick one automatically.
##
## A preset only touches how the game LOOKS: particles, weather, background motion,
## afterimages, dither, scanlines, glow and parallax. It never touches physics, hazards,
## collision or timing, so a level is exactly as fair on LOW as on HIGH (a test pins this).
## Picking a preset writes those visual settings, which the player can still tweak one by one.

enum Preset { AUTO, LOW, MEDIUM, HIGH }

const NAMES: Array[String] = ["AUTO", "LOW", "MEDIUM", "HIGH"]

## The visual settings each preset writes (GameSettings field -> value).
const FIELDS := {
	Preset.LOW: {
		"floating_particles": false, "bg_motion": false, "afterimages": false,
		"pixel_dither": 0.0, "scanlines": 0.0, "glow_intensity": 0.4, "parallax_intensity": 0.5,
	},
	Preset.MEDIUM: {
		"floating_particles": true, "bg_motion": true, "afterimages": false,
		"pixel_dither": 0.6, "scanlines": 0.0, "glow_intensity": 0.7, "parallax_intensity": 0.8,
	},
	Preset.HIGH: {
		"floating_particles": true, "bg_motion": true, "afterimages": true,
		"pixel_dither": 1.0, "scanlines": 0.0, "glow_intensity": 1.0, "parallax_intensity": 1.0,
	},
}

## Frame times (ms) that decide the automatic preset. 60 fps is 16.7 ms.
const HIGH_MAX_MS := 18.5
const MEDIUM_MAX_MS := 25.0
## A sustained p95 above this means the current preset is too heavy for this machine.
const STRUGGLE_P95_MS := 30.0


## Write a preset's visual settings into GameSettings. AUTO is not a preset: the caller
## resolves it to LOW / MEDIUM / HIGH first (see pick_for).
static func apply(gs: Node, preset: int) -> void:
	if gs == null or not FIELDS.has(preset):
		return
	var f: Dictionary = FIELDS[preset]
	for k in f:
		gs.set(k, f[k])
	if gs.has_method("save_settings"):
		gs.save_settings()


## The preset for a machine, from how it ran the title scene and what it is rendering with.
## Browsers cannot say much about the GPU, so the web never starts above MEDIUM.
static func pick_for(median_ms: float, renderer: String, is_web: bool) -> int:
	var r := renderer.to_lower()
	if r.contains("llvmpipe") or r.contains("swiftshader") or r.contains("software") \
			or r.contains("basic render") or r.contains("softpipe"):
		return Preset.LOW
	var pick := Preset.LOW
	if median_ms <= HIGH_MAX_MS:
		pick = Preset.HIGH
	elif median_ms <= MEDIUM_MAX_MS:
		pick = Preset.MEDIUM
	if is_web and pick == Preset.HIGH:
		pick = Preset.MEDIUM
	return pick


## The next preset down (LOW stays LOW).
static func lower(preset: int) -> int:
	match preset:
		Preset.HIGH:
			return Preset.MEDIUM
		_:
			return Preset.LOW


static func percentile(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var idx := clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return float(sorted[idx])

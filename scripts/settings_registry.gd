class_name SettingsRegistry
extends RefCounted
## The declarative list of newer settings. Each entry says what the setting is, where it
## lives on the Settings page, its default and its limits; GameSettings stores, validates,
## saves and resets every one of them the same way, and SettingsPage builds the row, the
## search entry and the per-page reset from the same entry. A new setting is one entry
## here plus the code that reads it, and a generic test covers persistence, limits,
## defaults, reset and platform visibility for all of them.
##
## Entry keys: key, tab, section, label, kind ("toggle" | "slider" | "choice"), default,
## lo/hi/step/fmt (slider), names (choice), note (optional), needs (optional: a
## Platform.supports() feature the platform must offer for the row to show).

const KINDS := ["toggle", "slider", "choice"]

const DEFS: Array = [
	# ── VIDEO: graphics quality ──
	{"key": "gfx_quality", "tab": "VIDEO", "section": "GRAPHICS QUALITY", "label": "Quality preset",
		"kind": "choice", "default": 0, "names": ["AUTO", "LOW", "MEDIUM", "HIGH"], "preset": true,
		"note": "AUTO times the game on your machine and picks for you. A preset only changes how things look (particles, weather, background motion, dither, glow). Hazards and timing never change with quality.",
		"tags": "graphics performance fps low high detail"},
	{"key": "gfx_detected", "tab": "VIDEO", "section": "GRAPHICS QUALITY", "label": "Detected preset",
		"kind": "slider", "default": -1.0, "lo": -1.0, "hi": 3.0, "step": 1.0, "fmt": "int", "hidden": true},
	# ── VIDEO: camera ──
	{"key": "cam_zoom", "tab": "VIDEO", "section": "CAMERA", "label": "View distance",
		"kind": "choice", "default": 1, "names": ["CLOSE", "DEFAULT", "WIDE"],
		"note": "How much of the level you see. WIDE shows more but is not used in boss chases or rising-floor levels, where it falls back to DEFAULT.",
		"tags": "zoom camera field of view"},
	{"key": "cam_peek", "tab": "VIDEO", "section": "CAMERA", "label": "Hold to look around",
		"kind": "toggle", "default": true,
		"note": "Hold the Look keys (Up / Z / C / X) or the right stick to look ahead, up or down; the view snaps back when you let go. Off in boss chases and rising-floor levels.",
		"tags": "peek pan look camera right stick"},
	{"key": "cam_follow", "tab": "VIDEO", "section": "CAMERA", "label": "Camera follow speed",
		"kind": "slider", "default": 8.0, "lo": 3.0, "hi": 14.0, "step": 0.5, "fmt": "num",
		"note": "How tightly the view tracks you. Lower is floatier, higher is stiffer.",
		"tags": "camera smoothing"},
	# ── CONTROLS: jump ──
	{"key": "ctl_jump_mode", "tab": "CONTROLS", "section": "JUMP STYLE", "label": "Jump height",
		"kind": "choice", "default": 0, "names": ["HOLD FOR HEIGHT", "ALWAYS FULL"],
		"note": "HOLD FOR HEIGHT: tap for a hop, hold for a full jump. ALWAYS FULL: every jump is full height, so there is nothing to hold.",
		"tags": "jump variable fixed simpler controls"},
	# ── ACCESS: reading ──
	{"key": "ui_text_scale", "tab": "ACCESS", "section": "READING", "label": "Text size",
		"kind": "choice", "default": 0, "names": ["NORMAL", "LARGE", "EXTRA LARGE"],
		"note": "Scales menu text at once. In-game text follows on the next level load.", "rebuild": true, "tags": "font larger bigger readability"},
	{"key": "a11y_high_contrast", "tab": "ACCESS", "section": "READING", "label": "High-contrast platforms",
		"kind": "toggle", "default": false,
		"note": "Draws a bright, thick edge on every platform you can land on.",
		"tags": "contrast outline edge visibility"},
	{"key": "a11y_colorblind", "tab": "ACCESS", "section": "READING", "label": "Colour-blind correction",
		"kind": "choice", "default": 0, "names": ["OFF", "RED-WEAK", "GREEN-WEAK", "BLUE-WEAK"],
		"note": "Shifts the colours of the world so hazards and platforms stay apart. Pick the one that matches your vision.",
		"tags": "colorblind colourblind protanopia deuteranopia tritanopia daltonize"},
	# ── ACCESS: assists (opt-in; nothing here is on by default) ──
	{"key": "assist_coyote", "tab": "ACCESS", "section": "ASSISTS", "label": "Extra ledge grace",
		"kind": "slider", "default": 0.0, "lo": 0.0, "hi": 0.12, "step": 0.01, "fmt": "sec",
		"note": "How long after running off an edge a jump still works. Added to the normal grace.", "tags": "coyote assist easier"},
	{"key": "assist_hazard_speed", "tab": "ACCESS", "section": "ASSISTS", "label": "Hazard speed",
		"kind": "choice", "default": 0, "names": ["NORMAL", "SLOWER", "SLOWEST"],
		"note": "Slows gates, vents, pendulums, blades and darts. Every safe window just gets longer.",
		"tags": "assist easier timing slow traps hazards"},
	{"key": "assist_buffer", "tab": "ACCESS", "section": "ASSISTS", "label": "Extra jump buffer",
		"kind": "slider", "default": 0.0, "lo": 0.0, "hi": 0.12, "step": 0.01, "fmt": "sec",
		"note": "How early before landing a jump press is remembered. Added to the normal buffer.", "tags": "buffer assist easier timing"},
]


static func all() -> Array:
	return DEFS


static func def_of(key: String) -> Dictionary:
	for d in DEFS:
		if String(d["key"]) == key:
			return d
	return {}


static func has_key(key: String) -> bool:
	return not def_of(key).is_empty()


static func default_of(key: String) -> Variant:
	var d := def_of(key)
	return d.get("default", null) if not d.is_empty() else null


## Whether the player sees this setting (hidden ones are bookkeeping).
static func shown(d: Dictionary) -> bool:
	return not bool(d.get("hidden", false)) and visible_on_platform(d)


## Settings that belong on a given tab, in declaration order.
static func for_tab(tab: String) -> Array:
	var out: Array = []
	for d in DEFS:
		if String(d["tab"]) == tab:
			out.append(d)
	return out


## Whether a platform shows this setting.
static func visible_on_platform(d: Dictionary) -> bool:
	var need := String(d.get("needs", ""))
	return need == "" or Platform.supports(need)


## Coerce any value (including untrusted JSON) into a legal one for this setting.
## Wrong types fall back to the default; numbers are clamped; choices are bounded.
static func sanitize(key: String, value: Variant) -> Variant:
	var d := def_of(key)
	if d.is_empty():
		return null
	var fallback: Variant = d["default"]
	match String(d["kind"]):
		"toggle":
			return value if value is bool else fallback
		"slider":
			if value is float or value is int:
				var f := float(value)
				if is_nan(f) or is_inf(f):
					return fallback
				return clampf(f, float(d["lo"]), float(d["hi"]))
			return fallback
		"choice":
			if value is float or value is int:
				return clampi(int(value), 0, (d["names"] as Array).size() - 1)
			return fallback
	return fallback


## Untrusted dictionary -> {key: legal value} for known keys only.
static func sanitize_all(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for d in DEFS:
		var k := String(d["key"])
		if (raw as Dictionary).has(k):
			out[k] = sanitize(k, (raw as Dictionary)[k])
	return out


## Readout text for a slider value.
static func format_value(d: Dictionary, v: float) -> String:
	match String(d.get("fmt", "")):
		"pct":
			return "%d PCT" % roundi(v * 100.0)
		"sec":
			return "%d MS" % roundi(v * 1000.0)
		"x":
			return "%.2fX" % v
		"num":
			return "%.1f" % v
		"int":
			return "%d" % roundi(v)
	return "%.2f" % v

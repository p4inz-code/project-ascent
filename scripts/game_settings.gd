extends Node
## Autoload singleton for persisting game settings.
##
## Settings are saved to user://settings.json and loaded on startup.
## Other scripts read from this singleton to determine visual/gameplay options.

signal settings_changed

const SETTINGS_PATH := "user://settings.json"

# === Audio ===
# Linear 0-1, matching audio.gd's tuned dB defaults exactly (0dB, -20dB,
# -8dB via linear = 10^(db/20)) so a fresh install with no settings.json
# yet gets the actually-designed mix, not an arbitrary different one.
var master_volume: float = 1.0
var music_volume: float = 0.1
var sfx_volume: float = 0.4

# === Visual ===
var screen_shake: bool = true
var afterimages: bool = true
var floating_particles: bool = true
var bg_motion: bool = true  # parallax / city silhouette movement
var show_fps: bool = false

# === Gameplay ===
var show_controls: bool = true
var death_flash: bool = true
var boss_warnings: bool = true
var attempt_counter: bool = true
var run_timer: bool = true

# === Personalisation ===
## Index into PLAYER_COLORS / ACCENT_COLORS. Stored as an index rather than a
## packed colour so a corrupted or hand-edited file can only ever select a
## palette entry that actually exists — no way to end up with an invisible
## player or unreadable UI.
var player_color: int = 0
var accent_color: int = 0

## Index into THEMES. A theme is a NAMED PRESET that sets the player colour,
## UI accent, platform edge tint and backdrop tint together, so picking one
## visibly changes the whole game rather than just the menu chrome.
##
## "Ascent" stays index 0 and is the game's own identity — the palette
## everything was designed around. Themes sit beside it, they do not replace
## it. Choosing a theme writes through to player_color/accent_color, so the
## individual pickers keep working as overrides underneath: a theme is a
## one-click starting point, not a cage.
var theme: int = 0

## Intensity dials, replacing what used to be on/off only. 0.0 reads as off,
## so these subsume the old booleans rather than fighting them.
var shake_intensity: float = 1.0
var parallax_intensity: float = 1.0
var glow_intensity: float = 1.0

const PLAYER_COLORS: Array[Color] = [
	Color(0.419608, 0.780392, 1.0),   # Ascent Blue (the original)
	Color(1.0, 0.45, 0.75),           # Magenta
	Color(0.45, 1.0, 0.62),           # Signal Green
	Color(1.0, 0.78, 0.35),           # Amber
	Color(0.80, 0.55, 1.0),           # Violet
	Color(1.0, 0.42, 0.36),           # Ember
]
const PLAYER_COLOR_NAMES: Array[String] = [
	"Ascent", "Magenta", "Signal", "Amber", "Violet", "Ember",
]

const ACCENT_COLORS: Array[Color] = [
	Color(0.20, 0.70, 1.00),          # Cyan (the original)
	Color(0.45, 1.00, 0.72),          # Mint
	Color(1.00, 0.60, 0.30),          # Orange
	Color(0.85, 0.55, 1.00),          # Lilac
	Color(1.00, 0.38, 0.48),          # Rose
]
const ACCENT_COLOR_NAMES: Array[String] = [
	"Cyan", "Mint", "Orange", "Lilac", "Rose",
]

## name, player colour index, accent index, platform edge tint, backdrop tint.
## The two tints multiply the level's own palette rather than replacing it, so
## every Act keeps its designed identity while still reading as the theme.
const THEMES: Array[Dictionary] = [
	{"name": "Ascent", "player": 0, "accent": 0,
		"edge": Color(1.00, 1.00, 1.00), "bg": Color(1.00, 1.00, 1.00)},
	{"name": "Ember",  "player": 5, "accent": 2,
		"edge": Color(1.15, 0.72, 0.48), "bg": Color(1.12, 0.86, 0.78)},
	{"name": "Frost",  "player": 0, "accent": 0,
		"edge": Color(0.72, 0.95, 1.15), "bg": Color(0.84, 0.95, 1.15)},
	{"name": "Vapor",  "player": 1, "accent": 3,
		"edge": Color(1.10, 0.70, 1.15), "bg": Color(1.05, 0.84, 1.18)},
	{"name": "Toxic",  "player": 2, "accent": 1,
		"edge": Color(0.72, 1.20, 0.78), "bg": Color(0.84, 1.12, 0.88)},
	{"name": "Mono",   "player": 0, "accent": 0,
		"edge": Color(0.92, 0.94, 0.98), "bg": Color(0.88, 0.90, 0.94)},
]


func get_theme() -> Dictionary:
	return THEMES[clampi(theme, 0, THEMES.size() - 1)]


## Apply a theme preset: writes through to the individual colour settings so
## the pickers stay in sync and keep working as overrides afterwards.
func apply_theme(index: int) -> void:
	theme = clampi(index, 0, THEMES.size() - 1)
	var t := get_theme()
	player_color = int(t["player"])
	accent_color = int(t["accent"])
	save_settings()


## Resolved colours, clamped to a real palette entry so a bad index can never
## reach the renderer.
func get_player_color() -> Color:
	return PLAYER_COLORS[clampi(player_color, 0, PLAYER_COLORS.size() - 1)]


func get_accent_color() -> Color:
	return ACCENT_COLORS[clampi(accent_color, 0, ACCENT_COLORS.size() - 1)]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func save_settings() -> void:
	var data := {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"screen_shake": screen_shake,
		"afterimages": afterimages,
		"floating_particles": floating_particles,
		"bg_motion": bg_motion,
		"show_fps": show_fps,
		"show_controls": show_controls,
		"death_flash": death_flash,
		"boss_warnings": boss_warnings,
		"attempt_counter": attempt_counter,
		"run_timer": run_timer,
		"player_color": player_color,
		"accent_color": accent_color,
		"theme": theme,
		"shake_intensity": shake_intensity,
		"parallax_intensity": parallax_intensity,
		"glow_intensity": glow_intensity,
	}
	# Same atomic write as SaveSystem.save() — write to a temp file and
	# rename over the real one so a crash mid-write can't leave
	# settings.json truncated and unparseable.
	var tmp_path := SETTINGS_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.rename(tmp_path, SETTINGS_PATH)
	settings_changed.emit()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("GameSettings: corrupted settings.json, using defaults")
		return
	var data = json.data
	if not data is Dictionary:
		push_warning("GameSettings: settings.json is not an object, using defaults")
		return
	# A hand-edited or corrupted file can carry any JSON type per key — e.g.
	# a string where a float is expected. Assigning that directly to these
	# explicitly-typed vars throws a runtime type error and would crash
	# _ready() (this is an autoload, so that takes the whole game down at
	# startup). Every read below is type-checked, falling back to the
	# current default rather than trusting the file blindly.
	master_volume = _read_float(data, "master_volume", master_volume)
	music_volume = _read_float(data, "music_volume", music_volume)
	sfx_volume = _read_float(data, "sfx_volume", sfx_volume)
	screen_shake = _read_bool(data, "screen_shake", screen_shake)
	afterimages = _read_bool(data, "afterimages", afterimages)
	floating_particles = _read_bool(data, "floating_particles", floating_particles)
	bg_motion = _read_bool(data, "bg_motion", bg_motion)
	show_fps = _read_bool(data, "show_fps", show_fps)
	show_controls = _read_bool(data, "show_controls", show_controls)
	death_flash = _read_bool(data, "death_flash", death_flash)
	boss_warnings = _read_bool(data, "boss_warnings", boss_warnings)
	attempt_counter = _read_bool(data, "attempt_counter", attempt_counter)
	run_timer = _read_bool(data, "run_timer", run_timer)
	player_color = _read_index(data, "player_color", player_color, PLAYER_COLORS.size())
	accent_color = _read_index(data, "accent_color", accent_color, ACCENT_COLORS.size())
	theme = _read_index(data, "theme", theme, THEMES.size())
	shake_intensity = _read_float(data, "shake_intensity", shake_intensity)
	parallax_intensity = _read_float(data, "parallax_intensity", parallax_intensity)
	glow_intensity = _read_float(data, "glow_intensity", glow_intensity)


func _read_float(data: Dictionary, key: String, fallback: float) -> float:
	var v = data.get(key, fallback)
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
	return fallback


## Palette indices get the same defensive treatment as every other read, plus
## a bounds check against the live palette size — so shrinking a palette in a
## later version can't leave an existing save pointing past the end of it.
func _read_index(data: Dictionary, key: String, fallback: int, count: int) -> int:
	var v = data.get(key, fallback)
	if v is int or v is float:
		return clampi(int(v), 0, count - 1)
	return fallback


func _read_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var v = data.get(key, fallback)
	if v is bool:
		return v
	return fallback


func reset_settings() -> void:
	master_volume = 1.0
	music_volume = 0.1
	sfx_volume = 0.4
	screen_shake = true
	afterimages = true
	floating_particles = true
	bg_motion = true
	show_fps = false
	show_controls = true
	death_flash = true
	boss_warnings = true
	attempt_counter = true
	run_timer = true
	player_color = 0
	accent_color = 0
	theme = 0
	shake_intensity = 1.0
	parallax_intensity = 1.0
	glow_intensity = 1.0
	save_settings()

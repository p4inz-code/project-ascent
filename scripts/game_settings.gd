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

# === Audio FX ===
## Volume of menu clicks and cues (their own bus), 0..1.
var ui_volume: float = 0.6
## Reverb on sound effects, 0 = dry.
var audio_room_echo: float = 0.0
## Compressor on the master bus: loud things quieter, quiet things clearer.
var audio_night_mode: bool = false
## Low-pass the master bus while the pause menu is open.
var audio_pause_muffle: bool = true
## Silence the game while its window is not focused.
var audio_mute_unfocused: bool = true

# === Interface / access ===
## Index into UITheme.FONT_NAMES.
var font_choice: int = 0
## Pause automatically when the window loses focus.
var pause_on_focus_loss: bool = false

# === Texture / pixel look ===
## 0 = off (smooth), 1 = normal pixel grid, 2 = chunky (double-size pixels).
var pixel_mode: int = 1
## 0..1 strength of the ordered dither that stipples gradients.
var pixel_dither: float = 1.0
## Colour steps per channel (fewer = more banded and retro).
var pixel_levels: int = 20
## 0..1 strength of CRT-style scanlines over the world.
var scanlines: float = 0.0
## Surface texture on plain platforms: 0 = brick, 1 = flat colour.
var tile_style: int = 0

const PIXEL_MODE_NAMES: Array[String] = ["OFF", "NORMAL", "CHUNKY"]
const TILE_STYLE_NAMES: Array[String] = ["BRICK", "FLAT"]
const PIXEL_LEVELS_MIN := 6
const PIXEL_LEVELS_MAX := 32

# === Registered settings (see SettingsRegistry) ===
## key -> value, only for keys the player has changed. Anything missing reads its default.
var reg: Dictionary = {}

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

# === Controls ===
## Index into Feel.Preset (PRECISE / SNAPPY / INSTANT). See feel.gd.
var feel_preset: int = 1

## Stick dead-zone for every analogue-driven action. Lower = twitchier.
const DEADZONE_MIN := 0.05
const DEADZONE_MAX := 0.5
const DEADZONE_DEFAULT := 0.2
var stick_deadzone: float = DEADZONE_DEFAULT

## Keyboard layout overrides: {action: [physical keycodes]}. Empty means the
## shipped defaults. Validated on load (see InputBindings.sanitize).
var key_bindings: Dictionary = {}

# === Character ===
## Index into ACCESSORIES / VISOR_COLORS / TRIM_COLORS (clamped on load).
var accessory: int = 0
var visor_color: int = 0
var trim_color: int = 0

const ACCESSORIES: Array[String] = ["pack", "antenna", "scarf", "none"]
const ACCESSORY_NAMES: Array[String] = ["Backpack", "Antenna", "Scarf", "Nothing"]
const VISOR_COLORS: Array[Color] = [
	Color(0.9216, 0.9725, 1.0), Color(1.0, 0.82, 0.35), Color(0.45, 1.0, 0.62),
	Color(1.0, 0.5, 0.78), Color(0.25, 0.28, 0.38),
]
const VISOR_COLOR_NAMES: Array[String] = ["Ice", "Gold", "Signal", "Rose", "Tinted"]
const TRIM_COLORS: Array[Color] = [
	Color(1.0, 0.702, 0.2784), Color(0.35, 0.85, 1.0), Color(1.0, 0.45, 0.62),
	Color(0.62, 1.0, 0.45), Color(0.95, 0.95, 1.0), Color(1.0, 0.35, 0.3),
]
const TRIM_COLOR_NAMES: Array[String] = ["Amber", "Cyan", "Pink", "Lime", "White", "Red"]


func get_visor_color() -> Color:
	return VISOR_COLORS[clampi(visor_color, 0, VISOR_COLORS.size() - 1)]


func get_trim_color() -> Color:
	return TRIM_COLORS[clampi(trim_color, 0, TRIM_COLORS.size() - 1)]


## Path of the player sprite sheet for the chosen accessory.
func sheet_path() -> String:
	var acc: String = ACCESSORIES[clampi(accessory, 0, ACCESSORIES.size() - 1)]
	return "res://assets/pixel/player_sheet.png" if acc == "pack" \
		else "res://assets/pixel/player_sheet_%s.png" % acc


# === Story ===
## True once the opening cutscene has played, so it shows on a first run only.
## Replayable any time from the title menu.
var intro_seen: bool = false
## True once the tutorial has been completed.
var tutorial_done: bool = false

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
	# Snapshot the shipped layout BEFORE any saved override is applied, so a
	# later "reset" restores the real defaults.
	InputBindings.snapshot_defaults()
	load_settings()
	InputBindings.apply(key_bindings)
	apply_stick_deadzone()
	AudioFx.apply(self)
	settings_changed.connect(func(): AudioFx.apply(self))


## Rebind one action's primary key and persist. Returns the displaced action
## (the key's previous owner, swapped onto this action's old key) or "".
func rebind_key(action: String, code: int) -> String:
	var displaced := InputBindings.rebind(action, code)
	key_bindings = InputBindings.export_all()
	save_settings()
	return displaced


## Push the dead-zone onto every action that listens to a stick.
var _muted_by_focus: bool = false
var _was_muted_before_focus_loss: bool = false


## Window focus: optionally silence the game while it is in the background, and
## optionally pause it so nothing happens while you are away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if audio_mute_unfocused and not _muted_by_focus:
			_was_muted_before_focus_loss = AudioServer.is_bus_mute(0)
			AudioServer.set_bus_mute(0, true)
			_muted_by_focus = true
		if pause_on_focus_loss:
			var gm := get_node_or_null("/root/GameManager")
			if gm != null and not gm.is_paused and gm.pause_menu != null:
				gm.pause_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _muted_by_focus:
			AudioServer.set_bus_mute(0, _was_muted_before_focus_loss)
			_muted_by_focus = false


func _process(_delta: float) -> void:
	# Muffle only while the PAUSE MENU is open, not on the title screen (which
	# also pauses the tree).
	var gm := get_node_or_null("/root/GameManager")
	var want: bool = audio_pause_muffle and gm != null and gm.is_paused
	if want != AudioFx.is_muffled():
		AudioFx.set_muffled(want)


func apply_stick_deadzone() -> void:
	stick_deadzone = clampf(stick_deadzone, DEADZONE_MIN, DEADZONE_MAX)
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion:
				InputMap.action_set_deadzone(action, stick_deadzone)
				break


func reset_key_bindings() -> void:
	InputBindings.reset_all()
	key_bindings = {}
	save_settings()


## Current value of a registered setting (its default until changed).
func get_reg(key: String) -> Variant:
	if reg.has(key):
		return reg[key]
	return SettingsRegistry.default_of(key)


## Set a registered setting. The value is validated; unknown keys are ignored.
func set_reg(key: String, value: Variant, save: bool = true) -> void:
	if not SettingsRegistry.has_key(key):
		return
	reg[key] = SettingsRegistry.sanitize(key, value)
	if save:
		save_settings()
	else:
		settings_changed.emit()


## Put one tab's registered settings back to their defaults.
func reset_registry_tab(tab: String) -> void:
	for d in SettingsRegistry.for_tab(tab):
		reg.erase(String(d["key"]))
	save_settings()


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
		"intro_seen": intro_seen,
		"tutorial_done": tutorial_done,
		"feel_preset": feel_preset,
		"pixel_mode": pixel_mode,
		"pixel_dither": pixel_dither,
		"pixel_levels": pixel_levels,
		"scanlines": scanlines,
		"tile_style": tile_style,
		"ui_volume": ui_volume,
		"audio_room_echo": audio_room_echo,
		"audio_night_mode": audio_night_mode,
		"audio_pause_muffle": audio_pause_muffle,
		"audio_mute_unfocused": audio_mute_unfocused,
		"font_choice": font_choice,
		"pause_on_focus_loss": pause_on_focus_loss,
		"accessory": accessory,
		"visor_color": visor_color,
		"trim_color": trim_color,
		"stick_deadzone": stick_deadzone,
		"key_bindings": InputBindings.export_all() if not key_bindings.is_empty() else {},
		"player_color": player_color,
		"accent_color": accent_color,
		"theme": theme,
		"shake_intensity": shake_intensity,
		"parallax_intensity": parallax_intensity,
		"glow_intensity": glow_intensity,
		"reg": reg,
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
	intro_seen = _read_bool(data, "intro_seen", intro_seen)
	tutorial_done = _read_bool(data, "tutorial_done", tutorial_done)
	feel_preset = _read_index(data, "feel_preset", feel_preset, Feel.VALUES.size())
	pixel_mode = _read_index(data, "pixel_mode", pixel_mode, PIXEL_MODE_NAMES.size())
	pixel_dither = _read_float(data, "pixel_dither", pixel_dither)
	pixel_levels = clampi(_read_int(data, "pixel_levels", pixel_levels), PIXEL_LEVELS_MIN, PIXEL_LEVELS_MAX)
	scanlines = _read_float(data, "scanlines", scanlines)
	tile_style = _read_index(data, "tile_style", tile_style, TILE_STYLE_NAMES.size())
	ui_volume = _read_float(data, "ui_volume", ui_volume)
	audio_room_echo = _read_float(data, "audio_room_echo", audio_room_echo)
	audio_night_mode = _read_bool(data, "audio_night_mode", audio_night_mode)
	audio_pause_muffle = _read_bool(data, "audio_pause_muffle", audio_pause_muffle)
	audio_mute_unfocused = _read_bool(data, "audio_mute_unfocused", audio_mute_unfocused)
	font_choice = _read_index(data, "font_choice", font_choice, UITheme.FONT_NAMES.size())
	pause_on_focus_loss = _read_bool(data, "pause_on_focus_loss", pause_on_focus_loss)
	accessory = _read_index(data, "accessory", accessory, ACCESSORIES.size())
	visor_color = _read_index(data, "visor_color", visor_color, VISOR_COLORS.size())
	trim_color = _read_index(data, "trim_color", trim_color, TRIM_COLORS.size())
	key_bindings = InputBindings.sanitize(data.get("key_bindings", {}))
	stick_deadzone = clampf(_read_float(data, "stick_deadzone", stick_deadzone), DEADZONE_MIN, DEADZONE_MAX)
	player_color = _read_index(data, "player_color", player_color, PLAYER_COLORS.size())
	accent_color = _read_index(data, "accent_color", accent_color, ACCENT_COLORS.size())
	theme = _read_index(data, "theme", theme, THEMES.size())
	shake_intensity = _read_float(data, "shake_intensity", shake_intensity)
	parallax_intensity = _read_float(data, "parallax_intensity", parallax_intensity)
	glow_intensity = _read_float(data, "glow_intensity", glow_intensity)
	reg = SettingsRegistry.sanitize_all(data.get("reg", {}))


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


func _read_int(data: Dictionary, key: String, fallback: int) -> int:
	var v = data.get(key, fallback)
	if v is int or v is float:
		return int(v)
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
	feel_preset = 1
	pixel_mode = 1
	pixel_dither = 1.0
	pixel_levels = 20
	scanlines = 0.0
	tile_style = 0
	ui_volume = 0.6
	audio_room_echo = 0.0
	audio_night_mode = false
	audio_pause_muffle = true
	audio_mute_unfocused = true
	font_choice = 0
	pause_on_focus_loss = false
	reg = {}
	accessory = 0
	visor_color = 0
	trim_color = 0
	stick_deadzone = DEADZONE_DEFAULT
	apply_stick_deadzone()
	InputBindings.reset_all()
	key_bindings = {}
	save_settings()

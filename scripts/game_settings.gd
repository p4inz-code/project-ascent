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


func _read_float(data: Dictionary, key: String, fallback: float) -> float:
	var v = data.get(key, fallback)
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
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
	save_settings()

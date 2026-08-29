extends Node
## Autoload singleton for persisting game settings.
##
## Settings are saved to user://settings.json and loaded on startup.
## Other scripts read from this singleton to determine visual/gameplay options.

signal settings_changed

const SETTINGS_PATH := "user://settings.json"

# === Audio ===
var master_volume: float = 1.0
var music_volume: float = 0.3
var sfx_volume: float = 0.5

# === Visual ===
var screen_shake: bool = true
var afterimages: bool = true
var floating_particles: bool = true
var bg_motion: bool = true  # parallax / city silhouette movement
var show_fps: bool = false
var hud_opacity: float = 1.0

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
		"hud_opacity": hud_opacity,
		"show_controls": show_controls,
		"death_flash": death_flash,
		"boss_warnings": boss_warnings,
		"attempt_counter": attempt_counter,
		"run_timer": run_timer,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
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
		return
	var data = json.data
	if data is Dictionary:
		master_volume = data.get("master_volume", master_volume)
		music_volume = data.get("music_volume", music_volume)
		sfx_volume = data.get("sfx_volume", sfx_volume)
		screen_shake = data.get("screen_shake", screen_shake)
		afterimages = data.get("afterimages", afterimages)
		floating_particles = data.get("floating_particles", floating_particles)
		bg_motion = data.get("bg_motion", bg_motion)
		show_fps = data.get("show_fps", show_fps)
		hud_opacity = data.get("hud_opacity", hud_opacity)
		show_controls = data.get("show_controls", show_controls)
		death_flash = data.get("death_flash", death_flash)
		boss_warnings = data.get("boss_warnings", boss_warnings)
		attempt_counter = data.get("attempt_counter", attempt_counter)
		run_timer = data.get("run_timer", run_timer)


func reset_settings() -> void:
	master_volume = 1.0
	music_volume = 0.3
	sfx_volume = 0.5
	screen_shake = true
	afterimages = true
	floating_particles = true
	bg_motion = true
	show_fps = false
	hud_opacity = 1.0
	show_controls = true
	death_flash = true
	boss_warnings = true
	attempt_counter = true
	run_timer = true
	save_settings()

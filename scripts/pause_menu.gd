extends CanvasLayer
## In-game pause menu for Project Ascent.
##
## Shows on ESC. Freezes gameplay. Provides: Resume, Restart Level,
## Settings (audio + visual + gameplay), Progress, Reset Progress, Quit.

@onready var _panel: Control = $Panel
@onready var _title_label: Label = $Panel/MenuVBox/Title
@onready var _resume_btn: Button = $Panel/MenuVBox/Resume
@onready var _restart_btn: Button = $Panel/MenuVBox/Restart
@onready var _settings_btn: Button = $Panel/MenuVBox/Settings
@onready var _progress_btn: Button = $Panel/MenuVBox/Progress
@onready var _reset_btn: Button = $Panel/MenuVBox/Reset
@onready var _quit_btn: Button = $Panel/MenuVBox/Quit

# Settings panel
@onready var _settings_panel: ScrollContainer = $Panel/SettingsPanel
@onready var _settings_back: Button = $Panel/SettingsPanel/VBox/Back

# Audio settings
@onready var _master_slider: HSlider = $Panel/SettingsPanel/VBox/AudioSection/AudioVBox/Master/MasterSlider
@onready var _music_slider: HSlider = $Panel/SettingsPanel/VBox/AudioSection/AudioVBox/Music/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/SettingsPanel/VBox/AudioSection/AudioVBox/SFX/SFXSlider
@onready var _master_value: Label = $Panel/SettingsPanel/VBox/AudioSection/AudioVBox/Master/MasterLabel/Value
@onready var _music_value: Label = $Panel/SettingsPanel/VBox/AudioSection/AudioVBox/Music/MusicLabel/Value
@onready var _sfx_value: Label = $Panel/SettingsPanel/VBox/AudioSection/AudioVBox/SFX/SFXLabel/Value

# Visual settings
@onready var _screen_shake_cb: CheckButton = $Panel/SettingsPanel/VBox/VisualSection/VisualVBox/ScreenShake
@onready var _afterimages_cb: CheckButton = $Panel/SettingsPanel/VBox/VisualSection/VisualVBox/Afterimages
@onready var _particles_cb: CheckButton = $Panel/SettingsPanel/VBox/VisualSection/VisualVBox/Particles
@onready var _bg_motion_cb: CheckButton = $Panel/SettingsPanel/VBox/VisualSection/VisualVBox/BgMotion
@onready var _show_fps_cb: CheckButton = $Panel/SettingsPanel/VBox/VisualSection/VisualVBox/ShowFps

# Gameplay settings
@onready var _show_controls_cb: CheckButton = $Panel/SettingsPanel/VBox/GameplaySection/GameplayVBox/ShowControls
@onready var _death_flash_cb: CheckButton = $Panel/SettingsPanel/VBox/GameplaySection/GameplayVBox/DeathFlash
@onready var _boss_warnings_cb: CheckButton = $Panel/SettingsPanel/VBox/GameplaySection/GameplayVBox/BossWarnings
@onready var _attempt_counter_cb: CheckButton = $Panel/SettingsPanel/VBox/GameplaySection/GameplayVBox/AttemptCounter
@onready var _run_timer_cb: CheckButton = $Panel/SettingsPanel/VBox/GameplaySection/GameplayVBox/RunTimer

# Progress sub-panel
@onready var _progress_panel: Control = $Panel/ProgressPanel
@onready var _progress_current: Label = $Panel/ProgressPanel/CurrentLevel
@onready var _progress_highest: Label = $Panel/ProgressPanel/HighestUnlocked
@onready var _progress_checkpoint: Label = $Panel/ProgressPanel/Checkpoint
@onready var _progress_completed: Label = $Panel/ProgressPanel/Completed
@onready var _progress_back: Button = $Panel/ProgressPanel/ProgressBack

# Reset confirmation
@onready var _reset_confirm: Control = $Panel/ResetConfirm
@onready var _reset_yes: Button = $Panel/ResetConfirm/HBox/Yes
@onready var _reset_no: Button = $Panel/ResetConfirm/HBox/No

var _gm = null
var _settings: Node = null  # GameSettings autoload
var _menu_buttons: Array[Button] = []

# Level-select sub-panel — built entirely in code in _build_level_select_ui()
# rather than hand-authored in pause_menu.tscn, since a 25-button grid is
# far simpler to generate than to lay out node-by-node in the scene file,
# and it mirrors the pattern hud.gd already uses for its controls panel.
var _levels_btn: Button
var _level_select_panel: VBoxContainer
var _level_buttons: Array[Button] = []


func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	_settings = get_node_or_null("/root/GameSettings")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Main menu buttons
	_resume_btn.pressed.connect(_on_resume)
	_restart_btn.pressed.connect(_on_restart)
	_settings_btn.pressed.connect(_on_settings)
	_progress_btn.pressed.connect(_on_progress)
	_reset_btn.pressed.connect(_on_reset)
	_quit_btn.pressed.connect(_on_quit)

	# Settings back
	_settings_back.pressed.connect(_on_settings_back)

	# Audio sliders
	_master_slider.value_changed.connect(_on_master_volume)
	_music_slider.value_changed.connect(_on_music_volume)
	_sfx_slider.value_changed.connect(_on_sfx_volume)

	# Visual toggles
	_screen_shake_cb.toggled.connect(func(v): _set_setting("screen_shake", v))
	_afterimages_cb.toggled.connect(func(v): _set_setting("afterimages", v))
	_particles_cb.toggled.connect(func(v): _set_setting("floating_particles", v))
	_bg_motion_cb.toggled.connect(func(v): _set_setting("bg_motion", v))
	_show_fps_cb.toggled.connect(func(v): _set_setting("show_fps", v))

	# Gameplay toggles
	_show_controls_cb.toggled.connect(func(v): _set_setting("show_controls", v))
	_death_flash_cb.toggled.connect(func(v): _set_setting("death_flash", v))
	_boss_warnings_cb.toggled.connect(func(v): _set_setting("boss_warnings", v))
	_attempt_counter_cb.toggled.connect(func(v): _set_setting("attempt_counter", v))
	_run_timer_cb.toggled.connect(func(v): _set_setting("run_timer", v))

	# Progress panel
	_progress_back.pressed.connect(_on_progress_back)

	# Reset confirm
	_reset_yes.pressed.connect(_on_reset_yes)
	_reset_no.pressed.connect(_on_reset_no)

	_build_level_select_ui()

	_menu_buttons = [_resume_btn, _restart_btn, _settings_btn,
		_progress_btn, _levels_btn, _reset_btn, _quit_btn]

	_show_main_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_panel.visible:
			_on_settings_back()
		elif _progress_panel.visible:
			_on_progress_back()
		elif _level_select_panel.visible:
			_on_level_select_back()
		elif _reset_confirm.visible:
			_on_reset_no()
		else:
			if _gm != null:
				_gm.toggle_pause()
		get_viewport().set_input_as_handled()


func _show_main_menu() -> void:
	_settings_panel.visible = false
	_progress_panel.visible = false
	_level_select_panel.visible = false
	_reset_confirm.visible = false
	for btn in _menu_buttons:
		btn.visible = true
	_title_label.text = "P A U S E D"


func _on_resume() -> void:
	if _gm != null:
		_gm.resume_game()


func _on_restart() -> void:
	if _gm != null:
		_gm.resume_game()
	var level = _find_level()
	if level != null and level.has_method("restart_level"):
		level.restart_level()
	elif _gm != null:
		_gm.restart_from_checkpoint()


func _on_settings() -> void:
	_hide_menu_buttons()
	_settings_panel.visible = true
	_title_label.text = "S E T T I N G S"
	_refresh_all_settings()


func _on_settings_back() -> void:
	_settings_panel.visible = false
	_show_main_menu()


func _on_progress() -> void:
	_hide_menu_buttons()
	_progress_panel.visible = true
	_title_label.text = "P R O G R E S S"
	_refresh_progress()


func _on_progress_back() -> void:
	_progress_panel.visible = false
	_show_main_menu()


func _on_levels() -> void:
	_hide_menu_buttons()
	_level_select_panel.visible = true
	_title_label.text = "L E V E L S"
	_refresh_level_select()


func _on_level_select_back() -> void:
	_level_select_panel.visible = false
	_show_main_menu()


func _on_level_selected(level_num: int) -> void:
	if _gm == null:
		return
	_gm.jump_to_level(level_num)
	# jump_to_level() already unpauses and hides the whole pause menu — reset
	# this panel's own visibility state so the NEXT time the menu opens it
	# shows the main buttons, not the level grid left over from this pick.
	_level_select_panel.visible = false
	_show_main_menu()


func _on_reset() -> void:
	_hide_menu_buttons()
	_reset_confirm.visible = true
	_title_label.text = "R E S E T ?"


func _on_reset_yes() -> void:
	_reset_confirm.visible = false
	if _gm != null:
		_gm.reset_progress()
	_show_main_menu()


func _on_reset_no() -> void:
	_reset_confirm.visible = false
	_show_main_menu()


func _on_quit() -> void:
	if _gm != null:
		_gm.quit_to_desktop()


func _hide_menu_buttons() -> void:
	for btn in _menu_buttons:
		btn.visible = false


# ── Audio settings ───────────────────────────────────────────────

func _refresh_all_settings() -> void:
	_refresh_audio_sliders()
	_refresh_visual_toggles()
	_refresh_gameplay_toggles()


func _refresh_audio_sliders() -> void:
	var audio = _find_audio()
	if audio == null:
		return
	var m := db_to_linear(audio.master_db())
	var mu := db_to_linear(audio.music_db())
	var s := db_to_linear(audio.sfx_db())
	_master_slider.value = m
	_music_slider.value = mu
	_sfx_slider.value = s
	_master_value.text = "%d%%" % int(m * 100)
	_music_value.text = "%d%%" % int(mu * 100)
	_sfx_value.text = "%d%%" % int(s * 100)


func _on_master_volume(value: float) -> void:
	_master_value.text = "%d%%" % int(value * 100)
	var audio = _find_audio()
	if audio != null:
		audio.set_master_volume(linear_to_db(value))
	if _settings != null:
		_settings.master_volume = value
		_settings.save_settings()


func _on_music_volume(value: float) -> void:
	_music_value.text = "%d%%" % int(value * 100)
	var audio = _find_audio()
	if audio != null:
		audio.set_music_volume(linear_to_db(value))
	if _settings != null:
		_settings.music_volume = value
		_settings.save_settings()


func _on_sfx_volume(value: float) -> void:
	_sfx_value.text = "%d%%" % int(value * 100)
	var audio = _find_audio()
	if audio != null:
		audio.set_sfx_volume(linear_to_db(value))
	if _settings != null:
		_settings.sfx_volume = value
		_settings.save_settings()


# ── Visual settings ──────────────────────────────────────────────

func _refresh_visual_toggles() -> void:
	if _settings == null:
		return
	_screen_shake_cb.button_pressed = _settings.screen_shake
	_afterimages_cb.button_pressed = _settings.afterimages
	_particles_cb.button_pressed = _settings.floating_particles
	_bg_motion_cb.button_pressed = _settings.bg_motion
	_show_fps_cb.button_pressed = _settings.show_fps


# ── Gameplay settings ────────────────────────────────────────────

func _refresh_gameplay_toggles() -> void:
	if _settings == null:
		return
	_show_controls_cb.button_pressed = _settings.show_controls
	_death_flash_cb.button_pressed = _settings.death_flash
	_boss_warnings_cb.button_pressed = _settings.boss_warnings
	_attempt_counter_cb.button_pressed = _settings.attempt_counter
	_run_timer_cb.button_pressed = _settings.run_timer


# ── Shared helper ────────────────────────────────────────────────

func _set_setting(key: String, value: Variant) -> void:
	if _settings != null:
		_settings.set(key, value)
		_settings.save_settings()


# ── Progress panel ───────────────────────────────────────────────

func _refresh_progress() -> void:
	if _gm == null:
		return
	var completed = _gm.get_completed_levels()
	_progress_current.text = str(_gm.current_level)
	_progress_highest.text = str(_gm.save_system.get_highest_unlocked())
	_progress_checkpoint.text = "Level %d" % _gm.save_system.get_checkpoint()
	_progress_completed.text = "%d / %d" % [completed, LevelData.TOTAL_LEVELS]
	if _gm.save_system.is_game_complete():
		_progress_completed.text = "%d / %d — GAME COMPLETE" % [completed, LevelData.TOTAL_LEVELS]


# ── Level select panel ───────────────────────────────────────────

## Builds the "Levels" menu button and its picker panel (title, 5-column
## grid of 25 level buttons, Back button) entirely at runtime and inserts
## the button right after Progress in the main menu list.
func _build_level_select_ui() -> void:
	var menu_vbox := _progress_btn.get_parent()
	_levels_btn = Button.new()
	_levels_btn.text = "Levels"
	_levels_btn.custom_minimum_size = _progress_btn.custom_minimum_size
	_levels_btn.add_theme_font_size_override("font_size", 18)
	menu_vbox.add_child(_levels_btn)
	menu_vbox.move_child(_levels_btn, _progress_btn.get_index() + 1)
	_levels_btn.pressed.connect(_on_levels)

	_level_select_panel = VBoxContainer.new()
	_level_select_panel.name = "LevelSelectPanel"
	_level_select_panel.visible = false
	_level_select_panel.add_theme_constant_override("separation", 6)
	_panel.add_child(_level_select_panel)

	var title := Label.new()
	title.text = "L E V E L S"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.20, 0.70, 1.0, 1.0))
	_level_select_panel.add_child(title)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 8)
	_level_select_panel.add_child(top_spacer)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_level_select_panel.add_child(grid)

	for i in LevelData.TOTAL_LEVELS:
		var level_num := i + 1
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(52, 40)
		btn.text = str(level_num)
		btn.pressed.connect(_on_level_selected.bind(level_num))
		grid.add_child(btn)
		_level_buttons.append(btn)

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	_level_select_panel.add_child(bottom_spacer)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_level_select_back)
	_level_select_panel.add_child(back_btn)


## Locked levels (never reached) are disabled entirely — jump_to_level()
## would refuse them anyway, but disabling the button is the honest signal
## instead of a click that silently does nothing. Completed levels and the
## current level are both selectable (replaying your current level just
## restarts it from the top, same as the existing Restart button).
func _refresh_level_select() -> void:
	if _gm == null:
		return
	for i in _level_buttons.size():
		var level_num := i + 1
		var btn := _level_buttons[i]
		var completed: bool = _gm.is_level_completed(level_num)
		var is_current: bool = level_num == _gm.current_level
		btn.disabled = not (completed or is_current)
		if is_current:
			btn.modulate = Color(1.0, 0.85, 0.4, 1.0)
		elif completed:
			btn.modulate = Color(0.55, 0.95, 0.65, 1.0)
		else:
			btn.modulate = Color(0.45, 0.45, 0.50, 1.0)


# ── Node lookup helpers ──────────────────────────────────────────

func _find_level():
	var parent = get_parent()
	if parent == null:
		return null
	# Direct sibling — the shape used when pause_menu.tscn is instantiated
	# standalone (e.g. a test), sitting next to the level itself.
	for child in parent.get_children():
		if child.has_signal("level_completed"):
			return child
	# The real in-game shape: game_scene -> LevelContainer -> level. This was
	# the actual bug — pause_menu only ever checked the sibling case above,
	# so in the real game this always returned null, silently breaking the
	# volume sliders (never read/applied to audio) and Restart Level
	# (fell through to a full level reload instead of its intended fast
	# in-place restart, resetting the attempt counter to 1 in the process).
	var level_container = parent.get_node_or_null("LevelContainer")
	if level_container != null:
		for child in level_container.get_children():
			if child.has_signal("level_completed"):
				return child
	return null


func _find_audio():
	var level = _find_level()
	if level != null:
		return level.get_node_or_null("Audio")
	return null

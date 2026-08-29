extends CanvasLayer
## In-game pause menu for Project Ascent.
##
## Shows on ESC. Freezes gameplay. Provides: Resume, Restart Level,
## Settings (volume), Progress, Reset Progress (with confirmation), Quit.

@onready var _panel: Control = $Panel
@onready var _title_label: Label = $Panel/MenuVBox/Title
@onready var _resume_btn: Button = $Panel/MenuVBox/Resume
@onready var _restart_btn: Button = $Panel/MenuVBox/Restart
@onready var _settings_btn: Button = $Panel/MenuVBox/Settings
@onready var _progress_btn: Button = $Panel/MenuVBox/Progress
@onready var _reset_btn: Button = $Panel/MenuVBox/Reset
@onready var _quit_btn: Button = $Panel/MenuVBox/Quit

# Settings sub-panel
@onready var _settings_panel: Control = $Panel/SettingsPanel
@onready var _master_slider: HSlider = $Panel/SettingsPanel/Master/MasterSlider
@onready var _music_slider: HSlider = $Panel/SettingsPanel/Music/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/SettingsPanel/SFX/SFXSlider
@onready var _settings_back: Button = $Panel/SettingsPanel/Back

# Progress sub-panel
@onready var _progress_panel: Control = $Panel/ProgressPanel
@onready var _progress_label: Label = $Panel/ProgressPanel/Info
@onready var _progress_back: Button = $Panel/ProgressPanel/ProgressBack

# Reset confirmation
@onready var _reset_confirm: Control = $Panel/ResetConfirm
@onready var _reset_yes: Button = $Panel/ResetConfirm/HBox/Yes
@onready var _reset_no: Button = $Panel/ResetConfirm/HBox/No

var _gm = null


func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_resume_btn.pressed.connect(_on_resume)
	_restart_btn.pressed.connect(_on_restart)
	_settings_btn.pressed.connect(_on_settings)
	_progress_btn.pressed.connect(_on_progress)
	_reset_btn.pressed.connect(_on_reset)
	_quit_btn.pressed.connect(_on_quit)
	_settings_back.pressed.connect(_on_settings_back)
	_progress_back.pressed.connect(_on_progress_back)
	_reset_yes.pressed.connect(_on_reset_yes)
	_reset_no.pressed.connect(_on_reset_no)

	_master_slider.value_changed.connect(_on_master_volume)
	_music_slider.value_changed.connect(_on_music_volume)
	_sfx_slider.value_changed.connect(_on_sfx_volume)

	for btn in [_resume_btn, _restart_btn, _settings_btn, _progress_btn,
			_reset_btn, _quit_btn, _settings_back, _progress_back,
			_reset_yes, _reset_no]:
		btn.add_theme_font_size_override("font_size", 20)

	_show_main_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_panel.visible:
			_on_settings_back()
		elif _progress_panel.visible:
			_on_progress_back()
		elif _reset_confirm.visible:
			_on_reset_no()
		else:
			if _gm != null:
				_gm.toggle_pause()
		get_viewport().set_input_as_handled()


func _show_main_menu() -> void:
	_settings_panel.visible = false
	_progress_panel.visible = false
	_reset_confirm.visible = false
	_resume_btn.visible = true
	_restart_btn.visible = true
	_settings_btn.visible = true
	_progress_btn.visible = true
	_reset_btn.visible = true
	_quit_btn.visible = true
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
	_resume_btn.visible = false
	_restart_btn.visible = false
	_settings_btn.visible = false
	_progress_btn.visible = false
	_reset_btn.visible = false
	_quit_btn.visible = false
	_settings_panel.visible = true
	_title_label.text = "S E T T I N G S"
	_refresh_sliders()


func _on_settings_back() -> void:
	_settings_panel.visible = false
	_show_main_menu()


func _on_progress() -> void:
	_resume_btn.visible = false
	_restart_btn.visible = false
	_settings_btn.visible = false
	_progress_btn.visible = false
	_reset_btn.visible = false
	_quit_btn.visible = false
	_progress_panel.visible = true
	_title_label.text = "P R O G R E S S"
	_refresh_progress()


func _on_progress_back() -> void:
	_progress_panel.visible = false
	_show_main_menu()


func _on_reset() -> void:
	_resume_btn.visible = false
	_restart_btn.visible = false
	_settings_btn.visible = false
	_progress_btn.visible = false
	_reset_btn.visible = false
	_quit_btn.visible = false
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


func _refresh_sliders() -> void:
	var audio = _find_audio()
	if audio == null:
		return
	_master_slider.value = db_to_linear(audio.master_db())
	_music_slider.value = db_to_linear(audio.music_db())
	_sfx_slider.value = db_to_linear(audio.sfx_db())


func _on_master_volume(value: float) -> void:
	var audio = _find_audio()
	if audio != null:
		audio.set_master_volume(linear_to_db(value))


func _on_music_volume(value: float) -> void:
	var audio = _find_audio()
	if audio != null:
		audio.set_music_volume(linear_to_db(value))


func _on_sfx_volume(value: float) -> void:
	var audio = _find_audio()
	if audio != null:
		audio.set_sfx_volume(linear_to_db(value))


func _refresh_progress() -> void:
	if _gm == null:
		return
	var completed = _gm.get_completed_levels()
	var info = "CURRENT LEVEL\n%d\n\n" % _gm.current_level
	info += "HIGHEST UNLOCKED\n%d\n\n" % _gm.save_system.get_highest_unlocked()
	info += "CHECKPOINT\nLevel %d\n\n" % _gm.save_system.get_checkpoint()
	info += "COMPLETED\n%d / %d" % [completed, LevelData.TOTAL_LEVELS]
	if _gm.save_system.is_game_complete():
		info += "\n\nGAME COMPLETE"
	_progress_label.text = info


func _find_level():
	var parent = get_parent()
	if parent != null:
		for child in parent.get_children():
			if child.has_signal("level_completed"):
				return child
	return null


func _find_audio():
	var level = _find_level()
	if level != null:
		return level.get_node_or_null("Audio")
	return null

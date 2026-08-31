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

# Personalisation controls — also built in code, from the palettes in
# game_settings.gd, so adding a colour there needs no scene edit.
var _player_swatches: Array[Button] = []
var _accent_swatches: Array[Button] = []
var _theme_buttons: Array[Button] = []
var _shake_slider: HSlider
var _parallax_slider: HSlider
var _glow_slider: HSlider
## Re-entrancy guard: _centre_panel() sets size/position, which re-fires the
## `resized` signal it is itself connected to.
var _centring: bool = false

## Authored panel width, held as a floor by _centre_panel() so the panel never
## collapses to its content's minimum width (~292px, narrower than the title).
## Height is deliberately content-driven: a fixed floor left a large dead gap
## above the title and below the last button on the main menu.
const DESIGN_WIDTH: float = 560.0
const DESIGN_MIN_HEIGHT: float = 0.0
## Breathing room added to the visible content's height, so the panel never
## hugs its contents to the pixel.
const PANEL_PADDING_Y: float = 40.0


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

	_apply_theme()
	_apply_icons()
	_build_personalisation_ui()
	_add_subpanel_headroom()

	# Size the panel to its content (floored at the authored proportions,
	# clamped to the screen) and keep it centred as either changes.
	#
	# The scene's own centre anchors were already correct — a wide-window
	# probe measures the panel dead-centre with them. What this adds is
	# resilience to *content* changes: without it the panel keeps whatever
	# size it had when first laid out, so the Personalisation section added
	# this phase pushed the bottom of the list off the screen edge.
	get_viewport().size_changed.connect(_centre_panel)
	# Re-centre whenever the panel's own size changes, not just on a window
	# resize. The panel grows when a sub-panel is shown or when content is
	# added (the Personalisation section built above is the case that exposed
	# this): centring once at startup pins a stale size, and the panel then
	# grows right and down out of that position instead of around its centre.
	_panel.resized.connect(_centre_panel)
	visibility_changed.connect(_centre_panel)
	_centre_panel.call_deferred()

	_show_main_menu()


## Reserve vertical space at the top of each sub-panel for the pinned title.
## Applied as a theme constant on the panel itself rather than a spacer node,
## so it survives the panels being shown and hidden repeatedly.
func _add_subpanel_headroom() -> void:
	# A real spacer node, not offset_top: these panels live inside a
	# PanelContainer, which forces every child to fill its rect and ignores
	# offsets outright — so the offset version left the reset dialog's text
	# sitting on top of the title.
	const HEADROOM := 58.0
	var targets: Array = [
		_settings_panel.get_node_or_null("VBox") if _settings_panel != null else null,
		_progress_panel,
		_level_select_panel,
		_reset_confirm,
	]
	for target in targets:
		if target == null or not (target is Control):
			continue
		var container := target as Control
		if container.get_node_or_null("TitleHeadroom") != null:
			continue
		var spacer := Control.new()
		spacer.name = "TitleHeadroom"
		spacer.custom_minimum_size = Vector2(0, HEADROOM)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(spacer)
		container.move_child(spacer, 0)


## Build the Personalisation section — colour swatches and intensity dials —
## and append it to the settings list. Built in code for the same reason the
## level-select grid is: swatch rows are generated from the palette arrays in
## game_settings.gd, so adding a colour there needs no scene edit at all.
func _build_personalisation_ui() -> void:
	if _settings_panel == null or _settings == null:
		return
	var vbox := _settings_panel.get_node_or_null("VBox")
	if vbox == null:
		return

	var section := PanelContainer.new()
	section.name = "PersonalSection"
	section.theme_type_variation = &"SectionPanel"
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	section.add_child(inner)

	var title := Label.new()
	title.text = "PERSONALISATION"
	title.theme_type_variation = &"SectionTitle"
	inner.add_child(title)

	# Themes sit ABOVE the individual pickers deliberately: a theme is the
	# one-click starting point, and the pickers below it are the overrides for
	# anyone who wants to build their own. Picking a theme writes through to
	# those pickers, so the two never disagree.
	_theme_buttons = _add_theme_row(inner)

	_player_swatches = _add_swatch_row(inner, "Player Colour",
		GameSettingsRef().PLAYER_COLORS, GameSettingsRef().PLAYER_COLOR_NAMES,
		_settings.player_color, _on_player_color)
	_accent_swatches = _add_swatch_row(inner, "UI Accent",
		GameSettingsRef().ACCENT_COLORS, GameSettingsRef().ACCENT_COLOR_NAMES,
		_settings.accent_color, _on_accent_color)

	_shake_slider = _add_intensity_row(inner, "Screen Shake",
		_settings.shake_intensity, _on_shake_intensity)
	_parallax_slider = _add_intensity_row(inner, "Parallax Depth",
		_settings.parallax_intensity, _on_parallax_intensity)
	_glow_slider = _add_intensity_row(inner, "Neon Glow",
		_settings.glow_intensity, _on_glow_intensity)

	# Sit above the Back button rather than after it.
	vbox.add_child(section)
	var back := vbox.get_node_or_null("Back")
	if back != null:
		vbox.move_child(section, back.get_index())


## The GameSettings autoload, typed loosely — its consts are reached through
## the instance because it is an autoload Node, not a class_name script.
func GameSettingsRef():
	return _settings



## A row of named theme presets. Text buttons rather than colour swatches,
## because a theme is more than a colour — the name is the point.
func _add_theme_row(parent: VBoxContainer) -> Array[Button]:
	var label := Label.new()
	label.text = "Theme"
	label.theme_type_variation = &"SettingLabel"
	parent.add_child(label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)

	var made: Array[Button] = []
	var themes: Array = _settings.THEMES
	for i in themes.size():
		var t: Dictionary = themes[i]
		var b := Button.new()
		b.text = str(t["name"])
		b.custom_minimum_size = Vector2(96, 30)
		var idx := i
		b.pressed.connect(func(): _on_theme_picked(idx))
		grid.add_child(b)
		made.append(b)
	_mark_selected_theme(made, _settings.theme)
	return made


## The active theme gets the accent tint; the rest stay neutral.
func _mark_selected_theme(buttons: Array[Button], selected: int) -> void:
	for i in buttons.size():
		if i == selected:
			buttons[i].add_theme_color_override("font_color", UITheme.accent)
		else:
			buttons[i].remove_theme_color_override("font_color")


func _on_theme_picked(index: int) -> void:
	if _settings == null:
		return
	# apply_theme() writes through to player_color/accent_color and saves,
	# which also fires settings_changed so the running level re-tints.
	_settings.apply_theme(index)
	_mark_selected_theme(_theme_buttons, index)
	_mark_selected_swatch(_player_swatches, _settings.player_color)
	_mark_selected_swatch(_accent_swatches, _settings.accent_color)
	_apply_theme()
	_apply_icons()


func _add_swatch_row(parent: VBoxContainer, label_text: String,
		colors: Array, names: Array, selected: int,
		on_pick: Callable) -> Array[Button]:
	var row_label := Label.new()
	row_label.text = label_text
	row_label.theme_type_variation = &"SettingLabel"
	parent.add_child(row_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var made: Array[Button] = []
	for i in colors.size():
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(52, 32)
		sw.tooltip_text = str(names[i])
		sw.focus_mode = Control.FOCUS_ALL
		# Each swatch paints itself in the colour it selects, so the row reads
		# as the palette rather than as five identical buttons with labels.
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sb.set_corner_radius_all(4)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.18)
		sw.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.border_color = Color.WHITE
		sw.add_theme_stylebox_override("hover", sb_hover)
		sw.add_theme_stylebox_override("focus", sb_hover.duplicate())
		var idx := i
		sw.pressed.connect(func(): on_pick.call(idx))
		row.add_child(sw)
		made.append(sw)

	_mark_selected_swatch(made, selected)
	return made


## The chosen swatch gets a bright ring; the rest keep the faint one. Drawn
## by swapping the border on the existing stylebox so the swatch colour and
## geometry stay exactly as built above.
func _mark_selected_swatch(swatches: Array[Button], selected: int) -> void:
	for i in swatches.size():
		var sb := swatches[i].get_theme_stylebox("normal") as StyleBoxFlat
		if sb == null:
			continue
		var copy := sb.duplicate() as StyleBoxFlat
		copy.border_color = Color.WHITE if i == selected else Color(1, 1, 1, 0.18)
		copy.set_border_width_all(3 if i == selected else 2)
		swatches[i].add_theme_stylebox_override("normal", copy)


func _add_intensity_row(parent: VBoxContainer, label_text: String,
		value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.theme_type_variation = &"SettingLabel"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := Label.new()
	val.theme_type_variation = &"SettingValue"
	val.text = "%d%%" % roundi(value * 100.0)
	row.add_child(val)
	parent.add_child(row)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(func(v: float):
		val.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v))
	parent.add_child(slider)
	return slider


func _on_player_color(idx: int) -> void:
	if _settings == null:
		return
	_settings.player_color = idx
	_settings.save_settings()
	_mark_selected_swatch(_player_swatches, idx)


func _on_accent_color(idx: int) -> void:
	if _settings == null:
		return
	_settings.accent_color = idx
	_settings.save_settings()
	_mark_selected_swatch(_accent_swatches, idx)
	# Rebuild the theme so the whole menu recolours immediately — a colour
	# picker you have to restart to see is not a colour picker.
	_apply_theme()
	_apply_icons()


func _on_shake_intensity(v: float) -> void:
	if _settings != null:
		_settings.shake_intensity = v
		_settings.save_settings()


func _on_parallax_intensity(v: float) -> void:
	if _settings != null:
		_settings.parallax_intensity = v
		_settings.save_settings()


func _on_glow_intensity(v: float) -> void:
	if _settings != null:
		_settings.glow_intensity = v
		_settings.save_settings()


func _centre_panel() -> void:
	if _panel == null:
		return
	if _centring:
		return  # setting size/position re-fires `resized`; don't recurse
	_centring = true

	var vp := get_viewport().get_visible_rect()
	# Anchor to top-left so position is absolute, not re-derived from an
	# anchor rect that goes stale the moment anything relayouts.
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	# Never let the panel exceed the screen. Its settings list is a
	# ScrollContainer, so clamping the height makes the content scroll rather
	# than running off the bottom edge — which is what it did once the
	# Personalisation section was added.
	var margin := 48.0
	var max_h: float = maxf(vp.size.y - margin * 2.0, 200.0)
	var max_w: float = maxf(vp.size.x - margin * 2.0, 200.0)
	# Height comes from the VISIBLE children only. PanelContainer's own
	# combined minimum size counts hidden children too, so the panel stayed
	# as tall as the longest sub-panel (the settings list) even on the small
	# reset dialog — leaving a large dead area under the buttons in every
	# other state.
	var content_h := 0.0
	for child in _panel.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var control := child as Control
		var h := control.get_combined_minimum_size().y
		# A ScrollContainer reports a tiny minimum by design — it scrolls, so
		# it does not demand room for its contents. Measuring it directly
		# collapsed the settings panel to a single row. Ask its content
		# instead, and let the outer clamp cap it to the screen.
		if control is ScrollContainer and control.get_child_count() > 0:
			var inner := control.get_child(0) as Control
			if inner != null:
				h = maxf(h, inner.get_combined_minimum_size().y)
		content_h = maxf(content_h, h)
	content_h += PANEL_PADDING_Y

	var min_size := _panel.get_combined_minimum_size()
	# Width holds the authored proportions as a floor. Sizing purely to
	# content collapses the panel to ~292px, narrower than the title itself.
	var sz := Vector2(
		clampf(maxf(min_size.x, DESIGN_WIDTH), 0.0, max_w),
		clampf(maxf(content_h, DESIGN_MIN_HEIGHT), 0.0, max_h))
	_panel.size = sz
	_panel.position = vp.position + (vp.size - sz) * 0.5

	_centring = false


## Assign the shared Theme at the menu root so every descendant Control
## inherits it. Everything this styles used to be 152 per-node
## `theme_override_*` entries in pause_menu.tscn; those are gone, and the
## overrides that remain in the scene are only the handful that are
## genuinely per-node (the title's size, section accent colours).
func _apply_theme() -> void:
	UITheme.refresh_accent(_settings)
	_panel.theme = UITheme.build()


## Icons for every menu action and settings section. Monochrome glyphs
## tinted through `icon_modulate` rather than pre-coloured PNGs, so a
## palette change stays a one-line edit in ui_theme.gd.
func _apply_icons() -> void:
	var icons := {
		_resume_btn: "resume",
		_restart_btn: "restart",
		_settings_btn: "settings",
		_progress_btn: "progress",
		_levels_btn: "levels",
		_reset_btn: "reset",
		_quit_btn: "quit",
	}
	for btn in icons:
		if btn == null:
			continue
		var tex: Texture2D = load("res://assets/ui/icons/%s.png" % icons[btn])
		if tex == null:
			continue
		btn.icon = tex
		btn.expand_icon = false
		# Destructive actions read in the danger colour, so Reset Progress
		# and Quit are visually distinct from the safe actions above them
		# before the label is even read.
		var tint: Color = UITheme.accent
		if btn == _reset_btn or btn == _quit_btn:
			tint = UITheme.DANGER
		btn.add_theme_color_override("icon_normal_color", tint)
		btn.add_theme_color_override("icon_hover_color", Color.WHITE)
		btn.add_theme_color_override("icon_pressed_color", Color.WHITE)


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
	_set_title_at_top(false)
	_centre_panel.call_deferred()
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
	# Every sub-panel is a sibling of MenuVBox inside a PanelContainer, which
	# stacks all its children in the same rect. With MenuVBox still centred,
	# the lone remaining Title sits in the middle of the panel and the
	# sub-panel's own content scrolls straight over it — the settings list
	# was visibly ghosting through the word "SETTINGS". Pinning the title to
	# the top keeps it clear of the content below it.
	_set_title_at_top(true)
	_centre_panel.call_deferred()


## Park the title at the top of the panel (sub-panel open) or centre it with
## the button list (main menu). Also reorders MenuVBox to draw last so the
## title stays above a sub-panel's background rather than under it.
func _set_title_at_top(at_top: bool) -> void:
	var menu_vbox := _panel.get_node_or_null("MenuVBox") as VBoxContainer
	if menu_vbox == null:
		return
	menu_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN if at_top \
		else BoxContainer.ALIGNMENT_CENTER
	if at_top:
		_panel.move_child(menu_vbox, _panel.get_child_count() - 1)
		# Drawing on top must not mean *catching input* on top. Every child of
		# a PanelContainer fills the whole rect, and a container defaults to
		# MOUSE_FILTER_STOP — so once MenuVBox was moved above the sub-panels
		# it swallowed every click meant for the settings underneath, making
		# the whole settings panel unusable. Only the pixels matter here.
		menu_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Opaque backing so a scrolled settings list passes *behind* the title
		# rather than through it. Every child of a PanelContainer fills the
		# same rect, so the title always overlays the scroll area — the
		# headroom spacer only keeps them apart at scroll position zero.
		var backing := StyleBoxFlat.new()
		backing.bg_color = UITheme.GROUND
		backing.bg_color.a = 1.0
		backing.content_margin_top = 10.0
		backing.content_margin_bottom = 10.0
		backing.content_margin_left = 12.0
		backing.content_margin_right = 12.0
		_title_label.add_theme_stylebox_override("normal", backing)
	else:
		# Back on the main menu MenuVBox holds the real buttons again, so it
		# must take input once more.
		menu_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
		_title_label.remove_theme_stylebox_override("normal")


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

	# No title label here: the panel's shared Title (pinned to the top by
	# _set_title_at_top) already reads "L E V E L S" whenever this panel is
	# open, and a second one drew straight over it.

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

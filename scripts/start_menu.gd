# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name StartMenu
extends CanvasLayer
## Title screen shown once at startup.
##
## Deliberately an OVERLAY on the running game rather than a scene in front of
## it: the level, the pause menu and every autoload are already alive
## underneath, so PLAY is just "hide this" and there is no scene transition to
## get wrong.
##
## Layout: a live pixel scene (TitleWorld) fills the screen; the left column
## carries the logo and a framed menu. SETTINGS and ABOUT open as full pages.
##
## Skipped entirely when the game is launched with --skip-menu, which the
## launcher passes: someone who already clicked Play in the launcher should not
## have to click it again.

signal dismissed

## Whole-number scale for the logo so it stays on the pixel grid.
const LOGO_SCALE := 3
const COLUMN_WIDTH := 480.0

var _world: TitleWorld
var _column: Control
var _play_btn: Button
var _version: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 220
	_version = AboutPage.read_version()
	_build()
	add_child(UpdateNotice.new())
	var updater := get_node_or_null("/root/GameUpdater")
	if updater != null:
		updater.start_background()
	get_tree().paused = true
	_play_music("title")


## The title has its own theme; the story film changes it and the menu brings it back.
func _play_music(track: String) -> void:
	var st := get_node_or_null("/root/Soundtrack")
	if st != null:
		st.play(track)


func _build() -> void:
	_world = TitleWorld.new()
	var gm_world := get_node_or_null("/root/GameManager")
	if gm_world != null and gm_world.save_system != null:
		_world.progress_level = clampi(gm_world.save_system.get_highest_unlocked(), 1, Altitude.TOTAL)
	add_child(_world)

	# The left column sits in a margin so it stays vertically centred however
	# tall the window is.
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("margin_left", 72)
	holder.add_theme_constant_override("margin_top", 40)
	holder.add_theme_constant_override("margin_bottom", 40)
	holder.add_theme_constant_override("margin_right", 40)
	add_child(holder)
	var vcentre := VBoxContainer.new()
	vcentre.alignment = BoxContainer.ALIGNMENT_CENTER
	vcentre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vcentre)
	_column = holder

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcentre.add_child(column)

	# The wordmark is generated pixel art (tools/gen_pixel_art.py), scaled by a
	# whole number with nearest filtering so every pixel stays a hard square.
	var logo := TextureRect.new()
	logo.texture = load("res://assets/pixel/logo.png") as Texture2D
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if logo.texture != null:
		logo.custom_minimum_size = Vector2(logo.texture.get_width(), logo.texture.get_height()) * LOGO_SCALE
	column.add_child(logo)

	var sub := Label.new()
	sub.text = ("VERSION %s" % _version) if _version != "" else "A PRECISION PLATFORMER"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	sub.add_theme_color_override("font_color", UITheme.AMBER)
	column.add_child(sub)

	# The framed menu: a bordered console panel, not loose buttons.
	var frame := PanelContainer.new()
	frame.theme = UITheme.build()
	column.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	frame.add_child(margin)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	margin.add_child(menu)

	_play_btn = _menu_button("PLAY", _on_play)
	menu.add_child(_play_btn)
	menu.add_child(_menu_button("TUTORIAL", _on_tutorial))
	menu.add_child(_menu_button("ENDLESS", _on_endless))
	menu.add_child(_menu_button("STORY", _on_story))
	# SETTINGS, ABOUT, SUPPORT and MORE FROM P4INZ are pixel badges in the top-right corner (the long
	# "CONTRIBUTE TO DEVELOPMENT" row in the play list read as clutter).
	_build_badges()
	# get_tree().quit() does nothing in a browser tab, so the web build has no QUIT.
	if Platform.supports("quit"):
		var q := _menu_button("QUIT", _on_quit)
		q.add_theme_color_override("font_color", UITheme.DANGER)
		menu.add_child(q)

	var hint := Label.new()
	hint.text = "ARROWS / WASD + ENTER        MOUSE ALSO WORKS"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", UITheme.sz(12))
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	column.add_child(hint)

	_play_btn.call_deferred("grab_focus")
	PageFx.enter.call_deferred(frame, menu)


var _badges: Control = null
const STUDIO_URL := "https://github.com/p4inz-code"


## Square pixel badges, icon over a short label, top-right.
func _build_badges() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Badges"
	bar.theme = UITheme.build()
	bar.add_theme_constant_override("separation", 14)
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_right = -40.0
	bar.offset_top = 40.0
	add_child(bar)
	_badges = bar
	var specs := [
		["Settings", "SETTINGS", PixelIcons.texture(PixelIcons.GEAR, 4), _on_settings],
		["About", "ABOUT", PixelIcons.texture(PixelIcons.INFO, 4), _on_about],
		["Contribute", "SUPPORT", PixelHeart.texture(4), _on_support],
		["Studio", "MORE", PixelIcons.texture(PixelIcons.STUDIO, 4, Color(1.0, 0.7, 0.3)), _on_studio],
	]
	for s in specs:
		var b := Button.new()
		b.name = String(s[0])
		b.text = String(s[1])
		b.icon = s[2]
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.custom_minimum_size = Vector2(104, 104)
		b.add_theme_font_size_override("font_size", UITheme.sz(13))
		b.tooltip_text = {"Settings": "Settings", "About": "About the game", "Contribute": "Contribute to development",
			"Studio": "More from P4INZ"}[String(s[0])]
		b.pressed.connect(s[3])
		bar.add_child(b)
		PageFx.hoverable(b)


func _on_studio() -> void:
	_open_page(StudioPage.new())


func _menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", UITheme.sz(22))
	b.pressed.connect(handler)
	return b


func _on_play() -> void:
	# A first-ever run gets the opening story before level 1, then PIP offers the tutorial.
	# Both are skippable, and both are marked seen either way so neither ever blocks a
	# returning player (the TUTORIAL and STORY buttons replay them).
	var gs := get_node_or_null("/root/GameSettings")
	var gm := get_node_or_null("/root/GameManager")
	if gs != null and not gs.intro_seen:
		await _run_cutscene()
		gs.intro_seen = true
		gs.save_settings()
		if not gs.tutorial_done:
			var play_it: bool = await _offer_tutorial()
			if play_it and gm != null:
				get_tree().paused = false
				dismissed.emit()
				queue_free()
				gm.start_tutorial(true)
				return
			gs.tutorial_done = true       # skipping counts as seen
			gs.save_settings()
	get_tree().paused = false
	dismissed.emit()
	queue_free()


## PIP's offer after the story. Returns true to play the tutorial, false to skip it.
func _offer_tutorial() -> bool:
	_set_title_visible(false)
	var offer := TutorialOffer.new()
	offer.name = "TutorialOffer"
	add_child(offer)
	var play_it: bool = await offer.chosen
	offer.queue_free()
	_set_title_visible(true)
	return play_it


## Plays the opening cutscene over the title and waits for it to end (finished
## or skipped). The title is hidden for the duration, then restored.
func _run_cutscene() -> void:
	# Only the menu column hides. The title world stays behind the film: the film ends by fading its own
	# background out, and with the title world hidden that fade revealed the running level 1 for a moment
	# before the menu came back ("after the story it goes to level 1, then back to the main menu").
	if is_instance_valid(_column):
		_column.visible = false
	if is_instance_valid(_badges):
		_badges.visible = false
	_play_music("story")
	var scene := Cutscene.new()
	add_child(scene)
	await scene.finished
	_play_music("title")
	_set_title_visible(true)


func _set_title_visible(on: bool) -> void:
	if is_instance_valid(_world):
		_world.visible = on
	if is_instance_valid(_column):
		_column.visible = on
	if is_instance_valid(_badges):
		_badges.visible = on


## Replay from the menu; never changes the seen flag.
func _on_story() -> void:
	await _run_cutscene()
	if is_instance_valid(_play_btn):
		_play_btn.grab_focus()


## The tutorial: level 0, taught by PIP. Never counts as progress.
func _on_tutorial() -> void:
	var gm := get_node_or_null("/root/GameManager")
	get_tree().paused = false
	dismissed.emit()
	queue_free()
	if gm != null:
		gm.start_tutorial()


## ENDLESS: random campaign levels in a streak; never saved to the campaign.
func _on_endless() -> void:
	var gm := get_node_or_null("/root/GameManager")
	get_tree().paused = false
	dismissed.emit()
	queue_free()
	if gm != null:
		gm.start_endless()


func _on_settings() -> void:
	_open_page(SettingsPage.new())


func _on_about() -> void:
	_open_page(AboutPage.new())


func _on_support() -> void:
	_open_page(SupportPage.new())


func _on_quit() -> void:
	Telemetry.record("quit", {"level": 0})
	Telemetry.save()
	get_tree().quit()


## Full pages sit on top of the title; the title is hidden while one is open and
## focus returns to PLAY when it closes.
func _open_page(page: Node) -> void:
	add_child(page)
	_set_title_visible(false)
	page.closed.connect(func():
		_set_title_visible(true)
		if is_instance_valid(_play_btn):
			_play_btn.grab_focus())

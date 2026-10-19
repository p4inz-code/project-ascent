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
	get_tree().paused = true


func _build() -> void:
	_world = TitleWorld.new()
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
	menu.add_child(_menu_button("STORY", _on_story))
	menu.add_child(_menu_button("SETTINGS", _on_settings))
	menu.add_child(_menu_button("ABOUT", _on_about))
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


func _menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", UITheme.sz(22))
	b.pressed.connect(handler)
	return b


func _on_play() -> void:
	# A first-ever run gets the opening story before level 1. It is skippable,
	# and marked seen either way so it never blocks a returning player.
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null and not gs.intro_seen:
		await _run_cutscene()
		gs.intro_seen = true
		gs.save_settings()
	get_tree().paused = false
	dismissed.emit()
	queue_free()


## Plays the opening cutscene over the title and waits for it to end (finished
## or skipped). The title is hidden for the duration, then restored.
func _run_cutscene() -> void:
	_set_title_visible(false)
	var scene := Cutscene.new()
	add_child(scene)
	await scene.finished
	_set_title_visible(true)


func _set_title_visible(on: bool) -> void:
	if is_instance_valid(_world):
		_world.visible = on
	if is_instance_valid(_column):
		_column.visible = on


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


func _on_settings() -> void:
	_open_page(SettingsPage.new())


func _on_about() -> void:
	_open_page(AboutPage.new())


func _on_quit() -> void:
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

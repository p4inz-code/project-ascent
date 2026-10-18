class_name StartMenu
extends CanvasLayer
## Title screen shown once at startup.
##
## Deliberately an OVERLAY on the running game rather than a scene in front of
## it. That choice does the work: the level, the pause menu, the settings
## panel and every autoload are already alive underneath, so SETTINGS opens the
## real settings panel instead of a second copy that could drift from it, and
## PLAY is just "hide this" — there is no scene transition to get wrong.
##
## Skipped entirely when the game is launched with --skip-menu, which the
## launcher passes: someone who already clicked Play in the launcher should not
## have to click it again.

signal dismissed

## Whole-number scale for the logo so it stays on the pixel grid.
const LOGO_SCALE := 5

const UPDATE_URL := "https://api.github.com/repos/p4inz-code/project-ascent/releases/latest"

var _root: Control
var _about_panel: Control = null
var _status: Label = null
var _http: HTTPRequest = null
var _version: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 220
	_version = _read_version()
	_build()
	get_tree().paused = true


func _read_version() -> String:
	# res://version.txt is written by build_release.ps1 right before export and
	# gets bundled into the PCK, so this same read works identically on
	# desktop and web — unlike OS.get_executable_path(), which resolves to
	# nothing in a browser. The loose copy next to the desktop exe (which the
	# launcher's updater reads) is written from the same $version value, so
	# the two can never disagree.
	var path := "res://version.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			return f.get_as_text().strip_edges()
	return ""


func _build() -> void:
	var dim := ColorRect.new()
	# Light enough that the pixel world reads behind the title; the menu
	# column itself carries the contrast.
	dim.color = Color(0.02, 0.03, 0.08, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# A CenterContainer, not an anchor preset: it keeps the menu centred however
	# wide the logo makes the column and however the window is shaped.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_root = VBoxContainer.new()
	_root.custom_minimum_size = Vector2(360, 0)
	_root.add_theme_constant_override("separation", 14)
	_root.theme = UITheme.build()
	center.add_child(_root)

	# The wordmark is generated pixel art (tools/gen_pixel_art.py), scaled by a
	# whole number with nearest filtering so every pixel stays a hard square.
	var title := TextureRect.new()
	title.texture = load("res://assets/pixel/logo.png") as Texture2D
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if title.texture != null:
		title.custom_minimum_size = Vector2(title.texture.get_width(), title.texture.get_height()) * LOGO_SCALE
	_root.add_child(title)

	var sub := Label.new()
	sub.text = ("v%s" % _version) if _version != "" else "a precision platformer"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	_root.add_child(sub)

	_root.add_child(_spacer(18))
	_root.add_child(_menu_button("PLAY", _on_play))
	_root.add_child(_menu_button("STORY", _on_story))
	_root.add_child(_menu_button("SETTINGS", _on_settings))
	_root.add_child(_menu_button("ABOUT", _on_about))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	_root.add_child(_status)

	_root.get_child(3).call_deferred("grab_focus")


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 20)
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


## Plays the opening cutscene over the title menu and waits for it to end
## (finished or skipped). The menu is hidden for the duration, then restored.
func _run_cutscene() -> void:
	_root.visible = false
	var scene := Cutscene.new()
	add_child(scene)
	await scene.finished
	if is_instance_valid(_root):
		_root.visible = true


## Replay from the menu; never changes the seen flag.
func _on_story() -> void:
	await _run_cutscene()
	if is_instance_valid(_root) and _root.get_child_count() > 3:
		(_root.get_child(3) as Control).grab_focus()


## Opens the full SETTINGS page. It is the same page the pause menu opens.
func _on_settings() -> void:
	var page := SettingsPage.new()
	add_child(page)
	_root.visible = false
	page.closed.connect(func():
		if is_instance_valid(_root):
			_root.visible = true
			(_root.get_child(3) as Control).grab_focus())


func _on_about() -> void:
	if _about_panel != null:
		_about_panel.visible = not _about_panel.visible
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for line in [
		"PROJECT ASCENT",
		"by p4inz - P4inz Interactive Labs",
		"v%s" % (_version if _version != "" else "dev build"),
	]:
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		box.add_child(l)
	var check := _menu_button("CHECK FOR UPDATES", _on_check_updates)
	check.custom_minimum_size = Vector2(0, 34)
	check.add_theme_font_size_override("font_size", 14)
	box.add_child(check)
	_about_panel = box
	_root.add_child(box)
	_root.move_child(box, _root.get_child_count() - 2)


## Read-only. The game deliberately never downloads or installs anything: it
## cannot replace its own running executable, and the launcher already does
## verified updates (HTTPS-only, checksum required). Duplicating that here
## would be a second update path to drift out of sync with the first.
func _on_check_updates() -> void:
	# The browser build has no launcher and no separate download to update to
	# — the page always serves the latest export — so the desktop-oriented
	# update flow below (and its "run from the launcher" message) would only
	# confuse a web player.
	if OS.has_feature("web"):
		_status.text = "playing in browser - always up to date"
		return
	if _version == "":
		_status.text = "no version file - run from the launcher"
		return
	_status.text = "checking..."
	if _http == null:
		_http = HTTPRequest.new()
		add_child(_http)
		_http.request_completed.connect(_on_update_response)
	if _http.request(UPDATE_URL) != OK:
		_status.text = "could not check right now"


func _on_update_response(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	# Every failure path lands on the same calm message. A title screen must
	# never block or alarm because a network call did not work.
	if code != 200:
		_status.text = "could not check right now"
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("tag_name"):
		_status.text = "could not check right now"
		return
	var latest := String(parsed["tag_name"]).lstrip("v")
	if latest == _version:
		_status.text = "up to date (v%s)" % _version
	else:
		_status.text = "v%s available - open the launcher to update" % latest

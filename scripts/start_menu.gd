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
	# version.txt sits beside the executable and is written by the build
	# script — the same file the launcher reads, so the two can never disagree.
	var path := OS.get_executable_path().get_base_dir().path_join("version.txt")
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			return f.get_as_text().strip_edges()
	return ""


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.custom_minimum_size = Vector2(360, 0)
	_root.add_theme_constant_override("separation", 14)
	_root.theme = UITheme.build()
	add_child(_root)

	var title := Label.new()
	title.text = "PROJECT ASCENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UITheme.accent)
	_root.add_child(title)

	var sub := Label.new()
	sub.text = ("v%s" % _version) if _version != "" else "a precision platformer"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	_root.add_child(sub)

	_root.add_child(_spacer(18))
	_root.add_child(_menu_button("PLAY", _on_play))
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
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(handler)
	return b


func _on_play() -> void:
	get_tree().paused = false
	dismissed.emit()
	queue_free()


## Opens the REAL settings panel, not a copy of it. The pause menu is already
## in the tree behind this overlay.
func _on_settings() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.pause_menu == null:
		_status.text = "settings unavailable here"
		return
	gm.pause_menu.visible = true
	if gm.pause_menu.has_method("show_settings"):
		gm.pause_menu.show_settings()
	visible = false
	# Come back to the title when the player leaves the pause menu, so
	# SETTINGS is a detour and not a one-way door out of the menu.
	if not gm.pause_menu.visibility_changed.is_connected(_on_pause_closed):
		gm.pause_menu.visibility_changed.connect(_on_pause_closed)


func _on_pause_closed() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.pause_menu != null and not gm.pause_menu.visible:
		visible = true
		get_tree().paused = true


func _on_about() -> void:
	if _about_panel != null:
		_about_panel.visible = not _about_panel.visible
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for line in [
		"PROJECT ASCENT",
		"by Atharva Patil - Northbyte Studios",
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

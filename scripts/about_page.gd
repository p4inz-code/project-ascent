class_name AboutPage
extends CanvasLayer
## Full-screen ABOUT page: what the game is, who made it, and the update check.
##
## The update check is read-only. The game deliberately never downloads or
## installs anything: it cannot replace its own running executable, and the
## launcher already does verified updates (HTTPS-only, checksum required).
## Duplicating that here would be a second update path to drift out of sync.

signal closed

const UPDATE_URL := "https://api.github.com/repos/p4inz-code/project-ascent/releases/latest"

var _version: String = ""
var _status: Label
var _http: HTTPRequest = null
var _check: Button
var _done: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 240
	_version = read_version()
	UITheme.refresh_accent(get_node_or_null("/root/GameSettings"))
	_build()


## res://version.txt is written by build_release.ps1 right before export and is
## bundled into the PCK, so this read works identically on desktop and web.
static func read_version() -> String:
	var path := "res://version.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			return f.get_as_text().strip_edges()
	return ""


func _label(text: String, size: int, colour: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build() -> void:
	add_child(PixelBackdrop.new())
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.theme = UITheme.build()
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	frame.add_child(margin)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(720, 0)
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var title := _label("A B O U T", UITheme.SIZE_TITLE, UITheme.accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/pixel/logo.png") as Texture2D
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if logo.texture != null:
		logo.custom_minimum_size = Vector2(logo.texture.get_width(), logo.texture.get_height()) * 3
	col.add_child(logo)

	var ver := _label(("VERSION %s" % _version) if _version != "" else "DEV BUILD",
		UITheme.SIZE_SMALL, UITheme.AMBER)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)

	_rule(col)
	col.add_child(_label(
		"You fell out of the sky into THE SPIRE: a tower outside time with no ground below it. "
		+ "One gate waits at the top and needs 100 cores to open. Climb, collect, get out. "
		+ "PIP, the AI in your suit, will keep you company.",
		UITheme.SIZE_BODY, UITheme.TEXT, true))
	_rule(col)

	col.add_child(_label("MADE BY", UITheme.SIZE_SMALL, UITheme.TEXT_DIM))
	col.add_child(_label("Atharva Patil  -  P4inz Interactive Labs", UITheme.SIZE_BODY, UITheme.TEXT))
	col.add_child(_label("BUILT WITH", UITheme.SIZE_SMALL, UITheme.TEXT_DIM))
	col.add_child(_label("Godot Engine 4  -  UI font: Cyberpunk Craftpix Pixel", UITheme.SIZE_BODY, UITheme.TEXT))
	col.add_child(_label(
		"Offline. No accounts, no ads, no tracking. The only network call is the optional "
		+ "update check below.", UITheme.SIZE_SMALL, UITheme.TEXT_DIM, true))

	_check = Button.new()
	_check.text = "CHECK FOR UPDATES"
	_check.custom_minimum_size = Vector2(0, 44)
	_check.pressed.connect(_on_check_updates)
	col.add_child(_check)
	_status = _label("", UITheme.SIZE_SMALL, UITheme.AMBER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(0, 22)
	col.add_child(_status)

	_done = Button.new()
	_done.text = "DONE"
	_done.custom_minimum_size = Vector2(0, 48)
	_done.pressed.connect(close)
	col.add_child(_done)
	_done.call_deferred("grab_focus")


func _rule(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = UITheme.LINE
	r.custom_minimum_size = Vector2(0, UITheme.PX)
	parent.add_child(r)


func _on_check_updates() -> void:
	# The browser build has no launcher and no separate download to update to;
	# the page always serves the latest export.
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
	# Every failure lands on the same calm message: a menu must never alarm
	# because a network call did not work.
	if code != 200:
		_status.text = "could not check right now"
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("tag_name"):
		_status.text = "could not check right now"
		return
	_status.text = update_message(String(parsed["tag_name"]), _version)


static func update_message(tag: String, current: String) -> String:
	var latest := tag.lstrip("v")
	if latest == current:
		return "up to date (v%s)" % current
	return "v%s available - open the launcher to update" % latest


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()

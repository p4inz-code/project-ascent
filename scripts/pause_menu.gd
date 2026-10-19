extends CanvasLayer
## Pause menu: the "suit computer".
##
## Docked to the left edge as a tall panel so the (frozen) action stays visible
## on the right, instead of a centred box hiding it. Header shows PIP's status
## and where the player is; the body swaps between the main list, the level
## grid, progress, and the reset confirmation. SETTINGS and CONTROLS open as
## full pages (SettingsPage / ControlsPage).
##
## Built in code from GameSettings/GameManager so there is no scene to drift.

const PANEL_WIDTH := 500.0

var _gm = null
var _settings: Node = null
var _theme: Theme

var _dock: PanelContainer
var _header_level: Label
var _header_pip: Label
var _views: Dictionary = {}          # name -> Control
var _view: String = "main"
var _main_buttons: Array[Button] = []
var _resume_btn: Button
var _level_buttons: Array[Button] = []
var _progress_lines: Dictionary = {}
var _tip: Label
var _tip_index: int = 0
var _page: Node = null               # open Settings/Controls page, if any


func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	_settings = get_node_or_null("/root/GameSettings")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	visible = false
	UITheme.refresh_accent(_settings)
	_theme = UITheme.build()
	_build()
	visibility_changed.connect(_on_visibility)
	_tip.text = TIPS[0]
	_show_view("main")


# ── construction ────────────────────────────────────────────────────

func _build() -> void:
	# Dim, don't hide: the world should still read behind the computer.
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_dock = PanelContainer.new()
	_dock.theme = _theme
	_dock.name = "Dock"
	_dock.anchor_left = 0.0
	_dock.anchor_right = 0.0
	_dock.anchor_top = 0.0
	_dock.anchor_bottom = 1.0
	_dock.offset_left = 36.0
	_dock.offset_right = 36.0 + PANEL_WIDTH
	_dock.offset_top = 36.0
	_dock.offset_bottom = -36.0
	add_child(_dock)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	_dock.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	var title := Label.new()
	title.text = "SUIT COMPUTER"
	title.add_theme_font_size_override("font_size", UITheme.sz(34))
	title.add_theme_color_override("font_color", UITheme.accent)
	col.add_child(title)

	_header_pip = Label.new()
	_header_pip.text = "PIP ONLINE  -  SUIT SEALED"
	_header_pip.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_header_pip.add_theme_color_override("font_color", UITheme.AMBER)
	col.add_child(_header_pip)

	_header_level = Label.new()
	_header_level.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	_header_level.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col.add_child(_header_level)

	var rule := ColorRect.new()
	rule.color = UITheme.LINE
	rule.custom_minimum_size = Vector2(0, UITheme.PX)
	col.add_child(rule)

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_views["main"] = _build_main()
	_views["levels"] = _build_levels()
	_views["progress"] = _build_progress()
	_views["reset"] = _build_reset()
	for v in _views.values():
		(v as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		body.add_child(v)

	col.add_child(_build_tip())

	var hint := Label.new()
	hint.text = "ESC  resume"
	hint.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col.add_child(hint)


## PIP's tip of the pause: a small boxed readout that fills the dock's foot.
const TIPS: Array[String] = [
	"Hold jump longer for a higher hop. Tap it for a short one.",
	"You can still jump a moment after leaving a ledge. Use it.",
	"Slide needs a run-up. If nothing happens, run first.",
	"Press into a wall while falling to slide down it, then jump off.",
	"A dash resets when you land. Save it for the gap.",
	"Checkpoints save your progress. Orbs are cores for the gate.",
	"Too twitchy or too floaty? Settings > Controls > Control feel.",
]


func _build_tip() -> Control:
	var box := PanelContainer.new()
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	box.add_child(m)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	m.add_child(inner)
	var who := Label.new()
	who.text = "PIP SAYS"
	who.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	who.add_theme_color_override("font_color", UITheme.AMBER)
	inner.add_child(who)
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(0, 64)
	inner.add_child(_tip)
	return box


func _button(text: String, handler: Callable, danger: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if danger:
		b.add_theme_color_override("font_color", UITheme.DANGER)
	b.pressed.connect(handler)
	return b


func _build_main() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_resume_btn = _button("RESUME", _on_resume)
	v.add_child(_resume_btn)
	_main_buttons = [_resume_btn]
	var entries := [
		["RESTART LEVEL", _on_restart, false],
		["MAIN MENU", _on_home, false],
		["LEVELS", _on_levels, false],
		["SETTINGS", _on_settings, false],
		["CONTROLS", _on_controls, false],
		["PROGRESS", _on_progress, false],
		["RESET PROGRESS", _on_reset, true],
	]
	for e in entries:
		var b := _button(e[0], e[1], e[2])
		v.add_child(b)
		_main_buttons.append(b)
	# get_tree().quit() does nothing in a browser tab, so the web build has no
	# QUIT; closing the tab is the player's own action there.
	if Platform.supports("quit"):
		var q := _button("QUIT TO DESKTOP", _on_quit, true)
		v.add_child(q)
		_main_buttons.append(q)
	return v


func _build_levels() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = "LEVELS"
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	v.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for i in LevelData.TOTAL_LEVELS:
		var n := i + 1
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 48)
		b.text = str(n)
		b.pressed.connect(_on_level_selected.bind(n))
		grid.add_child(b)
		_level_buttons.append(b)
	v.add_child(_back_button())
	return v


func _build_progress() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = "PROGRESS"
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	v.add_child(l)
	for key in ["Current level", "Furthest unlocked", "Checkpoint", "Completed"]:
		var r := HBoxContainer.new()
		var a := Label.new()
		a.text = key
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(a)
		var b := Label.new()
		b.add_theme_color_override("font_color", UITheme.accent)
		r.add_child(b)
		v.add_child(r)
		_progress_lines[key] = b
	v.add_child(_back_button())
	return v


func _build_reset() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = "RESET ALL PROGRESS?"
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	l.add_theme_color_override("font_color", UITheme.DANGER)
	v.add_child(l)
	var t := Label.new()
	t.text = "Every level goes back to locked and you start again from level 1. This cannot be undone."
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(t)
	var no := _button("NO, KEEP IT", _on_reset_no)
	var yes := _button("YES, RESET", _on_reset_yes, true)
	v.add_child(no)
	v.add_child(yes)
	return v


func _back_button() -> Button:
	var b := _button("BACK", func(): _show_view("main"))
	b.name = "Back"
	return b


# ── views ───────────────────────────────────────────────────────────

func _show_view(name: String) -> void:
	_view = name
	for k in _views:
		(_views[k] as Control).visible = (k == name)
	_refresh_header()
	match name:
		"main":
			if is_inside_tree() and _resume_btn != null:
				_resume_btn.call_deferred("grab_focus")
		"levels":
			_refresh_level_select()
		"progress":
			_refresh_progress()
	_focus_first.call_deferred(name)


func _focus_first(name: String) -> void:
	if name == "main" or not _views.has(name) or not is_inside_tree():
		return
	for b in _views[name].find_children("*", "Button", true, false):
		if not (b as Button).disabled and (b as Button).is_visible_in_tree():
			(b as Button).grab_focus()
			return


func _on_visibility() -> void:
	if visible:
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip.text = TIPS[_tip_index]
		_show_view("main")


func _refresh_header() -> void:
	if _gm == null or _header_level == null:
		return
	var def = LevelData.get_level(_gm.current_level)
	var nm: String = def.name if def != null else ""
	_header_level.text = "LEVEL %d / %d   %s" % [_gm.current_level, LevelData.TOTAL_LEVELS, nm]


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


func _on_home() -> void:
	var scene := get_parent()
	if scene != null and scene.has_method("go_home"):
		scene.go_home()


func _on_levels() -> void:
	_show_view("levels")


func _on_progress() -> void:
	_show_view("progress")


func _on_reset() -> void:
	_show_view("reset")


func _on_reset_yes() -> void:
	if _gm != null:
		_gm.reset_progress()
	_show_view("main")


func _on_reset_no() -> void:
	_show_view("main")


func _on_quit() -> void:
	if _gm != null:
		_gm.quit_to_desktop()


func _on_level_selected(level_num: int) -> void:
	if _gm == null:
		return
	_gm.jump_to_level(level_num)
	_show_view("main")


## Locked levels are disabled outright: jump_to_level() would refuse them, and a
## dead click is worse than a visibly unavailable button.
func _refresh_level_select() -> void:
	if _gm == null:
		return
	for i in _level_buttons.size():
		var n := i + 1
		var b := _level_buttons[i]
		var done: bool = _gm.is_level_completed(n)
		var here: bool = n == _gm.current_level
		b.disabled = not (done or here)
		if here:
			b.modulate = Color(1.0, 0.85, 0.4, 1.0)
		elif done:
			b.modulate = Color(0.55, 0.95, 0.65, 1.0)
		else:
			b.modulate = Color(0.45, 0.45, 0.50, 1.0)


func _refresh_progress() -> void:
	if _gm == null:
		return
	var done: int = _gm.get_completed_levels()
	_progress_lines["Current level"].text = str(_gm.current_level)
	_progress_lines["Furthest unlocked"].text = str(_gm.save_system.get_highest_unlocked())
	_progress_lines["Checkpoint"].text = "Level %d" % _gm.save_system.get_checkpoint()
	var text := "%d / %d" % [done, LevelData.TOTAL_LEVELS]
	if _gm.save_system.is_game_complete():
		text += "  -  GAME COMPLETE"
	_progress_lines["Completed"].text = text


# ── pages ───────────────────────────────────────────────────────────

func _on_settings() -> void:
	_open_page(SettingsPage.new())


func _on_controls() -> void:
	_open_page(ControlsPage.new())


## Settings is also reachable from the title menu through this entry point.
func show_settings() -> void:
	_on_settings()


## Kept for callers/tests that close the page programmatically.
func _on_settings_back() -> void:
	if is_instance_valid(_page):
		_page.close()


func _open_page(page: Node) -> void:
	if is_instance_valid(_page):
		return
	_page = page
	add_child(page)
	page.closed.connect(_on_page_closed)
	_dock.visible = false


func _on_page_closed() -> void:
	_page = null
	_dock.visible = true
	_show_view("main")


# ── input ───────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# On the title screen Escape belongs to the title: without this it would pause
	# (then un-pause) the game running underneath it.
	var scene := get_parent()
	if scene != null and scene.get_node_or_null("StartMenu") != null:
		return
	# An open page handles its own Escape.
	if is_instance_valid(_page):
		return
	get_viewport().set_input_as_handled()
	if _view != "main":
		_show_view("main")
	elif _gm != null:
		_gm.toggle_pause()


# ── lookup helpers ──────────────────────────────────────────────────

func _find_level():
	var parent = get_parent()
	if parent == null:
		return null
	# Direct sibling: the shape used when pause_menu.tscn is instantiated
	# standalone (e.g. a test), sitting next to the level itself.
	for child in parent.get_children():
		if child.has_signal("level_completed"):
			return child
	# The real in-game shape: game_scene -> LevelContainer -> level.
	var level_container = parent.get_node_or_null("LevelContainer")
	if level_container != null:
		for child in level_container.get_children():
			if child.has_signal("level_completed"):
				return child
	return null

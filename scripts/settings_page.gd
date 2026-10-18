class_name SettingsPage
extends CanvasLayer
## Full-screen SETTINGS page (title menu and pause menu both open this one
## implementation, so the two can never drift apart).
##
## Layout, Minecraft-style: a title bar, a row of tabs, one scrolling column of
## wide rows, and a DONE button. Everything is reachable by keyboard and gamepad:
## Q / E (or LB / RB) switch tabs, Escape / B closes, focus walks the rows.
##
## Built entirely in code from GameSettings, so adding a setting is one row.

signal closed

const TABS: Array[String] = ["CONTROLS", "AUDIO", "VIDEO", "GAMEPLAY"]
const COLUMN_WIDTH := 880.0

var _gs: Node = null
var _theme: Theme
var _tab_buttons: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _tab: int = 0
var _scroll: ScrollContainer
var _done: Button
var _notice: Label

# Rebinding state: which action is waiting for a key, and its button.
var _listening_action: String = ""
var _bind_buttons: Dictionary = {}
var _feel_buttons: Array[Button] = []
var _feel_desc: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 240
	_gs = get_node_or_null("/root/GameSettings")
	UITheme.refresh_accent(_gs)
	_theme = UITheme.build()
	_build()
	_select_tab(0)


# ── construction ────────────────────────────────────────────────────

func _build() -> void:
	add_child(PixelBackdrop.new())

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	# A framed panel, so the page reads as a console set into the wall.
	var frame := PanelContainer.new()
	frame.theme = _theme
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	# Keep the column inside short windows: rows scroll, chrome does not.
	get_viewport().size_changed.connect(_fit)

	var title := Label.new()
	title.text = "S E T T I N G S"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", UITheme.accent)
	column.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(200, 44)
		b.toggle_mode = true
		var idx: int = i
		b.pressed.connect(func(): _select_tab(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(COLUMN_WIDTH, 420)
	column.add_child(_scroll)

	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(holder)
	for tab_name in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(page)
		_pages.append(page)

	_build_controls(_pages[0])
	_build_audio(_pages[1])
	_build_video(_pages[2])
	_build_gameplay(_pages[3])

	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_notice.add_theme_color_override("font_color", UITheme.AMBER)
	_notice.custom_minimum_size = Vector2(0, 24)
	column.add_child(_notice)

	_done = Button.new()
	_done.text = "DONE"
	_done.custom_minimum_size = Vector2(COLUMN_WIDTH, 48)
	_done.pressed.connect(close)
	column.add_child(_done)

	var hint := Label.new()
	hint.text = "Q / E  switch tab        ESC  back"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	column.add_child(hint)
	_fit()


## Shrink the scrolling area on short windows so DONE is always on screen.
func _fit() -> void:
	if _scroll == null:
		return
	var h := get_viewport().get_visible_rect().size.y
	_scroll.custom_minimum_size.y = clampf(h - 400.0, 140.0, 520.0)


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	l.add_theme_color_override("font_color", UITheme.AMBER)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	parent.add_child(pad)
	parent.add_child(l)
	var rule := ColorRect.new()
	rule.color = UITheme.LINE
	rule.custom_minimum_size = Vector2(0, UITheme.PX)
	parent.add_child(rule)


## A full-width pixel toggle: label on the left, ON / OFF readout on the right.
## (The stock check-switch icon is a few pixels wide and unreadable at this scale.)
func _toggle_row(parent: Control, text: String, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 40)
	# ON must not flood the row with the pressed-button fill (the ON/OFF text
	# already carries the state): keep a quiet surface and light the border.
	var on_box := (_theme.get_stylebox("normal", "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
	on_box.bg_color = UITheme.SURFACE_HI
	on_box.border_color = UITheme.accent_dim
	b.add_theme_stylebox_override("pressed", on_box)
	var on_hover := on_box.duplicate() as StyleBoxFlat
	on_hover.border_color = UITheme.accent
	b.add_theme_stylebox_override("hover_pressed", on_hover)
	var state := Label.new()
	state.set_anchors_preset(Control.PRESET_FULL_RECT)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.offset_right = -18
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(state)
	var paint := func(on: bool):
		state.text = "ON" if on else "OFF"
		state.add_theme_color_override("font_color", UITheme.GOOD if on else UITheme.TEXT_DIM)
	var start: bool = bool(_gs.get(key)) if _gs != null else false
	b.set_pressed_no_signal(start)
	paint.call(start)
	b.toggled.connect(func(v: bool):
		paint.call(v)
		_put(key, v))
	parent.add_child(b)
	return b


## A labelled slider. `fmt` turns the 0..1 style value into the readout.
func _slider_row(parent: Control, text: String, value: float, lo: float, hi: float,
		step: float, fmt: Callable, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := Label.new()
	val.text = fmt.call(value)
	val.add_theme_color_override("font_color", UITheme.accent)
	row.add_child(val)
	parent.add_child(row)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(func(v: float):
		val.text = fmt.call(v)
		on_change.call(v))
	parent.add_child(s)
	return s


static func _pct(v: float) -> String:
	return "%d PCT" % roundi(v * 100.0)


func _put(key: String, value: Variant) -> void:
	if _gs != null:
		_gs.set(key, value)
		_gs.save_settings()


# ── CONTROLS ────────────────────────────────────────────────────────

func _build_controls(page: VBoxContainer) -> void:
	_section(page, "CONTROL FEEL")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	for i in Feel.NAMES.size():
		var b := Button.new()
		b.text = Feel.NAMES[i]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		var idx: int = i
		b.pressed.connect(func(): _pick_feel(idx))
		row.add_child(b)
		_feel_buttons.append(b)
	_feel_desc = Label.new()
	_feel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feel_desc.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_feel_desc.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	page.add_child(_feel_desc)
	_refresh_feel()

	_section(page, "KEYBOARD")
	var note := Label.new()
	note.text = "Click a key, then press the new one.  ESC cancels.  Taking a key another action uses swaps them."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	note.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	page.add_child(note)
	for action in InputBindings.ACTIONS:
		var r := HBoxContainer.new()
		var l := Label.new()
		l.text = String(InputBindings.LABELS.get(action, action))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var kb := Button.new()
		kb.custom_minimum_size = Vector2(300, 40)
		var a: String = action
		kb.pressed.connect(func(): _begin_listen(a))
		r.add_child(kb)
		page.add_child(r)
		_bind_buttons[action] = kb
	_refresh_bindings()
	var reset := Button.new()
	reset.text = "RESET KEYS TO DEFAULT"
	reset.pressed.connect(_reset_keys)
	page.add_child(reset)

	_section(page, "GAMEPAD")
	var dz: float = _gs.stick_deadzone if _gs != null else 0.2
	_slider_row(page, "Stick dead-zone", dz, _gs.DEADZONE_MIN if _gs != null else 0.05, _gs.DEADZONE_MAX if _gs != null else 0.5,
		0.01, func(v): return _pct(v), _set_deadzone)
	var pad_note := Label.new()
	pad_note.text = "Gamepad buttons are fixed: A jump, X dash, B slide.  Lower dead-zone = twitchier stick."
	pad_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad_note.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	pad_note.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	page.add_child(pad_note)


func _set_deadzone(v: float) -> void:
	if _gs == null:
		return
	_gs.stick_deadzone = v
	_gs.apply_stick_deadzone()
	_gs.save_settings()


func _pick_feel(i: int) -> void:
	if _gs != null:
		_gs.feel_preset = Feel.clamp_preset(i)
		_gs.save_settings()
	_refresh_feel()


func _refresh_feel() -> void:
	var cur: int = Feel.clamp_preset(_gs.feel_preset) if _gs != null else Feel.Preset.SNAPPY
	for i in _feel_buttons.size():
		_feel_buttons[i].set_pressed_no_signal(i == cur)
	if _feel_desc != null:
		_feel_desc.text = String(Feel.DESCRIPTIONS[cur])


func _refresh_bindings() -> void:
	for action in _bind_buttons:
		var b: Button = _bind_buttons[action]
		if action == _listening_action:
			b.text = "PRESS A KEY..."
			continue
		var names: Array[String] = []
		for code in InputBindings.keys_for(action):
			names.append(InputBindings.key_name(code))
		b.text = "  /  ".join(names) if not names.is_empty() else "UNBOUND"


func _begin_listen(action: String) -> void:
	_listening_action = action
	_notice.text = ""
	_refresh_bindings()


func _reset_keys() -> void:
	_listening_action = ""
	if _gs != null:
		_gs.reset_key_bindings()
	else:
		InputBindings.reset_all()
	_refresh_bindings()
	_notice.text = "Keys restored to default."


## Called with the captured key; split out so tests can drive it directly.
func _commit_listen(code: int) -> void:
	var action := _listening_action
	_listening_action = ""
	if action == "":
		return
	if not InputBindings.is_valid_key(code):
		_notice.text = "That key can't be used."
	else:
		var displaced: String = _gs.rebind_key(action, code) if _gs != null \
			else InputBindings.rebind(action, code)
		if displaced != "":
			_notice.text = "%s now uses %s's old key." % [
				String(InputBindings.LABELS.get(displaced, displaced)),
				String(InputBindings.LABELS.get(action, action))]
		else:
			_notice.text = ""
	_refresh_bindings()


# ── AUDIO ───────────────────────────────────────────────────────────

func _build_audio(page: VBoxContainer) -> void:
	_section(page, "VOLUME")
	var items := [
		["Master", "master_volume", "set_master_volume"],
		["Music", "music_volume", "set_music_volume"],
		["Effects", "sfx_volume", "set_sfx_volume"],
	]
	for it in items:
		var key: String = it[1]
		var method: String = it[2]
		_slider_row(page, it[0], float(_gs.get(key)) if _gs != null else 1.0, 0.0, 1.0, 0.05,
			func(v): return _pct(v), func(v: float):
				var audio := _find_audio()
				if audio != null:
					audio.call(method, linear_to_db(v))
				_put(key, v))


func _find_audio() -> Node:
	# The Audio node lives under the running level, not as an autoload.
	var n := get_tree().root.find_child("Audio", true, false)
	return n if n != null and n.has_method("set_master_volume") else null


# ── VIDEO ───────────────────────────────────────────────────────────

func _build_video(page: VBoxContainer) -> void:
	_section(page, "EFFECTS")
	_toggle_row(page, "Screen shake", "screen_shake")
	_toggle_row(page, "Afterimages", "afterimages")
	_toggle_row(page, "Floating particles", "floating_particles")
	_toggle_row(page, "Background motion", "bg_motion")
	_toggle_row(page, "Show FPS", "show_fps")
	_slider_row(page, "Screen shake amount", _gs.shake_intensity if _gs != null else 1.0,
		0.0, 1.0, 0.05, func(v): return _pct(v), func(v): _put("shake_intensity", v))
	_slider_row(page, "Parallax depth", _gs.parallax_intensity if _gs != null else 1.0,
		0.0, 1.0, 0.05, func(v): return _pct(v), func(v): _put("parallax_intensity", v))
	_slider_row(page, "Neon glow", _gs.glow_intensity if _gs != null else 1.0,
		0.0, 1.0, 0.05, func(v): return _pct(v), func(v): _put("glow_intensity", v))

	_section(page, "LOOK")
	var themes := HFlowContainer.new()
	themes.add_theme_constant_override("h_separation", 6)
	themes.add_theme_constant_override("v_separation", 6)
	page.add_child(themes)
	var theme_buttons: Array[Button] = []
	if _gs != null:
		for i in _gs.THEMES.size():
			var b := Button.new()
			b.text = str(_gs.THEMES[i]["name"])
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(130, 40)
			b.set_pressed_no_signal(i == _gs.theme)
			var idx: int = i
			b.pressed.connect(func():
				_gs.apply_theme(idx)
				for j in theme_buttons.size():
					theme_buttons[j].set_pressed_no_signal(j == idx))
			themes.add_child(b)
			theme_buttons.append(b)
		_swatches(page, "Suit colour", _gs.PLAYER_COLORS, _gs.player_color,
			func(i): _put("player_color", i))
		_swatches(page, "Menu accent", _gs.ACCENT_COLORS, _gs.accent_color,
			func(i): _put("accent_color", i))


func _swatches(parent: Control, text: String, colors: Array, selected: int, on_pick: Callable) -> void:
	var l := Label.new()
	l.text = text
	parent.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var made: Array[Button] = []
	for i in colors.size():
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(64, 36)
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sb.set_border_width_all(UITheme.PX)
		sb.border_color = Color.WHITE if i == selected else Color(0, 0, 0, 0.5)
		for state in ["normal", "hover", "pressed", "focus"]:
			sw.add_theme_stylebox_override(state, sb)
		var idx: int = i
		sw.pressed.connect(func():
			on_pick.call(idx)
			for j in made.size():
				var s2 := made[j].get_theme_stylebox("normal") as StyleBoxFlat
				var c := s2.duplicate() as StyleBoxFlat
				c.border_color = Color.WHITE if j == idx else Color(0, 0, 0, 0.5)
				for state in ["normal", "hover", "pressed", "focus"]:
					made[j].add_theme_stylebox_override(state, c))
		row.add_child(sw)
		made.append(sw)


# ── GAMEPLAY ────────────────────────────────────────────────────────

func _build_gameplay(page: VBoxContainer) -> void:
	_section(page, "HUD")
	_toggle_row(page, "Show controls panel", "show_controls")
	_toggle_row(page, "Attempt counter", "attempt_counter")
	_toggle_row(page, "Run timer", "run_timer")
	_section(page, "FEEDBACK")
	_toggle_row(page, "Death flash", "death_flash")
	_toggle_row(page, "Boss warnings", "boss_warnings")


# ── tabs, input, closing ────────────────────────────────────────────

func _select_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_listening_action = ""
	if _notice != null:
		_notice.text = ""
	for j in _pages.size():
		_pages[j].visible = (j == _tab)
		_tab_buttons[j].set_pressed_no_signal(j == _tab)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	# Key capture comes first and swallows everything, including Escape (cancel).
	if _listening_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
				_listening_action = ""
				_refresh_bindings()
				_notice.text = "Cancelled."
			else:
				_commit_listen(int((event as InputEventKey).physical_keycode))
		elif event is InputEventMouseButton and event.pressed:
			# Clicking elsewhere abandons the capture rather than trapping the page.
			_listening_action = ""
			_refresh_bindings()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_Q:
			_select_tab(_tab - 1)
			get_viewport().set_input_as_handled()
			return
		if k == KEY_E:
			_select_tab(_tab + 1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed:
		var b := (event as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_LEFT_SHOULDER:
			_select_tab(_tab - 1)
			get_viewport().set_input_as_handled()
			return
		if b == JOY_BUTTON_RIGHT_SHOULDER:
			_select_tab(_tab + 1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()

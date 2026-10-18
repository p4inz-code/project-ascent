class_name SettingsPage
extends CanvasLayer
## Full-screen SETTINGS page (title menu, pause menu and the F10 shortcut all open
## this one implementation, so they can never drift apart).
##
## Layout, Minecraft-style: a title bar, a search box, a row of tabs, one scrolling
## column of wide rows, and a DONE button. Everything is reachable by keyboard and
## gamepad: Q / E (or LB / RB) switch tabs, Escape / B closes, focus walks the rows.
##
## Tabs: CONTROLS, AUDIO, VIDEO, GAMEPLAY, CHARACTER, ACCESS. Typing in the search
## box shows every row, across all tabs, whose name matches.
##
## Built entirely in code from GameSettings, so adding a setting is one row. Theme,
## accent and font choices rebuild the page at once, so they show the moment you
## click them.

signal closed

const TABS: Array[String] = ["CONTROLS", "AUDIO", "VIDEO", "GAMEPLAY", "CHARACTER", "ACCESS"]
const COLUMN_WIDTH := 960.0
const TEST_SOUNDS := [["JUMP", "jump"], ["LAND", "land"], ["DASH", "dash"], ["DEATH", "death"], ["GOAL", "goal"], ["MENU", "ui"]]

var _gs: Node = null
var _theme: Theme
var _tab_buttons: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _tab: int = 0
var _scroll: ScrollContainer
var _done: Button
var _notice: Label
var _search: LineEdit
var _searchable: Array = []        # [{ctl, text, page}]
var _preview: CharacterPreview = null
var _hint: Label

# Rebinding state: which action is waiting for a key, and its button.
var _listening_action: String = ""
var _bind_buttons: Dictionary = {}
var _feel_buttons: Array[Button] = []
var _feel_desc: Label
var _reset_armed: bool = false


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
	centre.name = "Centre"
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
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	if not get_viewport().size_changed.is_connected(_fit):
		get_viewport().size_changed.connect(_fit)

	var title := Label.new()
	title.text = "S E T T I N G S"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", UITheme.accent)
	column.add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "SEARCH SETTINGS..."
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(0, 38)
	_search.text_changed.connect(_on_search)
	column.add_child(_search)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(tabs)
	_tab_buttons.clear()
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(150, 44)
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
	_pages.clear()
	_searchable.clear()
	for _tab_name in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(page)
		_pages.append(page)

	_build_controls(_pages[0])
	_build_audio(_pages[1])
	_build_video(_pages[2])
	_build_gameplay(_pages[3])
	_build_character(_pages[4])
	_build_access(_pages[5])

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

	_hint = Label.new()
	_hint.text = "Q / E  switch tab        ESC  back        F10  open settings anywhere"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	column.add_child(_hint)
	_fit()


## Rebuild the whole page (after a theme, accent or font change) and put the
## player back on the tab they were on. Deferred: the button that asked for it
## is part of what gets rebuilt.
func _rebuild_deferred() -> void:
	call_deferred("_rebuild")


func _rebuild() -> void:
	var keep_tab := _tab
	var keep_search := _search.text if _search != null else ""
	for child in get_children():
		child.queue_free()
	_tab_buttons.clear()
	_bind_buttons.clear()
	_feel_buttons.clear()
	_preview = null
	UITheme.refresh_accent(_gs)
	_theme = UITheme.build()
	# Freed nodes leave the tree at the end of the frame; build after that.
	await get_tree().process_frame
	_build()
	if keep_search != "":
		_search.text = keep_search
	_select_tab(keep_tab)
	if keep_search != "":
		_on_search(keep_search)


## Shrink the scrolling area on short windows so DONE is always on screen.
func _fit() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	var h := get_viewport().get_visible_rect().size.y
	_scroll.custom_minimum_size.y = clampf(h - 430.0, 140.0, 560.0)


## Show a one-line message under the rows (safe while the page is rebuilding).
func _say(text: String) -> void:
	if _notice != null and is_instance_valid(_notice):
		_notice.text = text


## Register a row so the search box can find it.
func _reg(page: Control, ctl: Control, text: String) -> void:
	_searchable.append({"ctl": ctl, "text": text.to_lower(), "page": page})


func _section(parent: Control, text: String) -> void:
	var holder := VBoxContainer.new()
	holder.set_meta("is_section", true)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
	l.add_theme_color_override("font_color", UITheme.AMBER)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	holder.add_child(pad)
	holder.add_child(l)
	var rule := ColorRect.new()
	rule.color = UITheme.LINE
	rule.custom_minimum_size = Vector2(0, UITheme.PX)
	holder.add_child(rule)
	parent.add_child(holder)


func _note(parent: Control, text: String) -> Label:
	var n := Label.new()
	n.text = text
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	n.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	n.set_meta("is_section", true)   # hidden while searching, like a heading
	parent.add_child(n)
	return n


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
	_reg(parent, b, text)
	return b


## A labelled slider. `fmt` turns the value into the readout.
func _slider_row(parent: Control, text: String, value: float, lo: float, hi: float,
		step: float, fmt: Callable, on_change: Callable) -> HSlider:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := Label.new()
	val.text = fmt.call(value)
	val.add_theme_color_override("font_color", UITheme.accent)
	row.add_child(val)
	wrap.add_child(row)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(func(v: float):
		val.text = fmt.call(v)
		on_change.call(v))
	wrap.add_child(s)
	parent.add_child(wrap)
	_reg(parent, wrap, text)
	return s


## A row of mutually exclusive buttons; calls on_pick(index). Returns the buttons.
func _choice_row(parent: Control, text: String, names: Array, selected: int, on_pick: Callable) -> Array[Button]:
	var wrap := VBoxContainer.new()
	var l := Label.new()
	l.text = text
	wrap.add_child(l)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	wrap.add_child(flow)
	var made: Array[Button] = []
	for i in names.size():
		var b := Button.new()
		b.text = String(names[i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 40)
		b.set_pressed_no_signal(i == selected)
		var idx: int = i
		b.pressed.connect(func():
			for j in made.size():
				made[j].set_pressed_no_signal(j == idx)
			on_pick.call(idx))
		flow.add_child(b)
		made.append(b)
	parent.add_child(wrap)
	_reg(parent, wrap, text + " " + " ".join(names))
	return made


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
	_reg(page, row, "control feel precise snappy instant sensitivity")
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
	_note(page, "Click a key, then press the new one.  ESC cancels.  Taking a key another action uses swaps them.")
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
		_reg(page, r, l.text + " key bind rebind")
	_refresh_bindings()
	var reset := Button.new()
	reset.text = "RESET KEYS TO DEFAULT"
	reset.pressed.connect(_reset_keys)
	page.add_child(reset)
	_reg(page, reset, "reset keys default")

	_section(page, "GAMEPAD")
	var dz: float = _gs.stick_deadzone if _gs != null else 0.2
	_slider_row(page, "Stick dead-zone", dz, _gs.DEADZONE_MIN if _gs != null else 0.05,
		_gs.DEADZONE_MAX if _gs != null else 0.5, 0.01, func(v): return _pct(v), _set_deadzone)
	_note(page, "Gamepad buttons are fixed: A jump, X dash, B slide.  Lower dead-zone = twitchier stick.")


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
	_say("")
	_refresh_bindings()


func _reset_keys() -> void:
	_listening_action = ""
	if _gs != null:
		_gs.reset_key_bindings()
	else:
		InputBindings.reset_all()
	_refresh_bindings()
	_say("Keys restored to default.")


## Called with the captured key; split out so tests can drive it directly.
func _commit_listen(code: int) -> void:
	var action := _listening_action
	_listening_action = ""
	if action == "":
		return
	if not InputBindings.is_valid_key(code):
		_say("That key can't be used.")
	else:
		var displaced: String = _gs.rebind_key(action, code) if _gs != null \
			else InputBindings.rebind(action, code)
		if displaced != "":
			_say("%s now uses %s's old key." % [
				String(InputBindings.LABELS.get(displaced, displaced)),
				String(InputBindings.LABELS.get(action, action))])
		else:
			_say("")
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
	_slider_row(page, "Menu sounds", _gs.ui_volume if _gs != null else 0.6, 0.0, 1.0, 0.05,
		func(v): return _pct(v), func(v): _put("ui_volume", v))

	_section(page, "SOUND FX")
	_slider_row(page, "Room echo (effects)", _gs.audio_room_echo if _gs != null else 0.0, 0.0, 1.0, 0.05,
		func(v): return _pct(v), func(v): _put("audio_room_echo", v))
	_toggle_row(page, "Night mode (evens out loud and quiet)", "audio_night_mode")
	_toggle_row(page, "Muffle sound while paused", "audio_pause_muffle")
	_toggle_row(page, "Mute when the window is in the background", "audio_mute_unfocused")

	_section(page, "SOUND TEST")
	_note(page, "Plays through your current volume and effect settings.")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	page.add_child(flow)
	_reg(page, flow, "sound test play")
	for t in TEST_SOUNDS:
		var b := Button.new()
		b.text = t[0]
		b.custom_minimum_size = Vector2(130, 40)
		var id: String = t[1]
		b.pressed.connect(func(): _test_sound(id))
		flow.add_child(b)


func _find_audio() -> Node:
	# The Audio node lives under the running level, not as an autoload.
	var n := get_tree().root.find_child("Audio", true, false)
	return n if n != null and n.has_method("set_master_volume") else null


func _test_sound(id: String) -> void:
	var audio := _find_audio()
	if audio != null and audio.has_method("preview"):
		audio.preview(id)
	else:
		_say("Sound test is available once a level is loaded.")


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
	if _gs != null:
		var theme_names: Array = []
		for t in _gs.THEMES:
			theme_names.append(str(t["name"]))
		_choice_row(page, "Theme (applies at once)", theme_names, _gs.theme, func(i: int):
			_gs.apply_theme(i)
			_rebuild_deferred())
		_swatches(page, "Menu accent", _gs.ACCENT_COLORS, _gs.accent_color, func(i: int):
			_put("accent_color", i)
			_rebuild_deferred())

	_section(page, "INTERFACE FONT")
	_note(page, "PIXEL is the game's own face. CLEAN is plain and very readable. MONO and SANS use your system's fonts and fall back to CLEAN where there are none (browsers).")
	_choice_row(page, "Font", UITheme.FONT_NAMES, UITheme.font_index, func(i: int):
		_put("font_choice", i)
		_rebuild_deferred())


func _swatches(parent: Control, text: String, colors: Array, selected: int, on_pick: Callable) -> Array[Button]:
	var wrap := VBoxContainer.new()
	var l := Label.new()
	l.text = text
	wrap.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)
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
			for j in made.size():
				var s2 := made[j].get_theme_stylebox("normal") as StyleBoxFlat
				var c := s2.duplicate() as StyleBoxFlat
				c.border_color = Color.WHITE if j == idx else Color(0, 0, 0, 0.5)
				for state in ["normal", "hover", "pressed", "focus"]:
					made[j].add_theme_stylebox_override(state, c)
			on_pick.call(idx))
		row.add_child(sw)
		made.append(sw)
	parent.add_child(wrap)
	_reg(parent, wrap, text + " colour color")
	return made


# ── GAMEPLAY ────────────────────────────────────────────────────────

func _build_gameplay(page: VBoxContainer) -> void:
	_section(page, "HUD")
	_toggle_row(page, "Show controls panel", "show_controls")
	_toggle_row(page, "Attempt counter", "attempt_counter")
	_toggle_row(page, "Run timer", "run_timer")
	_section(page, "FEEDBACK")
	_toggle_row(page, "Death flash", "death_flash")
	_toggle_row(page, "Boss warnings", "boss_warnings")
	_section(page, "WINDOW")
	_toggle_row(page, "Pause when the window loses focus", "pause_on_focus_loss")


# ── CHARACTER ───────────────────────────────────────────────────────

func _build_character(page: VBoxContainer) -> void:
	_section(page, "TREVOR")
	_preview = CharacterPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(_preview)
	_reg(page, _preview, "preview trevor character")
	if _gs == null:
		return
	_choice_row(page, "Gear", _gs.ACCESSORY_NAMES, _gs.accessory, func(i: int):
		_put("accessory", i)
		_preview.refresh())
	_swatches(page, "Suit colour", _gs.PLAYER_COLORS, _gs.player_color, func(i: int):
		_put("player_color", i)
		_preview.refresh())
	_swatches(page, "Trim colour (gear and lights)", _gs.TRIM_COLORS, _gs.trim_color, func(i: int):
		_put("trim_color", i)
		_preview.refresh())
	_swatches(page, "Visor", _gs.VISOR_COLORS, _gs.visor_color, func(i: int):
		_put("visor_color", i)
		_preview.refresh())


# ── ACCESS ──────────────────────────────────────────────────────────

func _build_access(page: VBoxContainer) -> void:
	_section(page, "EASE OF USE")
	var calm := Button.new()
	calm.text = "REDUCE MOTION  (no shake, no flash, slow background)"
	calm.alignment = HORIZONTAL_ALIGNMENT_LEFT
	calm.custom_minimum_size = Vector2(0, 44)
	calm.pressed.connect(_reduce_motion)
	page.add_child(calm)
	_reg(page, calm, "reduce motion calm accessibility shake flash")
	_note(page, "Sets screen shake to zero, turns off the death flash, afterimages and background motion, and halves parallax. Each can still be changed on its own tab.")

	_section(page, "RESET")
	var reset := Button.new()
	reset.text = "RESET ALL SETTINGS"
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.custom_minimum_size = Vector2(0, 44)
	reset.add_theme_color_override("font_color", UITheme.DANGER)
	reset.pressed.connect(func(): _reset_all(reset))
	page.add_child(reset)
	_reg(page, reset, "reset all settings defaults")
	_note(page, "Puts every setting, key and choice back to how the game shipped. Your progress is not touched. Press twice to confirm.")


func _reduce_motion() -> void:
	if _gs == null:
		return
	_gs.shake_intensity = 0.0
	_gs.parallax_intensity = 0.5
	_gs.screen_shake = false
	_gs.death_flash = false
	_gs.afterimages = false
	_gs.bg_motion = false
	_gs.save_settings()
	_say("Motion reduced.")
	_rebuild_deferred()


func _reset_all(button: Button) -> void:
	if not _reset_armed:
		_reset_armed = true
		button.text = "PRESS AGAIN TO CONFIRM RESET"
		return
	_reset_armed = false
	if _gs != null:
		_gs.reset_settings()
	_say("All settings restored.")
	_rebuild_deferred()


# ── search, tabs, input, closing ────────────────────────────────────

## Show every row, across all tabs, whose name contains the query; clear it to
## go back to the tab view.
func _on_search(text: String) -> void:
	var q := text.strip_edges().to_lower()
	if q == "":
		_select_tab(_tab)
		return
	_listening_action = ""
	for j in _pages.size():
		_pages[j].visible = true
		_tab_buttons[j].set_pressed_no_signal(false)
	var hits := 0
	for page in _pages:
		for child in page.get_children():
			var keep := false
			for entry in _searchable:
				if entry["ctl"] == child:
					keep = String(entry["text"]).contains(q)
					break
			child.visible = keep
			if keep:
				hits += 1
	_say("%d match(es)" % hits if hits > 0 else "Nothing matches '%s'." % text)
	_scroll.scroll_vertical = 0


func _select_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_listening_action = ""
	if _notice != null:
		_say("")
	# Leaving a search: every row visible again.
	for page in _pages:
		for child in page.get_children():
			child.visible = true
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
				_say("Cancelled.")
			else:
				_commit_listen(int((event as InputEventKey).physical_keycode))
		elif event is InputEventMouseButton and event.pressed:
			# Clicking elsewhere abandons the capture rather than trapping the page.
			_listening_action = ""
			_refresh_bindings()
		return
	# While typing in the search box, letters belong to it (Q and E included).
	var typing := _search != null and _search.has_focus()
	if event is InputEventKey and event.pressed and not event.echo and not typing:
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
		# Escape first clears a search, then closes.
		if typing and _search.text != "":
			_search.text = ""
			_on_search("")
			return
		close()


func close() -> void:
	closed.emit()
	queue_free()

class_name BriefingScreen
extends CanvasLayer
## PIP's briefing, shown once after the tutorial (and before level 1 even if the tutorial was skipped):
## the two modes and the STRONG / WEAK pick, what boss levels are, and the content notice with the
## Language and Spooky effects toggles. It never explains how to beat anything: no hints, ever.

signal closed

var _gs: Node = null
var _mode_label: Label
var _weak_ask: bool = false
var _weak_btn: Button
var _strong_btn: Button
var _lang_btn: Button
var _spook_btn: Button
var _go_btn: Button
var chosen_mode: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 245
	_gs = get_node_or_null("/root/GameSettings")
	if _gs != null:
		chosen_mode = int(_gs.get_reg("gp_mode"))
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(900, 0)
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)
	box.add_child(_title("PIP BRIEFING"))
	box.add_child(_text("THE TWO MODES.\nSTRONG (default): pure torture. No hints, no mercy. I will roast you, and the more you die the worse it gets. WEAK: no trolling, no taunts, no brag cards. Same levels, same difficulty, still no hints."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_strong_btn = _button("I AM STRONG", _pick_strong)
	_weak_btn = _button("I AM WEAK", _pick_weak)
	row.add_child(_strong_btn)
	row.add_child(_weak_btn)
	_mode_label = _text("")
	box.add_child(_mode_label)
	box.add_child(_text("BOSS LEVELS.\nEvery 5th level is a BOSS. Bosses are not normal levels: different rules, far harder. Every attempt re-rolls."))
	box.add_child(_text("CONTENT NOTICE.\nStrong language aimed at you, crude insults, sudden scares and loud sounds, flashing."))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	box.add_child(row2)
	_lang_btn = _button("", _toggle_language)
	_spook_btn = _button("", _toggle_spooky)
	row2.add_child(_lang_btn)
	row2.add_child(_spook_btn)
	_go_btn = _button("CONTINUE", _finish)
	box.add_child(_go_btn)
	_refresh()
	_strong_btn.call_deferred("grab_focus")


func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UITheme.sz(34))
	return l


func _text(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(880, 0)
	l.add_theme_font_size_override("font_size", UITheme.sz(18))
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(260, 52)
	b.pressed.connect(cb)
	return b


func _pick_strong() -> void:
	chosen_mode = 0
	_weak_ask = false
	_refresh()


func _pick_weak() -> void:
	if not _weak_ask:
		_weak_ask = true
		_refresh()
		return
	chosen_mode = 1
	_weak_ask = false
	_refresh()


func _toggle_language() -> void:
	if _gs == null:
		return
	_gs.set_reg("gp_language", 1 - int(_gs.get_reg("gp_language")))
	_refresh()


func _toggle_spooky() -> void:
	if _gs == null:
		return
	_gs.set_reg("gp_spooky", (int(_gs.get_reg("gp_spooky")) + 1) % 3)
	_refresh()


func _refresh() -> void:
	if _weak_ask:
		_weak_btn.text = "YES, I AM WEAK"
		_mode_label.text = "ARE YOU SURE YOU ARE WEAK?"
	else:
		_weak_btn.text = "I AM WEAK" + ("  [PICKED]" if chosen_mode == 1 else "")
		_mode_label.text = "Picked: %s" % ("STRONG. Good." if chosen_mode == 0 else "WEAK. (A small WEAK tag will follow you around.)")
	_strong_btn.text = "I AM STRONG" + ("  [PICKED]" if chosen_mode == 0 else "")
	if _gs != null:
		_lang_btn.text = "LANGUAGE: " + ["STRONG", "BLEEPED"][int(_gs.get_reg("gp_language"))]
		_spook_btn.text = "SPOOKY EFFECTS: " + ["FULL", "REDUCED", "OFF"][int(_gs.get_reg("gp_spooky"))]


func _finish() -> void:
	if _gs != null:
		_gs.set_reg("gp_mode", chosen_mode, false)
		_gs.set_reg("gp_briefed", true)
	closed.emit()
	queue_free()

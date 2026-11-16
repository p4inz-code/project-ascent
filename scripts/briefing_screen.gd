# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name BriefingScreen
extends CanvasLayer
## PIP's briefing, shown once after the tutorial (and before level 1 even if the tutorial was skipped):
## the two modes and the STRONG / WEAK pick, what boss levels are, and the content notice with the
## Language and Spooky effects toggles. It never explains how to beat anything: no hints, ever.
##
## Presented as PIP talking on the suit terminal: a framed console with PIP's portrait, PIP's own lines typed
## out (a press finishes a line), and every choice answered in PIP's voice. It was white rules text on flat
## black, which read as a settings dialog, not a character.

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
var _typed: Array[Label] = []
var _pip_face: TextureRect = null
var _t: float = 0.0

const AMBER := Color(1.0, 0.78, 0.35)
const RED := Color(1.0, 0.42, 0.36)
const DIM := Color(0.62, 0.70, 0.82)
const TYPE_SPEED := 150.0     # characters per second

const STRONG_LINES := [
	"STRONG. Bold. I have watched four hundred climbers say that. I have their names somewhere.",
	"STRONG it is. When you cry I will be recording.",
	"STRONG. Good. I was getting bored of the ones who quit at level two.",
]
const WEAK_ASK := "ARE YOU SURE? Think about it. I will remember. The suit will remember. Your ancestors will feel it."
const WEAK_LINES := [
	"WEAK. Fine. I will be polite. It will hurt me more than it hurts you. A small WEAK tag will follow you. Forever.",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 245
	_gs = get_node_or_null("/root/GameSettings")
	if _gs != null:
		chosen_mode = int(_gs.get_reg("gp_mode"))
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.theme = UITheme.build()
	add_child(centre)
	var frame := PanelContainer.new()
	centre.add_child(frame)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 28)
	frame.add_child(pad)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	pad.add_child(outer)

	# header: PIP's face and the channel line
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	outer.add_child(head)
	_pip_face = TextureRect.new()
	var strip := load("res://assets/pixel/cs_pip.png") as Texture2D
	if strip != null and strip.get_width() >= strip.get_height() * 2:
		# cs_pip.png is an animation strip of square frames: show the first one
		var face := AtlasTexture.new()
		face.atlas = strip
		face.region = Rect2(0, 0, strip.get_height(), strip.get_height())
		_pip_face.texture = face
	else:
		_pip_face.texture = strip
	_pip_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pip_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pip_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pip_face.custom_minimum_size = Vector2(96, 96)
	head.add_child(_pip_face)
	var head_text := VBoxContainer.new()
	head.add_child(head_text)
	head_text.add_child(_label("PIP  //  SUIT CHANNEL OPEN", UITheme.sz(30), UITheme.accent))
	head_text.add_child(_label("Your suit's assistant. Opinionated. Not optional.", UITheme.sz(15), DIM))

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(980, 0)
	box.add_theme_constant_override("separation", 12)
	outer.add_child(box)

	box.add_child(_section("1 / PICK YOUR SUFFERING"))
	box.add_child(_typed_line("Two modes. STRONG: no hints, no mercy, and I roast you harder every time you die. WEAK: I stay quiet and polite. Same levels. Same difficulty. Same pain. Only your dignity changes."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_strong_btn = _button("I AM STRONG", _pick_strong)
	_weak_btn = _button("I AM WEAK", _pick_weak)
	row.add_child(_strong_btn)
	row.add_child(_weak_btn)
	_mode_label = _label("", UITheme.sz(17), AMBER)
	_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_label.custom_minimum_size = Vector2(960, 0)
	box.add_child(_mode_label)

	box.add_child(_section("2 / BOSSES"))
	box.add_child(_typed_line("Every fifth level is a BOSS. Different rules. Far harder. Every attempt re-rolls, so do not bother memorising. I already tried. On someone else."))

	box.add_child(_section("3 / THE FINE PRINT"))
	box.add_child(_typed_line("Strong language aimed at you. Crude insults. Sudden scares, loud sounds, flashing. If that is a problem, turn it down below. I will judge you silently."))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	box.add_child(row2)
	_lang_btn = _button("", _toggle_language)
	_spook_btn = _button("", _toggle_spooky)
	row2.add_child(_lang_btn)
	row2.add_child(_spook_btn)

	_go_btn = _button("CONTINUE", _finish)
	_go_btn.custom_minimum_size = Vector2(980, 56)
	outer.add_child(_go_btn)
	outer.add_child(_label("PRESS ANY KEY TO FINISH A LINE", UITheme.sz(12), DIM))
	_refresh()
	_strong_btn.call_deferred("grab_focus")


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _section(t: String) -> Label:
	var l := _label(t, UITheme.sz(16), AMBER)
	return l


## A line PIP types out; the whole text is laid out from the start (visible_characters only reveals it).
func _typed_line(t: String) -> Label:
	var l := _label(t, UITheme.sz(18), Color(0.92, 0.95, 1.0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(960, 0)
	l.visible_characters = 0
	_typed.append(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	# PIP's face blinks its light while it talks
	if _pip_face != null:
		_pip_face.modulate = Color(1, 1, 1, 0.75 + 0.25 * absf(sin(_t * 6.0))) if _typing() else Color.WHITE
	# lines type one after another
	for l in _typed:
		if l.visible_characters >= 0 and l.visible_characters < l.text.length():
			l.visible_characters = mini(l.text.length(), l.visible_characters + maxi(1, int(TYPE_SPEED * delta + 0.5)))
			if l.visible_characters >= l.text.length():
				l.visible_characters = -1
			return


func _typing() -> bool:
	for l in _typed:
		if l.visible_characters >= 0:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# any press finishes the typing at once (the buttons still work as normal)
	if event.is_pressed() and not event.is_echo() and _typing():
		for l in _typed:
			l.visible_characters = -1


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(320, 52)
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
		_mode_label.text = WEAK_ASK
		_mode_label.add_theme_color_override("font_color", RED)
	else:
		_weak_btn.text = "I AM WEAK" + ("  [PICKED]" if chosen_mode == 1 else "")
		var lines: Array = STRONG_LINES if chosen_mode == 0 else WEAK_LINES
		_mode_label.text = String(lines[int(Time.get_ticks_msec() / 997) % lines.size()])
		_mode_label.add_theme_color_override("font_color", AMBER if chosen_mode == 0 else DIM)
	_strong_btn.text = "I AM STRONG" + ("  [PICKED]" if chosen_mode == 0 else "")
	if _gs != null:
		_lang_btn.text = "LANGUAGE: " + ["STRONG", "BLEEPED"][int(_gs.get_reg("gp_language"))]
		_spook_btn.text = "SPOOKY: " + ["FULL", "REDUCED", "OFF"][int(_gs.get_reg("gp_spooky"))]


func _finish() -> void:
	if _gs != null:
		_gs.set_reg("gp_mode", chosen_mode, false)
		_gs.set_reg("gp_briefed", true)
	closed.emit()
	queue_free()

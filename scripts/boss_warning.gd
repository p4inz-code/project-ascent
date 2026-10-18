class_name BossWarning
extends CanvasLayer
## The alarm that plays when a boss chase starts: a hazard-striped banner slides in
## from the top with a flickering WARNING, a siren pair of "!" signs, a pulsing red
## edge vignette, and a plain instruction line. About 2.6 seconds, then it leaves.
##
## Screen-space, above the HUD, never blocks input. Hidden entirely when the player
## has turned Boss warnings off (the caller decides; see Boss._show_warning).

signal finished

const PX := 3.0
const SLIDE_IN := 0.25
const HOLD := 2.1
const SLIDE_OUT := 0.3
const BANNER_H := 176.0

var title_text: String = "WARNING"
var subtitle_text: String = "THE WARDEN HAS FOUND YOU"
var hint_text: String = "KEEP MOVING.  DO NOT STOP."

var time: float = 0.0
var skip_animation: bool = false

var _banner: Control
var _stripes: Control
var _title: Label
var _sub: Label
var _hint: Label
var _vignette: TextureRect
var _signs: Array[Label] = []


func total_time() -> float:
	return SLIDE_IN + HOLD + SLIDE_OUT


## 0 off-screen, 1 fully in, for a given moment.
func slide_at(t: float) -> float:
	if t < SLIDE_IN:
		return clampf(t / SLIDE_IN, 0.0, 1.0)
	if t < SLIDE_IN + HOLD:
		return 1.0
	return clampf(1.0 - (t - SLIDE_IN - HOLD) / SLIDE_OUT, 0.0, 1.0)


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if skip_animation:
		time = SLIDE_IN + 0.5
		_apply()


func _build() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.08, 0.08, 0.0))
	grad.set_color(1, Color(1.0, 0.08, 0.08, 0.5))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.15)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)

	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_bottom = BANNER_H
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var plate := ColorRect.new()
	plate.color = Color(0.20, 0.03, 0.05, 0.92)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(plate)
	_stripes = Control.new()
	_stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stripes.draw.connect(_draw_stripes)
	_banner.add_child(_stripes)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 18.0
	col.offset_bottom = -18.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(col)
	_title = _label(col, title_text, 56, Color(1.0, 0.32, 0.28))
	_sub = _label(col, subtitle_text, 24, Color(1.0, 0.85, 0.5))
	_hint = _label(col, hint_text, 16, Color(0.9, 0.8, 0.8))
	for side in [0, 1]:
		var sign := Label.new()
		sign.text = "!"
		sign.add_theme_font_size_override("font_size", 72)
		sign.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		sign.set_anchors_preset(Control.PRESET_CENTER_LEFT if side == 0 else Control.PRESET_CENTER_RIGHT)
		sign.offset_left = 140.0 if side == 0 else -190.0
		sign.offset_right = sign.offset_left + 50.0
		sign.offset_top = -48.0
		sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.add_child(sign)
		_signs.append(sign)
	_apply()


func _label(parent: Control, text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _draw_stripes() -> void:
	# Hazard stripes along the top and bottom edges, scrolling.
	var w := _stripes.size.x
	var h := _stripes.size.y
	var bar := PX * 4.0
	var scroll := fmod(time * 60.0, bar * 4.0)
	var x := -bar * 4.0 + scroll
	var i := 0
	while x < w:
		var c := Color(1.0, 0.8, 0.1) if i % 2 == 0 else Color(0.08, 0.03, 0.04)
		for edge_y in [0.0, h - bar]:
			var pts := PackedVector2Array([
				Vector2(x, edge_y + bar), Vector2(x + bar, edge_y + bar),
				Vector2(x + bar * 2.0, edge_y), Vector2(x + bar, edge_y)])
			_stripes.draw_colored_polygon(pts, c)
		x += bar
		i += 1


func _process(delta: float) -> void:
	if skip_animation:
		return
	time += delta
	_apply()
	if time >= total_time():
		finished.emit()
		queue_free()


func _apply() -> void:
	var s := slide_at(time)
	_banner.offset_top = -BANNER_H * (1.0 - s)
	_banner.offset_bottom = BANNER_H - BANNER_H * (1.0 - s)
	# WARNING flickers; the signs blink opposite each other.
	var flick := 0.75 + 0.25 * sin(time * 24.0)
	_title.modulate.a = flick
	for i in _signs.size():
		_signs[i].modulate.a = 1.0 if int(time * 4.0 + float(i)) % 2 == 0 else 0.25
	# Three pulses of red at the edges.
	var pulse := maxf(0.0, sin(time * TAU * 1.1)) * s
	_vignette.modulate.a = pulse
	_stripes.queue_redraw()

# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name ClearCard
extends Control
## The level-clear payoff, shown when the door opens and before the act's cover closes. A dark band slams in
## across the screen with lit edges; the headline (LEVEL N CLEARED / BOSS DEFEATED / ALL LEVELS COMPLETE) drops
## in, the level name under it, then three stats count up one after another (TIME, ATTEMPTS, CORES x/3) while
## pixel confetti bursts from the band. A blinking prompt says a press moves on (game_scene handles the press).
## It replaced a plain "LEVEL COMPLETE" text floating over the level.

var headline: String = "LEVEL CLEARED"
var subtitle: String = ""
var time_s: float = 0.0
var attempts: int = 1
var cores: int = 0
var cores_max: int = 3
var accent: Color = Color(1.0, 0.83, 0.47)

var _band: ColorRect
var _edge_top: ColorRect
var _edge_bot: ColorRect
var _title: Label
var _sub: Label
var _stats: Array[Label] = []
var _prompt: Label
var _t: float = 0.0
var _bits: Array = []        # confetti: {pos, vel, col, size}
var _calm: bool = false

const BAND_H := 300.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calm = PageFx.calm(self)
	var font: Font = UITheme.make_font(0)
	_band = ColorRect.new()
	_band.color = Color(0.02, 0.03, 0.07, 0.94)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_edge_top = ColorRect.new()
	_edge_bot = ColorRect.new()
	for e in [_edge_top, _edge_bot]:
		e.color = accent
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(e)
	_title = _label(headline, UITheme.sz(64), accent, font)
	_sub = _label(subtitle, UITheme.sz(20), Color(0.75, 0.82, 0.92), font)
	var cores_txt := "%d / %d" % [cores, cores_max] if cores_max > 0 else "-"
	for pair in [["TIME", Hud.format_time(time_s)], ["ATTEMPTS", str(attempts)], ["CORES", cores_txt]]:
		var l := _label("%s\n%s" % [pair[0], "" if not _calm else pair[1]], UITheme.sz(24), Color.WHITE, font)
		l.set_meta("final", String(pair[1]))
		l.set_meta("name", String(pair[0]))
		l.modulate.a = 0.0
		_stats.append(l)
	_prompt = _label("PRESS JUMP TO CONTINUE", UITheme.sz(14), Color(0.62, 0.70, 0.82), font)
	_prompt.modulate.a = 0.0
	_layout()
	resized.connect(_layout)
	_animate()


func _label(t: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	add_child(l)
	return l


func _layout() -> void:
	var w := size.x if size.x > 0.0 else 1920.0
	var h := size.y if size.y > 0.0 else 1080.0
	var y0 := h * 0.5 - BAND_H * 0.5
	_band.position = Vector2(0, y0)
	_band.size = Vector2(w, BAND_H)
	_edge_top.position = Vector2(0, y0 - 6)
	_edge_top.size = Vector2(w, 6)
	_edge_bot.position = Vector2(0, y0 + BAND_H)
	_edge_bot.size = Vector2(w, 6)
	_title.position = Vector2(0, y0 + 26)
	_title.size = Vector2(w, 80)
	_sub.position = Vector2(0, y0 + 104)
	_sub.size = Vector2(w, 30)
	for i in _stats.size():
		_stats[i].position = Vector2(w * 0.5 + float(i - 1) * 300.0 - 130.0, y0 + 150)
		_stats[i].size = Vector2(260, 80)
	_prompt.position = Vector2(0, y0 + BAND_H - 40)
	_prompt.size = Vector2(w, 24)


func _animate() -> void:
	if _calm:
		for s in _stats:
			s.modulate.a = 1.0
		_prompt.modulate.a = 1.0
		return
	# the band slams in from the left in pixel steps, the title drops in, stats follow one by one
	_band.scale = Vector2(0.0, 1.0)
	_edge_top.scale = Vector2(0.0, 1.0)
	_edge_bot.scale = Vector2(0.0, 1.0)
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_band, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_edge_top, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_edge_bot, "scale:x", 1.0, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_callback(_burst)
	t.tween_property(_title, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(_title, "position:y", _title.position.y, 0.18).from(_title.position.y - 30.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_sub, "modulate:a", 1.0, 0.12)
	for s in _stats:
		t.tween_property(s, "modulate:a", 1.0, 0.08)
		t.tween_method(_count.bind(s), 0.0, 1.0, 0.28)
	t.tween_property(_prompt, "modulate:a", 1.0, 0.2)


## Stats count up: numbers roll from zero to their value (times roll too).
func _count(f: float, l: Label) -> void:
	var final := String(l.get_meta("final"))
	var name := String(l.get_meta("name"))
	var shown := final
	if name == "TIME":
		shown = Hud.format_time(time_s * f)
	elif name == "ATTEMPTS":
		shown = str(int(round(float(attempts) * f)))
	elif name == "CORES" and cores_max > 0:
		shown = "%d / %d" % [int(round(float(cores) * f)), cores_max]
	l.text = "%s\n%s" % [name, shown]


func _burst() -> void:
	var w := size.x if size.x > 0.0 else 1920.0
	var h := size.y if size.y > 0.0 else 1080.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cols := [accent, Color(0.55, 0.9, 1.0), Color(1, 1, 1), Color(1.0, 0.5, 0.4)]
	for i in 70:
		var from_top := i % 2 == 0
		_bits.append({"pos": Vector2(rng.randf_range(0.1, 0.9) * w, h * 0.5 + (-BAND_H * 0.5 if from_top else BAND_H * 0.5)),
			"vel": Vector2(rng.randf_range(-160.0, 160.0), rng.randf_range(-420.0, -120.0) * (1.0 if from_top else -0.4)),
			"col": cols[i % cols.size()], "size": float(rng.randi_range(1, 3)) * 3.0})


func _process(delta: float) -> void:
	_t += delta
	if _prompt != null and _prompt.modulate.a > 0.5:
		_prompt.self_modulate.a = 0.55 + 0.45 * (1.0 if fmod(_t, 0.9) < 0.6 else 0.0)
	if _bits.is_empty():
		return
	for b in _bits:
		b["vel"].y += 900.0 * delta
		b["pos"] += b["vel"] * delta
	queue_redraw()


func _draw() -> void:
	for b in _bits:
		var p: Vector2 = b["pos"]
		var s: float = b["size"]
		draw_rect(Rect2(Vector2(floorf(p.x / 3.0) * 3.0, floorf(p.y / 3.0) * 3.0), Vector2(s, s)), b["col"])

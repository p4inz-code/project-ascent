class_name ComingSoon
extends CanvasLayer
## The "next part is coming" card that follows the ending: a short pixel
## sequence where the camera rises past the top of the Spire and finds it does not
## end there, then a title card. About 14 seconds; any key skips to the card, and
## a second press closes it.
##
## Timeline (seconds):
##   0-4    the top of the Spire at night, PIP: "WE MADE IT"
##   4-9    the view rises: the tower goes on, new lights wake above
##   9-14   title card: PART II - COMING SOON

signal closed

const PX := 3.0
const BEATS := [0.0, 4.0, 9.0, 14.0]

var time: float = 0.0
var skip_animation: bool = false   # tests set this to land on the final card

var _canvas: Control
var _line: Label
var _title: Label
var _soon: Label
var _thanks: Label
var _prompt: Label
var _stars: Array[Vector3] = []
var _card_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 236
	var rng := RandomNumberGenerator.new()
	rng.seed = 2025
	for i in 160:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))
	_build()
	if skip_animation:
		time = BEATS[3]
		_apply()


func _build() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_scene)
	add_child(_canvas)

	var theme := UITheme.build()
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var col := VBoxContainer.new()
	col.theme = theme
	col.custom_minimum_size = Vector2(900, 0)
	col.add_theme_constant_override("separation", 18)
	centre.add_child(col)

	_line = _label(col, "", 26, UITheme.AMBER)
	_title = _label(col, "PROJECT ASCENT", 56, UITheme.accent)
	_soon = _label(col, "PART II  -  COMING SOON", 34, UITheme.TEXT)
	_thanks = _label(col, "THANK YOU FOR PLAYING", 20, UITheme.TEXT_DIM)
	_prompt = _label(col, "PRESS ANY KEY", 16, UITheme.TEXT_DIM)
	for l in [_title, _soon, _thanks, _prompt]:
		l.modulate.a = 0.0
	# The caption sits low so the tower reads above it; push it down with a spacer.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 260)
	col.add_child(spacer)
	col.move_child(spacer, 0)


func _label(parent: Control, text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	parent.add_child(l)
	return l


## What the PIP caption says at this moment.
func caption_at(t: float) -> String:
	if t < BEATS[1]:
		return "WE MADE IT TO THE TOP, TREVOR."
	if t < BEATS[2]:
		return "...THE SPIRE DOES NOT END HERE."
	return ""


func in_card() -> bool:
	return time >= BEATS[2] + 1.0


func _process(delta: float) -> void:
	if skip_animation:
		return
	time = minf(time + delta, BEATS[3] + 30.0)
	_apply()


func _apply() -> void:
	_line.text = caption_at(time)
	_line.modulate.a = clampf(minf(time - 0.4, (BEATS[2] - 0.3) - time), 0.0, 1.0) if time < BEATS[2] else 0.0
	var card := clampf((time - BEATS[2] - 0.6) / 1.2, 0.0, 1.0)
	_title.modulate.a = card
	_soon.modulate.a = clampf((time - BEATS[2] - 1.6) / 1.0, 0.0, 1.0)
	_thanks.modulate.a = clampf((time - BEATS[2] - 2.6) / 1.0, 0.0, 1.0)
	_prompt.modulate.a = (0.5 + 0.5 * sin(time * 3.0)) * clampf((time - BEATS[3]) / 1.0, 0.0, 1.0) if time > BEATS[3] else 0.0
	_card_ready = time >= BEATS[3]
	_canvas.queue_redraw()


func _snap(v: float) -> float:
	return floorf(v / PX) * PX


func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	_canvas.draw_rect(Rect2(_snap(x), _snap(y), maxf(PX, _snap(w)), maxf(PX, _snap(h))), c)


func _draw_scene() -> void:
	var size := _canvas.size
	# Sky: darker the higher the camera goes.
	var rise := clampf((time - BEATS[1]) / (BEATS[2] - BEATS[1]), 0.0, 1.0)
	var top := Color(0.02, 0.03, 0.09).lerp(Color(0.01, 0.01, 0.05), rise)
	var low := Color(0.12, 0.14, 0.32).lerp(Color(0.05, 0.05, 0.16), rise)
	var bands := 28
	var bh := maxf(PX, _snap(size.y / bands))
	var y := 0.0
	var i := 0
	while y < size.y:
		var t := clampf(float(i) / float(bands - 1), 0.0, 1.0)
		_canvas.draw_rect(Rect2(0, y, size.x, bh), top.lerp(low, t * t))
		y += bh
		i += 1
	for s in _stars:
		var tw := 0.5 + 0.5 * sin(time * 1.3 + s.z)
		_rect(s.x * size.x, s.y * size.y, PX, PX, Color(0.8, 0.85, 1.0, tw))

	# The Spire: a stepped tower whose top slides DOWN the screen as the camera
	# rises, revealing more and more of it above the old summit.
	var cx := _snap(size.x * 0.5)
	var scroll := rise * size.y * 0.9
	var summit := size.y * 0.25 + scroll
	var body := Color(0.10, 0.12, 0.22)
	var edge := Color(0.24, 0.30, 0.52)
	var tiers := [[300.0, 0.0], [240.0, 0.18], [180.0, 0.38], [120.0, 0.6], [70.0, 0.82]]
	for tier in tiers:
		var w: float = tier[0]
		var ty: float = summit + size.y * float(tier[1]) * 0.8
		_rect(cx - w * 0.5, ty, w, size.y * 2.0, body)
		_rect(cx - w * 0.5, ty, w, PX, edge)
		var wy := ty + PX * 8.0
		var row := 0
		while wy < size.y and row < 12:
			var wx := cx - w * 0.5 + PX * 6.0
			var col := 0
			while wx < cx + w * 0.5 - PX * 8.0:
				if sin(time * 0.9 + float(row * 5 + col * 3) + w) > -0.3:
					var warm := (row + col) % 3 != 0
					_rect(wx, wy, PX * 2.0, PX * 3.0, Color(1.0, 0.83, 0.47) if warm else Color(0.35, 0.85, 1.0))
				wx += PX * 9.0
				col += 1
			wy += PX * 12.0
			row += 1
	# New floors above the old summit: they light up one by one as the camera rises.
	var floors := 9
	for f in floors:
		var fy := summit - float(f + 1) * PX * 14.0
		var lit := clampf(rise * float(floors) - float(f), 0.0, 1.0)
		if lit > 0.0 and fy > -PX * 14.0:
			_rect(cx - 35.0, fy, 70.0, PX * 12.0, body)
			_rect(cx - 35.0, fy, 70.0, PX, edge)
			_rect(cx - 12.0, fy + PX * 3.0, PX * 2.0, PX * 3.0, Color(1.0, 0.83, 0.47, lit))
			_rect(cx + 9.0, fy + PX * 3.0, PX * 2.0, PX * 3.0, Color(0.35, 0.85, 1.0, lit))
	# The gate at the old summit: open, bright, a doorway to more.
	var gate_a := clampf((time - 1.0) / 2.0, 0.0, 1.0)
	_rect(cx - PX * 5.0, summit - PX * 10.0, PX * 10.0, PX * 10.0, Color(1.0, 0.85, 0.45, 0.25 + 0.5 * gate_a))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if not event.is_pressed() or (event is InputEventKey and (event as InputEventKey).echo):
		return
	get_viewport().set_input_as_handled()
	press()


## One press jumps to the card; a press on the card closes it.
func press() -> void:
	if _card_ready:
		close()
	elif time < BEATS[3]:
		time = BEATS[3]
		_apply()


func close() -> void:
	closed.emit()
	queue_free()

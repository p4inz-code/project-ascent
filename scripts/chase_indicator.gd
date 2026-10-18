class_name ChaseIndicator
extends CanvasLayer
## Shows where the pursuers are when they are not on screen: a red arrow on the
## screen edge pointing at each one, with its distance in metres, and an edge glow
## that grows as the nearest one closes in. The player should always know where the
## danger is and how long they have, without it taking over the screen.
##
## Targets are Node2Ds; the world-to-screen mapping comes from the viewport's canvas
## transform, so it follows the camera and any zoom.

const PX := 3.0
const MARGIN := 46.0
const PIXELS_PER_METRE := 60.0
## Closer than this (world px), the edge glow starts; at CLOSE it is at full strength.
const DANGER_RANGE := 700.0
const CLOSE := 180.0
## Arrows closer than this on the screen edge are drawn as one.
const GROUP_DISTANCE := 60.0

var targets: Array[Node2D] = []
var active: bool = false

var _canvas: Control
var _glow: TextureRect
var _arrows: Array = []     # [{pos, angle, dist, name}] computed each frame
var _nearest: float = INF


## Where an off-screen point appears on the screen edge. Returns
## {"on_screen": bool, "pos": Vector2, "angle": float (radians, pointing at it)}.
static func edge_point(screen_pos: Vector2, rect: Rect2, margin: float = MARGIN) -> Dictionary:
	var inner := rect.grow(-margin)
	if rect.has_point(screen_pos):
		return {"on_screen": true, "pos": screen_pos, "angle": 0.0}
	var centre := rect.get_center()
	var dir := (screen_pos - centre)
	var angle := dir.angle()
	if dir.is_zero_approx():
		return {"on_screen": true, "pos": centre, "angle": 0.0}
	# Scale the direction so it just touches the inner rectangle.
	var sx := INF if is_zero_approx(dir.x) else inner.size.x * 0.5 / absf(dir.x)
	var sy := INF if is_zero_approx(dir.y) else inner.size.y * 0.5 / absf(dir.y)
	var k := minf(sx, sy)
	return {"on_screen": false, "pos": centre + dir * k, "angle": angle}


## Edge-glow strength (0..1) for the nearest pursuer at `dist` world px.
static func danger_at(dist: float) -> float:
	return clampf((DANGER_RANGE - dist) / (DANGER_RANGE - CLOSE), 0.0, 1.0)


func _ready() -> void:
	layer = 99
	# Clear in the middle, red only toward the edges, so the action stays readable.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.1, 0.1, 0.0), Color(1.0, 0.1, 0.1, 0.0), Color(1.0, 0.1, 0.1, 0.34)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.2)
	_glow = TextureRect.new()
	_glow.texture = tex
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate.a = 0.0
	add_child(_glow)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_arrows)
	add_child(_canvas)


func nearest_distance() -> float:
	return _nearest


func arrow_count() -> int:
	return _arrows.size()


## Recompute from the player's position. Safe to call with any viewport size
## (tests pass a rect and a canvas transform directly).
func refresh(player_pos: Vector2, rect: Rect2, canvas_xform: Transform2D) -> void:
	_arrows.clear()
	_nearest = INF
	if not active:
		_glow.modulate.a = 0.0
		_canvas.queue_redraw()
		return
	for t in targets:
		if t == null or not is_instance_valid(t):
			continue
		var dist := t.global_position.distance_to(player_pos)
		_nearest = minf(_nearest, dist)
		var info := edge_point(canvas_xform * t.global_position, rect)
		if not bool(info["on_screen"]):
			# Pursuers that arrive together share one arrow: the nearest one's
			# distance and a count, instead of a stack of overlapping labels.
			var merged := false
			for existing in _arrows:
				if (existing["pos"] as Vector2).distance_to(info["pos"]) < GROUP_DISTANCE:
					existing["count"] = int(existing["count"]) + 1
					existing["dist"] = minf(float(existing["dist"]), dist)
					merged = true
					break
			if not merged:
				_arrows.append({"pos": info["pos"], "angle": info["angle"], "dist": dist, "count": 1})
	var d := danger_at(_nearest) if _nearest != INF else 0.0
	_glow.modulate.a = d * (0.7 + 0.3 * sin(Time.get_ticks_msec() / 120.0))
	_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if not active:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var vp := get_viewport()
	refresh(player.global_position, vp.get_visible_rect(), vp.get_canvas_transform())


func _draw_arrows() -> void:
	for a in _arrows:
		var p: Vector2 = a["pos"]
		var angle: float = a["angle"]
		var dist: float = a["dist"]
		var urgent := dist < 500.0
		var col := Color(1.0, 0.3, 0.25) if urgent else Color(1.0, 0.6, 0.3)
		var pulse := 1.0 + (0.2 * sin(Time.get_ticks_msec() / 90.0) if urgent else 0.0)
		var fwd := Vector2.from_angle(angle)
		var side := Vector2(-fwd.y, fwd.x)
		var tip := p + fwd * 20.0 * pulse
		var back := p - fwd * 14.0
		var tri := PackedVector2Array([tip, back + side * 15.0, back - side * 15.0])
		_canvas.draw_colored_polygon(tri, Color(0.05, 0.0, 0.02, 0.85))
		var inner := PackedVector2Array([
			p + fwd * 13.0 * pulse, p - fwd * 8.0 + side * 9.0, p - fwd * 8.0 - side * 9.0])
		_canvas.draw_colored_polygon(inner, col)
		# Distance in metres, beside the arrow, on the side facing into the screen.
		var font := ThemeDB.fallback_font
		var text := "%d M" % int(round(dist / PIXELS_PER_METRE))
		if int(a["count"]) > 1:
			text += "  x%d" % int(a["count"])
		var label_pos := p - fwd * 34.0 - Vector2(18.0, -5.0)
		label_pos.x = clampf(label_pos.x, 6.0, _canvas.size.x - 60.0)
		label_pos.y = clampf(label_pos.y, 20.0, _canvas.size.y - 8.0)
		_canvas.draw_string(font, label_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.8))
		_canvas.draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)

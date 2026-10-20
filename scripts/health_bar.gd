class_name HealthBar
extends Control
## The suit-energy cells: three glowing cells in a pixel visor frame, top-left under the level name.
## A lost cell cracks like glass and stays dark; the last cell turns amber and pulses.

const CELL_W := 46.0
const CELL_H := 22.0
const GAP := 8.0
const PAD := 12.0
const SKEW := 7.0

var hp: int = Health.MAX_HP
var max_hp: int = Health.MAX_HP
var _player: Player = null
var _flash: float = 0.0
## Cell index that broke most recently, for the shatter flash.
var _broke: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(PAD * 2.0 + max_hp * CELL_W + (max_hp - 1) * GAP + SKEW, CELL_H + PAD * 1.6)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		var now: int = _player.health.hp
		if now != hp:
			if now < hp:
				_broke = now
				_flash = 0.6
			hp = now
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var edge := Color(0.25, 0.9, 1.0, 0.85)
	if hp == 1:
		edge = Color(1.0, 0.72, 0.25, 0.9)
	# Visor frame: chamfered corners, dark glass.
	var c := 8.0
	var frame := PackedVector2Array([
		Vector2(c, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h - c),
		Vector2(w - c, h), Vector2(c, h), Vector2(0, h - c), Vector2(0, c)])
	draw_colored_polygon(frame, Color(0.03, 0.06, 0.09, 0.78))
	var loop := PackedVector2Array(frame)
	loop.append(frame[0])
	draw_polyline(loop, edge, 2.0)
	var t := float(Time.get_ticks_msec()) / 1000.0
	for i in max_hp:
		var x0 := PAD + float(i) * (CELL_W + GAP)
		var y0 := (h - CELL_H) * 0.5
		var cell := PackedVector2Array([
			Vector2(x0 + SKEW, y0), Vector2(x0 + CELL_W + SKEW, y0),
			Vector2(x0 + CELL_W, y0 + CELL_H), Vector2(x0, y0 + CELL_H)])
		if i < hp:
			var base := Color(0.20, 0.85, 0.95)
			if hp == 1:
				var pulse := 0.65 + 0.35 * sin(t * 7.0)
				base = Color(1.0, 0.68, 0.18).lerp(Color(1.0, 0.4, 0.15), 1.0 - pulse)
			draw_colored_polygon(cell, base)
			var shine := PackedVector2Array([
				Vector2(x0 + SKEW + 3, y0 + 3), Vector2(x0 + CELL_W + SKEW - 3, y0 + 3),
				Vector2(x0 + CELL_W + SKEW - 6, y0 + 8), Vector2(x0 + SKEW + 1, y0 + 8)])
			draw_colored_polygon(shine, Color(1, 1, 1, 0.35))
		else:
			draw_colored_polygon(cell, Color(0.05, 0.08, 0.11, 0.9))
			var cell_loop := PackedVector2Array(cell)
			cell_loop.append(cell[0])
			draw_polyline(cell_loop, Color(0.25, 0.9, 1.0, 0.25), 1.0)
			# Cracks: a fixed zigzag per cell, so the glass looks the same every time.
			var cx := x0 + CELL_W * 0.5 + SKEW * 0.5
			var cy := y0 + CELL_H * 0.5
			var crack := PackedVector2Array([
				Vector2(cx - 17, cy - 9), Vector2(cx - 7, cy - 1), Vector2(cx - 12, cy + 4),
				Vector2(cx - 2, cy + 3), Vector2(cx + 6, cy + 10)])
			draw_polyline(crack, Color(0.55, 0.95, 1.0, 0.7), 1.5)
			var crack2 := PackedVector2Array([
				Vector2(cx + 14, cy - 10), Vector2(cx + 6, cy - 3), Vector2(cx + 11, cy + 2), Vector2(cx + 3, cy + 6)])
			draw_polyline(crack2, Color(0.55, 0.95, 1.0, 0.5), 1.0)
			if i == _broke and _flash > 0.0:
				draw_colored_polygon(cell, Color(1, 1, 1, clampf(_flash / 0.6, 0.0, 1.0) * 0.9))

class_name TileDecor
extends Node2D
## Pattern overlay for special tiles. Every special surface gets a colour AND a
## pattern, so the rule reads without relying on colour alone:
##
##   ice       pale glint stripes + twinkling sparkles
##   sticky    green-brown ooze with drips hanging off the top edge
##   conveyor  chevrons that scroll the way the belt pushes
##   bounce    spring coils
##   crumble   cracks and dust specks
##   timed     hazard stripes (the platform itself blinks before it changes)
##   one_way   a dashed lip along the top
##
## Pure decoration: it never touches collision or physics. Drawn on the same
## pixel grid as everything else (UITheme.PX units of world space = one art
## pixel), centred on the platform like the platform's own polygon.

const PX := 3.0

const KINDS: Array[String] = ["ice", "sticky", "conveyor", "bounce", "crumble", "timed", "one_way"]

var kind: String = ""
var size: Vector2 = Vector2(128.0, 32.0)
## +1 / -1: the way a conveyor pushes.
var direction: int = 1

var _time: float = 0.0


## Whether a kind has a pattern. Fake platforms deliberately do NOT: they must
## look like plain stone, their flicker is the whole tell.
static func has_pattern(platform_kind: String) -> bool:
	return platform_kind in KINDS


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(kind == "conveyor" or kind == "ice")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _snap(v: float) -> float:
	return floorf(v / PX) * PX


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(_snap(x), _snap(y), maxf(PX, _snap(w)), maxf(PX, _snap(h))), c)


func _draw() -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	match kind:
		"ice":
			_draw_ice(hx, hy)
		"sticky":
			_draw_sticky(hx, hy)
		"conveyor":
			_draw_conveyor(hx, hy)
		"bounce":
			_draw_bounce(hx, hy)
		"crumble":
			_draw_crumble(hx, hy)
		"timed":
			_draw_timed(hx, hy)
		"one_way":
			_draw_one_way(hx, hy)


func _draw_ice(hx: float, hy: float) -> void:
	_r(-hx, -hy, size.x, size.y, Color(0.62, 0.86, 1.0, 0.16))
	# Diagonal glint stripes, stepped one pixel per row.
	var x := -hx + PX * 4
	while x < hx - PX * 6:
		for row in int(minf(size.y / PX, 6.0)):
			_r(x + row * PX, -hy + row * PX, PX * 2, PX, Color(1, 1, 1, 0.34))
		x += PX * 14
	# Frosted top lip.
	_r(-hx, -hy, size.x, PX, Color(0.85, 0.95, 1.0, 0.65))
	# Sparkles that twinkle on a fixed pseudo-random layout.
	var i := 0
	var sx := -hx + PX * 8
	while sx < hx - PX * 4:
		var tw := sin(_time * 2.4 + float(i) * 1.7)
		if tw > 0.55:
			var sy := -hy + PX * (2 + (i * 3) % 4)
			_r(sx, sy, PX, PX, Color(1, 1, 1, 0.9))
			_r(sx - PX, sy, PX, PX, Color(1, 1, 1, 0.45))
			_r(sx + PX, sy, PX, PX, Color(1, 1, 1, 0.45))
		sx += PX * 11
		i += 1


func _draw_sticky(hx: float, hy: float) -> void:
	_r(-hx, -hy, size.x, size.y, Color(0.35, 0.40, 0.12, 0.28))
	_r(-hx, -hy, size.x, PX * 2, Color(0.55, 0.62, 0.20, 0.85))
	# Drips hanging from the top edge, each a different length.
	var x := -hx + PX * 3
	var i := 0
	while x < hx - PX * 3:
		var length := PX * (2 + (i * 5) % 5)
		_r(x, -hy + PX * 2, PX, length, Color(0.55, 0.62, 0.20, 0.85))
		_r(x, -hy + PX * 2 + length, PX, PX, Color(0.72, 0.80, 0.30, 0.95))
		x += PX * 7
		i += 1
	# Bubbles in the goo.
	var bx := -hx + PX * 6
	var j := 0
	while bx < hx - PX * 4:
		_r(bx, -hy + PX * (6 + (j * 2) % 3), PX, PX, Color(0.8, 0.9, 0.4, 0.55))
		bx += PX * 13
		j += 1


func _draw_conveyor(hx: float, hy: float) -> void:
	_r(-hx, -hy, size.x, size.y, Color(1.0, 0.72, 0.2, 0.14))
	var step := PX * 8
	var offset := fposmod(_time * 60.0 * float(direction), step)
	var x := -hx - step + offset
	var mid := -hy + minf(size.y * 0.5, PX * 6)
	while x < hx:
		# A chevron: two stepped arms meeting at the leading point.
		for k in 3:
			var d := float(k) * PX
			var px_ := x + (d if direction > 0 else -d)
			var left := clampf(px_, -hx, hx - PX)
			if px_ >= -hx and px_ < hx - PX:
				_r(left, mid - (3 - k) * PX, PX, PX, Color(1.0, 0.82, 0.3, 0.95))
				_r(left, mid + (2 - k) * PX, PX, PX, Color(1.0, 0.82, 0.3, 0.95))
		x += step
	_r(-hx, -hy, size.x, PX, Color(1.0, 0.82, 0.3, 0.9))


func _draw_bounce(hx: float, hy: float) -> void:
	_r(-hx, -hy, size.x, size.y, Color(0.4, 1.0, 0.7, 0.16))
	# Vertical zig-zag coils along the pad.
	var x := -hx + PX * 3
	while x < hx - PX * 3:
		var up := true
		var y := -hy + PX
		while y < hy - PX:
			_r(x + (PX if up else 0.0), y, PX * 2, PX, Color(0.55, 1.0, 0.8, 0.95))
			up = not up
			y += PX
		x += PX * 8
	_r(-hx, -hy, size.x, PX * 2, Color(0.75, 1.0, 0.9, 0.95))


func _draw_crumble(hx: float, hy: float) -> void:
	var dark := Color(0.05, 0.04, 0.05, 0.75)
	var x := -hx + PX * 5
	var i := 0
	while x < hx - PX * 6:
		# A jagged crack running down from the top face.
		var cx := x
		var y := -hy + PX * 2
		for step in int(minf(size.y / PX - 2.0, 6.0)):
			_r(cx, y, PX, PX, dark)
			cx += PX * (1 if (i + step) % 2 == 0 else -1)
			y += PX
		x += PX * 17
		i += 1
	# Dust specks sitting on the surface.
	var dx := -hx + PX * 9
	while dx < hx - PX * 4:
		_r(dx, -hy - PX, PX, PX, Color(0.8, 0.75, 0.65, 0.6))
		dx += PX * 19


func _draw_timed(hx: float, hy: float) -> void:
	# Hazard stripes: alternating warm / dark diagonals along the face.
	var x := -hx
	var i := 0
	while x < hx:
		for row in int(minf(size.y / PX, 4.0)):
			var cx := x + row * PX
			if cx >= -hx and cx < hx:
				var c := Color(1.0, 0.8, 0.15, 0.75) if i % 2 == 0 else Color(0.05, 0.05, 0.08, 0.65)
				_r(cx, -hy + row * PX, PX * 3, PX, c)
		x += PX * 4
		i += 1


func _draw_one_way(hx: float, hy: float) -> void:
	# A dashed lip: the visual for "you can pass up through this".
	var x := -hx
	while x < hx:
		_r(x, -hy, PX * 4, PX, Color(0.85, 0.92, 1.0, 0.9))
		x += PX * 7

# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
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

const KINDS: Array[String] = ["ice", "sticky", "conveyor", "bounce", "crumble", "timed", "one_way",
	"basalt", "rust", "frost", "slate", "ember", "crystal", "circuit"]
## The biome surfaces of the machine levels (see MachineRuntime): they only dress the tile, never change
## how it plays. basalt = cracked black rock with glints, rust = riveted plate, frost = crystal, slate =
## layered strata, ember = rock with glowing cracks.
const BIOME_KINDS: Array[String] = ["basalt", "rust", "frost", "slate", "ember", "crystal", "circuit"]

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
	set_process(kind == "conveyor" or kind == "ice" or kind == "ember")
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
		"basalt", "rust", "frost", "slate", "ember", "crystal", "circuit":
			_draw_biome(hx, hy)


## Deterministic pixel dressing for the biome tiles: the same tile always gets the same marks.
func _draw_biome(hx: float, hy: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([kind, int(size.x), int(size.y)])
	var cols := int(size.x / PX)
	var rows := int(size.y / PX)
	if rows < 2 or cols < 4:
		return
	match kind:
		"basalt":
			# cracks: short stepped dark lines, a few with a warm glint
			for n in maxi(2, cols / 9):
				var cx := rng.randi_range(2, cols - 3)
				var cy := rng.randi_range(1, maxi(1, rows - 2))
				var len_px := rng.randi_range(3, 7)
				var warm := rng.randf() < 0.3
				for k in len_px:
					_r(-hx + (cx + k) * PX, -hy + clampi(cy + (k % 2), 0, rows - 1) * PX, PX, PX, Color(0.04, 0.02, 0.02, 0.75))
					if warm and k == len_px / 2:
						_r(-hx + (cx + k) * PX, -hy + clampi(cy + (k % 2), 0, rows - 1) * PX, PX, PX, Color(1.0, 0.5, 0.2, 0.8))
		"rust":
			# rivets along the top, rust blotches, scratches
			var rx := 3
			while rx < cols - 2:
				_r(-hx + rx * PX, -hy + PX, PX, PX, Color(0.12, 0.08, 0.06, 0.9))
				_r(-hx + rx * PX, -hy + PX, PX, PX * 0.5, Color(0.75, 0.55, 0.35, 0.7))
				rx += 8
			for n in maxi(2, cols / 8):
				var bx := rng.randi_range(1, cols - 3)
				var by := rng.randi_range(1, maxi(1, rows - 2))
				_r(-hx + bx * PX, -hy + by * PX, PX * 2.0, PX, Color(0.55, 0.28, 0.12, 0.55))
				_r(-hx + (bx + 1) * PX, -hy + by * PX + PX, PX, PX, Color(0.45, 0.2, 0.08, 0.5))
			for n in maxi(1, cols / 14):
				var sx := rng.randi_range(2, cols - 6)
				var sy := rng.randi_range(1, maxi(1, rows - 2))
				for k in 4:
					_r(-hx + (sx + k) * PX, -hy + clampi(sy + k / 2, 0, rows - 1) * PX, PX, PX, Color(0.85, 0.7, 0.5, 0.25))
		"frost":
			# SNOW on dark rock: a matte white cap with a ragged lower edge and a few drifts. Deliberately nothing
			# like the glossy striped ICE tile, because this tile is NOT slippery and must not look it.
			var cap := 0
			while cap < cols:
				var depth := 1 + (rng.randi_range(0, 2) if rows > 3 else 0)
				for k in depth:
					_r(-hx + cap * PX, -hy + k * PX, PX, PX, Color(0.93, 0.95, 0.98, 0.95 if k == 0 else 0.75))
				cap += 1
			for n in maxi(1, cols / 12):
				var fx := rng.randi_range(1, cols - 3)
				var fy := rng.randi_range(mini(3, rows - 1), maxi(mini(3, rows - 1), rows - 2))
				_r(-hx + fx * PX, -hy + fy * PX, PX * 2.0, PX, Color(0.06, 0.08, 0.12, 0.45))
		"crystal":
			# RIFT: violet shards growing out of the tile, with a pale core
			for n in maxi(2, cols / 7):
				var sx := rng.randi_range(1, cols - 3)
				var sh := rng.randi_range(2, maxi(2, mini(5, rows)))
				for k in sh:
					var a2 := 0.85 - 0.12 * k
					_r(-hx + (sx + (k / 2)) * PX, -hy + (rows - 1 - k) * PX, PX, PX, Color(0.72, 0.5, 1.0, a2))
				_r(-hx + sx * PX, -hy + (rows - 1) * PX, PX, PX, Color(0.95, 0.88, 1.0, 0.9))
			_r(-hx, -hy, size.x, PX, Color(0.8, 0.65, 1.0, 0.35))
		"circuit":
			# CORE: traces and lit nodes
			var ty := 1
			while ty < rows - 1:
				var x0 := rng.randi_range(1, maxi(1, cols / 3))
				var ln := rng.randi_range(4, maxi(4, cols / 2))
				_r(-hx + x0 * PX, -hy + ty * PX, PX * float(mini(ln, cols - x0 - 1)), PX * 0.5, Color(1.0, 0.45, 0.35, 0.45))
				_r(-hx + (x0 + mini(ln, cols - x0 - 1)) * PX, -hy + ty * PX, PX, PX, Color(1.0, 0.85, 0.6, 0.9))
				ty += rng.randi_range(2, 3)
		"slate":
			# horizontal strata with lighter chips
			var ly := 2
			while ly < rows - 1:
				_r(-hx + PX, -hy + ly * PX, size.x - PX * 2.0, PX * 0.5, Color(0.04, 0.05, 0.1, 0.35))
				ly += rng.randi_range(2, 4)
			for n in maxi(2, cols / 10):
				_r(-hx + rng.randi_range(1, cols - 3) * PX, -hy + rng.randi_range(1, maxi(1, rows - 2)) * PX, PX * 2.0, PX, Color(0.7, 0.78, 0.95, 0.25))
		"ember":
			var glow := 0.55 + 0.35 * sin(_time * 2.0)
			for n in maxi(2, cols / 8):
				var ex := rng.randi_range(2, cols - 4)
				var ey := rng.randi_range(1, maxi(1, rows - 2))
				var ph := rng.randf() * TAU
				var a := clampf(glow + 0.3 * sin(_time * 3.0 + ph), 0.2, 1.0)
				for k in rng.randi_range(2, 5):
					_r(-hx + (ex + k) * PX, -hy + clampi(ey + (k % 2), 0, rows - 1) * PX, PX, PX, Color(1.0, 0.55, 0.15, a))
				_r(-hx + ex * PX, -hy + ey * PX - PX, PX, PX, Color(1.0, 0.8, 0.3, a * 0.4))


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

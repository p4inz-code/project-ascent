class_name GoalGate
extends Node2D
## The door at the end of every level: a pixel-art gate built to be read from across
## the screen and to feel like an arrival.
##
##   two steel pillars with a column of lights climbing them,
##   a lintel carrying ten core sockets that light as you bank cores (10 per socket),
##   a shimmering energy field in the doorway,
##   a bobbing chevron above it ("this way"), and a light shaft to the sky.
##
## When the player reaches it the field drains upward and the door flares. On the
## final level, with every core banked, the whole gate runs gold.
##
## Origin: the centre of the doorway, matching the Goal Area2D it decorates.

const PX := 3.0
const SOCKETS := 10

var door_size: Vector2 = Vector2(56.0, 96.0)
var cores: int = 0
var core_goal: int = 100
## True on the last level: the gate shows the core count and goes gold at full.
var is_final: bool = false

var _time: float = 0.0
var _open: float = 0.0          # 0 = closed, 1 = fully open (field drained)
var _opening: bool = false
var _flare: float = 0.0


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Light this many of the ten lintel sockets.
func lit_sockets() -> int:
	if core_goal <= 0:
		return 0
	return clampi(int(floor(float(cores) / float(core_goal) * float(SOCKETS) + 0.0001)), 0, SOCKETS)


func is_full() -> bool:
	return cores >= core_goal


func is_open() -> bool:
	return _open >= 1.0


## The player reached the door: drain the field and flare.
func open() -> void:
	_opening = true
	_flare = 1.0


func _process(delta: float) -> void:
	_time += delta
	if _opening:
		_open = minf(_open + delta / 0.7, 1.0)
	_flare = maxf(_flare - delta * 1.4, 0.0)
	queue_redraw()


func _snap(v: float) -> float:
	return floorf(v / PX) * PX


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(_snap(x), _snap(y), maxf(PX, _snap(w)), maxf(PX, _snap(h))), c)


func _draw() -> void:
	var hw := door_size.x * 0.5
	var hh := door_size.y * 0.5
	var gold := is_final and is_full()
	var field_a := Color(0.25, 0.85, 1.0)
	var field_b := Color(1.0, 0.83, 0.47)
	var accent := Color(1.0, 0.83, 0.47) if gold else UITheme.accent
	var steel := Color(0.24, 0.28, 0.40)
	var steel_hi := Color(0.42, 0.48, 0.66)
	var steel_lo := Color(0.12, 0.14, 0.22)

	# Light shaft to the sky: a tall, faint column that says "the exit is here".
	var shaft_h := 520.0
	for i in 8:
		var t := float(i) / 8.0
		var a := (0.16 - t * 0.14) * (0.7 + 0.3 * sin(_time * 2.0 + t * 3.0))
		_r(-hw + PX * 2.0, -hh - shaft_h * (t + 0.125), door_size.x - PX * 4.0, shaft_h / 8.0 + 1.0,
			Color(accent.r, accent.g, accent.b, maxf(a, 0.0)))

	# Floor plate.
	_r(-hw - PX * 7.0, hh, door_size.x + PX * 14.0, PX * 2.0, steel_lo)
	_r(-hw - PX * 7.0, hh, door_size.x + PX * 14.0, PX, steel_hi)

	# Pillars with climbing lights.
	for side in [-1.0, 1.0]:
		var px_x: float = (-hw - PX * 5.0) if side < 0.0 else hw
		_r(px_x, -hh - PX * 6.0, PX * 5.0, door_size.y + PX * 6.0, steel)
		_r(px_x, -hh - PX * 6.0, PX, door_size.y + PX * 6.0, steel_hi)
		_r(px_x + PX * 4.0, -hh - PX * 6.0, PX, door_size.y + PX * 6.0, steel_lo)
		var lights := 7
		for i in lights:
			var on := fmod(_time * 3.0 + float(i) * 0.7, float(lights)) < 1.6
			var ly := hh - PX * 8.0 - float(i) * (door_size.y / float(lights))
			_r(px_x + PX * 1.5, ly, PX * 2.0, PX * 2.0, accent if on else steel_lo)

	# Lintel with the ten core sockets.
	var lintel_y := -hh - PX * 11.0
	_r(-hw - PX * 7.0, lintel_y, door_size.x + PX * 14.0, PX * 6.0, steel)
	_r(-hw - PX * 7.0, lintel_y, door_size.x + PX * 14.0, PX, steel_hi)
	_r(-hw - PX * 7.0, lintel_y + PX * 5.0, door_size.x + PX * 14.0, PX, steel_lo)
	var lit := lit_sockets()
	var sock_w := (door_size.x + PX * 8.0) / float(SOCKETS)
	for i in SOCKETS:
		var sx := -hw - PX * 4.0 + sock_w * float(i) + sock_w * 0.2
		_r(sx, lintel_y + PX * 1.5, sock_w * 0.6, PX * 3.0, steel_lo)
		if i < lit:
			var pulse := 0.75 + 0.25 * sin(_time * 4.0 + float(i))
			_r(sx + PX * 0.5, lintel_y + PX * 2.0, maxf(sock_w * 0.6 - PX, PX), PX * 2.0,
				Color(field_b.r, field_b.g, field_b.b, pulse))

	# The doorway: an energy field of vertical shimmering columns that drains up on open.
	var open_h := door_size.y * _open
	var col_w := PX * 2.0
	var cols := int(door_size.x / col_w)
	for c in cols:
		var cx := -hw + float(c) * col_w
		var wave := 0.5 + 0.5 * sin(_time * 3.0 + float(c) * 0.9)
		var tint := field_a.lerp(field_b, 0.85 if gold else (0.25 + 0.2 * wave))
		var top := -hh + open_h
		var height := door_size.y - open_h
		if height <= 0.0:
			continue
		_r(cx, top, col_w, height, Color(tint.r, tint.g, tint.b, 0.22 + 0.18 * wave))
		# Bright streaks racing up the field.
		var streak := fmod(_time * 90.0 + float(c) * 23.0, door_size.y)
		var sy := hh - streak
		if sy > top:
			_r(cx, sy, col_w, PX * 3.0, Color(1, 1, 1, 0.35 + 0.3 * wave))
	# The leading edge of the draining field.
	if _opening and _open < 1.0:
		_r(-hw, -hh + open_h, door_size.x, PX, Color(1, 1, 1, 0.9))

	# Flare when the player arrives.
	if _flare > 0.0:
		_r(-hw - PX * 4.0, -hh - PX * 8.0, door_size.x + PX * 8.0, door_size.y + PX * 8.0,
			Color(1, 1, 1, 0.45 * _flare))

	# A beacon on the lintel.
	var beacon_a := 0.5 + 0.5 * sin(_time * 3.0)
	_r(-PX * 2.0, lintel_y - PX * 4.0, PX * 4.0, PX * 4.0, Color(accent.r, accent.g, accent.b, 0.5 + 0.5 * beacon_a))

	# "This way": a chevron bobbing above the gate.
	if _open < 0.1:
		var bob := sin(_time * 3.2) * PX * 2.0
		var cy := lintel_y - PX * 12.0 + bob
		for k in 4:
			_r(-PX * float(4 - k), cy + float(k) * PX, PX * 2.0, PX, accent)
			_r(PX * float(3 - k), cy + float(k) * PX, PX * 2.0, PX, accent)

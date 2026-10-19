class_name TransitionFx
extends Control
## The between-levels cover for each act. `cover` runs 0 (nothing) to 1 (screen fully hidden);
## the game scene tweens it up, swaps the level behind it, and tweens it back down. The plain
## black fade underneath still runs, so if this ever drew nothing the game would still
## transition cleanly.
##
##   Act I   AIRLOCK      metal shutters slide shut from both sides and open again
##   Act II  HEAT FLASH   an orange-white flash floods the screen
##   Act III FROST WIPE   an icy wipe sweeps across with a jagged edge
##   Act IV  WARP STREAK  light streaks stretch across the dark
##   Act V   DAWN ASCENT  amber light rises from the bottom of the screen

enum Style { AIRLOCK, HEAT_FLASH, FROST_WIPE, WARP_STREAK, DAWN_ASCENT }

const STYLE_NAMES: Array[String] = ["AIRLOCK", "HEAT FLASH", "FROST WIPE", "WARP STREAK", "DAWN ASCENT"]
const STREAKS := 26

var style: int = Style.AIRLOCK:
	set(v):
		style = v
		queue_redraw()
var cover: float = 0.0:
	set(v):
		cover = clampf(v, 0.0, 1.0)
		visible = cover > 0.001
		queue_redraw()

## Set by drawing; tests read it to prove something was actually drawn.
var draw_calls: int = 0


## Which act a level is in, as a style. Five acts, five distinct looks.
static func style_for_level(level: int) -> int:
	if level <= 5:
		return Style.AIRLOCK
	if level <= 10:
		return Style.HEAT_FLASH
	if level <= 15:
		return Style.FROST_WIPE
	if level <= 20:
		return Style.WARP_STREAK
	return Style.DAWN_ASCENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _draw() -> void:
	draw_calls = 0
	if cover <= 0.001:
		return
	var w := size.x if size.x > 0.0 else 1920.0
	var h := size.y if size.y > 0.0 else 1080.0
	match style:
		Style.AIRLOCK:
			_draw_airlock(w, h)
		Style.HEAT_FLASH:
			_draw_heat(w, h)
		Style.FROST_WIPE:
			_draw_frost(w, h)
		Style.WARP_STREAK:
			_draw_warp(w, h)
		Style.DAWN_ASCENT:
			_draw_dawn(w, h)


func _rect(r: Rect2, c: Color) -> void:
	draw_rect(r, c)
	draw_calls += 1


func _draw_airlock(w: float, h: float) -> void:
	var half := w * 0.5 * cover
	var metal := Color(0.10, 0.13, 0.19)
	var edge := Color(0.46, 0.62, 0.80)
	var warn := Color(1.0, 0.83, 0.47)
	_rect(Rect2(0, 0, half, h), metal)
	_rect(Rect2(w - half, 0, half, h), metal)
	# Panel seams and a lit edge down the leading side of each shutter.
	for i in 6:
		var y := h * (i + 1) / 7.0
		_rect(Rect2(0, y, half, 3), Color(0.06, 0.08, 0.12))
		_rect(Rect2(w - half, y, half, 3), Color(0.06, 0.08, 0.12))
	_rect(Rect2(half - 6, 0, 6, h), edge)
	_rect(Rect2(w - half, 0, 6, h), edge)
	# Hazard chevrons on the leading edge.
	var step := 54.0
	var y2 := 0.0
	var flip := false
	while y2 < h:
		if flip:
			_rect(Rect2(half - 22, y2, 16, step * 0.5), warn)
			_rect(Rect2(w - half + 6, y2, 16, step * 0.5), warn)
		flip = not flip
		y2 += step * 0.5


func _draw_heat(w: float, h: float) -> void:
	# Fast to white, then it burns down to dull orange as the screen clears.
	var hot := Color(1.0, 0.96, 0.82)
	var warm := Color(1.0, 0.48, 0.12)
	var c := warm.lerp(hot, clampf(cover * 1.4, 0.0, 1.0))
	c.a = clampf(cover * 1.25, 0.0, 1.0)
	_rect(Rect2(0, 0, w, h), c)
	# A band of heat shimmer rising from below.
	var band := Color(1.0, 0.7, 0.2, 0.35 * (1.0 - cover))
	_rect(Rect2(0, h * (1.0 - cover), w, h * 0.12), band)


func _draw_frost(w: float, h: float) -> void:
	var front := w * cover
	var ice := Color(0.74, 0.90, 1.0)
	var deep := Color(0.20, 0.44, 0.66)
	_rect(Rect2(0, 0, front, h), deep)
	# Jagged leading edge: crystals along the wipe line.
	var teeth := 18
	for i in teeth:
		var y0 := h * i / float(teeth)
		var depth := 26.0 + 22.0 * float((i * 7) % 5)
		var pts := PackedVector2Array([
			Vector2(front, y0), Vector2(front + depth, y0 + h / teeth * 0.5), Vector2(front, y0 + h / teeth)])
		draw_colored_polygon(pts, ice)
		draw_calls += 1
	_rect(Rect2(front - 8, 0, 8, h), ice)


func _draw_warp(w: float, h: float) -> void:
	_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.08, clampf(cover * 1.1, 0.0, 1.0)))
	# Streaks stretch with the cover, longest at mid-transition.
	var stretch := sin(cover * PI)
	for i in STREAKS:
		var y := h * (float((i * 37) % STREAKS) + 0.5) / STREAKS
		var len := w * (0.15 + 0.85 * stretch) * (0.4 + 0.6 * float((i * 13) % 7) / 6.0)
		var x := (w - len) * (0.5 + 0.5 * sin(float(i) * 1.7))
		var c := Color(0.55, 0.85, 1.0, 0.25 + 0.6 * stretch)
		_rect(Rect2(x, y - 1.5, len, 3.0), c)


func _draw_dawn(w: float, h: float) -> void:
	var top := h * (1.0 - cover)
	# A gradient from deep blue at the top of the light to amber at the very bottom.
	var pts := PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, h), Vector2(0, h)])
	var cols := PackedColorArray([
		Color(0.12, 0.16, 0.34, clampf(cover * 2.0, 0.0, 1.0)), Color(0.12, 0.16, 0.34, clampf(cover * 2.0, 0.0, 1.0)),
		Color(1.0, 0.78, 0.40, 1.0), Color(1.0, 0.78, 0.40, 1.0)])
	draw_polygon(pts, cols)
	draw_calls += 1
	# The sun itself, rising with the light.
	draw_circle(Vector2(w * 0.5, h - h * 0.35 * cover), 90.0 * cover, Color(1.0, 0.95, 0.75, 0.9))
	draw_calls += 1

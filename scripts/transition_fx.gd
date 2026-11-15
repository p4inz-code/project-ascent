# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name TransitionFx
extends Control
## The between-levels cover, one per act, drawn as chunky PIXEL ART (everything sits on a 24 px block grid and the
## motion ticks in steps) so it belongs to the game instead of sliding smooth rectangles over it. `cover` runs 0
## (nothing) to 1 (screen fully hidden); the game scene eases it up, swaps the level behind it, shows the level
## card, and eases it back down. At cover 1 every style hides the whole screen with no gaps.
##
##   I    AIRLOCK      riveted shutters close from both sides, with hazard chevrons on the leading edges
##   II   HEAT FLASH   embers rise in columns until the screen is molten
##   III  FROST WIPE   ice crystals grow across the screen behind a jagged edge
##   IV   WARP STREAK  rows of light shoot across, alternating direction
##   V    DAWN ASCENT  amber light climbs in bands with the sun behind it
##   VI   PIPE SHUTTER vertical pipes drop from the roof one after another
##   VII  RIFT TEAR    violet blocks eat the screen outward from a crack
##   VIII CORE IRIS    a block iris closes on the centre

enum Style { AIRLOCK, HEAT_FLASH, FROST_WIPE, WARP_STREAK, DAWN_ASCENT, PIPE_SHUTTER, RIFT_TEAR, CORE_IRIS }

const STYLE_NAMES: Array[String] = ["AIRLOCK", "HEAT FLASH", "FROST WIPE", "WARP STREAK", "DAWN ASCENT", "PIPE SHUTTER", "RIFT TEAR", "CORE IRIS"]
const BLOCK := 24.0
const STEPS := 30.0

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


## Which act a level is in, as a style. Eight acts, eight distinct looks.
static func style_for_level(level: int) -> int:
	return clampi((level - 1) / 5, 0, Style.CORE_IRIS)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _rect(r: Rect2, c: Color) -> void:
	draw_rect(r, c)
	draw_calls += 1


## A cheap fixed hash in 0..1 for a block, so patterns are the same every time.
func _h(ix: int, iy: int) -> float:
	var n := (ix * 73856093) ^ (iy * 19349663)
	return float(absi(n) % 1000) / 1000.0


func _draw() -> void:
	draw_calls = 0
	if cover <= 0.001:
		return
	var w := size.x if size.x > 0.0 else 1920.0
	var h := size.y if size.y > 0.0 else 1080.0
	# the motion ticks: 30 steps from open to shut
	var c := ceilf(cover * STEPS) / STEPS
	match style:
		Style.AIRLOCK:
			_draw_airlock(w, h, c)
		Style.HEAT_FLASH:
			_draw_columns(w, h, c, Color(0.5, 0.1, 0.03), Color(1.0, 0.55, 0.15), Color(1.0, 0.9, 0.6), true)
		Style.FROST_WIPE:
			_draw_frost(w, h, c)
		Style.WARP_STREAK:
			_draw_warp(w, h, c)
		Style.DAWN_ASCENT:
			_draw_dawn(w, h, c)
		Style.PIPE_SHUTTER:
			_draw_columns(w, h, c, Color(0.08, 0.13, 0.15), Color(0.2, 0.38, 0.4), Color(0.5, 0.85, 0.85), false)
		Style.RIFT_TEAR:
			_draw_rift(w, h, c)
		Style.CORE_IRIS:
			_draw_iris(w, h, c)


func _draw_airlock(w: float, h: float, c: float) -> void:
	var half := ceilf(w * 0.5 * c / BLOCK) * BLOCK
	if c >= 1.0:
		half = w * 0.5 + BLOCK
	var metal := Color(0.10, 0.13, 0.19)
	var seam := Color(0.06, 0.08, 0.12)
	var edge := Color(0.46, 0.62, 0.80)
	var warn := Color(1.0, 0.83, 0.47)
	_rect(Rect2(0, 0, half, h), metal)
	_rect(Rect2(w - half, 0, half, h), metal)
	var y := 0.0
	var row := 0
	while y < h:
		_rect(Rect2(0, y, half, 3), seam)
		_rect(Rect2(w - half, y, half, 3), seam)
		# rivets
		_rect(Rect2(half - 60.0, y + 30.0, 6, 6), edge.darkened(0.3))
		_rect(Rect2(w - half + 54.0, y + 30.0, 6, 6), edge.darkened(0.3))
		if row % 2 == 0:
			_rect(Rect2(half - 30.0, y, 24, BLOCK * 2.0), warn)
			_rect(Rect2(w - half + 6.0, y, 24, BLOCK * 2.0), warn)
		y += BLOCK * 4.0
		row += 1
	_rect(Rect2(half - 6, 0, 6, h), edge)
	_rect(Rect2(w - half, 0, 6, h), edge)


## Columns of blocks that grow from the bottom (embers, rising) or the top (pipes, dropping), each column with its
## own delay, until the screen is covered.
func _draw_columns(w: float, h: float, c: float, dark: Color, mid: Color, bright: Color, from_bottom: bool) -> void:
	var cols := int(ceilf(w / (BLOCK * 2.0)))
	for i in cols:
		var delay := _h(i, 7) * 0.45
		var f := clampf((c - delay) / 0.55, 0.0, 1.0)
		if c >= 1.0:
			f = 1.0
		if f <= 0.0:
			continue
		var len := ceilf(h * f / BLOCK) * BLOCK
		var x := float(i) * BLOCK * 2.0
		var y0 := h - len if from_bottom else 0.0
		_rect(Rect2(x, y0, BLOCK * 2.0, len), dark if i % 2 == 0 else dark.lightened(0.06))
		# the leading edge glows
		var ey := y0 if from_bottom else y0 + len - BLOCK
		if f < 1.0:
			_rect(Rect2(x, ey, BLOCK * 2.0, BLOCK), mid)
			_rect(Rect2(x + BLOCK * 0.5, ey + (0.0 if from_bottom else BLOCK * 0.5), BLOCK, BLOCK * 0.5), bright)
		elif not from_bottom:
			_rect(Rect2(x + BLOCK * 0.75, 0.0, BLOCK * 0.5, h), mid.darkened(0.35))


func _draw_frost(w: float, h: float, c: float) -> void:
	var deep := Color(0.13, 0.30, 0.48)
	var ice := Color(0.74, 0.90, 1.0)
	var rows := int(ceilf(h / BLOCK))
	for r in rows:
		var lead := w * (c * 1.25 - 0.25 * _h(r, 3))
		if c >= 1.0:
			lead = w + BLOCK
		if lead <= 0.0:
			continue
		lead = ceilf(lead / BLOCK) * BLOCK
		var y := float(r) * BLOCK
		_rect(Rect2(0, y, lead, BLOCK), deep if r % 2 == 0 else deep.lightened(0.05))
		if c < 1.0:
			_rect(Rect2(lead - BLOCK, y, BLOCK, BLOCK), ice)
			if _h(r, 11) > 0.5:
				_rect(Rect2(lead, y + BLOCK * 0.25, BLOCK * 0.5, BLOCK * 0.5), ice)


func _draw_warp(w: float, h: float, c: float) -> void:
	var dark := Color(0.02, 0.03, 0.08)
	var light := Color(0.55, 0.85, 1.0)
	var rows := int(ceilf(h / BLOCK))
	for r in rows:
		var delay := _h(r, 5) * 0.4
		var f := clampf((c - delay) / 0.6, 0.0, 1.0)
		if c >= 1.0:
			f = 1.0
		if f <= 0.0:
			continue
		var len := ceilf(w * f / BLOCK) * BLOCK
		var y := float(r) * BLOCK
		var from_left := r % 2 == 0
		var x := 0.0 if from_left else w - len
		_rect(Rect2(x, y, len, BLOCK), dark)
		if f < 1.0:
			_rect(Rect2(x + len - BLOCK * 3.0 if from_left else x, y + BLOCK * 0.25, BLOCK * 3.0, BLOCK * 0.5), light)


func _draw_dawn(w: float, h: float, c: float) -> void:
	var bands := 9
	var top_col := Color(0.12, 0.16, 0.34)
	var bot_col := Color(1.0, 0.78, 0.40)
	var bh := ceilf(h / float(bands) / BLOCK) * BLOCK
	for b in bands:
		var f := clampf(c * float(bands) - float(b), 0.0, 1.0)
		if c >= 1.0:
			f = 1.0
		if f <= 0.0:
			continue
		var y := h - float(b + 1) * bh
		_rect(Rect2(0, y + bh * (1.0 - f), w, bh * f + 1.0), bot_col.lerp(top_col, float(b) / float(bands - 1)))
	# the sun: a block disc rising behind the bands
	var cy := h - h * 0.4 * c
	var rad := 96.0 * c
	var iy := -4
	while iy <= 4:
		var half := floorf(sqrt(maxf(16.0 - float(iy * iy), 0.0))) * (rad / 4.0)
		if half > 0.0:
			_rect(Rect2(w * 0.5 - half, cy + float(iy) * (rad / 4.0), half * 2.0, rad / 4.0 + 1.0), Color(1.0, 0.95, 0.75))
		iy += 1


## Blocks appear in order of their distance from a jagged crack down the middle.
func _draw_rift(w: float, h: float, c: float) -> void:
	var cols := int(ceilf(w / BLOCK))
	var rows := int(ceilf(h / BLOCK))
	var dark := Color(0.06, 0.02, 0.12)
	var glow := Color(0.72, 0.45, 1.0)
	for r in rows:
		var crack := w * 0.5 + (_h(r / 3, 17) - 0.5) * 220.0
		for k in cols:
			var x := float(k) * BLOCK
			var d := absf(x + BLOCK * 0.5 - crack) / (w * 0.62) + _h(k, r) * 0.12
			if c < 1.0 and d > c:
				continue
			var front := c < 1.0 and d > c - 0.05
			_rect(Rect2(x, float(r) * BLOCK, BLOCK, BLOCK), glow if front else dark)


## A block iris: everything further from the centre than the shrinking radius is covered.
func _draw_iris(w: float, h: float, c: float) -> void:
	var cols := int(ceilf(w / BLOCK))
	var rows := int(ceilf(h / BLOCK))
	var dark := Color(0.10, 0.03, 0.03)
	var hot := Color(1.0, 0.45, 0.3)
	var max_r := sqrt(w * w + h * h) * 0.5
	var radius := max_r * (1.0 - c)
	for r in rows:
		# draw each row as runs: left cover, right cover (fewer draw calls than per block)
		var y := float(r) * BLOCK
		var dy := absf(y + BLOCK * 0.5 - h * 0.5)
		if c >= 1.0 or dy >= radius:
			_rect(Rect2(0, y, w, BLOCK), dark)
			continue
		var half := floorf(sqrt(radius * radius - dy * dy) / BLOCK) * BLOCK
		var x0 := w * 0.5 - half
		var x1 := w * 0.5 + half
		_rect(Rect2(0, y, maxf(x0, 0.0), BLOCK), dark)
		_rect(Rect2(x1, y, maxf(w - x1, 0.0), BLOCK), dark)
		_rect(Rect2(x0 - BLOCK, y, BLOCK, BLOCK), hot)
		_rect(Rect2(x1, y, BLOCK, BLOCK), hot)
	draw_calls = maxi(draw_calls, 1) if cols > 0 else draw_calls

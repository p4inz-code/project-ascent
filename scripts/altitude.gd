# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name Altitude
extends RefCounted
## The climb is the point of the game, so the sky says how high you are. Every level gets a tint across the top of
## the sky that follows its number: ember storm at the bottom, dawn rose, thin cold blue, deep indigo, then the
## near-black violet of space. Each act keeps its own palette underneath; this only leans it a little.

const TOTAL := 40
## fraction of the climb, colour at the top of the sky
const STOPS: Array = [
	[0.00, Color(0.40, 0.10, 0.07)],
	[0.25, Color(0.92, 0.50, 0.44)],
	[0.50, Color(0.42, 0.70, 1.00)],
	[0.75, Color(0.12, 0.15, 0.42)],
	[1.00, Color(0.05, 0.02, 0.16)],
]
const TOP_ALPHA := 0.30


static func fraction(level: int) -> float:
	return clampf(float(level - 1) / float(TOTAL - 1), 0.0, 1.0)


static func tint(level: int) -> Color:
	var f := fraction(level)
	for i in range(1, STOPS.size()):
		if f <= float(STOPS[i][0]):
			var a: float = STOPS[i - 1][0]
			var b: float = STOPS[i][0]
			var c: Color = (STOPS[i - 1][1] as Color).lerp(STOPS[i][1], (f - a) / (b - a))
			return Color(c.r, c.g, c.b, TOP_ALPHA)
	var last: Color = STOPS[STOPS.size() - 1][1]
	return Color(last.r, last.g, last.b, TOP_ALPHA)


## Stars grow brighter as the air thins: 0.55 of their colour at the bottom, full at the top.
static func star_alpha(level: int) -> float:
	return lerpf(0.55, 1.0, fraction(level))


## A vertical gradient texture (tinted top fading to nothing at the horizon) for the sky overlay.
static func overlay_texture(level: int) -> GradientTexture2D:
	var g := Gradient.new()
	var top := tint(level)
	g.colors = PackedColorArray([top, Color(top.r, top.g, top.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.85])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 256
	return t

# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. All rights reserved. See LICENSE.
# SPDX-License-Identifier: LicenseRef-ProjectAscent-FreeToPlay
class_name ReactionCard
extends Control
## An original pixel reaction face that pops up beside the death line (and a proud one on a clear). Fourteen
## cards, composed from one round head plus eyes, a mouth and an extra (a sweat drop, a crown, shades...).
## Pure decoration: it never takes input and never blocks. No third-party memes, no text on the card.

const PX := 4.0
const GRID := 12

const DEATH_BY_TIER := {
	1: ["blank", "wince", "stare"],
	2: ["sweat", "shrug", "wince", "stare"],
	3: ["grit", "dizzy", "sweat", "facepalm"],
	4: ["rage", "grit", "dizzy", "tear"],
	5: ["skull", "rage", "tear", "dizzy"],
}
const CLEAR_CARDS: Array[String] = ["cool", "grin"]
const BOSS_CARDS: Array[String] = ["crown", "cool"]
const ALL_KINDS: Array[String] = ["blank", "wince", "stare", "sweat", "shrug", "grit", "dizzy", "facepalm", "rage", "tear", "skull", "cool", "grin", "crown"]

var kind: String = "blank"

## 12x12 head mask: 'o' outline, 'f' face
const HEAD := [
	"...oooooo...",
	"..offffffo..",
	".offffffffo.",
	"offffffffffo",
	"offffffffffo",
	"offffffffffo",
	"offffffffffo",
	"offffffffffo",
	"offffffffffo",
	".offffffffo.",
	"..offffffo..",
	"...oooooo...",
]


static func kinds_for(tier: int, clear: bool, boss: bool) -> Array:
	if clear:
		return BOSS_CARDS if boss else CLEAR_CARDS
	return DEATH_BY_TIER.get(clampi(tier, 1, 5), DEATH_BY_TIER[1])


static func pick(rng: RandomNumberGenerator, tier: int, clear: bool, boss: bool) -> String:
	var pool := kinds_for(tier, clear, boss)
	return String(pool[rng.randi_range(0, pool.size() - 1)])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PX * GRID, PX * GRID)
	size = custom_minimum_size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _px(x: int, y: int, c: Color) -> void:
	draw_rect(Rect2(float(x) * PX, float(y) * PX, PX, PX), c)


func _draw() -> void:
	var face := Color(1.0, 0.83, 0.35)
	if kind in ["rage", "grit"]:
		face = Color(1.0, 0.55, 0.3)
	elif kind in ["skull", "dizzy"]:
		face = Color(0.82, 0.86, 0.9)
	elif kind in ["cool", "grin", "crown"]:
		face = Color(1.0, 0.88, 0.4)
	var ink := Color(0.12, 0.08, 0.1)
	for y in GRID:
		var row: String = HEAD[y]
		for x in GRID:
			match row[x]:
				"o":
					_px(x, y, ink)
				"f":
					_px(x, y, face)
	# eyes
	match kind:
		"blank", "shrug":
			_px(3, 5, ink); _px(8, 5, ink)
		"wince", "tear":
			for k in 2:
				_px(3 + k, 5 + k, ink); _px(8 - k, 5 + k, ink)
		"stare":
			_px(3, 4, Color.WHITE); _px(4, 4, Color.WHITE); _px(3, 5, ink); _px(4, 5, ink)
			_px(7, 4, Color.WHITE); _px(8, 4, Color.WHITE); _px(7, 5, ink); _px(8, 5, ink)
		"sweat", "grin":
			_px(3, 5, ink); _px(4, 5, ink); _px(7, 5, ink); _px(8, 5, ink)
		"grit", "rage":
			for k in 3:
				_px(2 + k, 4 + (1 if k == 2 else 0), ink); _px(9 - k, 4 + (1 if k == 2 else 0), ink)
			_px(3, 6, ink); _px(8, 6, ink)
		"dizzy":
			_px(3, 5, ink); _px(4, 6, ink); _px(4, 4, ink); _px(2, 6, ink)
			_px(8, 5, ink); _px(7, 6, ink); _px(7, 4, ink); _px(9, 6, ink)
		"facepalm":
			_px(3, 5, ink); _px(8, 5, ink)
			for yy in range(3, 9):
				_px(1, yy, Color(1.0, 0.7, 0.45)); _px(2, yy, Color(1.0, 0.7, 0.45))
		"skull":
			_px(3, 5, ink); _px(4, 5, ink); _px(3, 6, ink); _px(4, 6, ink)
			_px(7, 5, ink); _px(8, 5, ink); _px(7, 6, ink); _px(8, 6, ink)
			_px(5, 7, ink); _px(6, 7, ink)
		"cool", "crown":
			for xx in range(2, 10):
				_px(xx, 5, ink)
			_px(5, 6, ink); _px(6, 6, ink)
	# mouth
	match kind:
		"blank", "stare":
			for xx in range(4, 8):
				_px(xx, 8, ink)
		"wince":
			_px(4, 8, ink); _px(5, 9, ink); _px(6, 8, ink); _px(7, 9, ink)
		"sweat", "shrug":
			_px(4, 9, ink); _px(5, 8, ink); _px(6, 8, ink); _px(7, 9, ink)
		"grit":
			for xx in range(3, 9):
				_px(xx, 8, ink)
			for xx in [4, 6, 8]:
				_px(xx, 9, Color.WHITE)
		"rage":
			for xx in range(3, 9):
				_px(xx, 8, ink)
			_px(3, 9, ink); _px(8, 9, ink)
		"dizzy":
			_px(4, 8, ink); _px(5, 9, ink); _px(6, 8, ink); _px(7, 9, ink)
		"tear":
			_px(4, 9, ink); _px(5, 8, ink); _px(6, 8, ink); _px(7, 9, ink)
		"skull":
			for xx in range(4, 8):
				_px(xx, 9, ink)
			_px(5, 9, Color.WHITE); _px(7, 9, Color.WHITE)
		"cool", "crown":
			_px(4, 8, ink); _px(5, 9, ink); _px(6, 9, ink); _px(7, 8, ink)
		"grin":
			for xx in range(3, 9):
				_px(xx, 8, ink)
			for xx in range(4, 8):
				_px(xx, 9, Color.WHITE)
	# extras
	if kind in ["sweat", "tear"]:
		var drop := Color(0.5, 0.8, 1.0)
		_px(10, 4, drop)
		_px(10, 5, drop)
		if kind == "sweat":
			_px(9, 6, drop)
		else:
			_px(3, 7, drop)
	if kind == "crown":
		var gold := Color(1.0, 0.78, 0.15)
		for xx in [3, 5, 7, 9]:
			_px(xx, 0, gold)
		for xx in range(3, 10):
			_px(xx, 1, gold)

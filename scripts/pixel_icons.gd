# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name PixelIcons
extends RefCounted
## Pixel-art badge icons for the title screen (settings gear, about, studio, and the support heart from
## PixelHeart). Drawn from character grids, baked into crisp ImageTextures; no image files to ship.
##   o outline   a accent   l light   d dark

const GEAR := [
	".....oo.....",
	"..oo.oo.oo..",
	".oaao..oaao.",
	".oallllllao.",
	"..olaaaalo..",
	"ooolaoodalooo",
	"ooolaoodaloo",
	"..olaaaalo..",
	".oallllllao.",
	".oaao..oaao.",
	"..oo.oo.oo..",
	".....oo.....",
]
const INFO := [
	"...oooooo...",
	"..oaaaaaao..",
	".oaaallaaao.",
	"oaaaallaaaao",
	"oaaaaaaaaaao",
	"oaaaallaaaao",
	"oaaaallaaaao",
	"oaaaallaaaao",
	".oaaallaaao.",
	"..oaaaaaao..",
	"...oooooo...",
	"............",
]
## The studio badge: a rocket climbing (P4INZ makes games about going up).
const STUDIO := [
	".....oo.....",
	"....olao....",
	"...olaaao...",
	"...oaaaao...",
	"...oadlao...",
	"...oaaaao...",
	"..ooaaaaoo..",
	".oaoaaaaoao.",
	".oaooaaooao.",
	".oo.olao.oo.",
	".....ll.....",
	"....l..l....",
]
const COLORS := {"o": Color(0.04, 0.07, 0.14), "a": Color(0.36, 0.72, 1.0), "l": Color(0.85, 0.95, 1.0),
	"d": Color(0.10, 0.20, 0.36)}


static func texture(grid: Array, scale_px: int = 4, accent: Color = Color(0.36, 0.72, 1.0)) -> ImageTexture:
	var w := 0
	for row in grid:
		w = maxi(w, String(row).length())
	var img := Image.create(w * scale_px, grid.size() * scale_px, false, Image.FORMAT_RGBA8)
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			var ch := row[x]
			if not COLORS.has(ch):
				continue
			var c: Color = COLORS[ch]
			if ch == "a":
				c = accent
			img.fill_rect(Rect2i(x * scale_px, y * scale_px, scale_px, scale_px), c)
	return ImageTexture.create_from_image(img)

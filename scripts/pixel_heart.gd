# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name PixelHeart
extends RefCounted
## The pixel-art heart on the CONTRIBUTE TO DEVELOPMENT buttons (main page and About). Drawn from a 11 x 10
## grid so there is no image file to ship; `texture()` bakes it into a crisp ImageTexture.

const GRID := [
	"..oo...oo..",
	".orrooorro.",
	"orrwrrrrrro",
	"orwrrrrrrro",
	"orrrrrrrrro",
	".orrrrrrro.",
	"..orrrrro..",
	"...orrro...",
	"....oro....",
	".....o.....",
]
const COLORS := {"o": Color(0.35, 0.05, 0.12), "r": Color(1.0, 0.27, 0.4), "w": Color(1.0, 0.78, 0.85)}


static func width() -> int:
	return String(GRID[0]).length()


static func height() -> int:
	return GRID.size()


static func texture(scale_px: int = 3) -> ImageTexture:
	var img := Image.create(width() * scale_px, height() * scale_px, false, Image.FORMAT_RGBA8)
	for y in height():
		var row: String = GRID[y]
		for x in width():
			var ch := row[x]
			if COLORS.has(ch):
				img.fill_rect(Rect2i(x * scale_px, y * scale_px, scale_px, scale_px), COLORS[ch])
	return ImageTexture.create_from_image(img)

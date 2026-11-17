shader_type canvas_item;
// Quantises whatever is beneath this layer to a block grid (block_px screen
// pixels per art pixel), then reduces colour depth with a 4x4 ordered (Bayer)
// dither computed per BLOCK, so gradients break into the stippled banding of
// real pixel art instead of staying smooth. Nearest sampling at the block
// centre keeps edges hard; no blending between blocks.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float block_px = 3.0;
uniform float levels = 20.0;       // colour steps per channel
uniform float dither_strength = 1.0;
uniform float scanline_strength = 0.0;   // 0..1, darkens alternate block rows
uniform mat3 cvd = mat3(1.0);            // colour-vision correction (identity when off)

float bayer4(vec2 c) {
	int x = int(mod(c.x, 4.0));
	int y = int(mod(c.y, 4.0));
	int i = x + y * 4;
	// Standard 4x4 Bayer matrix, normalised to (0,1).
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0,
	                        12.0, 4.0, 14.0, 6.0,
	                        3.0, 11.0, 1.0, 9.0,
	                        15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(SCREEN_UV * res / block_px);
	vec2 snapped_uv = (cell + 0.5) * block_px / res;
	vec3 c = textureLod(screen_tex, snapped_uv, 0.0).rgb;
	c = clamp(cvd * c, 0.0, 1.0);
	float t = (bayer4(cell) - 0.5) * dither_strength;
	c = floor(c * levels + 0.5 + t) / levels;
	// CRT scanlines: every other block row dims, so they stay locked to the pixel grid.
	float row = mod(cell.y, 2.0);
	c *= 1.0 - scanline_strength * 0.45 * row;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

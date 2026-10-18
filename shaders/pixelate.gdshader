shader_type canvas_item;
// Quantises whatever is beneath this layer to a block grid (block_px screen
// pixels per art pixel). Nearest sampling at the block centre keeps edges
// hard; no blending between blocks.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float block_px = 3.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(SCREEN_UV * res / block_px);
	vec2 snapped_uv = (cell + 0.5) * block_px / res;
	COLOR = textureLod(screen_tex, snapped_uv, 0.0);
}

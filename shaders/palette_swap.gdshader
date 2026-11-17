shader_type canvas_item;
// Recolours only chosen ramps of the player sprite and leaves the outline and
// boots alone. A plain modulate would tint everything (pink suit -> muddy trim),
// which is why this is a swap and not a multiply.
//
// The src_* colours must match tools/gen_pixel_art.py (SUIT, SUIT_SHADE, SCARF,
// SCARF_SHADE, VISOR).

uniform vec4 suit = vec4(0.4196, 0.7804, 1.0, 1.0);
uniform vec4 accent = vec4(1.0, 0.702, 0.2784, 1.0);   // scarf / antenna tip / pack light
uniform vec4 visor = vec4(0.9216, 0.9725, 1.0, 1.0);
uniform vec4 src_suit = vec4(0.4196, 0.7804, 1.0, 1.0);
uniform vec4 src_shade = vec4(0.2471, 0.5608, 0.8392, 1.0);
uniform vec4 src_accent = vec4(1.0, 0.702, 0.2784, 1.0);
uniform vec4 src_accent_shade = vec4(0.8392, 0.4941, 0.1255, 1.0);
uniform vec4 src_visor = vec4(0.9216, 0.9725, 1.0, 1.0);
uniform float shade_amount = 0.28;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.0) {
		if (distance(c.rgb, src_suit.rgb) < 0.02) {
			c.rgb = suit.rgb;
		} else if (distance(c.rgb, src_shade.rgb) < 0.02) {
			c.rgb = suit.rgb * (1.0 - shade_amount);
		} else if (distance(c.rgb, src_accent.rgb) < 0.02) {
			c.rgb = accent.rgb;
		} else if (distance(c.rgb, src_accent_shade.rgb) < 0.02) {
			c.rgb = accent.rgb * (1.0 - shade_amount);
		} else if (distance(c.rgb, src_visor.rgb) < 0.02) {
			c.rgb = visor.rgb;
		}
	}
	COLOR = c;
}

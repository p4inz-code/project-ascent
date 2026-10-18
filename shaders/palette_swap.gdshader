shader_type canvas_item;
// Recolours only the player's suit ramp, leaving the outline, visor, boots and
// the amber scarf alone. A plain modulate would also tint the scarf (pink suit
// -> muddy scarf), which is why this is a swap and not a multiply.
//
// src_suit / src_shade must match tools/gen_pixel_art.py's SUIT / SUIT_SHADE.

uniform vec4 suit = vec4(0.4196, 0.7804, 1.0, 1.0);
uniform vec4 src_suit = vec4(0.4196, 0.7804, 1.0, 1.0);
uniform vec4 src_shade = vec4(0.2471, 0.5608, 0.8392, 1.0);
uniform float shade_amount = 0.28;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.0) {
		if (distance(c.rgb, src_suit.rgb) < 0.02) {
			c.rgb = suit.rgb;
		} else if (distance(c.rgb, src_shade.rgb) < 0.02) {
			c.rgb = suit.rgb * (1.0 - shade_amount);
		}
	}
	COLOR = c;
}

shader_type canvas_item;
// One shader for every pool in the game: lava, acid and water. It is procedural and
// animated: slowly drifting plates of crust with glowing cracks between them (lava),
// churning bright patches (acid), rolling light bands (water), a bright rim at the
// surface and a darker, cooler body toward the bottom. The pixel filter quantises
// the result, so it ends up as stippled, banded, pixel-art liquid.
//
// Apply to a ColorRect: UV runs 0..1 across it, size_px says how big that is.

uniform vec4 deep : source_color = vec4(0.22, 0.03, 0.02, 1.0);
uniform vec4 mid : source_color = vec4(0.78, 0.20, 0.05, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform vec4 crust : source_color = vec4(0.10, 0.035, 0.035, 1.0);
uniform vec2 size_px = vec2(400.0, 200.0);
uniform float cell_px = 46.0;          // size of one noise cell in world pixels
uniform float speed = 0.10;
uniform float crust_level = 0.56;      // above ~1.0 there is no crust at all
uniform float glow = 1.0;              // how strongly the cracks / patches glow
uniform float rim_px = 14.0;           // height of the bright surface band
uniform float seed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size_px;
	vec2 p = px / cell_px;
	float t = TIME * speed;
	float depth = clamp(UV.y, 0.0, 1.0);

	// Two drifting layers: slow broad plates and a faster fine churn.
	float broad = fbm(p * vec2(0.9, 1.4) + vec2(t, t * 0.35));
	float fine = fbm(p * 2.4 - vec2(t * 1.6, t * 0.5));
	float v = broad * 0.72 + fine * 0.28;

	// Plates of crust where v is high; the glowing crack is the band just below the edge.
	float plate = smoothstep(crust_level, crust_level + 0.05, v);
	float crack = smoothstep(crust_level - 0.13, crust_level, v) - plate;
	crack = max(crack, 0.0);

	vec3 body = mix(mid.rgb, deep.rgb, pow(depth, 0.8));
	// The churn brightens parts of the body even where there is no crust.
	float churn = smoothstep(0.55, 0.9, fine) * (1.0 - depth * 0.7);
	vec3 col = mix(body, hot.rgb, clamp(glow * (0.12 * churn + crack * 1.1), 0.0, 1.0));
	col = mix(col, crust.rgb, plate * 0.9 * (1.0 - depth * 0.45));

	// The surface: a bright rim, strongest right at the top edge, wobbling a little.
	float wob = (noise(vec2(px.x / 24.0 + t * 6.0, 0.0)) - 0.5) * 6.0;
	float rim = smoothstep(rim_px, 0.0, px.y + wob);
	col = mix(col, hot.rgb, rim * 0.85);
	col += hot.rgb * rim * 0.25;

	COLOR = vec4(col, 1.0);
}

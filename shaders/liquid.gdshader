shader_type canvas_item;
// One shader for every pool in the game: lava, acid and water, drawn as PIXEL ART so it sits with the rest of
// the game instead of looking like a smooth photo texture pasted under blocky tiles:
//   * everything is snapped to the same 3 px art-pixel grid the tiles and sprites use;
//   * the colour is a five-step ramp (crust, deep, mid, hot, white-hot) with no smooth gradients;
//   * lava is dark cooled plates split by thin glowing veins that drift slowly, brighter near the surface;
//   * acid is churning bright patches, water is slow rolling light bands;
//   * the surface is a stepped, slowly travelling wave with a bright skin.
//
// Apply to a ColorRect: UV runs 0..1 across it, size_px says how big that is.

uniform vec4 deep : source_color = vec4(0.22, 0.03, 0.02, 1.0);
uniform vec4 mid : source_color = vec4(0.78, 0.20, 0.05, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform vec4 crust : source_color = vec4(0.10, 0.035, 0.035, 1.0);
uniform vec2 size_px = vec2(400.0, 200.0);
uniform float cell_px = 46.0;          // size of one noise cell in world pixels
uniform float speed = 0.10;
uniform float crust_level = 0.56;      // below 1.0: plates and veins (lava). 1.0 and above: no crust (acid, water)
uniform float glow = 1.0;              // how strongly the veins / patches glow
uniform float rim_px = 9.0;            // height of the bright surface skin
uniform float seed = 0.0;
uniform float art_px = 3.0;            // one art pixel in world pixels

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
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}

vec3 ramp(float h) {
	// five flat steps, no blending between them
	if (h < 0.2) { return crust.rgb; }
	if (h < 0.4) { return deep.rgb; }
	if (h < 0.62) { return mix(deep.rgb, mid.rgb, 0.65); }
	if (h < 0.82) { return mid.rgb; }
	if (h < 0.94) { return hot.rgb; }
	return mix(hot.rgb, vec3(1.0), 0.45);
}

void fragment() {
	// snap to the art-pixel grid
	vec2 px = floor(UV * size_px / art_px) * art_px;
	vec2 p = px / cell_px;
	// time moves in small steps too, so the pixels tick rather than smear
	float t = floor(TIME * speed * 24.0) / 24.0;
	float depth = clamp(px.y / max(size_px.y, 1.0), 0.0, 1.0);
	float h;
	if (crust_level < 1.0) {
		// LAVA: a slow sideways drift; veins are where the noise crosses its midline
		float n = fbm(p * vec2(0.85, 1.35) + vec2(t, t * 0.3));
		float vein = 1.0 - abs(2.0 * n - 1.0);                 // 1 on the vein, falling away to the plates
		float w = 0.90 - 0.05 * glow;                          // vein width
		float core = smoothstep(w, 1.0, vein);                 // the bright line itself
		float halo = smoothstep(w - 0.16, w, vein);            // the orange around it
		float plate = 1.0 - halo;                              // cooled rock between veins
		float breathe = 0.5 + 0.5 * sin(TIME * 1.3 + n * 9.0);
		h = 0.30 + 0.10 * (1.0 - depth);                       // the dim body between plates and veins
		h = mix(h, 0.08, plate * smoothstep(crust_level - 0.2, crust_level + 0.2, noise(p * 0.7 + 3.0) + 0.25));
		h = max(h, halo * (0.55 + 0.12 * breathe));
		h = max(h, core * (0.86 + 0.14 * breathe));
		h *= 1.0 - depth * 0.35;                                // cooler toward the bottom
	} else {
		// ACID and WATER: rolling patches, brighter near the surface
		float broad = fbm(p * vec2(0.9, 1.5) + vec2(t * 1.4, t * 0.4));
		float fine = noise(p * 2.6 - vec2(t * 2.2, 0.0));
		h = 0.34 + 0.34 * broad + 0.22 * smoothstep(0.62, 0.9, fine) * glow;
		h *= 1.0 - depth * 0.45;
	}
	vec3 col = ramp(clamp(h, 0.0, 1.0));

	// the surface: a stepped travelling wave with a bright skin and a darker line under it
	float wave = floor((sin(px.x / 26.0 + TIME * 1.6) * 3.0 + sin(px.x / 11.0 - TIME * 2.3) * 1.5) / art_px) * art_px;
	float y = px.y + wave;
	if (y < art_px) {
		col = mix(hot.rgb, vec3(1.0), 0.35);
	} else if (y < rim_px) {
		col = hot.rgb;
	} else if (y < rim_px + art_px) {
		col = mid.rgb;
	}
	COLOR = vec4(col, 1.0);
}

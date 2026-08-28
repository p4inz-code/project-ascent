shader_type canvas_item;
// Screen-edge darkening. Pulls the eye to the middle of the frame, where the
// player is kept by the camera, and stops the flat background reading as a
// featureless slab of colour at the corners.
//
// Compatibility-renderer safe: no derivatives, no screen texture read, no
// branching. Runs on WebGL2.

// How dark the corners get. 0 disables the effect entirely.
uniform float strength : hint_range(0.0, 1.0) = 0.5;
// Radius (in half-screens) at which darkening starts. Larger = tighter to edges.
uniform float extent : hint_range(0.2, 1.5) = 0.82;
// Horizontal stretch, so a wide viewport doesn't get a circular mask.
uniform float aspect_bias : hint_range(0.5, 1.5) = 1.08;

void fragment() {
	vec2 centred = (UV - vec2(0.5)) * vec2(aspect_bias, 1.0);
	float dist = length(centred);
	// edge0 > edge1 on purpose: 1 at the centre falling to 0 at `extent`.
	float falloff = smoothstep(extent, extent * 0.35, dist);
	COLOR = vec4(vec3(0.0), (1.0 - falloff) * strength);
}

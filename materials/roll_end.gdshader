shader_type spatial;
render_mode diffuse_burley;

// The flat ends of a bolt of cloth (MaterialRoll): the cloth wound round the cardboard
// core, seen edge-on. UV is the disc's own plane in metres, centred on the axis, so the
// rings are sized in real millimetres whatever the bolt's girth.
//
// One spiral groove per turn rather than concentric circles (it IS one long strip), a
// faint angular wobble so no two turns are evenly spaced, and a little darkening towards
// the outside where the layers pack looser. Grooves fade out once they get finer than a
// pixel, so a far bolt reads as a soft, lightly banded end instead of shimmering.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
// The pattern's accent, caught as short broken flecks along some turns (0 for solid
// cloth); flecks, not whole rings, or a striped cloth's end turns into a target.
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float pattern_mix = 0.0;
// Metres: the cardboard tube's outside, and this bolt's outside.
uniform float core_r = 0.035;
uniform float outer_r = 0.13;
// Radius of the tube's hole; inside it the end reads as the dark hollow of the core.
uniform float hole_r = 0.031;
uniform vec4 hole_color : source_color = vec4(0.10, 0.075, 0.05, 1.0);
// Metres of radius per turn: one groove every ring_spacing.
uniform float ring_spacing = 0.004;
// How dark a groove gets (0 = none). Kept modest so it reads as layers, not a target.
uniform float groove_depth = 0.28;
// Groove width as a fraction of a turn.
uniform float groove_width = 0.22;
// Turns drift by this fraction of a turn around the circle (uneven winding).
uniform float wobble = 0.35;
// Darkening from the core to the outside of the bolt.
uniform float outer_darken = 0.18;
// Faint grey lift on each layer's face, so a near-black cloth still shows its turns
// (multiplying a groove into black changes nothing).
uniform float face_lift = 0.02;
// Fine per-turn brightness scatter.
uniform float turn_variation = 0.08;

float _hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float _vnoise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(_hash(i), _hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

float _hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Periodic value noise round the circle: `a` in turns (0..1), `cells` per turn.
float _ring_noise(float a, float cells, float seed) {
	float x = a * cells;
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float h0 = _hash2(vec2(mod(i, cells), seed));
	float h1 = _hash2(vec2(mod(i + 1.0, cells), seed));
	return mix(h0, h1, f);
}

void fragment() {
	float rad = length(UV);
	float ang = atan(UV.y, UV.x) / TAU + 0.5;  // 0..1 round the end

	// Radial position in turns from the core, bent by the spiral and the wobble.
	float wob = (_ring_noise(ang, 7.0, 1.0) - 0.5) * 0.7 + (_ring_noise(ang, 19.0, 2.0) - 0.5) * 0.3;
	float turns = (rad - core_r) / ring_spacing + ang + wob * wobble;
	float t = fract(turns);
	// Per-layer shade from the radius alone: the spiral's seam (where the angle wraps)
	// must not show as a step.
	float layer = (rad - core_r) / ring_spacing + wob * wobble;

	// Anti-aliased groove: a soft notch at each turn boundary, faded out as the turns
	// get finer than about two pixels.
	float fw = max(fwidth(rad) / ring_spacing, 1e-4);
	float edge = abs(t - 0.5) * 2.0;  // 1 at a groove, 0 mid-layer
	float half_w = max(groove_width, fw * 1.5);
	float groove = smoothstep(1.0 - half_w - fw, 1.0 - half_w * 0.3, edge);
	groove *= 1.0 - smoothstep(0.35, 0.7, fw);

	vec3 col = cloth_color.rgb;
	float fleck = smoothstep(0.62, 0.8, _ring_noise(ang, 31.0, floor(layer)));
	fleck *= smoothstep(0.4, 0.7, _vnoise1(layer * 0.9 + 11.0)) * (1.0 - groove);
	col = mix(col, pattern_color.rgb, pattern_mix * fleck);
	col *= 1.0 + (_vnoise1(layer * 1.3) - 0.5) * turn_variation;
	float out_t = clamp((rad - core_r) / max(outer_r - core_r, 1e-3), 0.0, 1.0);
	col *= 1.0 - outer_darken * out_t * out_t;
	col *= 1.0 - groove_depth * groove;
	col += face_lift * (1.0 - groove) * (1.0 - smoothstep(0.35, 0.7, fw));

	float in_hole = 1.0 - smoothstep(hole_r - 0.0008, hole_r + 0.0008, rad);
	col = mix(col, hole_color.rgb, in_hole);

	ALBEDO = col;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}

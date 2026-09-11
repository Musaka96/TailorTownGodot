shader_type spatial;
render_mode cull_back, diffuse_burley;

// Matte patchy ground: two greens blended by noise so the floor reads as uneven turf, with
// an optional base texture on top. Everything is matte (no specular) to match the shop.

uniform vec4 color_a : source_color = vec4(0.34, 0.55, 0.20, 1.0);  // lighter patches
uniform vec4 color_b : source_color = vec4(0.20, 0.38, 0.14, 1.0);  // darker ground
uniform sampler2D base_texture : source_color, hint_default_white;
uniform bool use_texture = false;
uniform vec2 tiling = vec2(1.0, 1.0);
// Size of the patches (higher = smaller, more frequent patches).
uniform float patch_scale : hint_range(1.0, 64.0, 0.5) = 12.0;
// How much of the lighter colour shows (its "spawn rate"): 0 = all dark, 1 = all light.
uniform float patch_amount : hint_range(0.0, 1.0, 0.01) = 0.5;
// Edge softness between patches.
uniform float patch_softness : hint_range(0.01, 0.5, 0.01) = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float n = vnoise(UV * patch_scale) * 0.65 + vnoise(UV * patch_scale * 2.7) * 0.35;
	float t = smoothstep(
		1.0 - patch_amount - patch_softness, 1.0 - patch_amount + patch_softness, n);
	vec3 col = mix(color_b.rgb, color_a.rgb, t);
	if (use_texture) {
		col *= texture(base_texture, UV * tiling).rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

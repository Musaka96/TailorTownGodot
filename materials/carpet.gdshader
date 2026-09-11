shader_type spatial;
render_mode cull_back, diffuse_burley;

// Carpet — a flat, matte floor covering you drop any texture into to "recreate" that
// carpet. Derived from the grass shader family for TailorTown (the grass shader is
// "Billboard Grass with Wind" by binbun, CC0). This variant drops the billboard/wind and
// tiles a carpet image with a soft woven pile + optional fringe at the edges.

group_uniforms Carpet;
// The carpet's pattern. Leave unset to fall back to a flat colour.
uniform sampler2D carpet_texture : source_color, hint_default_white;
uniform bool use_texture = true;
uniform vec4 tint : source_color = vec4(0.62, 0.20, 0.22, 1.0);  // default: deep red rug
uniform vec2 tiling = vec2(3.0, 3.0);

group_uniforms Pile;
// Fine woven "fuzz" so it doesn't read as flat plastic; scale is in texels of the pattern.
uniform float pile_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float pile_scale : hint_range(4.0, 256.0, 1.0) = 90.0;

group_uniforms Fringe;
// A soft lighter border, like a bound/fringed rug edge. 0 = off.
uniform float fringe_width : hint_range(0.0, 0.2, 0.005) = 0.04;
uniform vec4 fringe_color : source_color = vec4(0.86, 0.80, 0.66, 1.0);

// Cheap value noise for the pile fuzz.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
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
	vec2 uv = UV * tiling;
	vec3 base = tint.rgb;
	if (use_texture) {
		base *= texture(carpet_texture, uv).rgb;
	}

	// Woven pile: two crossed streaks of fuzz that slightly lighten/darken the weave.
	float pile = value_noise(UV * pile_scale) + value_noise(UV * pile_scale * vec2(0.25, 4.0));
	pile = (pile * 0.5 - 0.5) * pile_strength;
	base *= (1.0 + pile);

	// Fringe: a lighter bound border around the rug.
	if (fringe_width > 0.0) {
		vec2 edge = min(UV, 1.0 - UV);
		float m = 1.0 - smoothstep(0.0, fringe_width, min(edge.x, edge.y));
		base = mix(base, fringe_color.rgb, m);
	}

	ALBEDO = base;
	ROUGHNESS = 1.0;  // matte, like the rest of the shop's materials
	SPECULAR = 0.0;
}

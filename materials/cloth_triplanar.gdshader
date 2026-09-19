shader_type spatial;
render_mode diffuse_burley;

// Triplanar 3D cloth: cloth colour x fabric weave x tinted pattern, projected in
// object space from the three axes and blended by the surface normal. No UVs, so
// the fabric never stretches over a hand-unwrapped character mesh. Same tunables
// as cloth.gdshader; `tri_scale` = texture repeats per metre.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
// Second accent (B-channel overcheck) + shot cloth — see cloth.gdshader.
uniform vec4 pattern_color2 : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float shot_strength = 0.0;
// Anisotropic mipmapping — see cloth.gdshader.
uniform sampler2D fabric_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pattern_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fabric_strength = 0.5;
uniform float pattern_strength = 0.85;
uniform float tri_scale = 3.0;
uniform float pattern_scale = 1.0;
uniform float pattern_intensity = 1.0;
uniform float pattern_relief = 0.85;
// Fibre sheen on grazing angles (per fabric, set by ClothMaterial; 0 = off). The engine's
// own rim is shaped by roughness, and ours is pinned at 1.0 for the matte look, which
// would turn RIM into a flat brightening — so the falloff is shaped here instead.
uniform float rim_strength = 0.0;
uniform float rim_power = 3.0;
// 0 = white sheen, 1 = tinted by the cloth colour (dark cloths then barely show it).
uniform float rim_tint = 0.4;
// Baked weave / woven-pattern normal maps + macro breakup — see cloth.gdshader.
// With the weights at power 12 the blend is effectively single-axis, so the
// tangent-space maps are blended plainly like the albedo is.
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pattern_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_depth = 0.0;
uniform float pattern_has_relief = 0.0;
uniform float macro_strength = 0.0;
uniform float macro_scale = 0.35;

varying vec3 tri_pos;
varying vec3 tri_norm;

void vertex() {
	tri_pos = VERTEX;
	tri_norm = NORMAL;
}

vec3 _weights(vec3 n) {
	// High power = pick (almost) only the dominant axis, so directional patterns like
	// pinstripes don't ghost a second, cross-axis set over the fabric.
	vec3 w = pow(abs(n), vec3(12.0));
	return w / max(w.x + w.y + w.z, 0.0001);
}

float _hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float _vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_hashf(i), _hashf(i + vec2(1.0, 0.0)), u.x),
		mix(_hashf(i + vec2(0.0, 1.0)), _hashf(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

vec3 _tri_sample(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y
		+ texture(tex, p.xy).rgb * w.z;
}

void fragment() {
	vec3 p = tri_pos * tri_scale;
	vec3 w = _weights(normalize(tri_norm));

	vec3 grain = mix(vec3(1.0), _tri_sample(fabric_tex, p, w) * 1.75, fabric_strength);

	// R = accent coverage, G = thread relief — see cloth.gdshader.
	vec3 pp = p * pattern_scale;
	vec3 pat = _tri_sample(pattern_tex, pp, w);
	float cover = clamp(pat.r * pattern_strength * pattern_intensity, 0.0, 1.0);
	float cover2 = clamp(pat.b * pattern_strength * pattern_intensity, 0.0, 1.0);

	vec3 col = mix(cloth_color.rgb, pattern_color.rgb, cover);
	col = mix(col, pattern_color2.rgb, cover2);
	col *= grain;
	col *= mix(1.0, pat.g * 2.0, pattern_relief);
	vec2 mp = tri_pos.xz + vec2(tri_pos.y, -tri_pos.y);
	float macro = _vnoise(mp * macro_scale) * 0.7 + _vnoise(mp * macro_scale * 3.1) * 0.3;
	col *= 1.0 + (macro - 0.5) * macro_strength;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col, pattern_color.rgb, pow(1.0 - facing, 2.0) * shot_strength);

	vec3 fab_n = _tri_sample(fabric_normal, p, w) * 2.0 - 1.0;
	vec3 pat_n = _tri_sample(pattern_normal, pp, w) * 2.0 - 1.0;
	vec3 nrm = mix(fab_n, normalize(vec3(fab_n.xy + pat_n.xy, fab_n.z)), pattern_has_relief);
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth;

	ALBEDO = col;
	ROUGHNESS = 1.0;  // matte
	METALLIC = 0.0;
	SPECULAR = 0.0;  // no specular highlight / reflections
	RIM = rim_strength * pow(1.0 - facing, rim_power);
	RIM_TINT = rim_tint;
}

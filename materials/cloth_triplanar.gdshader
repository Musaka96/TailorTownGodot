shader_type spatial;

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

// --- Cloth Look v3: photo grain + cloth lighting. All defaults = the old look. ---
// grain_tex is a scanned-swatch tile stored as a LINEAR ratio with mean grain_mean;
// colour * grain / grain_mean is the photograph again. It multiplies under the dye on
// top of the procedural weave, so every fabric/pattern/colour combination still works.
uniform sampler2D grain_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grain_strength = 0.0;
uniform float grain_mean = 0.25;
uniform float grain_scale = 1.85;  // grain tiles per fabric tile (9 cm scan / 16.7 cm tile)
uniform float grain_contrast = 1.0;
// Ragged pattern edges: the tile edge is softened over a few texels and the yarn
// (photo grain luma) pushes it in and out, so a houndstooth tooth is not razor-cut.
uniform float pattern_fuzz = 0.0;
// light(): Burley diffuse + the engine rim at the defaults; wrap widens the terminator
// for soft nap, sheen is a Charlie lobe (Filament cloth) for the fuzzy grazing lift,
// aniso a Kajiya-Kay highlight along the warp for mohair and sharkskin.
uniform float wrap = 0.0;
uniform float sheen_strength = 0.0;
uniform float sheen_roughness = 0.75;
uniform float sheen_tint = 0.5;
uniform float aniso = 0.0;
uniform float aniso_shine = 40.0;
uniform float aniso_tint = 0.6;

varying vec3 tri_pos;
varying vec3 tri_norm;
varying vec3 v_tangent;

void vertex() {
	tri_pos = VERTEX;
	tri_norm = NORMAL;
	v_tangent = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
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
	vec3 photo = _tri_sample(grain_tex, p * grain_scale, w);
	float fuzz = (dot(photo, vec3(0.3333)) - grain_mean) / grain_mean;

	// R = accent coverage, G = thread relief — see cloth.gdshader.
	vec3 pp = p * pattern_scale;
	vec3 pat = _tri_sample(pattern_tex, pp, w);
	if (pattern_fuzz > 0.0) {
		vec3 o = vec3(pattern_fuzz * 1.5 / 256.0);
		vec3 soft = (_tri_sample(pattern_tex, pp + o, w) + _tri_sample(pattern_tex, pp - o, w)
			+ _tri_sample(pattern_tex, pp + vec3(o.x, -o.y, o.z), w)
			+ _tri_sample(pattern_tex, pp + vec3(-o.x, o.y, -o.z), w)) * 0.25;
		vec2 edge = soft.rb * (1.0 - soft.rb) * 4.0;
		pat.rb = clamp(soft.rb + fuzz * pattern_fuzz * 0.35 * edge, 0.0, 1.0);
	}
	float cover = clamp(pat.r * pattern_strength * pattern_intensity, 0.0, 1.0);
	float cover2 = clamp(pat.b * pattern_strength * pattern_intensity, 0.0, 1.0);

	vec3 col = mix(cloth_color.rgb, pattern_color.rgb, cover);
	col = mix(col, pattern_color2.rgb, cover2);
	col *= grain;
	col *= mix(vec3(1.0), mix(vec3(grain_mean), photo, grain_contrast) / grain_mean, grain_strength);
	col *= mix(1.0, pat.g * 2.0, pattern_relief);
	vec2 mp = tri_pos.xz + vec2(tri_pos.y, -tri_pos.y);
	float macro = _vnoise(mp * macro_scale) * 0.7 + _vnoise(mp * macro_scale * 3.1) * 0.3;
	col *= 1.0 + (macro - 0.5) * macro_strength;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col, pattern_color.rgb, pow(1.0 - facing, 2.0) * shot_strength);

	vec3 fab_n = _tri_sample(fabric_normal, p, w) * 2.0 - 1.0;
	vec3 grain_n = _tri_sample(grain_normal, p * grain_scale, w) * 2.0 - 1.0;
	fab_n = mix(fab_n, grain_n, grain_strength);
	vec3 pat_n = _tri_sample(pattern_normal, pp, w) * 2.0 - 1.0;
	vec3 nrm = mix(fab_n, normalize(vec3(fab_n.xy + pat_n.xy, fab_n.z)), pattern_has_relief);
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_depth;

	ALBEDO = col;
	ROUGHNESS = 1.0;  // matte
	METALLIC = 0.0;
	SPECULAR = 0.0;  // no specular highlight / reflections
}


float _schlick(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}


// Charlie sheen distribution (Estevez & Kulla), as used by Filament's cloth model.
float _d_charlie(float roughness, float ndoth) {
	float inv_alpha = 1.0 / max(roughness, 0.05);
	float cos2h = ndoth * ndoth;
	float sin2h = max(1.0 - cos2h, 0.0078125);
	return (2.0 + inv_alpha) * pow(sin2h, inv_alpha * 0.5) / (2.0 * PI);
}


void light() {
	float ndotl_raw = dot(NORMAL, LIGHT);
	float ndotl = clamp(ndotl_raw, 0.0, 1.0);
	float ndotv = clamp(dot(NORMAL, VIEW), 0.001, 1.0);
	vec3 h = normalize(VIEW + LIGHT);
	float ndoth = clamp(dot(NORMAL, h), 0.0, 1.0);
	float ldoth = clamp(dot(LIGHT, h), 0.0, 1.0);
	// LIGHT_COLOR carries a PI factor; the engine's BRDFs divide it back out.
	vec3 lit = LIGHT_COLOR * ATTENUATION / PI;

	// Burley, as render_mode diffuse_burley computed it, so wrap = 0 is the old look.
	float fd90_m1 = 2.0 * ldoth * ldoth * ROUGHNESS - 0.5;
	float burley = (1.0 + fd90_m1 * _schlick(ndotv)) * (1.0 + fd90_m1 * _schlick(ndotl)) * ndotl;
	float wrapped = clamp((ndotl_raw + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += mix(burley, wrapped, step(0.001, wrap)) * lit;

	// The engine rim as it behaves at roughness 1: flat falloff, so the fresnel is ours.
	float rim = rim_strength * pow(1.0 - ndotv, rim_power);
	DIFFUSE_LIGHT += rim * mix(vec3(1.0), ALBEDO, rim_tint) * LIGHT_COLOR * ATTENUATION;

	if (sheen_strength > 0.0) {
		float d = _d_charlie(sheen_roughness, ndoth);
		float v = 1.0 / (4.0 * (ndotl + ndotv - ndotl * ndotv));
		vec3 sheen_col = mix(vec3(1.0), ALBEDO, sheen_tint);
		SPECULAR_LIGHT += sheen_strength * d * v * sheen_col * ndotl * lit;
	}
	if (aniso > 0.0) {
		float tdoth = dot(v_tangent, h);
		float spec = pow(sqrt(max(1.0 - tdoth * tdoth, 0.0)), aniso_shine);
		SPECULAR_LIGHT += aniso * spec * mix(vec3(1.0), ALBEDO, aniso_tint) * ndotl * lit;
	}
}

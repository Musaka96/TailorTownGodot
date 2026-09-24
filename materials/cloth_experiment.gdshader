// Experimental cloth shader for scenes/dev/cloth_refs.tscn.
// NOT used by the game. It tests two ideas against the scanned swatch references:
//   1. photo-derived neutral grain (linear ratio, mean grain_mean) multiplied under a flat dye colour,
//      with the procedural pattern coverage layered on top (R accent, B overcheck);
//   2. a cloth lighting model in light(): wrapped diffuse for the nap, a Charlie
//      sheen lobe (Filament / Unreal cloth) for the fuzzy grazing-angle lift, and an
//      optional Kajiya-Kay anisotropic highlight along the warp for mohair and sharkskin.
shader_type spatial;
render_mode cull_back;

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform vec4 pattern_color2 : source_color = vec4(0.7, 0.5, 0.3, 1.0);

// Neutral grain: linear RGB ratio stored with per-channel mean grain_mean, so
// albedo = colour * grain / grain_mean reconstructs the photograph when colour is its mean.
uniform sampler2D grain_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Procedural pattern tile: R = accent coverage, B = overcheck coverage. Blank = solid.
uniform sampler2D pattern_tex : filter_linear_mipmap_anisotropic, repeat_enable;

uniform float grain_scale = 1.0;  // grain tiles per UV unit
uniform float pattern_scale = 1.0;  // pattern tiles per UV unit
uniform float grain_strength = 1.0;  // 0 = flat dye, 1 = full photo grain
uniform float grain_mean = 0.25;  // the grain PNG's stored mean (linear); 1/grain_mean = gain
uniform float grain_contrast = 1.0;  // >1 exaggerates thread contrast
uniform float normal_depth = 1.0;
uniform float pattern_intensity = 1.0;

// Cloth lighting.
uniform float wrap = 0.35;  // diffuse wrap: light bleeds past the terminator on soft nap
uniform float sheen = 0.6;  // Charlie sheen strength (0 = plain lambert)
uniform float sheen_roughness = 0.75;  // 1 = broad fuzz halo, 0.3 = tight satin edge
uniform float sheen_tint = 0.5;  // 0 = white sheen, 1 = sheen in the cloth's own colour
uniform float aniso = 0.0;  // Kajiya-Kay highlight strength along the warp
uniform float aniso_shine = 40.0;  // highlight tightness
uniform float aniso_tint = 0.6;

varying vec3 v_tangent;


void vertex() {
	v_tangent = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
}


vec3 grained(vec3 colour, vec3 grain) {
	vec3 g = mix(vec3(grain_mean), grain, grain_contrast) / grain_mean;
	return colour * mix(vec3(1.0), g, grain_strength);
}


void fragment() {
	vec2 guv = UV * grain_scale;
	vec3 grain = texture(grain_tex, guv).rgb;
	vec3 base = grained(cloth_color.rgb, grain);
	// The accent threads take the same grain as the ground so the pattern reads woven.
	vec3 pat = texture(pattern_tex, UV * pattern_scale).rgb;
	base = mix(base, grained(pattern_color.rgb, grain), pat.r * pattern_intensity);
	base = mix(base, grained(pattern_color2.rgb, grain), pat.b * pattern_intensity);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	NORMAL_MAP = texture(grain_normal, guv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}


// Charlie sheen distribution (Estevez & Kulla), as used by Filament's cloth model.
float d_charlie(float roughness, float ndoth) {
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

	// LIGHT_COLOR carries a PI factor, so every term divides by PI.
	float wrapped = clamp((ndotl_raw + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += wrapped * ATTENUATION * LIGHT_COLOR / PI;

	// Sheen: brightest at grazing angles, where fibres standing off the surface catch
	// the light. Neubelt visibility keeps it from blowing out at the terminator.
	float d = d_charlie(sheen_roughness, ndoth);
	float v = 1.0 / (4.0 * (ndotl + ndotv - ndotl * ndotv));
	vec3 sheen_col = mix(vec3(1.0), ALBEDO, sheen_tint);
	SPECULAR_LIGHT += sheen * d * v * sheen_col * ndotl * ATTENUATION * LIGHT_COLOR / PI;

	// Anisotropic highlight along the warp (v_tangent) for wiry, lustrous yarns.
	if (aniso > 0.0) {
		float tdoth = dot(v_tangent, h);
		float spec = pow(sqrt(max(1.0 - tdoth * tdoth, 0.0)), aniso_shine);
		vec3 aniso_col = mix(vec3(1.0), ALBEDO, aniso_tint);
		SPECULAR_LIGHT += aniso * spec * aniso_col * ndotl * ATTENUATION * LIGHT_COLOR / PI;
	}
}

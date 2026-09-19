shader_type spatial;
render_mode diffuse_burley;

// 3D cloth material, tiled across the mesh UVs. Matte, non-metallic.
//
// The pattern is not an overlay: its accent takes the fabric's grain exactly like the
// ground colour does, and a woven pattern's own thread relief (G channel) shades the
// whole surface. Tint one on top instead and it reads as paint on cloth, not cloth.
// Pattern channels: R = accent coverage, G = thread relief (0.5 neutral),
// B = second-accent (overcheck) coverage — glen check / tattersall are two-colour.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
// Second accent for the B-channel overcheck (set by ClothMaterial, derived from the
// first accent — a glen check's overpane runs in its own colour).
uniform vec4 pattern_color2 : source_color = vec4(0.9, 0.9, 0.9, 1.0);
// Shot cloth: warp and weft read as different colours, so the cloth shifts towards
// the accent at grazing angles. Per pattern (end-on-end, sharkskin); 0 = off.
uniform float shot_strength = 0.0;
// Anisotropic mipmapping: the patterns are fine and high-contrast, so a garment
// seen at an angle turns to moire without it (the .png.import files must keep
// mipmaps/generate=true).
uniform sampler2D fabric_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pattern_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fabric_strength = 0.5;
uniform float pattern_strength = 0.85;
uniform float uv_scale = 2.5;
// Extra density on the pattern only (the weave keeps uv_scale): <1 draws a bolder,
// wider-spaced motif that survives being minified. Set per pattern by ClothMaterial.
uniform float pattern_scale = 1.0;
// Per-pattern tint strength, set by ClothMaterial: a 50%-coverage check like
// houndstooth needs far less than a pinstripe or it swamps the cloth colour.
uniform float pattern_intensity = 1.0;
// How strongly a woven pattern's thread relief shades the cloth.
uniform float pattern_relief = 0.85;
// Fibre sheen on grazing angles (per fabric, set by ClothMaterial; 0 = off). The engine's
// own rim is shaped by roughness, and ours is pinned at 1.0 for the matte look, which
// would turn RIM into a flat brightening — so the falloff is shaped here instead.
uniform float rim_strength = 0.0;
uniform float rim_power = 3.0;
// 0 = white sheen, 1 = tinted by the cloth colour (dark cloths then barely show it).
uniform float rim_tint = 0.4;
// Baked weave normal maps (tools/build_textures.gd <name>_n.png): the thread relief
// shades with the actual light instead of only the baked albedo multiply.
// pattern_has_relief = 1 only for the woven patterns, whose thread normal is blended
// over the ground weave's (UDN); depth 0 = flat (the regression guard).
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pattern_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_depth = 0.0;
uniform float pattern_has_relief = 0.0;
// Very-low-frequency brightness breakup (repeats per metre of cloth), so a suit at
// distance isn't a perfectly flat tint once mipmaps eat the weave.
uniform float macro_strength = 0.0;
uniform float macro_scale = 0.35;

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

void fragment() {
	vec2 uv = UV * uv_scale;
	// RGB, not a scalar: grayscale fabrics multiply as before, tweed's coloured
	// neps re-tint the cloth (they multiply the dye, so they stay harmonious).
	vec3 grain = mix(vec3(1.0), texture(fabric_tex, uv).rgb * 1.75, fabric_strength);

	vec3 pat = texture(pattern_tex, uv * pattern_scale).rgb;
	float cover = clamp(pat.r * pattern_strength * pattern_intensity, 0.0, 1.0);
	float cover2 = clamp(pat.b * pattern_strength * pattern_intensity, 0.0, 1.0);

	vec3 col = mix(cloth_color.rgb, pattern_color.rgb, cover);
	col = mix(col, pattern_color2.rgb, cover2);
	col *= grain;
	col *= mix(1.0, pat.g * 2.0, pattern_relief);
	float macro = _vnoise(UV * macro_scale) * 0.7 + _vnoise(UV * macro_scale * 3.1) * 0.3;
	col *= 1.0 + (macro - 0.5) * macro_strength;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col, pattern_color.rgb, pow(1.0 - facing, 2.0) * shot_strength);

	vec3 fab_n = texture(fabric_normal, uv).rgb * 2.0 - 1.0;
	vec3 pat_n = texture(pattern_normal, uv * pattern_scale).rgb * 2.0 - 1.0;
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

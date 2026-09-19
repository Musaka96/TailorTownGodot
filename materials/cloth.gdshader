shader_type spatial;
render_mode diffuse_burley;

// 3D cloth material, tiled across the mesh UVs. Matte, non-metallic.
//
// The pattern is not an overlay: its accent takes the fabric's grain exactly like the
// ground colour does, and a woven pattern's own thread relief (G channel) shades the
// whole surface. Tint one on top instead and it reads as paint on cloth, not cloth.
// Pattern channels: R = accent coverage, G = thread relief (0.5 neutral).

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
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

void fragment() {
	vec2 uv = UV * uv_scale;
	float weave = texture(fabric_tex, uv).r;
	float grain = mix(1.0, weave * 1.75, fabric_strength);

	vec3 pat = texture(pattern_tex, uv * pattern_scale).rgb;
	float cover = clamp(pat.r * pattern_strength * pattern_intensity, 0.0, 1.0);

	vec3 col = mix(cloth_color.rgb, pattern_color.rgb, cover) * grain;
	col *= mix(1.0, pat.g * 2.0, pattern_relief);

	ALBEDO = col;
	ROUGHNESS = 1.0;  // matte
	METALLIC = 0.0;
	SPECULAR = 0.0;  // no specular highlight / reflections
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	RIM = rim_strength * pow(1.0 - facing, rim_power);
	RIM_TINT = rim_tint;
}

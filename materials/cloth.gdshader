shader_type spatial;
render_mode diffuse_burley;

// 3D cloth material: cloth colour (base) × fabric weave (multiply) × pattern
// (tinted overlay), tiled across the mesh UVs. Matte, non-metallic.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform sampler2D fabric_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D pattern_tex : filter_linear_mipmap, repeat_enable;
uniform float fabric_strength = 0.5;
uniform float pattern_strength = 0.85;
uniform float uv_scale = 2.5;

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 col = cloth_color.rgb;

	float weave = texture(fabric_tex, uv).r;
	col *= mix(1.0, weave * 1.75, fabric_strength);

	vec4 pat = texture(pattern_tex, uv);
	col = mix(col, pattern_color.rgb, pat.a * pattern_strength);

	ALBEDO = col;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}

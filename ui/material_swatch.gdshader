shader_type canvas_item;

// Layered material preview: cloth colour × fabric weave, the pattern woven in (not
// tinted on top — see materials/cloth.gdshader), then a rounded-rectangle mask.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
// Second accent for the B-channel overcheck — kept identical to cloth.gdshader.
uniform vec4 pattern_color2 : source_color = vec4(0.9, 0.9, 0.9, 1.0);
// Mipmapped: the swatch draws a 256px pattern into ~84px, which aliases into
// moire with plain linear filtering.
uniform sampler2D fabric_tex : filter_linear_mipmap;
uniform sampler2D pattern_tex : filter_linear_mipmap;
uniform float fabric_strength = 0.55;
uniform float pattern_strength = 0.85;
uniform float pattern_scale = 1.0;
uniform float pattern_intensity = 1.0;
uniform float pattern_relief = 0.85;
// Scanned-swatch photo grain (Cloth Look v3), the same multiply as cloth.gdshader:
// a linear ratio tile with mean grain_mean, under the dye. 0 = off (the old swatch).
uniform sampler2D grain_tex : filter_linear_mipmap, repeat_enable;
uniform float grain_strength = 0.0;
uniform float grain_mean = 0.25;
uniform float grain_scale = 1.85;
uniform float grain_contrast = 1.0;
uniform vec2 rect_size = vec2(84.0, 84.0);
uniform float corner_radius = 16.0;

void fragment() {
	// Fabric weave modulates the base colour (RGB so tweed's coloured neps show).
	vec3 grain = mix(vec3(1.0), texture(fabric_tex, UV).rgb * 1.75, fabric_strength);

	// Pattern: R = accent coverage, G = thread relief, B = overcheck coverage.
	// Kept identical to cloth.gdshader so the swatch shows the garment's cloth.
	vec3 pat = texture(pattern_tex, UV * pattern_scale).rgb;
	float cover = clamp(pat.r * pattern_strength * pattern_intensity, 0.0, 1.0);
	float cover2 = clamp(pat.b * pattern_strength * pattern_intensity, 0.0, 1.0);

	vec3 col = mix(cloth_color.rgb, pattern_color.rgb, cover);
	col = mix(col, pattern_color2.rgb, cover2);
	col *= grain;
	vec3 photo = texture(grain_tex, UV * grain_scale).rgb;
	col *= mix(vec3(1.0), mix(vec3(grain_mean), photo, grain_contrast) / grain_mean, grain_strength);
	col *= mix(1.0, pat.g * 2.0, pattern_relief);

	// Rounded-rectangle mask (signed distance) with 1px anti-aliasing.
	vec2 halfsize = rect_size * 0.5;
	vec2 p = UV * rect_size - halfsize;
	vec2 q = abs(p) - (halfsize - vec2(corner_radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float aa = fwidth(d);
	float mask = 1.0 - smoothstep(-aa, aa, d);

	COLOR = vec4(col, cloth_color.a * mask);
}

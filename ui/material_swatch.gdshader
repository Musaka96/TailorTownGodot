shader_type canvas_item;

// Layered material preview: cloth colour × fabric weave, the pattern woven in (not
// tinted on top — see materials/cloth.gdshader), then a rounded-rectangle mask.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
// Mipmapped: the swatch draws a 256px pattern into ~84px, which aliases into
// moire with plain linear filtering.
uniform sampler2D fabric_tex : filter_linear_mipmap;
uniform sampler2D pattern_tex : filter_linear_mipmap;
uniform float fabric_strength = 0.55;
uniform float pattern_strength = 0.85;
uniform float pattern_scale = 1.0;
uniform float pattern_intensity = 1.0;
uniform float pattern_relief = 0.85;
uniform vec2 rect_size = vec2(84.0, 84.0);
uniform float corner_radius = 16.0;

void fragment() {
	// Fabric weave modulates the base colour (grayscale texture, ~0.5 neutral).
	float weave = texture(fabric_tex, UV).r;
	float grain = mix(1.0, weave * 1.75, fabric_strength);

	// Pattern: R = accent coverage, G = thread relief. Kept identical to
	// cloth.gdshader so the swatch shows the cloth the garment will be made of.
	vec3 pat = texture(pattern_tex, UV * pattern_scale).rgb;
	float cover = clamp(pat.r * pattern_strength * pattern_intensity, 0.0, 1.0);

	vec3 col = mix(cloth_color.rgb, pattern_color.rgb, cover) * grain;
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

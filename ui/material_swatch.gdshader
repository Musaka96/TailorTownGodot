shader_type canvas_item;

// Layered material preview: cloth colour (bottom) → fabric weave (multiply) →
// pattern (tinted overlay) → rounded-rectangle mask.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform sampler2D fabric_tex : filter_linear;
uniform sampler2D pattern_tex : filter_linear;
uniform float fabric_strength = 0.55;
uniform float pattern_strength = 0.85;
uniform vec2 rect_size = vec2(84.0, 84.0);
uniform float corner_radius = 16.0;

void fragment() {
	vec3 col = cloth_color.rgb;

	// Fabric weave modulates the base colour (grayscale texture, ~0.5 neutral).
	float weave = texture(fabric_tex, UV).r;
	col *= mix(1.0, weave * 1.75, fabric_strength);

	// Pattern tints on top using its alpha as coverage.
	vec4 pat = texture(pattern_tex, UV);
	col = mix(col, pattern_color.rgb, pat.a * pattern_strength);

	// Rounded-rectangle mask (signed distance) with 1px anti-aliasing.
	vec2 halfsize = rect_size * 0.5;
	vec2 p = UV * rect_size - halfsize;
	vec2 q = abs(p) - (halfsize - vec2(corner_radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float aa = fwidth(d);
	float mask = 1.0 - smoothstep(-aa, aa, d);

	COLOR = vec4(col, cloth_color.a * mask);
}

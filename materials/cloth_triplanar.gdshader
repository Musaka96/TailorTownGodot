shader_type spatial;
render_mode diffuse_burley;

// Triplanar 3D cloth: cloth colour x fabric weave x tinted pattern, projected in
// object space from the three axes and blended by the surface normal. No UVs, so
// the fabric never stretches over a hand-unwrapped character mesh. Same tunables
// as cloth.gdshader; `tri_scale` = texture repeats per metre.

uniform vec4 cloth_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform sampler2D fabric_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D pattern_tex : filter_linear_mipmap, repeat_enable;
uniform float fabric_strength = 0.5;
uniform float pattern_strength = 0.85;
uniform float tri_scale = 3.0;

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

void fragment() {
	vec3 p = tri_pos * tri_scale;
	vec3 w = _weights(normalize(tri_norm));

	float weave = texture(fabric_tex, p.zy).r * w.x
		+ texture(fabric_tex, p.xz).r * w.y
		+ texture(fabric_tex, p.xy).r * w.z;

	float pat = texture(pattern_tex, p.zy).a * w.x
		+ texture(pattern_tex, p.xz).a * w.y
		+ texture(pattern_tex, p.xy).a * w.z;

	vec3 col = cloth_color.rgb;
	col *= mix(1.0, weave * 1.75, fabric_strength);
	col = mix(col, pattern_color.rgb, pat * pattern_strength);

	ALBEDO = col;
	ROUGHNESS = 1.0;  // matte
	METALLIC = 0.0;
	SPECULAR = 0.0;  // no specular highlight / reflections
}

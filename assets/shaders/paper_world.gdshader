shader_type spatial;
render_mode cull_back, specular_disabled;

// The world in the characters' paper (PaperWorld, scenes/world/paper_world.gd, swaps it
// onto every opaque world surface at runtime; the owner's pick "G", 2026-09-26).
//
// The original colour (albedo_color x albedo_tex x vertex colour) is kept, softened toward
// one colour per painted region (`flatten`, a mip bias: the texture's detail melts into
// flat sheets), then laid under the paper (paper_world.gdshaderinc). Cloth keeps its printed
// pattern (the player tells a pinstripe from a herringbone by it): pattern_tex's R channel
// at the cloth's own UV scale, in pattern_color, as cloth.gdshader draws it.

#include "res://assets/shaders/face_sdf.gdshaderinc"
#include "res://assets/shaders/paper_mache.gdshaderinc"
#include "res://assets/shaders/paper_world.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform bool use_vertex_color = false;
// mip bias on the painted texture: 0 = as painted, ~5 = its detail gone, flat sheets
uniform float flatten = 2.5;
// the cloth's printed pattern (off when pattern_mix is 0)
uniform sampler2D pattern_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 pattern_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float pattern_uv = 1.0;
uniform float pattern_mix = 0.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV * uv1_scale.xy + uv1_offset.xy;
	vec3 base = albedo_color.rgb * texture(albedo_tex, uv, flatten).rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	if (pattern_mix > 0.0) {
		float cover = clamp(texture(pattern_tex, UV * pattern_uv).r * pattern_mix, 0.0, 1.0);
		base = mix(base, pattern_color.rgb, cover);
	}
	vec3 nrm;
	ALBEDO = paper_world(base, w_pos, w_nrm, NORMAL, VERTEX, nrm);
	NORMAL = nrm;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

shader_type spatial;

// Shoe leather, tiled across the mesh UVs. Unlike cloth this keeps Godot's standard PBR
// lighting (no light()): a soft GGX highlight, optional clearcoat for patent.
//
// grain_tex is a LINEAR ratio tile with mean grain_mean, the same format as the cloth
// grains (tools/cloth_refs/make_leather_grain.py; make_grain.py for scans), so
// leather_color * grain / grain_mean is the leather. The grain also drives roughness:
// the creases (darker grain) go rougher, the high points smoother, the way worn leather
// catches light only on its tops.

uniform vec4 leather_color : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform sampler2D grain_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grain_mean = 0.25;
uniform float grain_scale = 4.0;  // grain tiles per UV unit
uniform float grain_strength = 1.0;
uniform float grain_contrast = 1.0;
uniform float normal_depth = 1.0;
uniform float roughness_base = 0.45;
// How far the grain pushes roughness off roughness_base (creases up, high points down).
uniform float roughness_grain = 0.25;
uniform float specular = 0.5;
// Patent: a hard lacquer coat over the leather (ShoeMaterial.FINISHES).
uniform float clearcoat = 0.0;
uniform float clearcoat_roughness = 0.2;

void fragment() {
	vec2 uv = UV * grain_scale;
	vec3 grain = texture(grain_tex, uv).rgb;
	vec3 ratio = mix(vec3(grain_mean), grain, grain_contrast) / grain_mean;
	ALBEDO = leather_color.rgb * mix(vec3(1.0), ratio, grain_strength);
	float luma = dot(grain, vec3(0.3333));
	ROUGHNESS = clamp(roughness_base - (luma - grain_mean) / grain_mean * roughness_grain, 0.05, 1.0);
	METALLIC = 0.0;
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	NORMAL_MAP = texture(grain_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}

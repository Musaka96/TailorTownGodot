shader_type spatial;
render_mode cull_back, specular_disabled;

// LOOK TEST (2026-09-26): the characters' paper (paper_skin.gdshader) on the world, so a
// room can be compared against the cut-paper characters. tools/shot_paper_world.gd swaps it
// onto every opaque mesh of the shop at runtime; nothing in the game uses it yet.
//
// The original colour (albedo_color x albedo_tex x vertex colour) is kept, optionally
// flattened toward one colour per painted region (`flatten`, a mip bias: the texture's
// detail melts into flat sheets), then laid under the characters' grain and papier-mache
// scan (face_sdf.gdshaderinc, paper_mache.gdshaderinc, the PaperSurface numbers). World
// meshes have no paper-sized UVs, so the paper is projected on the three world planes and
// blended by the normal: `tile` = face units per metre, the same paper as the head at ~5.

#include "res://assets/shaders/face_sdf.gdshaderinc"
#include "res://assets/shaders/paper_mache.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform bool use_vertex_color = false;
// mip bias on the painted texture: 0 = as painted, ~5 = its detail gone, flat sheets
uniform float flatten = 0.0;
// face units per metre (5 = the head's paper at the same size)
uniform float tile = 5.0;
uniform float grain = 0.1;
uniform float seed = 0.0;
// how hard the three projections part at an edge (higher = crisper seam, less smear)
uniform float blend_sharp = 6.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// One projection: the paper at q (face units), its colour and its lit normal (view space).
vec3 paper_plane(vec3 base, vec2 q, float s, vec3 n, vec3 pos, out vec3 nrm) {
	vec3 col = paper_surface(base, q, 1.0, grain, s);
	vec2 grad;
	col = paper_mache(col, q + 7.3 * s, 1.0, grad);
	nrm = paper_normal(n, pos, paper_slope(q, grad), paper_texel(q));
	return col;
}

void fragment() {
	vec2 uv = UV * uv1_scale.xy + uv1_offset.xy;
	vec3 base = albedo_color.rgb * texture(albedo_tex, uv, flatten).rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	vec3 w = pow(abs(normalize(w_nrm)), vec3(blend_sharp));
	w /= max(w.x + w.y + w.z, 1e-5);
	vec3 p = w_pos * tile;
	vec3 nx;
	vec3 ny;
	vec3 nz;
	vec3 cx = paper_plane(base, p.zy, seed, NORMAL, VERTEX, nx);
	vec3 cy = paper_plane(base, p.xz, seed + 1.0, NORMAL, VERTEX, ny);
	vec3 cz = paper_plane(base, p.xy, seed + 2.0, NORMAL, VERTEX, nz);
	ALBEDO = cx * w.x + cy * w.y + cz * w.z;
	NORMAL = normalize(nx * w.x + ny * w.y + nz * w.z);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}


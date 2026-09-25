shader_type spatial;
render_mode cull_back, specular_disabled;

// The head's skin with the cut-paper face (face_paper.gdshaderinc) drawn into it. Lit like
// the rig's flat skin material (matte: roughness 1, no metal, no specular), and the face is
// part of the same surface, so it takes the same light and never floats or z-fights.
//
// The head mesh carries a baked face UV in UV2 (FaceUvBaker): the bounding rect of its flat
// front mapped to 0..1, u right and v down as the camera sees the face; the back of the head
// is pushed far outside that range. The face is laid out in FACE UNITS, the reference head
// disc: `disc_scale` rect widths across, its centre `disc_center_v` of the rect height down
// from the top. Sizes follow the rect width (round pieces stay round on any rect); heights
// follow the rect height relative to `layout_aspect`, the rect the presets were laid out on.

#include "res://assets/shaders/face_paper.gdshaderinc"
#include "res://assets/shaders/paper_mache.gdshaderinc"

uniform vec4 skin_color : source_color = vec4(0.86, 0.72, 0.6, 1.0);
// the skin is paper too, all round the head: the face's grain (paper_surface) at the mesh's
// UV1, `skin_tile` face units per UV unit (tripo heads: ~4, measured on UV1 against the
// face UV), `skin_grain` its contrast (0 = the old flat skin); over it the papier-mache
// surface (paper_mache.gdshaderinc: scan + torn strips, lit through the normal), which the
// face pieces sit on, each one flat sheet (no scan, no strips) a paper's step higher at its
// cut edge (piece_relief)
uniform float skin_tile = 4.0;
uniform float skin_grain = 0.1;
uniform bool face_enabled = false;
// rect width / height
uniform float face_aspect = 0.58;
uniform float layout_aspect = 0.58;
uniform float disc_scale = 2.1;
uniform float disc_center_v = 0.44;
// whole-face nudges (FaceFrame): shift in rect units (x right, y down) and scale about the
// rect centre
uniform vec2 frame_offset = vec2(0.0);
uniform float frame_scale = 1.0;
// paints the face rect as a checkerboard with a red border (projection check)
uniform bool debug_uv = false;

// where the papier-mache strips leave the face sheet for the mesh UV1 (face units from
// the disc centre): |x| from .x to .y, |y| from .z to .w
const vec4 FRONT_EDGE = vec4(0.36, 0.52, 0.5, 0.7);

vec3 debug_rect(vec3 col, vec2 f) {
	if (f.x < 0.0 || f.x > 1.0 || f.y < 0.0 || f.y > 1.0) {
		return col;
	}
	vec2 cell = floor(f * 8.0);
	float chk = mod(cell.x + cell.y, 2.0);
	vec3 c = mix(vec3(0.95, 0.93, 0.85), vec3(0.3, 0.45, 0.75), chk);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y) * face_aspect);
	return edge < 0.025 ? vec3(0.9, 0.1, 0.1) : c;
}

void fragment() {
	vec3 skin = skin_color.rgb;
	vec3 col = paper_surface(skin, UV, skin_tile, skin_grain, 0.0);
	float lift = 0.0;
	// rect units, then face units (disc diameters from the disc centre, y down); one screen
	// pixel in face units is taken outside any branch
	vec2 f = (UV2 - 0.5 - frame_offset) / max(frame_scale, 1e-3) + 0.5;
	float ds = max(disc_scale, 1e-3);
	vec2 p = vec2((f.x - 0.5) / ds, (f.y - disc_center_v) / (ds * max(face_aspect, 1e-3)));
	float px = 0.5 * (fwidth(p.x) + fwidth(p.y));
	if (debug_uv) {
		col = debug_rect(col, f);
	} else if (face_enabled && abs(p.x) < 0.6 && abs(p.y) < 0.6) {
		float stretch = layout_aspect / max(face_aspect, 1e-3);
		col = face_paper(col, skin, skin_grain, p, px, stretch, lift);
	}
	// the scan and the strips stop under the pieces (each piece is one sheet of its own paper,
	// blended out by its coverage, so its edge stays clean; the shadow it casts lies outside
	// it, on the strips), and each piece adds its own step. The head's UV1 is cut
	// into islands across the face, so on the front the strips lie in face units (p, the
	// planar face UV, one sheet) and blend to UV1 round the sides, where p stretches
	float keep = 1.0 - clamp(lift, 0.0, 1.0);
	vec2 q = UV * skin_tile;
	vec2 grad_q;
	vec3 col_q = paper_mache(col, q, keep, grad_q);
	vec2 grad_p;
	vec3 col_p = paper_mache(col, p, keep, grad_p);
	float front = face_enabled && !debug_uv ? 1.0 : 0.0;
	front *= 1.0 - smoothstep(FRONT_EDGE.x, FRONT_EDGE.y, abs(p.x));
	front *= 1.0 - smoothstep(FRONT_EDGE.z, FRONT_EDGE.w, abs(p.y));
	col = mix(col_q, col_p, front);
	// a piece's step fades out once a face unit is under ~50 px (it would only ring the piece)
	float step_on = 1.0 - smoothstep(0.01, 0.02, px);
	float hp = PIECE_LAYER * piece_relief * step_on * lift;
	vec2 dh = mix(paper_slope(q, grad_q), paper_slope(p, grad_p), front);
	dh += vec2(dFdx(hp), dFdy(hp));
	NORMAL = paper_normal(NORMAL, VERTEX, dh, mix(paper_texel(q), paper_texel(p), front));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

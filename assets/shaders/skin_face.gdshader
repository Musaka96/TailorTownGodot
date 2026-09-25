shader_type spatial;
render_mode cull_back, specular_disabled;

// The head's skin with the procedural face drawn into it. Lit like the rig's flat skin
// material (matte: roughness 1, no metal, no specular), and the face is part of the same
// surface, so it takes the same light and never floats or z-fights.
//
// The head mesh carries a baked face UV in UV2 (FaceUvBaker): the bounding rect of its flat
// front mapped to 0..1, u right and v down as the camera sees the face; the back of the head
// is pushed far outside that range. Every element sits in FACE UNITS: `*_pos` is its centre
// (u, v in 0..1 of the rect; eyes and brows give the distance of the left one from the
// midline and a height) and `*_size` the side of its square drawing box as a fraction of the
// face width. Inside the box the element is the same face_sdf drawing the sprite path uses
// (q = -1..1, y up), with its FaceStyle.pack() vectors as plain uniforms (one material per
// rig; FaceStyle.apply_to_material() writes them). Layer order: brows, eyes (with their
// cheek blush under them), nose (and moustache), mouth.

#include "res://assets/shaders/face_sdf.gdshaderinc"

// how far past its box (q units) an element may still draw: presets and expressions nudge
// drawings off the box centre, and nothing gets clipped at the edge the way a sprite would
const float Q_BOUND = 1.8;

uniform vec4 skin_color : source_color = vec4(0.86, 0.72, 0.6, 1.0);
uniform bool face_enabled = false;
// rect width / height, so a circle drawn in face units stays round
uniform float face_aspect = 1.0;
// whole-face nudges (FaceFrame): shift in face units (x right, y down) and scale about the
// rect centre
uniform vec2 frame_offset = vec2(0.0);
uniform float frame_scale = 1.0;
// paints the face rect as a checkerboard with a red border (projection check)
uniform bool debug_uv = false;

group_uniforms eye;
uniform vec2 e_pos = vec2(0.22, 0.42);
uniform float e_size = 0.6;
uniform vec4 e_p0 = vec4(0.0);
uniform vec4 e_p1 = vec4(0.0);
uniform vec4 e_p2 = vec4(0.0);
uniform vec4 e_p3 = vec4(0.0);
uniform vec4 e_p4 = vec4(0.0);
uniform vec4 e_p5 = vec4(0.0);
uniform vec4 e_c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 e_c1 : source_color = vec4(1.0);
uniform vec4 e_c2 : source_color = vec4(1.0);
uniform vec4 e_c3 : source_color = vec4(1.0);
uniform vec4 e_c4 : source_color = vec4(1.0);
uniform vec4 e_c5 : source_color = vec4(1.0);

group_uniforms brow;
uniform vec2 b_pos = vec2(0.2, 0.3);
uniform float b_size = 0.55;
uniform vec4 b_p0 = vec4(0.0);
uniform vec4 b_p1 = vec4(0.0);
uniform vec4 b_p2 = vec4(0.0);
uniform vec4 b_c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);

group_uniforms nose;
uniform vec2 n_pos = vec2(0.5, 0.6);
uniform float n_size = 0.5;
uniform vec4 n_p0 = vec4(0.0);
uniform vec4 n_p1 = vec4(0.0);
uniform vec4 n_p2 = vec4(0.0);
uniform vec4 n_c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 n_c1 : source_color = vec4(1.0);

group_uniforms mouth;
uniform vec2 m_pos = vec2(0.5, 0.78);
uniform float m_size = 0.6;
uniform vec4 m_p0 = vec4(0.0);
uniform vec4 m_p1 = vec4(0.0);
uniform vec4 m_p2 = vec4(0.0);
uniform vec4 m_c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 m_c1 : source_color = vec4(1.0);
uniform vec4 m_c2 : source_color = vec4(1.0);
uniform vec4 m_c3 : source_color = vec4(1.0);
group_uniforms;

// Face uv -> an element's q space (its box -1..1, y up); `mirror` flips x (the right-hand
// eye and brow, whose inner corner is then +x like the left one's).
vec2 el_q(vec2 f, vec2 centre, float side, bool mirror) {
	vec2 d = (f - centre) * vec2(1.0, 1.0 / face_aspect) / max(side, 1e-4);
	return vec2(mirror ? -2.0 * d.x : 2.0 * d.x, -2.0 * d.y);
}

bool el_near(vec2 q) {
	return max(abs(q.x), abs(q.y)) < Q_BOUND;
}

vec3 layer(vec3 col, vec4 el) {
	return mix(col, el.rgb, clamp(el.a, 0.0, 1.0));
}

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
	vec3 col = skin_color.rgb;
	// face units, and one screen pixel in face widths (taken outside any branch)
	vec2 f = (UV2 - 0.5 - frame_offset) / max(frame_scale, 1e-3) + 0.5;
	float fw = 0.5 * (fwidth(f.x) + fwidth(f.y) / face_aspect);
	bool on_face = f.x > -0.5 && f.x < 1.5 && f.y > -0.5 && f.y < 1.5;
	if (debug_uv) {
		col = debug_rect(col, f);
	} else if (face_enabled && on_face) {
		vec2 bl = vec2(0.5 - b_pos.x, b_pos.y);
		vec2 br = vec2(0.5 + b_pos.x, b_pos.y);
		vec2 el = vec2(0.5 - e_pos.x, e_pos.y);
		vec2 er = vec2(0.5 + e_pos.x, e_pos.y);
		float bpx = 2.0 * fw / max(b_size, 1e-4);
		float epx = 2.0 * fw / max(e_size, 1e-4);
		for (int side = 0; side < 2; side++) {
			bool mir = side == 1;
			vec2 q = el_q(f, mir ? br : bl, b_size, mir);
			if (el_near(q)) {
				col = layer(col, face_brow(
					q, bpx, b_p0.xy, b_p0.z, b_p0.w, b_p1.x, b_p1.y, b_p1.z, b_p1.w, b_p2.x,
					b_c0.rgb
				));
			}
		}
		for (int side = 0; side < 2; side++) {
			bool mir = side == 1;
			vec2 q = el_q(f, mir ? er : el, e_size, mir);
			if (el_near(q)) {
				col = layer(col, face_eye(
					q, epx, e_p0.xy, e_p0.zw, e_p1.x, e_p1.y, e_p1.z, mir ? 1.0 : 0.0, e_p2.x,
					e_p2.yz, e_p2.w, e_p3.x, e_p3.y, e_p3.z, e_p3.w, e_p4.x, e_p4.y, e_p4.z,
					e_p4.w, e_p5.xy, e_p5.z, e_p5.w, e_c0.rgb, e_c1.rgb, e_c2.rgb, e_c3.rgb,
					e_c4.rgb, e_c5.rgb
				));
			}
		}
		vec2 qn = el_q(f, n_pos, n_size, false);
		if (el_near(qn)) {
			col = layer(col, face_nose(
				qn, 2.0 * fw / max(n_size, 1e-4), n_p0.xy, int(round(n_p1.x)), n_p0.z, n_p0.w,
				n_p1.y, n_p1.z, n_p1.w, n_p2.x, n_c0.rgb, n_c1.rgb
			));
		}
		vec2 qm = el_q(f, m_pos, m_size, false);
		if (el_near(qm)) {
			col = layer(col, face_mouth(
				qm, 2.0 * fw / max(m_size, 1e-4), m_p0.xy, int(round(m_p1.x)), m_p0.z, m_p0.w,
				m_p1.y, m_p1.z, m_p1.w, m_p2.x, m_p2.y, m_p2.z, m_c0.rgb, m_c1.rgb, m_c2.rgb,
				m_c3.rgb
			));
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

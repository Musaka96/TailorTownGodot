// The cut-paper face (docs/FACE_STYLE_GUIDE.md): the FaceStyle uniforms and face_paper(),
// which lays every piece on the skin in the guide's order (cheeks, eye whites, pupils, lids,
// brows, nose, mouth, teeth, tongue). Each uniform is the FaceStyle field of the same name
// (FaceStyle.apply_to_material() writes them all). Included by skin_face.gdshader (on the
// head) and face_canvas.gdshader (the 2D review sheets).
//
// Units: face units (face_sdf.gdshaderinc), fractions of the reference head disc. Heights
// (`*_height`, cheek_pos.y) are measured from the top of the disc, spacings from the
// midline to the left one's centre; round pieces are sized by their radius.

#include "res://assets/shaders/face_sdf.gdshaderinc"

// the lid piece reaches this far past the eye outline, so it covers the white's edge
const float LID_MARGIN = 0.006;
// the dark crescent along a shut lid, thickest in the middle (guide: 0.035)
const float LID_STRIP = 0.035;
// how deep the mouth curves: sag at the middle = MOUTH_SAG x curve x half-width
const float MOUTH_SAG = 1.4;
// how much deeper a fully open mouth hangs than the smile it opens from, in half-widths
const float MOUTH_DEPTH = 0.9;

group_uniforms eye;
uniform float eye_spacing = 0.23;
uniform float eye_height = 0.49;
uniform float white_radius = 0.15;
uniform float white_aspect = 1.1;
uniform float pupil_radius = 0.095;
uniform float pupil_aspect = 1.0;
uniform float pupil_wedge = 0.0;
uniform float pupil_wedge_dir = 45.0;
uniform bool pupil_wedge_mirror = true;
uniform vec2 pupil_offset = vec2(0.0);
uniform float lid = 0.0;
uniform float lid_curve = 1.0;
group_uniforms brow;
uniform float brow_spacing = 0.24;
uniform float brow_height = 0.22;
uniform float brow_length = 0.24;
uniform float brow_thickness = 0.06;
uniform float brow_angle = 0.0;
uniform float brow_arch = 0.1;
uniform float brow_corner = 1.0;
uniform float brow_taper = 0.0;
group_uniforms nose;
uniform int nose_kind = 0;
uniform vec2 nose_size = vec2(0.08, 0.08);
uniform float nose_height = 0.64;
group_uniforms mouth;
uniform float mouth_height = 0.81;
uniform float mouth_width = 0.2;
uniform float mouth_thickness = 0.022;
uniform float mouth_curve = 0.2;
uniform float mouth_open = 0.0;
uniform float mouth_round = 0.0;
uniform float mouth_teeth = 0.0;
uniform float mouth_tongue = 0.0;
group_uniforms cheek;
uniform float cheek_radius = 0.0;
uniform vec2 cheek_pos = vec2(0.3, 0.7);
group_uniforms;

// A height measured from the disc top -> y from the disc centre. `stretch` scales the layout
// vertically (the head's face rect may be taller or shorter than the reference).
float fp_y(float from_top, float stretch) {
	return (from_top - 0.5) * stretch;
}

// `under` is what the pieces lie on, `skin` the lids' colour (a lid is the sheet paper like
// every piece, in the skin's colour). `lift` gains one per piece layer over p (piece_lift),
// the step the papier-mache normal lights (skin_face.gdshader).
vec3 face_paper(vec3 under, vec3 skin, vec2 p, float px, float stretch, inout float lift) {
	vec3 col = under;
	vec2 sh = p - paper_shadow_offset;
	// cheeks
	if (cheek_radius > 1e-3) {
		float per = 6.283 * cheek_radius;
		float sz = 2.0 * cheek_radius;
		for (int i = 0; i < 2; i++) {
			float s = i == 0 ? -1.0 : 1.0;
			float seed = 1.0 + float(i);
			vec2 c = vec2(s * cheek_pos.x, fp_y(cheek_pos.y, stretch));
			float d = length(p - c) - cheek_radius + paper_cut(p, per, sz, seed);
			float ds = length(sh - c) - cheek_radius + paper_cut(sh, per, sz, seed);
			col = paper_piece(col, d, ds, paper_rose.rgb, p, seed, px);
			lift = piece_lift(lift, d, px);
		}
	}
	// eyes: whites, pupils, lids (with the shut strip), one eye at a time
	bool has_white = white_radius > 1e-3;
	vec2 wr = vec2(white_radius, white_radius * white_aspect);
	vec2 pr = vec2(pupil_radius, pupil_radius * pupil_aspect);
	vec2 outline = has_white ? wr : pr;
	// at least a pixel past the outline, so no sliver of the white's antialiased edge shows
	float lm = max(LID_MARGIN, px);
	vec2 edge = lid_edge(outline, lid, lid_curve, lm);
	float eye_y = fp_y(eye_height, stretch);
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? -1.0 : 1.0;
		vec2 c = vec2(s * eye_spacing, eye_y);
		if (length(p - c) > 1.6 * max(outline.x, outline.y) + 0.05) {
			continue;
		}
		float fi = float(i);
		// the pupil sits inside the white: a pupil pushed past its edge is cut by it
		float d_white = 1e3;
		float d_white_s = 1e3;
		if (has_white) {
			float per = 3.1416 * (wr.x + wr.y);
			float sz = 2.0 * min(wr.x, wr.y);
			d_white = fs_sd_ellipse(p - c, wr) + paper_cut(p, per, sz, 3.0 + fi);
			d_white_s = fs_sd_ellipse(sh - c, wr) + paper_cut(sh, per, sz, 3.0 + fi);
			col = paper_piece(col, d_white, d_white_s, paper_cream.rgb, p, 3.0 + fi, px);
			lift = piece_lift(lift, d_white, px);
		}
		// the wedge opens at pupil_wedge_dir degrees (0 = the viewer's right, 90 = up) on the
		// left eye; the right eye mirrors it, or copies it for a sideways gaze
		float wa = radians(i == 1 && pupil_wedge_mirror ? 180.0 - pupil_wedge_dir : pupil_wedge_dir);
		vec2 wdir = vec2(cos(wa), -sin(wa));
		vec2 pc = c + pupil_offset;
		float per_p = 3.1416 * (pr.x + pr.y);
		float sz_p = 2.0 * min(pr.x, pr.y);
		// the wedge is two straight snips: its edges are cut clean, the round edge by hand
		float cp = paper_cut(p, per_p, sz_p, 5.0 + fi);
		float cps = paper_cut(sh, per_p, sz_p, 5.0 + fi);
		float dp = piece_pupil(p, pc, wdir, pr, pupil_wedge, cp, true);
		float dps = piece_pupil(sh, pc, wdir, pr, pupil_wedge, cps, true);
		dp = max(dp, d_white);
		dps = max(dps, d_white_s);
		col = paper_piece(col, dp, dps, paper_dark.rgb, p, 5.0 + fi, px);
		lift = piece_lift(lift, dp, px);
		if (lid > 0.01) {
			float per_l = 3.1416 * (outline.x + outline.y);
			float sz_l = 2.0 * outline.y;
			// the lid is skin on skin: only its moving lower edge shows a rim and a shadow
			// (on the white and the pupil), so an open or shut eye leaves no ring round it
			float d_out = lid_outline(p, c, outline, lm);
			float d_cut = lid_cut(p, c, outline, edge, lm) + paper_cut(p, per_l, sz_l, 7.0 + fi);
			float d_cut_s = lid_cut(sh, c, outline, edge, lm) + paper_cut(sh, per_l, sz_l, 7.0 + fi);
			float dl = max(d_out, d_cut);
			// (its shadow stays inside the eye, clear of the outline's own antialiased edge)
			float dls = max(d_out + lm + 0.5 * max(paper_shadow_soft, px), d_cut_s);
			col = paper_piece_ex(col, dl, d_cut, dls, skin, paper_grain, p, 0.0, px, 1.0);
			lift = piece_lift(lift, dl, px);
			float shut = smoothstep(0.85, 1.0, lid);
			if (shut > 0.0) {
				float t = max(LID_STRIP, 2.0 * px);
				float per_s = 4.0 * outline.x;
				float dk = piece_lid_strip(p, c, outline, edge, lm, t);
				float dks = piece_lid_strip(sh, c, outline, edge, lm, t);
				dk += paper_cut(p, per_s, t, 9.0 + fi);
				dks += paper_cut(sh, per_s, t, 9.0 + fi);
				vec3 under = col;
				col = mix(under, paper_piece(under, dk, dks, paper_dark.rgb, p, 9.0 + fi, px), shut);
				lift = mix(lift, piece_lift(lift, dk, px), shut);
			}
		}
	}
	// brows
	float ba = radians(brow_angle);
	float per_b = 2.0 * brow_length + 2.0 * brow_thickness;
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? -1.0 : 1.0;
		vec2 c = vec2(s * brow_spacing, fp_y(brow_height, stretch));
		float fi = float(i);
		float bt = brow_thickness;
		float cb = paper_cut(p, per_b, bt, 11.0 + fi);
		float cbs = paper_cut(sh, per_b, bt, 11.0 + fi);
		float d = piece_brow(
			p, c, s, brow_length, bt, ba, brow_arch, brow_corner, brow_taper, cb, false
		);
		float ds = piece_brow(
			sh, c, s, brow_length, bt, ba, brow_arch, brow_corner, brow_taper, cbs, false
		);
		col = paper_piece(col, d, ds, paper_brow.rgb, p, 11.0 + fi, px);
		lift = piece_lift(lift, d, px);
	}
	// nose
	vec2 nc = vec2(0.0, fp_y(nose_height, stretch));
	float per_n = 3.1416 * (nose_size.x + nose_size.y);
	float sz_n = 2.0 * min(nose_size.x, nose_size.y);
	float dn = piece_nose(p, nc, nose_kind, nose_size) + paper_cut(p, per_n, sz_n, 13.0);
	float dns = piece_nose(sh, nc, nose_kind, nose_size) + paper_cut(sh, per_n, sz_n, 13.0);
	col = paper_piece(col, dn, dns, paper_rose.rgb, p, 13.0, px);
	lift = piece_lift(lift, dn, px);
	// mouth: the line; opening, it turns into a dark D hanging from a straight top edge
	// (rounding into an "o" with mouth_round), teeth and tongue on top of it
	vec2 mc = vec2(0.0, fp_y(mouth_height, stretch));
	float hw = 0.5 * mouth_width;
	if (abs(p.x - mc.x) < hw + 0.05 && abs(p.y - mc.y) < mouth_width + 0.1) {
		float mt = max(mouth_thickness, px);
		float sag = MOUTH_SAG * mouth_curve * hw;
		float per_m = 2.0 * mouth_width + 3.0 * mt;
		float dm = piece_mouth_line(p, mc, mouth_width, mt, sag);
		float dms = piece_mouth_line(sh, mc, mouth_width, mt, sag);
		float op = clamp(mouth_open, 0.0, 1.0);
		float rnd = clamp(mouth_round, 0.0, 1.0);
		// the D's top edge runs level with the line's top; shut, it is as deep as the smile
		float y0 = -0.5 * mt;
		float depth = mt + max(sag, 0.0) * (1.0 - op) + op * MOUTH_DEPTH * hw;
		float d_open = 1e3;
		float d_open_s = 1e3;
		float sz_m = mt;
		if (op > 0.001) {
			float top = rnd * 0.8 * depth;
			float rc = 0.5 * mt;
			d_open = piece_mouth_open(p, mc, hw, y0, depth, top, rc);
			d_open_s = piece_mouth_open(sh, mc, hw, y0, depth, top, rc);
			// the line morphs into the D over the first bit of opening
			float k = smoothstep(0.0, 0.12, op);
			dm = mix(dm, d_open, k);
			dms = mix(dms, d_open_s, k);
			sz_m = mix(mt, min(2.0 * depth, mouth_width), k);
		}
		dm += paper_cut(p, per_m, sz_m, 14.0);
		dms += paper_cut(sh, per_m, sz_m, 14.0);
		col = paper_piece(col, dm, dms, paper_dark.rgb, p, 14.0, px);
		lift = piece_lift(lift, dm, px);
		if (op > 0.01) {
			float inset = 0.35 * mt;
			if (mouth_teeth > 0.01) {
				float band = max(0.36 * depth, 0.9 * mt) * clamp(mouth_teeth, 0.0, 1.0);
				float dt = piece_teeth(p, mc, y0, band, d_open, inset);
				float dts = piece_teeth(sh, mc, y0, band, d_open_s, inset);
				dt += paper_cut(p, 2.0 * mouth_width, band, 15.0);
				dts += paper_cut(sh, 2.0 * mouth_width, band, 15.0);
				col = paper_piece(col, dt, dts, paper_cream.rgb, p, 15.0, px);
				lift = piece_lift(lift, dt, px);
			}
			// the tongue: a rose half-disc at the bottom once the mouth is well open
			float tg = max(mouth_tongue, smoothstep(0.6, 0.75, op) * (1.0 - rnd));
			if (tg > 0.01) {
				float tr = 0.5 * hw * clamp(tg, 0.0, 1.0);
				vec2 tc = mc + vec2(0.0, y0 + depth);
				float dg = max(length(p - tc) - tr, d_open + inset);
				float dgs = max(length(sh - tc) - tr, d_open_s + inset);
				dg += paper_cut(p, 6.283 * tr, tr, 16.0);
				dgs += paper_cut(sh, 6.283 * tr, tr, 16.0);
				col = paper_piece(col, dg, dgs, paper_rose.rgb, p, 16.0, px);
				lift = piece_lift(lift, dg, px);
			}
		}
	}
	return col;
}

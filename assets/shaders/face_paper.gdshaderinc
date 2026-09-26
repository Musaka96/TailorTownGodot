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
// the smiling arc (eye_smile, the "closed arcs" happy eye): the shut crescent flipped into
// an upward arc; x = its middle's height, y = how far its ends drop below the middle, both
// in the lid's half-heights (y down: the middle sits above the eye centre)
const vec2 EYE_SMILE_ARC = vec2(-0.25, 0.6);
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
uniform float eye_smile = 0.0;
uniform float eye_tilt = 0.0;
group_uniforms brow;
uniform float brow_spacing = 0.24;
uniform float brow_height = 0.22;
uniform float brow_length = 0.24;
uniform float brow_thickness = 0.06;
uniform float brow_angle = 0.0;
uniform float brow_arch = 0.1;
uniform float brow_corner = 0.5;
uniform float brow_asym = 0.0;
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
// The catalogue's proposed pieces (2026-09-26, IMPORT/faces_proc/catalogue.png,
// tools/shot_faces.gd -- catalogue): every one off at its default, so no preset changes.
group_uniforms extra;
// E3: the white's bottom cut flat, this fraction of its height away (0.5 = a half disc)
uniform float white_flat = 0.0;
// E4: the white cut as a cream ring this thick (the middle cut out; the pupil sits inside)
uniform float eye_ring = 0.0;
// E6: a dark lash strip this thick along the white's outer upper edge, two ticks
uniform float eye_lash = 0.0;
// E7: a rose crescent strip this thick under each eye (a tired eye bag)
uniform float eye_bag = 0.0;
// E8: a cream speck of this radius on each pupil, up and to the viewer's left
uniform float pupil_glint = 0.0;
// X3: a dark paper ring this thick round the viewer's left eye
uniform float monocle = 0.0;
// X7: two short rose strips this thick at each eye's outer corner (crow's feet)
uniform float eye_crease = 0.0;
// B3: the brow's inner end swells into a round head, 0..1 (the rest stays an even strip)
uniform float brow_comma = 0.0;
// B5: one strip across both brows
uniform bool brow_join = false;
// N1: a cream disc of this radius on the nose, a little above its centre
uniform float nose_button = 0.0;
// N6: two dark nostril discs of this radius at the nose's bottom
uniform float nose_nostrils = 0.0;
// M1: the mouth as a dark ring of this outer radius (mouth_thickness thick)
uniform float mouth_ring = 0.0;
// M3: the mouth sheared, the viewer's right corner up by this x its distance from the middle
uniform float mouth_skew = 0.0;
// M4: the mouth as a pursed heart this half-wide
uniform float mouth_heart = 0.0;
// M5: two cream front teeth this far below the shut mouth line
uniform float mouth_buck = 0.0;
// M6: a rose lip strip round the dark mouth, this much wider on every side
uniform float mouth_lips = 0.0;
// X1: freckles, specks of this radius (the brow paper) round each cheek position
uniform float freckles = 0.0;
// X2: a dark beauty mark of this radius at beauty_pos (x from the midline, from the top)
uniform float beauty_mark = 0.0;
uniform vec2 beauty_pos = vec2(0.15, 0.75);
// X5: moustache, 0 none, 1 one thick strip, 2 a two-piece chevron (brow paper); size =
// (half-width, thickness), its centre moustache_height from the top
uniform int moustache = 0;
uniform vec2 moustache_size = vec2(0.13, 0.04);
uniform float moustache_height = 0.76;
// X6: a chin patch (brow paper) this half-wide and half-tall, centred beard_height down
uniform vec2 beard = vec2(0.0);
uniform float beard_height = 0.92;
group_uniforms;

// freckle specks round a cheek position (x outward), their radii x freckles
const vec3 FRECKLE_DOTS[5] = vec3[5](
	vec3(-0.045, -0.025, 1.0), vec3(-0.005, -0.045, 0.8), vec3(0.035, -0.02, 1.1),
	vec3(-0.02, 0.01, 0.85), vec3(0.025, 0.025, 0.95)
);

// A height measured from the disc top -> y from the disc centre (face units both).
float fp_y(float from_top) {
	return from_top - 0.5;
}

// Add one piece of sheet paper at p: `d` its distance, `w` how much of it is there (a piece
// fading in). `lift` gains its layer (piece_lift), `sheet` its cover (the piece's own paper
// lies on top here, not the skin's surface).
void fp_layer(float d, float px, float w, inout float lift, inout float sheet) {
	float c = w * piece_lift(0.0, d, px);
	lift += c;
	sheet = max(sheet, c);
}

// Lay one catalogue piece on col: d, ds its distances at p and at the shadow sample BEFORE
// the hand cut; cut = (perimeter, smaller size, seed) for paper_cut.
vec3 fp_cut_piece(
	vec3 col, float d, float ds, vec3 fill, vec2 p, vec2 sh, vec3 cut, float px,
	inout float lift, inout float sheet
) {
	d += paper_cut(p, cut.x, cut.y, cut.z);
	ds += paper_cut(sh, cut.x, cut.y, cut.z);
	fp_layer(d, px, 1.0, lift, sheet);
	return paper_piece(col, d, ds, fill, p, cut.z, px);
}

// The white's outline (E3: its bottom cut flat by white_flat), e from the eye centre.
float fp_white(vec2 e, vec2 wr) {
	float d = fs_sd_ellipse(e, wr);
	if (white_flat > 1e-3) {
		float flat_y = wr.y * (1.0 - 2.0 * white_flat);
		d = fs_round_max(d, e.y - flat_y, 0.25 * wr.x);
	}
	return d;
}

// `under` is the skin the pieces lie on, and also the lids: a lid is the skin itself, a layer
// higher (its fill is `under` at p, no sheet paper, no grain, no rim). `lift` gains one per
// piece layer over p (piece_lift), the step the papier-mache normal lights; `sheet` is how
// much of a piece's own sheet paper is on top (0 = the skin's surface, a lid's included:
// the head's papier-mache carries on over it); `still` is where the steps under a lid must
// not light (its body, away from its lower edge), so only that edge shows a step
// (skin_face.gdshader).
vec3 face_paper(
	vec3 under, vec2 p, float px, inout float lift, inout float sheet,
	inout float still
) {
	vec3 col = under;
	vec2 sh = p - paper_shadow_offset;
	// cheeks
	if (cheek_radius > 1e-3) {
		float per = 6.283 * cheek_radius;
		float sz = 2.0 * cheek_radius;
		for (int i = 0; i < 2; i++) {
			float s = i == 0 ? -1.0 : 1.0;
			float seed = 1.0 + float(i);
			vec2 c = vec2(s * cheek_pos.x, fp_y(cheek_pos.y));
			float d = length(p - c) - cheek_radius + paper_cut(p, per, sz, seed);
			float ds = length(sh - c) - cheek_radius + paper_cut(sh, per, sz, seed);
			col = paper_piece(col, d, ds, paper_rose.rgb, p, seed, px);
			fp_layer(d, px, 1.0, lift, sheet);
		}
	}
	// X1 freckles (brow paper specks round each cheek position), X2 a beauty mark
	if (freckles > 1e-3) {
		for (int i = 0; i < 2; i++) {
			float s = i == 0 ? -1.0 : 1.0;
			vec2 cc = vec2(s * cheek_pos.x, fp_y(cheek_pos.y));
			if (length(p - cc) > 0.1) {
				continue;
			}
			for (int k = 0; k < 5; k++) {
				vec3 f = FRECKLE_DOTS[k];
				// the right cheek's specks are the left's turned over, so the two never mirror
				vec2 fc = cc + (i == 0 ? vec2(-f.x, f.y) : vec2(f.x, -f.y));
				float r = freckles * f.z;
				vec3 cut = vec3(6.283 * r, 2.0 * r, 20.0 + float(i * 5 + k));
				float d = length(p - fc) - r;
				float ds = length(sh - fc) - r;
				col = fp_cut_piece(col, d, ds, paper_brow.rgb, p, sh, cut, px, lift, sheet);
			}
		}
	}
	if (beauty_mark > 1e-3) {
		vec2 bc = vec2(beauty_pos.x, fp_y(beauty_pos.y));
		float r = beauty_mark;
		vec3 cut = vec3(6.283 * r, 2.0 * r, 30.0);
		float d = length(p - bc) - r;
		col = fp_cut_piece(col, d, length(sh - bc) - r, paper_dark.rgb, p, sh, cut, px, lift, sheet);
	}
	// eyes: whites, pupils, lids (with the shut strip), one eye at a time
	bool has_white = white_radius > 1e-3;
	vec2 wr = vec2(white_radius, white_radius * white_aspect);
	vec2 pr = vec2(pupil_radius, pupil_radius * pupil_aspect);
	vec2 outline = has_white ? wr : pr;
	// at least a pixel past the outline, so no sliver of the white's antialiased edge shows
	float lm = max(LID_MARGIN, px);
	vec2 edge = lid_edge(outline, lid, lid_curve, lm);
	bool has_lid = lid > 0.01;
	float eye_y = fp_y(eye_height);
	// the lash, bag, crease and monocle reach past the eye
	float eye_reach = eye_lash + eye_bag + monocle + eye_crease > 0.0 ? 0.1 : 0.0;
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? -1.0 : 1.0;
		vec2 c = vec2(s * eye_spacing, eye_y);
		if (length(p - c) > 1.6 * max(outline.x, outline.y) + 0.05 + eye_reach) {
			continue;
		}
		float fi = float(i);
		// the eye's own frame: eye_tilt turns the whole eye about its centre, outer corner up
		// (pe, se: p and its shadow sample in that frame; the fills stay at p)
		float ta = -s * radians(eye_tilt);
		mat2 untilt = mat2(vec2(cos(ta), -sin(ta)), vec2(sin(ta), cos(ta)));
		vec2 pe = c + untilt * (p - c);
		vec2 se = c + untilt * (sh - c);
		// the lid's lower edge (< 0 above it, where the lid covers the eye)
		float d_cut = 1e3;
		float d_cut_s = 1e3;
		if (has_lid) {
			float per_l = 3.1416 * (outline.x + outline.y);
			float sz_l = 2.0 * outline.y;
			d_cut = lid_cut(pe, c, outline, edge, lm) + paper_cut(pe, per_l, sz_l, 7.0 + fi);
			d_cut_s = lid_cut(se, c, outline, edge, lm) + paper_cut(se, per_l, sz_l, 7.0 + fi);
		}
		// E7 the eye bag and X7 the crow's feet lie on the skin, under the white (eo, eos:
		// the eye's frame with +x outward)
		vec2 eo = vec2(s * (pe.x - c.x), pe.y - c.y);
		vec2 eos = vec2(s * (se.x - c.x), se.y - c.y);
		if (eye_bag > 1e-3) {
			vec2 rb = outline + vec2(-0.01, 0.012) + 0.5 * eye_bag;
			vec2 a = radians(vec2(-140.0, -40.0));
			float d = piece_arc_strip(eo, rb, a.x, a.y, eye_bag);
			float ds = piece_arc_strip(eos, rb, a.x, a.y, eye_bag);
			vec3 cut = vec3(3.0 * rb.x, eye_bag, 31.0 + fi);
			col = fp_cut_piece(col, d, ds, paper_rose.rgb, p, sh, cut, px, lift, sheet);
		}
		if (eye_crease > 1e-3) {
			float d = piece_crease(eo, outline, eye_crease);
			float ds = piece_crease(eos, outline, eye_crease);
			vec3 cut = vec3(0.12, eye_crease, 33.0 + fi);
			col = fp_cut_piece(col, d, ds, paper_rose.rgb, p, sh, cut, px, lift, sheet);
		}
		// the pupil sits inside the white: a pupil pushed past its edge is cut by it
		float d_white = 1e3;
		float d_white_s = 1e3;
		if (has_white) {
			float per = 3.1416 * (wr.x + wr.y);
			float sz = 2.0 * min(wr.x, wr.y);
			d_white = fp_white(pe - c, wr) + paper_cut(pe, per, sz, 3.0 + fi);
			d_white_s = fp_white(se - c, wr) + paper_cut(se, per, sz, 3.0 + fi);
			// E4: the white cut as a ring, its middle cut out (the pupil is still cut by the
			// ring's outer edge)
			float dw = d_white;
			float dws = d_white_s;
			if (eye_ring > 1e-3) {
				dw = abs(dw + 0.5 * eye_ring) - 0.5 * eye_ring;
				dws = abs(dws + 0.5 * eye_ring) - 0.5 * eye_ring;
			}
			// only the white below the lid's edge throws a shadow on the skin round it (a shut
			// eye leaves none peeking past the lid)
			float d_vis_s = max(dws, -d_cut_s);
			col = paper_piece(col, dw, d_vis_s, paper_cream.rgb, p, 3.0 + fi, px);
			fp_layer(dw, px, 1.0, lift, sheet);
		}
		// the wedge opens at pupil_wedge_dir degrees (0 = the viewer's right, 90 = up) on the
		// left eye; the right eye mirrors it, or copies it for a sideways gaze
		float wa = radians(i == 1 && pupil_wedge_mirror ? 180.0 - pupil_wedge_dir : pupil_wedge_dir);
		vec2 wdir = vec2(cos(wa), -sin(wa));
		vec2 pc = c + pupil_offset;
		float per_p = 3.1416 * (pr.x + pr.y);
		float sz_p = 2.0 * min(pr.x, pr.y);
		// the wedge is two straight snips: its edges are cut clean, the round edge by hand
		float cp = paper_cut(pe, per_p, sz_p, 5.0 + fi);
		float cps = paper_cut(se, per_p, sz_p, 5.0 + fi);
		float dp = piece_pupil(pe, pc, wdir, pr, pupil_wedge, cp, true);
		float dps = piece_pupil(se, pc, wdir, pr, pupil_wedge, cps, true);
		// (a dot eye has no white to cut it: the pupil is the whole eye)
		if (has_white) {
			dp = max(dp, d_white);
			dps = max(dps, d_white_s);
		}
		col = paper_piece(col, dp, dps, paper_dark.rgb, p, 5.0 + fi, px);
		fp_layer(dp, px, 1.0, lift, sheet);
		// E8 a cream speck on the pupil, E6 the lash strip (both under the lid, which hides
		// them as it shuts)
		if (pupil_glint > 1e-3) {
			vec2 gc = pc + vec2(-0.38 * pr.x, -0.42 * pr.y);
			float r = pupil_glint;
			float d = length(pe - gc) - r;
			float ds = length(se - gc) - r;
			vec3 cut = vec3(6.283 * r, 2.0 * r, 35.0 + fi);
			col = fp_cut_piece(col, d, ds, paper_cream.rgb, p, sh, cut, px, lift, sheet);
		}
		if (eye_lash > 1e-3) {
			float d = piece_lash(eo, outline, eye_lash);
			float ds = piece_lash(eos, outline, eye_lash);
			vec3 cut = vec3(0.3, eye_lash, 37.0 + fi);
			col = fp_cut_piece(col, d, ds, paper_dark.rgb, p, sh, cut, px, lift, sheet);
		}
		if (has_lid) {
			// the lid is the skin itself, a layer up: its fill is the skin under the face at p
			// (no sheet paper, grain or rim), and only its moving lower edge shows, by its step
			// (`still` hides the rest of its outline's) and its shadow on the white and the
			// pupil, so an open or shut eye leaves no ring round it
			float d_out = lid_outline(pe, c, outline, lm);
			float dl = max(d_out, d_cut);
			// (its shadow stays inside the eye, clear of the outline's own antialiased edge)
			float dls = max(d_out + lm + 0.5 * max(paper_shadow_soft, px), d_cut_s);
			col = paper_piece_ex(col, dl, -1e3, dls, under, 0.0, p, 0.0, px, 0.0);
			lift += piece_lift(0.0, dl, px);
			sheet *= 1.0 - clamp(0.5 - dl / max(px, 1e-6), 0.0, 1.0);
			float r = piece_ramp(px);
			float body = 1.0 - smoothstep(r, 2.0 * r, d_out);
			float shut = smoothstep(0.85, 1.0, lid);
			// a smiling shut eye shows no lower lid edge at all: only the arc
			float smile = clamp(eye_smile, 0.0, 1.0);
			float calm = smile * shut;
			still = max(still, body * max(smoothstep(r, 2.0 * r, -d_cut), calm));
			if (shut > 0.0) {
				float t = max(LID_STRIP, 2.0 * px);
				float per_s = 4.0 * outline.x;
				// eye_smile flips the crescent into the upward arc, the same strip
				float ry = outline.y + lm;
				vec2 edge_s = mix(edge, ry * vec2(EYE_SMILE_ARC.x, -EYE_SMILE_ARC.y), smile);
				float dk = piece_lid_strip(pe, c, outline, edge_s, lm, t);
				float dks = piece_lid_strip(se, c, outline, edge_s, lm, t);
				dk += paper_cut(pe, per_s, t, 9.0 + fi);
				dks += paper_cut(se, per_s, t, 9.0 + fi);
				vec3 lidded = col;
				col = mix(lidded, paper_piece(lidded, dk, dks, paper_dark.rgb, p, 9.0 + fi, px), shut);
				fp_layer(dk, px, shut, lift, sheet);
			}
		}
		// X3 the monocle: a dark ring round the viewer's left eye, over the lid
		if (monocle > 1e-3 && i == 0) {
			float rm = max(outline.x, outline.y) + 0.03 + 0.5 * monocle;
			float d = abs(length(pe - c) - rm) - 0.5 * monocle;
			float ds = abs(length(se - c) - rm) - 0.5 * monocle;
			vec3 cut = vec3(6.283 * rm, monocle, 39.0);
			col = fp_cut_piece(col, d, ds, paper_dark.rgb, p, sh, cut, px, lift, sheet);
		}
	}
	// brows (B5 brow_join: one strip across both; B3 brow_comma: a round head at the inner
	// end of an otherwise even strip)
	float ba = radians(brow_angle);
	float per_b = 2.0 * brow_length + 2.0 * brow_thickness;
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? -1.0 : 1.0;
		vec2 c = vec2(s * brow_spacing, fp_y(brow_height));
		float fi = float(i);
		float bt = brow_thickness;
		float len = brow_length;
		float arch = brow_arch;
		float a = ba;
		if (brow_join) {
			c.x = 0.0;
			s = 1.0;
			len = 2.0 * brow_spacing + brow_length;
			a = 0.0;
			arch = 0.25 * brow_arch;
		} else if (i == 1 && abs(brow_asym) > 1e-3) {
			// brow_asym turns the viewer's right brow about its outer end (which stays put)
			a = ba + radians(brow_asym);
			vec2 half_len = vec2(0.5 * s * brow_length, 0.5 * brow_length);
			c += half_len * vec2(cos(ba) - cos(a), sin(ba) - sin(a));
		}
		float cb = paper_cut(p, per_b, bt, 11.0 + fi);
		float cbs = paper_cut(sh, per_b, bt, 11.0 + fi);
		float d = piece_brow(p, c, s, len, bt, a, arch, brow_corner, cb, false);
		float ds = piece_brow(sh, c, s, len, bt, a, arch, brow_corner, cbs, false);
		if (brow_comma > 1e-3 && !brow_join) {
			float hr = 0.5 * bt * (1.0 + 0.6 * brow_comma);
			vec2 head = brow_inner_end(len, bt, a, arch, brow_corner);
			head -= vec2(cos(a), -sin(a)) * 0.3 * hr;
			vec2 hc = c + vec2(-s * head.x, head.y);
			d = fs_smin(d, length(p - hc) - hr + cb, 0.01);
			ds = fs_smin(ds, length(sh - hc) - hr + cbs, 0.01);
		}
		col = paper_piece(col, d, ds, paper_brow.rgb, p, 11.0 + fi, px);
		fp_layer(d, px, 1.0, lift, sheet);
		if (brow_join) {
			break;
		}
	}
	// nose
	vec2 nc = vec2(0.0, fp_y(nose_height));
	float per_n = 3.1416 * (nose_size.x + nose_size.y);
	float sz_n = 2.0 * min(nose_size.x, nose_size.y);
	float dn = piece_nose(p, nc, nose_kind, nose_size);
	float dns = piece_nose(sh, nc, nose_kind, nose_size);
	if (nose_kind >= 7) {
		dn = piece_nose_more(p - nc, nose_kind, nose_size);
		dns = piece_nose_more(sh - nc, nose_kind, nose_size);
	}
	dn += paper_cut(p, per_n, sz_n, 13.0);
	dns += paper_cut(sh, per_n, sz_n, 13.0);
	col = paper_piece(col, dn, dns, paper_rose.rgb, p, 13.0, px);
	fp_layer(dn, px, 1.0, lift, sheet);
	// N1 a cream button on the nose, N6 two dark nostrils at its bottom
	if (nose_button > 1e-3) {
		vec2 bc = nc + vec2(0.0, -0.15 * nose_size.y);
		float r = nose_button;
		vec3 cut = vec3(6.283 * r, 2.0 * r, 41.0);
		float d = length(p - bc) - r;
		col = fp_cut_piece(col, d, length(sh - bc) - r, paper_cream.rgb, p, sh, cut, px, lift, sheet);
	}
	if (nose_nostrils > 1e-3) {
		float ny = nose_kind == 0 ? nose_size.x : nose_size.y;
		for (int i = 0; i < 2; i++) {
			vec2 oc = nc + vec2((i == 0 ? -0.45 : 0.45) * nose_size.x, 0.62 * ny);
			float r = nose_nostrils;
			vec3 cut = vec3(6.283 * r, 2.0 * r, 42.0 + float(i));
			float d = length(p - oc) - r;
			float ds = length(sh - oc) - r;
			col = fp_cut_piece(col, d, ds, paper_dark.rgb, p, sh, cut, px, lift, sheet);
		}
	}
	// mouth: the line; opening, it turns into a dark D hanging from a straight top edge
	// (rounding into an "o" with mouth_round), teeth and tongue on top of it
	vec2 mc = vec2(0.0, fp_y(mouth_height));
	float hw = 0.5 * mouth_width;
	float reach = max(max(hw, mouth_ring), mouth_heart) + mouth_lips + 0.05;
	if (abs(p.x - mc.x) < reach && abs(p.y - mc.y) < 2.0 * reach + 0.05) {
		// M3: the whole mouth sheared, the viewer's right corner up (pm, shm: p and its shadow
		// sample in the sheared frame; the fills stay at p)
		vec2 pm = p + vec2(0.0, mouth_skew * (p.x - mc.x));
		vec2 shm = sh + vec2(0.0, mouth_skew * (sh.x - mc.x));
		float mt = max(mouth_thickness, px);
		float sag = MOUTH_SAG * mouth_curve * hw;
		float per_m = 2.0 * mouth_width + 3.0 * mt;
		float dm = piece_mouth_line(pm, mc, mouth_width, mt, sag);
		float dms = piece_mouth_line(shm, mc, mouth_width, mt, sag);
		float sz_m = mt;
		// M1 the ring and M4 the heart take the line's place at rest
		if (mouth_ring > 1e-3) {
			float rr = mouth_ring - 0.5 * mt;
			dm = abs(length(pm - mc) - rr) - 0.5 * mt;
			dms = abs(length(shm - mc) - rr) - 0.5 * mt;
			per_m = 6.283 * mouth_ring;
		} else if (mouth_heart > 1e-3) {
			dm = piece_heart_mouth(pm - mc, mouth_heart);
			dms = piece_heart_mouth(shm - mc, mouth_heart);
			per_m = 7.0 * mouth_heart;
			sz_m = 1.6 * mouth_heart;
		}
		float op = clamp(mouth_open, 0.0, 1.0);
		float rnd = clamp(mouth_round, 0.0, 1.0);
		// the D's top edge runs level with the line's top; shut, it is as deep as the smile
		float y0 = -0.5 * mt;
		float depth = mt + max(sag, 0.0) * (1.0 - op) + op * MOUTH_DEPTH * hw;
		float d_open = 1e3;
		float d_open_s = 1e3;
		if (op > 0.001) {
			float top = rnd * 0.8 * depth;
			float rc = 0.5 * mt;
			d_open = piece_mouth_open(pm, mc, hw, y0, depth, top, rc);
			d_open_s = piece_mouth_open(shm, mc, hw, y0, depth, top, rc);
			// the line morphs into the D over the first bit of opening
			float k = smoothstep(0.0, 0.12, op);
			dm = mix(dm, d_open, k);
			dms = mix(dms, d_open_s, k);
			sz_m = mix(sz_m, min(2.0 * depth, mouth_width), k);
		}
		// M6 the lips: a rose lens under the dark line (piece_lips; round the ring or the
		// heart, and once the mouth opens, the dark piece grown by mouth_lips), with its own
		// cut (an offset of the mouth's own edge reads as an outline)
		if (mouth_lips > 1e-3) {
			vec3 cut = vec3(per_m + 6.283 * mouth_lips, sz_m + 2.0 * mouth_lips, 43.0);
			float d = dm - mouth_lips;
			float ds = dms - mouth_lips;
			if (mouth_ring < 1e-3 && mouth_heart < 1e-3) {
				float k = smoothstep(0.0, 0.12, op);
				d = mix(piece_lips(pm - mc, mouth_width, mt, sag, mouth_lips), d, k);
				ds = mix(piece_lips(shm - mc, mouth_width, mt, sag, mouth_lips), ds, k);
			}
			col = fp_cut_piece(col, d, ds, paper_rose.rgb, p, sh, cut, px, lift, sheet);
		}
		// M5 two buck teeth hanging from under the shut line's middle
		if (mouth_buck > 1e-3 && op < 0.01) {
			float top = 0.5 * sag;
			float d = piece_buck(pm - mc, mouth_width, mt, top, mouth_buck);
			float ds = piece_buck(shm - mc, mouth_width, mt, top, mouth_buck);
			vec3 cut = vec3(0.1, 0.03, 44.0);
			col = fp_cut_piece(col, d, ds, paper_cream.rgb, p, sh, cut, px, lift, sheet);
		}
		dm += paper_cut(p, per_m, sz_m, 14.0);
		dms += paper_cut(sh, per_m, sz_m, 14.0);
		col = paper_piece(col, dm, dms, paper_dark.rgb, p, 14.0, px);
		fp_layer(dm, px, 1.0, lift, sheet);
		if (op > 0.01) {
			float inset = 0.35 * mt;
			if (mouth_teeth > 0.01) {
				float band = max(0.36 * depth, 0.9 * mt) * clamp(mouth_teeth, 0.0, 1.0);
				float dt = piece_teeth(pm, mc, y0, band, d_open, inset);
				float dts = piece_teeth(shm, mc, y0, band, d_open_s, inset);
				dt += paper_cut(p, 2.0 * mouth_width, band, 15.0);
				dts += paper_cut(sh, 2.0 * mouth_width, band, 15.0);
				col = paper_piece(col, dt, dts, paper_cream.rgb, p, 15.0, px);
				fp_layer(dt, px, 1.0, lift, sheet);
			}
			// the tongue: a rose half-disc at the bottom once the mouth is well open
			float tg = max(mouth_tongue, smoothstep(0.6, 0.75, op) * (1.0 - rnd));
			if (tg > 0.01) {
				float tr = 0.5 * hw * clamp(tg, 0.0, 1.0);
				vec2 tc = mc + vec2(0.0, y0 + depth);
				float dg = max(length(pm - tc) - tr, d_open + inset);
				float dgs = max(length(shm - tc) - tr, d_open_s + inset);
				dg += paper_cut(p, 6.283 * tr, tr, 16.0);
				dgs += paper_cut(sh, 6.283 * tr, tr, 16.0);
				col = paper_piece(col, dg, dgs, paper_rose.rgb, p, 16.0, px);
				fp_layer(dg, px, 1.0, lift, sheet);
			}
		}
	}
	// X5 the moustache and X6 the chin patch (brow paper, over the mouth)
	if (moustache > 0) {
		vec2 oc = vec2(0.0, fp_y(moustache_height));
		float d = piece_moustache(p - oc, moustache, moustache_size);
		float ds = piece_moustache(sh - oc, moustache, moustache_size);
		vec3 cut = vec3(4.0 * moustache_size.x, moustache_size.y, 45.0);
		col = fp_cut_piece(col, d, ds, paper_brow.rgb, p, sh, cut, px, lift, sheet);
	}
	if (beard.x > 1e-3) {
		vec2 bc = vec2(0.0, fp_y(beard_height));
		float d = piece_beard(p - bc, beard);
		float ds = piece_beard(sh - bc, beard);
		vec3 cut = vec3(4.0 * (beard.x + beard.y), 2.0 * min(beard.x, beard.y), 46.0);
		col = fp_cut_piece(col, d, ds, paper_brow.rgb, p, sh, cut, px, lift, sheet);
	}
	return col;
}

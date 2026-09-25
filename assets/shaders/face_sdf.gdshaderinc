// Procedural face elements (eye, brow, nose, mouth) drawn from signed distance fields.
// Shared by face_element.gdshader (spatial, on the rig's face sprites) and
// face_element_canvas.gdshader (2D review sheets). Looks are data: see FaceStyle
// (data/scripts/face_style.gd), which packs its fields into the fp0..fp5 / fc0..fc5 vectors
// that face_element() unpacks below.
//
// Space: q is the quad mapped to [-1, 1] with y UP (q = (0,0) is the quad centre). `px` is
// the size of one screen pixel in q units; every edge is softened over about one pixel and
// every stroke is kept at least ~1.3 px wide so thin outlines never break into dashes when
// the face is small on screen.
//
// Mirroring: the other eye/brow is drawn on a horizontally flipped quad (Sprite3D.flip_h,
// or a Control with scale.x = -1), so the whole drawing mirrors for free. Things that must
// NOT mirror (the gaze direction) are flipped back with `mirror`, which also picks the eye
// that winks. In q space the inner corner (toward the nose) is always +x.

float fs_fill(float d, float px) {
	return clamp(0.5 - d / max(px, 1e-5), 0.0, 1.0);
}

vec2 fs_rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

float fs_union(float a, float b) {
	return min(a, b);
}

float fs_subtract(float a, float b) {
	return max(a, -b);
}

// Ellipse distance (Inigo Quilez's gradient-normalised approximation; exact enough for AA).
float fs_sd_ellipse(vec2 p, vec2 r) {
	float k0 = length(p / r);
	float k1 = length(p / (r * r));
	if (k0 < 1e-4) {
		return -min(r.x, r.y);
	}
	return k0 * (k0 - 1.0) / k1;
}

// Ellipse distance by a few Newton steps (Inigo Quilez): unlike fs_sd_ellipse it stays
// true off the curve for very flat ellipses, so an offset (rounding) of one is even.
float fs_sd_ellipse_exact(vec2 p, vec2 ab) {
	p = abs(p);
	vec2 q = ab * (p - ab);
	float w = q.x < q.y ? 1.570796327 : 0.0;
	for (int i = 0; i < 5; i++) {
		vec2 cs = vec2(cos(w), sin(w));
		vec2 u = ab * cs;
		vec2 v = ab * vec2(-cs.y, cs.x);
		w = w + dot(p - u, v) / (dot(p - u, u) + dot(v, v));
	}
	float d = length(p - ab * vec2(cos(w), sin(w)));
	return dot(p / ab, p / ab) > 1.0 ? d : -d;
}

// Distance to segment a-b; y = position along it (0 at a, 1 at b).
vec2 fs_sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
	return vec2(length(pa - ba * h), h);
}

float fs_sd_capsule(vec2 p, vec2 a, vec2 b, float r) {
	return fs_sd_segment(p, a, b).x - r;
}

float fs_dot2(vec2 v) {
	return dot(v, v);
}

// Distance to the quadratic bezier A-B-C (Inigo Quilez); y = curve parameter t in [0, 1].
vec2 fs_sd_bezier(vec2 pos, vec2 A, vec2 B, vec2 C) {
	vec2 a = B - A;
	vec2 b = A - 2.0 * B + C;
	if (dot(b, b) < 1e-7) {
		return fs_sd_segment(pos, A, C);
	}
	vec2 c = a * 2.0;
	vec2 d = A - pos;
	float kk = 1.0 / dot(b, b);
	float kx = kk * dot(a, b);
	float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
	float kz = kk * dot(d, a);
	float p = ky - kx * kx;
	float pcube = p * p * p;
	float q = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
	float h = q * q + 4.0 * pcube;
	float res;
	float tt;
	if (h >= 0.0) {
		h = sqrt(h);
		vec2 x = (vec2(h, -h) - q) / 2.0;
		vec2 uv = sign(x) * pow(abs(x), vec2(1.0 / 3.0));
		tt = clamp(uv.x + uv.y - kx, 0.0, 1.0);
		res = fs_dot2(d + (c + b * tt) * tt);
	} else {
		float z = sqrt(-p);
		float v = acos(clamp(q / (p * z * 2.0), -1.0, 1.0)) / 3.0;
		float m = cos(v);
		float n = sin(v) * 1.732050808;
		vec3 t = clamp(vec3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
		float r1 = fs_dot2(d + (c + b * t.x) * t.x);
		float r2 = fs_dot2(d + (c + b * t.y) * t.y);
		res = r1 < r2 ? r1 : r2;
		tt = r1 < r2 ? t.x : t.y;
	}
	return vec2(sqrt(res), tt);
}

// Stroke of a quadratic bezier with round (semicircle) caps. `taper` 0 = even width; more
// thins the ends a little, `bias` > 0 makes the t = 1 end heavier. House rule: no stroke
// ever ends in a point, so the width anywhere stays at least FS_END_MIN of the middle and
// the cap is the half disc of that end width (t clamps at the ends, so the width is constant
// around the cap).
const float FS_END_MIN = 0.72;

float fs_sd_bezier_stroke(vec2 p, vec2 A, vec2 B, vec2 C, float w, float taper, float bias, float px) {
	vec2 r = fs_sd_bezier(p, A, B, C);
	float s = abs(2.0 * r.y - 1.0);
	float k = mix(1.0, 1.0 - clamp(taper, 0.0, 1.0), s * s) * mix(1.0 - bias, 1.0, r.y);
	float ww = w * max(k, FS_END_MIN);
	return r.x - 0.5 * max(ww, 1.3 * px);
}

// Quadratic bezier through the parabola y = y0 + y1 x + y2 x^2 over [x0, x1] (exact).
vec2 fs_sd_parabola(vec2 p, float y0, float y1, float y2, float x0, float x1) {
	float ya = y0 + y1 * x0 + y2 * x0 * x0;
	float yc = y0 + y1 * x1 + y2 * x1 * x1;
	float slope = y1 + 2.0 * y2 * x0;
	vec2 B = vec2(0.5 * (x0 + x1), ya + slope * 0.5 * (x1 - x0));
	return fs_sd_bezier(p, vec2(x0, ya), B, vec2(x1, yc));
}

// max(a, b) with the convex corner rounded off at radius r (no sharp wedge where two
// edges cut each other).
float fs_intersect_round(float a, float b, float r) {
	vec2 u = max(vec2(r + a, r + b), vec2(0.0));
	return min(-r, max(a, b)) + length(u);
}

// Equilateral triangle, point up, "radius" r (Inigo Quilez).
float fs_sd_triangle(vec2 p, float r) {
	const float k = 1.732050808;
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

// Layer `src` (straight alpha) over `dst`.
vec4 fs_over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 c = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(a, 1e-5);
	return vec4(c, a);
}

// --- Eye ------------------------------------------------------------------------------
// |u| (x / rx) where the curve y = y0 - k u^2 leaves the unit-x ellipse of height ry through
// its top (1 when it stays inside to the side). Bisection; the review sheets and the rig
// only need a few pixels of accuracy.
float fs_crescent_end(float y0, float k, float ry) {
	if (y0 - k < 0.0) {
		return 1.0;
	}
	float lo = 0.0;
	float hi = 1.0;
	for (int i = 0; i < 10; i++) {
		float m = 0.5 * (lo + hi);
		bool inside = y0 - k * m * m <= ry * sqrt(max(1.0 - m * m, 0.0));
		lo = inside ? m : lo;
		hi = inside ? hi : m;
	}
	return lo;
}

// Upper lid: a parabola (sag `lid_arch` x ry) resting at `lid_height` x ry above the eye
// centre that comes down with `openness`; at 0 only its lash line is left, an even arc with
// round ends. A low `lid_height` (0 = cut at the centre) is a heavy lid; the closed line
// then sits lower too. `lid_band` > 0 draws a dark band of that thickness along the lid
// edge, a little wider than the eye with round ends, that stays on as the closed-eye line.
// `squint` pushes a lower lid up; at 1 the eye is the happy crescent, a thick even arc that
// keeps the open lid's shape (a blink only thins it). `lid_angle` > 0 tips the lid down at
// the inner corner (angry), < 0 at the outer (sad). `marks` (0..3) short wrinkle strokes
// about `mark_len` long fan out under the outer corner. `wink` closes the mirrored eye only,
// into an arc over the eye (ends down) that dips at the inner end. `iris_inset` moves the
// iris toward the nose on both eyes. A `blush_r` > 0 disc sits under everything at
// `blush_off` from the eye centre (q units, -x = outward).
vec4 face_eye(
	vec2 q, float px, vec2 center, vec2 radii, float tilt, float top_shade, float wink,
	float mirror, float iris_r, vec2 gaze, float pupil_r, float openness, float squint,
	float lid_angle, float marks, float lid_band, float lid_arch, float lid_height,
	float mark_len, vec2 blush_off, float blush_r, float iris_inset, vec3 line_col,
	vec3 sclera_col, vec3 iris_col, vec3 pupil_col, vec3 mark_col, vec3 blush_col
) {
	float ms = mirror > 0.5 ? -1.0 : 1.0;
	float wk = mirror > 0.5 ? clamp(wink, 0.0, 1.0) : 0.0;
	float op = clamp(openness, 0.0, 1.0) * (1.0 - wk);
	vec2 e = fs_rot(q - center, -tilt);
	float rx = radii.x;
	float ry = radii.y;
	float u = e.x / rx;
	float wmin = 1.3 * px;
	float d_ell = fs_sd_ellipse(e, radii);
	// upper lid
	float closed_h = mix(-0.14, -0.55, clamp(1.0 - lid_height, 0.0, 1.0)) * ry;
	float h = mix(closed_h, lid_height * ry, op);
	// the lid flattens as it closes, so a shut eye is a level line (happy is the squint)
	float lid_k = mix(-0.08, lid_arch, smoothstep(0.0, 0.6, op)) * ry;
	float lid_s = -lid_angle * 0.8 * ry;
	float lid_y = h - lid_k * u * u + lid_s * u;
	float lid_dy = (-2.0 * lid_k * u + lid_s) / rx;
	float d_lid = (e.y - lid_y) / sqrt(1.0 + lid_dy * lid_dy);
	// lower lid (squint)
	float sq = clamp(squint, 0.0, 1.0);
	float lo_h = mix(-1.1 * ry, 0.72 * ry, sq);
	float lo_k = mix(0.2 * ry, lid_k + 0.12 * ry, sq);
	float lo_y = lo_h - lo_k * u * u;
	float lo_dy = -2.0 * lo_k * u / rx;
	float d_lo = (lo_y - e.y) / sqrt(1.0 + lo_dy * lo_dy);
	// where the lids cut the ellipse the corners are rounded off, so no wedge ends in a point
	float rc = max(0.15 * min(rx, ry), px);
	float d_shape = fs_intersect_round(fs_intersect_round(d_ell, d_lid, rc), d_lo, rc);
	// fully squinted the eye becomes the happy crescent: a stroke along the middle of the two
	// open lids, as thick as the gap between them at the centre, stopping at the eye's edge
	// with round caps. Closing only thins it (a crescent that blinks stays a crescent).
	float sq_on = smoothstep(0.55, 1.0, sq);
	if (sq_on > 0.0) {
		float k_open = lid_arch * ry;
		float top = min(lid_height * ry, ry);
		float c_w = max(top - lo_h, 0.12 * ry) * mix(0.4, 1.0, clamp(openness, 0.0, 1.0));
		float c_y = 0.5 * (top + lo_h);
		float c_k = k_open + 0.06 * ry;
		float c_u = fs_crescent_end(c_y, c_k, ry) - 0.36 * c_w / rx;
		c_u = max(c_u, 0.2);
		vec2 cr = fs_sd_parabola(e, c_y, 0.5 * lid_s / rx, -c_k / (rx * rx), -c_u * rx, c_u * rx);
		float d_cres = cr.x - 0.5 * max(c_w, wmin);
		d_shape = mix(d_shape, d_cres, sq_on);
	}
	// the squinted crescent fills in dark
	float w_lo = smoothstep(0.55, 1.0, sq) * ry;
	float d_in = max(d_ell, max(d_lid, d_lo + w_lo));
	// interior: sclera, iris, pupil
	vec2 ic = vec2(gaze.x * ms + iris_inset, gaze.y);
	float d_iris = length(e - ic) - iris_r;
	float d_pupil = length(e - ic) - pupil_r;
	vec3 col = sclera_col;
	col = mix(col, iris_col, fs_fill(d_iris, px));
	col = mix(col, pupil_col, fs_fill(d_pupil, px));
	// flat shade band under the upper edge
	float top_y = min(lid_y, ry * sqrt(max(1.0 - u * u, 0.0)));
	float band = fs_fill(top_y - 0.22 * ry - e.y, px) * clamp(top_shade, 0.0, 1.0);
	col = mix(col, col * vec3(0.84, 0.76, 0.7), band);
	col = mix(line_col, col, fs_fill(d_in, px));
	float fade = mix(smoothstep(0.1, 0.15, op), 1.0, sq_on);
	vec4 res = vec4(col, fs_fill(d_shape, px) * fade);
	// under the eye: the cheek blush (a flat disc), then the wrinkle marks
	vec4 under = vec4(blush_col, 0.0);
	if (blush_r > 1e-4) {
		float d_bl = fs_sd_ellipse(q - center - blush_off, vec2(1.0, 0.88) * blush_r);
		under.a = fs_fill(d_bl, px);
	}
	// wrinkle marks under the outer (-x) corner
	int nm = int(round(clamp(marks, 0.0, 3.0)));
	if (nm > 0 && mark_len > 1e-4) {
		float d_mk = 1e5;
		float mw = max(0.3 * mark_len, wmin);
		for (int i = 0; i < 3; i++) {
			if (i >= nm) {
				break;
			}
			float t = nm > 1 ? float(i) / float(nm - 1) : 0.5;
			float ang = radians(mix(208.0, 238.0, t));
			float ml = mark_len * mix(0.75, 1.3, t);
			vec2 mc = vec2(cos(ang), sin(ang)) * (radii + 1.1 * mark_len);
			vec2 md = vec2(cos(ang - 0.61), sin(ang - 0.61)) * 0.5 * ml;
			vec2 mn = vec2(-md.y, md.x) * 0.25;
			d_mk = min(d_mk, fs_sd_bezier_stroke(e, mc - md, mc + mn, mc + md, mw, 0.0, 0.0, px));
		}
		// below about a pixel of real width they would only smudge the cheek: fade them out
		float mk_on = smoothstep(0.5, 0.9, 0.3 * mark_len / max(px, 1e-5));
		under = fs_over(under, vec4(mark_col, fs_fill(d_mk, px) * mk_on));
	}
	res = fs_over(under, res);
	// the lid line: the lid band when set (always on), else the closing lash line across the
	// full eye width; one even width along the lid curve with round caps at both ends
	bool has_band = lid_band > 1e-4;
	float thin_w = max(min(0.3 * min(rx, ry), 0.1), wmin);
	float line_w = has_band ? max(lid_band, wmin) : thin_w;
	float ext = has_band ? 1.14 : 1.04;
	// squinting hands the line over to the happy crescent (it thins away)
	float keep = 1.0 - smoothstep(0.5, 1.0, sq);
	float lw = line_w * keep;
	float y0 = h + (has_band ? 0.35 * lw : 0.0);
	float y1 = lid_s / rx;
	// a wink shuts into a heavier arc a little wider than the eye (ends down, inner end low)
	lw = mix(lw, max(0.55 * min(rx, ry), wmin), wk);
	ext = mix(ext, 1.3, wk);
	// the caps end where the old hard cut was: the curve stops half a width short of it
	float x_end = max(ext * rx - 0.5 * lw, 0.05 * rx);
	y0 = mix(y0, 0.28 * ry, wk);
	y1 = mix(y1, -0.2, wk);
	float y2 = mix(-lid_k / (rx * rx), -0.62 / x_end, wk);
	vec2 lid_c = fs_sd_parabola(e, y0, y1, y2, -x_end, x_end);
	float d_lash = lid_c.x - 0.5 * lw;
	float lash_a = fs_fill(d_lash, px) * (has_band ? 1.0 : 1.0 - smoothstep(0.12, 0.3, op));
	lash_a *= clamp(keep * 4.0, 0.0, 1.0);
	return fs_over(res, vec4(line_col, lash_a));
}

// --- Brow -----------------------------------------------------------------------------
// An even bezier stroke with round ends: `arch` = sag / length, `angle` tips it (radians,
// + = inner end up), `raise` lifts it. The inner (+x) end is a touch heavier.
vec4 face_brow(
	vec2 q, float px, vec2 center, float len, float thick, float arch, float angle,
	float taper, float raise, float angle_offset, vec3 col
) {
	vec2 p = fs_rot(q - center - vec2(0.0, raise), angle + angle_offset);
	float sag = arch * len;
	p.y += 0.5 * sag;
	vec2 A = vec2(-0.5 * len, 0.0);
	vec2 B = vec2(0.0, 2.0 * sag + 1e-3);
	vec2 C = vec2(0.5 * len, 0.0);
	float d = fs_sd_bezier_stroke(p, A, B, C, thick, taper, 0.2, px);
	return vec4(col, fs_fill(d, px));
}

// --- Nose -----------------------------------------------------------------------------
// kind 0 dot, 1 hook, 2 arc (bottom of the nose), 3 tiny triangle, 4 two nostril dots.
// A moustache (`m_w` full width > 0) hangs `m_gap` below the dot: two even strokes with
// round ends that droop out from a peak under the nose, their tips turning up by `m_curl`.
vec4 face_nose(
	vec2 q, float px, vec2 center, int kind, float size, float thick, float m_w, float m_t,
	float m_curl, float m_gap, vec3 col, vec3 m_col
) {
	vec2 p = q - center;
	float s = size;
	float w = max(thick, 1.3 * px);
	float d;
	if (kind == 1) {
		d = fs_sd_bezier_stroke(p, vec2(-0.05, 0.55) * s, vec2(-0.2, -0.6) * s, vec2(0.4, -0.3) * s, w, 0.25, 0.0, px);
	} else if (kind == 2) {
		d = fs_sd_bezier_stroke(p, vec2(-0.45, 0.08) * s, vec2(0.0, -0.42) * s, vec2(0.45, 0.08) * s, w, 0.25, 0.0, px);
	} else if (kind == 3) {
		d = fs_sd_triangle(p, 0.3 * s) - 0.08 * s;
	} else if (kind == 4) {
		vec2 r = vec2(0.13, 0.1) * s;
		d = fs_union(fs_sd_ellipse(p - vec2(-0.24 * s, 0.0), r), fs_sd_ellipse(p - vec2(0.24 * s, 0.0), r));
	} else {
		d = fs_sd_ellipse(p, vec2(0.36, 0.33) * s);
	}
	vec4 res = vec4(col, fs_fill(d, px));
	if (m_w > 1e-4) {
		float t = max(m_t, 1.3 * px);
		float hm = 0.5 * m_w;
		vec2 m = vec2(abs(p.x), p.y);
		float y0 = -0.33 * s - m_gap - 0.5 * t;
		vec2 m0 = vec2(0.0, y0);
		vec2 m1 = vec2(0.32 * hm, y0 - 0.28 * hm);
		vec2 m2 = vec2(0.68 * hm, y0 - 0.22 * hm);
		// the tip carries on from the lobe and bends up
		vec2 m3 = m2 + normalize(m2 - m1) * 0.2 * hm;
		vec2 m4 = vec2(hm - 0.5 * t, m2.y + m_curl * 0.35 * hm);
		float dm = min(fs_sd_bezier(m, m0, m1, m2).x, fs_sd_bezier(m, m2, m3, m4).x) - 0.5 * t;
		res = fs_over(vec4(m_col, fs_fill(dm, px)), res);
	}
	return res;
}

// --- Mouth ----------------------------------------------------------------------------
// kind 0 simple stroke, 1 cat "w", 2 small "o", 3 wide smile with corner ticks. `curve`
// -1 frown .. 1 smile; `skew` lifts the +x corner (< 0 the other). `open` 0..1 opens the
// line into a mouth, `depth` = how deep a full open goes: an oval on a level mouth, and the
// more it smiles the flatter the top (a D-shaped laugh). Inside it is dark; `tongue` fills
// that fraction of the depth from the bottom with a rounded tongue, and `teeth` lays a white
// band with round ends and two dark dividers under the top edge (the grin).
float fs_mouth_base(float u, int kind, float cs, float hw) {
	if (kind == 1) {
		float v = 2.0 * abs(u) - 1.0;
		return -(0.2 + 0.12 * cs / max(hw, 1e-4)) * hw * (1.0 - v * v) + cs * u * u;
	}
	return cs * u * u;
}

vec4 face_mouth(
	vec2 q, float px, vec2 center, int kind, float width, float thick, float curve, float open,
	float depth, float teeth, float tongue, float skew, vec3 line_col, vec3 inner_col,
	vec3 tongue_col, vec3 teeth_col
) {
	vec2 p = q - center;
	float hw = 0.5 * width;
	// the lopsided smile: a shear, so every kind and the open mouth follow it
	p.y -= clamp(skew, -1.0, 1.0) * 0.5 * p.x;
	float w = max(thick, 1.3 * px);
	float cs = clamp(curve, -1.0, 1.0) * 0.42 * hw;
	float op = clamp(open, 0.0, 1.0);
	float dep = depth * hw;
	if (kind == 2) {
		vec2 r = vec2(hw * (0.28 + 0.14 * op), hw * (0.22 + 0.34 * op));
		float d_o = fs_sd_ellipse(p, r);
		vec3 c = mix(line_col, inner_col, fs_fill(d_o + w, px));
		return vec4(c, fs_fill(d_o, px));
	}
	float d_line;
	if (kind == 1) {
		float lift = cs * 0.5;
		float sagw = -(0.4 + 0.25 * clamp(curve, -1.0, 1.0)) * hw;
		float d1 = fs_sd_bezier_stroke(p, vec2(-hw, lift), vec2(-0.5 * hw, sagw), vec2(0.0, 0.0), w, 0.0, 0.0, px);
		float d2 = fs_sd_bezier_stroke(p, vec2(0.0, 0.0), vec2(0.5 * hw, sagw), vec2(hw, lift), w, 0.0, 0.0, px);
		d_line = fs_union(d1, d2);
	} else {
		d_line = fs_sd_bezier_stroke(p, vec2(-hw, cs), vec2(0.0, -cs), vec2(hw, cs), w, 0.0, 0.0, px);
		if (kind == 3) {
			vec2 n = normalize(vec2(-2.0 * cs, hw));
			float tl = 0.13 * hw;
			vec2 cr = vec2(hw, cs);
			vec2 cl = vec2(-hw, cs);
			vec2 nl = vec2(-n.x, n.y);
			float tick_r = max(0.4 * w, 0.65 * px);
			float tick = fs_union(
				fs_sd_capsule(p, cr - n * tl, cr + n * tl, tick_r),
				fs_sd_capsule(p, cl - nl * tl, cl + nl * tl, tick_r)
			);
			d_line = fs_union(d_line, tick);
		}
	}
	vec4 res = vec4(line_col, fs_fill(d_line, px));
	if (op > 0.01) {
		float u = clamp(p.x / hw, -1.0, 1.0);
		float bu = fs_mouth_base(u, kind == 1 ? 0 : kind, cs, hw);
		float tth = clamp(teeth, 0.0, 1.0);
		// two half ellipses (the top flatter with teeth or a smile) sheared onto the mouth's
		// curve; shrunk by half a stroke and grown back, so the corners are round that much
		float flat_top = max(tth, smoothstep(0.0, 0.35, curve));
		float ry_t = op * dep * mix(0.6, 0.1, flat_top);
		float ry_b = op * dep;
		vec2 pm = vec2(p.x, p.y - bu);
		float rr = 0.5 * w;
		// half a stroke wider than the line, so its round caps are the oval's own corners
		vec2 rad = vec2(hw + rr, pm.y > 0.0 ? ry_t : ry_b);
		float d_m = fs_sd_ellipse_exact(pm, max(rad - rr, vec2(0.02 * hw))) - rr;
		float d_inner = d_m + w;
		vec3 c = inner_col;
		float tg = clamp(tongue, 0.0, 1.0);
		if (tg > 0.01) {
			vec2 tr = vec2(1.3 * hw, ry_b * (0.15 + tg));
			float d_tg = fs_sd_ellipse(p - vec2(0.0, -1.15 * ry_b), tr);
			c = mix(c, tongue_col, fs_fill(d_tg, px));
		}
		if (tth > 0.01) {
			// a round-ended band hugging the top edge, two dark dividers across it
			float bh = mix(0.3, 0.72, tth) * (ry_t + ry_b);
			float xe = max(0.82 * hw - 0.5 * bh, 0.05 * hw);
			float yb = ry_t - 0.5 * bh;
			float d_tb = fs_sd_parabola(p, yb, 0.0, cs / (hw * hw), -xe, xe).x - 0.5 * bh;
			float d_dv = abs(abs(p.x) - 0.3 * hw) - 0.3 * w;
			float band = fs_fill(d_tb, px);
			c = mix(c, teeth_col, band);
			c = mix(c, line_col, band * fs_fill(d_dv, px));
		}
		c = mix(line_col, c, fs_fill(d_inner, px));
		res = fs_over(vec4(c, fs_fill(d_m, px)), res);
	}
	return res;
}

// --- Packed dispatch --------------------------------------------------------------------
// element: 0 eye, 1 brow, 2 nose, 3 mouth. Layout of fp0..fp5 / fc0..fc5 per element is
// documented in FaceStyle.pack() (data/scripts/face_style.gd).
vec4 face_element(
	int el, vec2 q, float px, vec4 a0, vec4 a1, vec4 a2, vec4 a3, vec4 a4, vec4 a5,
	vec4 k0, vec4 k1, vec4 k2, vec4 k3, vec4 k4, vec4 k5
) {
	if (el == 0) {
		return face_eye(
			q, px, a0.xy, a0.zw, a1.x, a1.y, a1.z, a1.w, a2.x, a2.yz, a2.w, a3.x, a3.y, a3.z,
			a3.w, a4.x, a4.y, a4.z, a4.w, a5.xy, a5.z, a5.w, k0.rgb, k1.rgb, k2.rgb, k3.rgb,
			k4.rgb, k5.rgb
		);
	} else if (el == 1) {
		return face_brow(q, px, a0.xy, a0.z, a0.w, a1.x, a1.y, a1.z, a1.w, a2.x, k0.rgb);
	} else if (el == 2) {
		return face_nose(
			q, px, a0.xy, int(round(a1.x)), a0.z, a0.w, a1.y, a1.z, a1.w, a2.x, k0.rgb, k1.rgb
		);
	}
	return face_mouth(
		q, px, a0.xy, int(round(a1.x)), a0.z, a0.w, a1.y, a1.z, a1.w, a2.x, a2.y, a2.z, k0.rgb,
		k1.rgb, k2.rgb, k3.rgb
	);
}

// UV (y down) -> q space and the pixel footprint in q units.
vec2 face_q(vec2 uv) {
	return vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
}

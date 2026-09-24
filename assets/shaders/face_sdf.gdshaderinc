// Procedural face elements (eye, brow, nose, mouth) drawn from signed distance fields.
// Shared by face_element.gdshader (spatial, on the rig's face sprites) and
// face_element_canvas.gdshader (2D review sheets). Looks are data: see FaceStyle
// (data/scripts/face_style.gd), which packs its fields into the fp0..fp6 / fc0..fc4 vectors
// that face_element() unpacks below.
//
// Space: q is the quad mapped to [-1, 1] with y UP (q = (0,0) is the quad centre). `px` is
// the size of one screen pixel in q units; every edge is softened over about one pixel and
// every stroke is kept at least ~1.3 px wide so thin outlines never break into dashes when
// the face is small on screen.
//
// Mirroring: the other eye/brow is drawn on a horizontally flipped quad (Sprite3D.flip_h,
// or a Control with scale.x = -1), so the whole drawing mirrors for free. Things that must
// NOT mirror (gaze direction, the highlight's light side) are flipped back with `mirror`.
// In q space the inner corner (toward the nose) is always +x.

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

// Stroke of a quadratic bezier whose width tapers toward both ends. `taper` 0 = even width,
// 1 = pointed ends; `bias` > 0 makes the t = 1 end heavier.
float fs_sd_bezier_stroke(vec2 p, vec2 A, vec2 B, vec2 C, float w, float taper, float bias, float px) {
	vec2 r = fs_sd_bezier(p, A, B, C);
	float s = abs(2.0 * r.y - 1.0);
	float ww = w * mix(1.0, 1.0 - taper, s * s) * mix(1.0 - bias, 1.0, r.y);
	return r.x - 0.5 * max(ww, 1.3 * px);
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
// Upper lid: a parabola (sag `lid_arch` x ry) resting at `lid_height` x ry above the eye
// centre that comes down with `openness`; at 0 only its lash line is left, a thick arc with
// tapered ends. A low `lid_height` (0 = cut at the centre) is a heavy lid; the closed line
// then sits lower too. `lid_band` > 0 draws a dark band of that thickness along the lid
// edge, a little wider than the eye and tapered, that stays on as the closed-eye line.
// `squint` pushes a lower lid up into an arc (happy crescent). `lid_angle` > 0 tips the lid
// down at the inner corner (angry), < 0 at the outer (sad). `marks` (0..3) short wrinkle
// strokes about `mark_len` long fan out under the outer corner. outline_w, lash and hl_r at
// 0 draw nothing at all (no minimum-width ring, no stray dot).
vec4 face_eye(
	vec2 q, float px, vec2 center, vec2 radii, float tilt, float outline_w, vec3 outline_col,
	vec3 sclera_col, float iris_r, vec3 iris_col, vec2 gaze, float pupil_r, vec3 pupil_col,
	float hl_r, vec2 hl_pos, float hl2_r, vec3 hl_col, float openness, float squint,
	float lid_angle, float top_shade, float lash, float mirror, float lid_band, float lid_arch,
	float lid_height, float marks, float mark_len, vec3 mark_col
) {
	float ms = mirror > 0.5 ? -1.0 : 1.0;
	vec2 e = fs_rot(q - center, -tilt);
	float rx = radii.x;
	float ry = radii.y;
	float u = e.x / rx;
	float wmin = 1.3 * px;
	float ws = outline_w > 1e-4 ? max(outline_w, wmin) : 0.0;
	float wt = max(lash, ws);
	wt = wt > 1e-4 ? max(wt, wmin) : 0.0;
	float d_ell = fs_sd_ellipse(e, radii);
	// upper lid
	float closed_h = mix(-0.14, -0.55, clamp(1.0 - lid_height, 0.0, 1.0)) * ry;
	float h = mix(closed_h, lid_height * ry, openness);
	// the lid flattens as it closes, so a shut eye is a level line (happy is the squint)
	float lid_k = mix(-0.08, lid_arch, smoothstep(0.0, 0.6, openness)) * ry;
	float lid_s = -lid_angle * 0.8 * ry;
	float lid_y = h - lid_k * u * u + lid_s * u;
	float lid_dy = (-2.0 * lid_k * u + lid_s) / rx;
	float d_lid = (e.y - lid_y) / sqrt(1.0 + lid_dy * lid_dy);
	// lower lid (squint)
	float sq = clamp(squint, 0.0, 1.0);
	// squinted, the lower lid follows the upper one so the happy crescent is an even arc
	float lo_h = mix(-1.1 * ry, 0.72 * ry, sq);
	float lo_k = mix(0.2 * ry, lid_k + 0.12 * ry, sq);
	float lo_y = lo_h - lo_k * u * u;
	float lo_dy = -2.0 * lo_k * u / rx;
	float d_lo = (lo_y - e.y) / sqrt(1.0 + lo_dy * lo_dy);
	float d_shape = max(d_ell, max(d_lid, d_lo));
	// the outline is heavier toward the top; the squinted crescent fills in dark
	float off = mix(ws, wt, smoothstep(-0.1, 0.75, e.y / ry));
	float w_lo = ws + smoothstep(0.55, 1.0, sq) * ry;
	float d_in = max(d_ell + off, max(d_lid + wt, d_lo + w_lo));
	// interior: sclera, iris, pupil
	vec2 ic = vec2(gaze.x * ms, gaze.y);
	float d_iris = length(e - ic) - iris_r;
	float d_pupil = length(e - ic) - pupil_r;
	vec3 col = sclera_col;
	col = mix(col, iris_col, fs_fill(d_iris, px));
	col = mix(col, pupil_col, fs_fill(d_pupil, px));
	// flat shade band under the upper edge
	float top_y = min(lid_y, ry * sqrt(max(1.0 - u * u, 0.0)));
	float band = fs_fill(top_y - wt - 0.22 * ry - e.y, px) * clamp(top_shade, 0.0, 1.0);
	col = mix(col, col * vec3(0.84, 0.76, 0.7), band);
	// highlights (always on the same screen side for both eyes)
	vec2 hp = ic + vec2(hl_pos.x * ms, hl_pos.y) * iris_r;
	float hl = hl_r > 0.001 ? fs_fill(length(e - hp) - hl_r * iris_r, px) : 0.0;
	vec2 hp2 = ic + vec2(-hl_pos.x * ms * 0.7, -hl_pos.y * 0.8) * iris_r;
	hl = max(hl, hl2_r > 0.001 ? fs_fill(length(e - hp2) - hl2_r * iris_r, px) : 0.0);
	col = mix(col, hl_col, hl);
	col = mix(outline_col, col, fs_fill(d_in, px));
	float fade = smoothstep(0.1, 0.15, openness);
	vec4 res = vec4(col, fs_fill(d_shape, px) * fade);
	// wrinkle marks under the outer (-x) corner, drawn beneath the eye
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
			d_mk = min(d_mk, fs_sd_bezier_stroke(e, mc - md, mc + mn, mc + md, mw, 0.2, 0.0, px));
		}
		// below about a pixel of real width they would only smudge the cheek: fade them out
		float mk_on = smoothstep(0.5, 0.9, 0.3 * mark_len / max(px, 1e-5));
		res = fs_over(vec4(mark_col, fs_fill(d_mk, px) * mk_on), res);
	}
	// the lid line: the lid band when set (always on), else the closing lash line across the
	// full eye width; tapered at both ends
	bool has_band = lid_band > 1e-4;
	float thin_w = max(min(0.3 * min(rx, ry), 0.1), wmin);
	float line_w = has_band ? max(lid_band, wmin) : max(wt * 1.25, thin_w);
	float ext = has_band ? 1.14 : 1.04;
	float tu = clamp(abs(u) / ext, 0.0, 1.0);
	// the band keeps its width and rounds off at the very ends; the lash line tapers
	float prof = has_band ? sqrt(max(1.0 - pow(tu, 6.0), 0.0)) : pow(max(1.0 - tu * tu, 0.0), 0.6);
	// squinting hands the line over to the happy crescent (it thins away)
	float keep = 1.0 - smoothstep(0.5, 1.0, sq);
	float lw = line_w * prof * keep;
	float d_lash = max(abs(d_lid - (has_band ? 0.35 * lw : 0.0)) - 0.5 * lw, abs(e.x) - ext * rx);
	float lash_a = fs_fill(d_lash, px) * (has_band ? 1.0 : 1.0 - smoothstep(0.12, 0.3, openness));
	lash_a *= clamp(keep * 4.0, 0.0, 1.0);
	return fs_over(res, vec4(outline_col, lash_a));
}

// --- Brow -----------------------------------------------------------------------------
// A tapered bezier: `arch` = sag / length, `angle` tips it (radians, + = inner end up),
// `raise` lifts it. The inner (+x) end is a touch heavier.
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
vec4 face_nose(vec2 q, float px, vec2 center, int kind, float size, float thick, vec3 col) {
	vec2 p = q - center;
	float s = size;
	float w = max(thick, 1.3 * px);
	float d;
	if (kind == 1) {
		d = fs_sd_bezier_stroke(p, vec2(-0.05, 0.55) * s, vec2(-0.2, -0.6) * s, vec2(0.4, -0.3) * s, w, 0.6, 0.0, px);
	} else if (kind == 2) {
		d = fs_sd_bezier_stroke(p, vec2(-0.45, 0.08) * s, vec2(0.0, -0.42) * s, vec2(0.45, 0.08) * s, w, 0.7, 0.0, px);
	} else if (kind == 3) {
		d = fs_sd_triangle(p, 0.3 * s) - 0.08 * s;
	} else if (kind == 4) {
		vec2 r = vec2(0.13, 0.1) * s;
		d = fs_union(fs_sd_ellipse(p - vec2(-0.24 * s, 0.0), r), fs_sd_ellipse(p - vec2(0.24 * s, 0.0), r));
	} else {
		d = fs_sd_ellipse(p, vec2(0.36, 0.33) * s);
	}
	return vec4(col, fs_fill(d, px));
}

// --- Mouth ----------------------------------------------------------------------------
// kind 0 simple stroke, 1 cat "w", 2 small "o", 3 wide smile with corner ticks. `curve`
// -1 frown .. 1 smile. `open` 0..1 opens the line into a mouth (dark inside, a tongue at
// the bottom, `teeth` 0..1 a band under the top edge; without teeth the top edge lifts too,
// so an open mouth is a plain oval). `depth` = how deep a full open goes.
float fs_mouth_base(float u, int kind, float cs, float hw) {
	if (kind == 1) {
		float v = 2.0 * abs(u) - 1.0;
		return -(0.2 + 0.12 * cs / max(hw, 1e-4)) * hw * (1.0 - v * v) + cs * u * u;
	}
	return cs * u * u;
}

vec4 face_mouth(
	vec2 q, float px, vec2 center, int kind, float width, float thick, float curve, float open,
	float depth, float teeth, float tongue, vec3 line_col, vec3 inner_col, vec3 tongue_col,
	vec3 teeth_col
) {
	vec2 p = q - center;
	float hw = 0.5 * width;
	float w = max(thick, 1.3 * px);
	float cs = clamp(curve, -1.0, 1.0) * 0.32 * hw;
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
		float d1 = fs_sd_bezier_stroke(p, vec2(-hw, lift), vec2(-0.5 * hw, sagw), vec2(0.0, 0.0), w, 0.5, 0.0, px);
		float d2 = fs_sd_bezier_stroke(p, vec2(0.0, 0.0), vec2(0.5 * hw, sagw), vec2(hw, lift), w, 0.5, 0.0, px);
		d_line = fs_union(d1, d2);
	} else {
		d_line = fs_sd_bezier_stroke(p, vec2(-hw, cs), vec2(0.0, -cs), vec2(hw, cs), w, 0.2, 0.0, px);
		if (kind == 3) {
			vec2 n = normalize(vec2(-2.0 * cs, hw));
			float tl = 0.13 * hw;
			vec2 cr = vec2(hw, cs);
			vec2 cl = vec2(-hw, cs);
			vec2 nl = vec2(-n.x, n.y);
			float tick = fs_union(
				fs_sd_capsule(p, cr - n * tl, cr + n * tl, 0.4 * w),
				fs_sd_capsule(p, cl - nl * tl, cl + nl * tl, 0.4 * w)
			);
			d_line = fs_union(d_line, tick);
		}
	}
	vec4 res = vec4(line_col, fs_fill(d_line, px));
	if (op > 0.01) {
		float u = clamp(p.x / hw, -1.0, 1.0);
		float bu = fs_mouth_base(u, kind == 1 ? 0 : kind, cs, hw);
		float arc = sqrt(max(1.0 - u * u, 0.0));
		float tth = clamp(teeth, 0.0, 1.0);
		float y_top = bu + op * dep * mix(0.6 * arc, 0.12 * (1.0 - u * u), tth);
		float y_bot = bu - op * dep * arc;
		float d_top = p.y - y_top;
		float d_bot = y_bot - p.y;
		float d_m = max(max(d_top, d_bot) * 0.85, abs(p.x) - hw);
		float d_inner = max(max(d_top + w * 0.8, d_bot + w), abs(p.x) - hw + w);
		vec3 c = inner_col;
		float tg = fs_fill(fs_sd_ellipse(p - vec2(0.0, y_bot + 0.05 * dep), vec2(0.55 * hw, 0.4 * op * dep)), px);
		c = mix(c, tongue_col, tg * clamp(tongue, 0.0, 1.0));
		float th = fs_fill(y_top - 0.22 * op * dep - p.y, px) * tth;
		c = mix(c, teeth_col, th);
		c = mix(line_col, c, fs_fill(d_inner, px));
		res = fs_over(vec4(c, fs_fill(d_m, px)), res);
	}
	return res;
}

// --- Packed dispatch --------------------------------------------------------------------
// element: 0 eye, 1 brow, 2 nose, 3 mouth. Layout of fp0..fp6 / fc0..fc4 per element is
// documented in FaceStyle.pack() (data/scripts/face_style.gd).
vec4 face_element(
	int el, vec2 q, float px, vec4 a0, vec4 a1, vec4 a2, vec4 a3, vec4 a4, vec4 a5, vec4 a6,
	vec4 k0, vec4 k1, vec4 k2, vec4 k3, vec4 k4
) {
	if (el == 0) {
		return face_eye(
			q, px, a0.xy, a0.zw, a1.x, a1.y, k0.rgb, k1.rgb, a2.x, k2.rgb, a2.yz, a2.w, k3.rgb,
			a3.x, a3.yz, a3.w, a5.rgb, a4.x, a4.y, a4.z, a1.w, a1.z, a4.w, a6.x, a6.y, a6.z,
			a6.w, a5.w, k4.rgb
		);
	} else if (el == 1) {
		return face_brow(q, px, a0.xy, a0.z, a0.w, a1.x, a1.y, a1.z, a1.w, a2.x, k0.rgb);
	} else if (el == 2) {
		return face_nose(q, px, a0.xy, int(round(a1.x)), a0.z, a0.w, k0.rgb);
	}
	return face_mouth(
		q, px, a0.xy, int(round(a1.x)), a0.z, a0.w, a1.y, a1.z, a1.w, a2.x, a2.y, k0.rgb,
		k1.rgb, k2.rgb, k3.rgb
	);
}

// UV (y down) -> q space and the pixel footprint in q units.
vec2 face_q(vec2 uv) {
	return vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
}

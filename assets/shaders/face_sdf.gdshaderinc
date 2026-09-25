// Cut-paper face pieces (docs/FACE_STYLE_GUIDE.md): signed distance fields for every piece
// (brow strip, eye white, pupil, lid, nose, mouth, teeth, tongue, cheek) and the paper
// treatment that lays one piece on whatever is below it. Shared by skin_face.gdshader (the
// face in the head material) and face_canvas.gdshader (the 2D review sheets) through
// face_paper.gdshaderinc, which holds the style uniforms and the layer order.
//
// Space: FACE UNITS, the reference head disc. p is measured from the disc centre in disc
// diameters, x right as the viewer sees the face and y DOWN. `px` is one screen pixel in
// the same units. A piece's distance is < 0 inside it.
//
// Paper treatment (guide section 1, the numbers are the uniforms' defaults): the cut edge
// wobbles by `paper_wobble` (low-frequency noise, about six waves round a piece), the edge
// is crisp (antialiased over one pixel), the fill carries fibre grain of `paper_grain`
// contrast fixed in face space, a `paper_rim` wide band of cream shows inside the cut, and
// the piece throws a soft shadow of the dark paper on the layer below, offset down and to
// the character's right (the viewer's left). Treatments finer than a pixel fade out, so at
// the gameplay camera only the shapes are left.

uniform vec4 paper_dark : source_color = vec4(0.227, 0.141, 0.094, 1.0);
uniform vec4 paper_brow : source_color = vec4(0.478, 0.29, 0.165, 1.0);
uniform vec4 paper_cream : source_color = vec4(1.0, 0.957, 0.886, 1.0);
uniform vec4 paper_rose : source_color = vec4(0.851, 0.549, 0.494, 1.0);
uniform vec2 paper_shadow_offset = vec2(-0.004, 0.006);
uniform float paper_shadow_alpha = 0.22;
uniform float paper_shadow_soft = 0.008;
uniform float paper_rim = 0.004;
uniform float paper_rim_alpha = 0.3;
uniform float paper_wobble = 0.003;
uniform float paper_grain = 0.04;

// --- Distance primitives -------------------------------------------------------------

float fs_dot2(vec2 v) {
	return dot(v, v);
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

// Ellipse distance by a few Newton steps (Inigo Quilez): stays true off the curve for very
// flat ellipses, so a flat-topped mouth keeps an even edge.
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

// Distance to the quadratic bezier A-B-C (Inigo Quilez); y = curve parameter t in [0, 1].
vec2 fs_sd_bezier(vec2 pos, vec2 A, vec2 B, vec2 C) {
	vec2 a = B - A;
	vec2 b = A - 2.0 * B + C;
	if (dot(b, b) < 1e-9) {
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

// Distance to the parabola y = y0 + y2 x^2 over [-x1, x1] (a quadratic bezier, exact).
float fs_sd_parabola(vec2 p, float y0, float y2, float x1) {
	float ye = y0 + y2 * x1 * x1;
	vec2 B = vec2(0.0, y0 - y2 * x1 * x1);
	return fs_sd_bezier(p, vec2(-x1, ye), B, vec2(x1, ye)).x;
}

// Two circles joined by their tangents (Inigo Quilez): r1 at the origin, r2 at (0, h),
// in y-UP coordinates.
float fs_sd_uneven_capsule(vec2 p, float r1, float r2, float h) {
	p.x = abs(p.x);
	float b = (r1 - r2) / h;
	float a = sqrt(max(1.0 - b * b, 0.0));
	float k = dot(p, vec2(-b, a));
	if (k < 0.0) {
		return length(p) - r1;
	}
	if (k > a * h) {
		return length(p - vec2(0.0, h)) - r2;
	}
	return dot(p, vec2(a, b)) - r1;
}

// Isosceles trapezoid (Inigo Quilez): half-width r1 at the bottom, r2 at the top, half
// height he, y-UP coordinates.
float fs_sd_trapezoid(vec2 p, float r1, float r2, float he) {
	vec2 k1 = vec2(r2, he);
	vec2 k2 = vec2(r2 - r1, 2.0 * he);
	p.x = abs(p.x);
	vec2 ca = vec2(p.x - min(p.x, (p.y < 0.0) ? r1 : r2), abs(p.y) - he);
	vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / fs_dot2(k2), 0.0, 1.0);
	float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
	return s * sqrt(min(fs_dot2(ca), fs_dot2(cb)));
}

// An infinite pie wedge along +y with half-angle sin/cos `c` (Inigo Quilez, radius r).
float fs_sd_pie(vec2 p, vec2 c, float r) {
	p.x = abs(p.x);
	float l = length(p) - r;
	float m = length(p - c * clamp(dot(p, c), 0.0, r));
	return max(l, m * sign(c.y * p.x - c.x * p.y));
}

// --- Paper ---------------------------------------------------------------------------

float paper_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise, smooth (C1) between lattice points, in 0..1.
float paper_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = paper_hash(i);
	float b = paper_hash(i + vec2(1.0, 0.0));
	float c = paper_hash(i + vec2(0.0, 1.0));
	float d = paper_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// A hand-cut edge: add to a piece's distance. `perimeter` (face units) sets the wave length
// so every piece gets about six waves round its edge; `seed` keeps pieces apart.
float paper_cut(vec2 p, float perimeter, float seed) {
	float cell = max(perimeter / 6.0, 1e-3);
	float n = paper_noise(p / cell + vec2(seed * 7.13, seed * 3.71));
	return paper_wobble * (2.0 * n - 1.0);
}

// Fibre grain, -1..1: two layers of stretched noise at crossing angles (short fibres).
float paper_fibres(vec2 p, float seed) {
	vec2 o = vec2(seed * 17.3, seed * 9.1);
	vec2 a = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * p;
	vec2 b = mat2(vec2(0.5, -0.87), vec2(0.87, 0.5)) * p;
	float n = paper_noise(a * vec2(90.0, 700.0) + o) + paper_noise(b * vec2(110.0, 520.0) - o);
	n += paper_noise(p * 260.0 + o.yx);
	return n / 1.5 - 1.0;
}

// Lay one paper piece on `under`: `d` is the piece's (cut) distance at p, `d_rim` the
// distance to the edges that show a cut rim (usually d), `d_shadow` the distance sampled
// at p - paper_shadow_offset (where its shadow falls), `grain` the fibre contrast.
vec3 paper_piece_ex(
	vec3 under, float d, float d_rim, float d_shadow, vec3 fill, float grain, vec2 p, float seed,
	float px
) {
	float soft = max(paper_shadow_soft, px);
	float sh = 1.0 - smoothstep(-0.5 * soft, 0.5 * soft, d_shadow);
	// an offset under about a pixel would only ring the piece with a dark outline: fade it
	float sh_on = smoothstep(0.35, 1.0, length(paper_shadow_offset) / max(px, 1e-6));
	vec3 col = mix(under, paper_dark.rgb, paper_shadow_alpha * sh_on * sh);
	float cover = clamp(0.5 - d / max(px, 1e-6), 0.0, 1.0);
	if (cover <= 0.0) {
		return col;
	}
	float fine = 1.0 - smoothstep(0.0015, 0.004, px);
	vec3 f = fill * (1.0 + grain * fine * paper_fibres(p, seed));
	float rim_on = smoothstep(0.4, 1.2, paper_rim / max(px, 1e-6));
	float rim = clamp((d_rim + paper_rim) / max(px, 1e-6) + 0.5, 0.0, 1.0);
	f = mix(f, paper_cream.rgb, paper_rim_alpha * rim_on * rim);
	return mix(col, f, cover);
}

// The usual piece: rim along its whole edge, the shared grain.
vec3 paper_piece(vec3 under, float d, float d_shadow, vec3 fill, vec2 p, float seed, float px) {
	return paper_piece_ex(under, d, d, d_shadow, fill, paper_grain, p, seed, px);
}

// --- Pieces (distances, face units, y down) ----------------------------------------------
// `side` is -1 for the eye/brow/cheek on the viewer's left, +1 on the right; inner (toward
// the nose) is -side in x.

// Brow: a thick strip with round ends, `len` long cap to cap. `angle` (radians, > 0 lifts
// the inner end), `arch` = how far the middle rises, as a fraction of half the length.
float piece_brow(vec2 p, vec2 c, float side, float len, float thick, float angle, float arch) {
	vec2 e = p - c;
	e.x *= -side;  // +x = inner end
	float l = max(len - thick, 1e-3);
	vec2 dir = vec2(cos(angle), -sin(angle));
	vec2 n = vec2(-sin(angle), -cos(angle));  // up, square to the strip
	float sag = 0.5 * arch * l;
	vec2 A = -0.5 * l * dir - 0.5 * sag * n;
	vec2 C = 0.5 * l * dir - 0.5 * sag * n;
	vec2 B = 1.5 * sag * n;
	return fs_sd_bezier(e, A, B, C).x - 0.5 * thick;
}

// Pupil: a dark ellipse with an optional 60 degree wedge cut out of it, pointing up and
// inward; `wedge` = how far into the pupil it cuts, as a fraction of the radius.
float piece_pupil(vec2 p, vec2 c, float side, vec2 r, float wedge) {
	vec2 e = p - c;
	float d = fs_sd_ellipse(e, r);
	if (wedge > 0.01) {
		vec2 dir = normalize(vec2(-side, -1.0));
		vec2 apex = dir * min(r.x, r.y) * (1.0 - clamp(wedge, 0.0, 1.0));
		vec2 q = e - apex;
		vec2 w = vec2(dot(q, vec2(-dir.y, dir.x)), dot(q, dir));
		d = max(d, -fs_sd_pie(w, vec2(0.5, 0.866), 4.0 * max(r.x, r.y)));
	}
	return d;
}

// Lid geometry of an eye whose outline (the white, or the pupil of a dot eye) has radii r:
// x = the lower edge's depth at the middle (below the centre, y down), y = how much it rises
// at the sides. `lid` 0 = away above the eye, 1 = the whole eye covered; `curve` 0 = a flat
// edge, 1 = the downward arc (a closing lid always ends as the arc).
vec2 lid_edge(vec2 r, float lid, float curve, float margin) {
	float ry = r.y + margin;
	float k = 0.5 * ry * mix(clamp(curve, 0.0, 1.0), 1.0, smoothstep(0.6, 1.0, lid));
	float y0 = mix(-ry - 0.03, ry, clamp(lid, 0.0, 1.0));
	return vec2(y0, k);
}

// The lid's outline: the eye outline grown by `margin`.
float lid_outline(vec2 p, vec2 c, vec2 r, float margin) {
	return fs_sd_ellipse(p - c, r + margin);
}

// Distance to the lid's lower edge (< 0 above it).
float lid_cut(vec2 p, vec2 c, vec2 r, vec2 edge, float margin) {
	vec2 e = p - c;
	float rx = r.x + margin;
	float u = e.x / rx;
	float y_edge = edge.x - edge.y * u * u;
	float slope = -2.0 * edge.y * u / rx;
	return (e.y - y_edge) / sqrt(1.0 + slope * slope);
}

// The dark strip along a shut lid's lower edge, round ends, the eye's width.
float piece_lid_strip(vec2 p, vec2 c, vec2 r, vec2 edge, float margin, float thick) {
	vec2 e = p - c;
	float rx = r.x + margin;
	float x1 = max(rx - 0.5 * thick, 1e-3);
	return fs_sd_parabola(e, edge.x, -edge.y / (rx * rx), x1) - 0.5 * thick;
}

// Nose: kind 0 disc (radius r.x), 1 oval (radii r), 2 teardrop with its round point up
// (half-width r.x at the bottom, half-height r.y), 3 strip: a tall rounded trapezoid,
// narrow at the top (half-width r.x at the bottom, half-height r.y).
float piece_nose(vec2 p, vec2 c, int kind, vec2 r) {
	vec2 e = p - c;
	vec2 up = vec2(e.x, -e.y);  // y-up for the primitives that want it
	if (kind == 1) {
		return fs_sd_ellipse(e, r);
	} else if (kind == 2) {
		float r1 = r.x;
		float r2 = max(0.4 * r1, 0.01);
		float h = max(2.0 * r.y - r1 - r2, 1e-3);
		return fs_sd_uneven_capsule(up + vec2(0.0, r.y - r1), r1, r2, h);
	} else if (kind == 3) {
		float top = 0.45 * r.x;
		float rr = 0.9 * top;
		return fs_sd_trapezoid(up, r.x - rr, top - rr, max(r.y - rr, 1e-3)) - rr;
	}
	return length(e) - r.x;
}

// The mouth's line y (down) at x: a parabola through the middle, `sag` lower in the middle
// than at the corners (> 0 smiles).
float mouth_base(float x, float hw, float sag) {
	float u = clamp(x / hw, -1.0, 1.0);
	return sag * (0.5 - u * u);
}

// Mouth line: a thin strip along the base curve with round ends, `width` cap to cap.
float piece_mouth_line(vec2 p, vec2 c, float width, float thick, float sag) {
	vec2 e = p - c;
	float hw = 0.5 * width;
	float x1 = max(hw - 0.5 * thick, 1e-3);
	float y2 = -sag / (hw * hw);
	return fs_sd_parabola(e, 0.5 * sag, y2, x1) - 0.5 * thick;
}

// Open mouth: an oval hanging from the base curve, `depth` deep below it and `top` above
// (a thin top is the flat D of a smile; a tall one rounds it into an "o").
float piece_mouth_open(vec2 p, vec2 c, float width, float sag, float depth, float top) {
	vec2 e = p - c;
	float hw = 0.5 * width;
	vec2 pm = vec2(e.x, e.y - mouth_base(e.x, hw, sag));
	vec2 rad = vec2(hw, pm.y < 0.0 ? top : depth);
	return fs_sd_ellipse_exact(pm, max(rad, vec2(1e-3)));
}

// Teeth: a cream band under the top edge of the open mouth, inside it by `inset`.
float piece_teeth(vec2 p, vec2 c, float width, float sag, float band, float d_open, float inset) {
	vec2 e = p - c;
	float hw = 0.5 * width;
	float y = e.y - mouth_base(e.x, hw, sag);
	return max(d_open + inset, y - band);
}

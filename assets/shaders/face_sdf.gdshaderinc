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
// Paper treatment (guide section 1, the numbers are the uniforms' defaults): the cut edge is
// HAND-CUT, `paper_jag` deep on a full-size piece (thin strips get less): straight scissor
// facets (linear value noise, two octaves) with the odd small nick, a different seed per
// piece so no two edges match. An edge that is one real straight snip (the pupil wedge's
// two sides) is cut clean: the primitives take the cut and a per-edge `straight` flag. The
// edge is crisp (antialiased over one pixel), the fill is the owner's sheet paper
// (`piece_tex`, its light and dark `piece_tex_albedo` and its normal `piece_tex_normal`, fixed
// in face space at `piece_tex_tile` tiles per face unit) under a faint procedural grain of
// `paper_grain` contrast (soft mottling, a few specks, long soft fibres; the skin and hair
// carry that grain at 0.1 at their own UV1, paper_surface()), light pieces show a
// `paper_rim` wide band of cream inside the cut, and the
// piece throws a soft shadow of the dark paper on the layer below, offset down and to the
// character's right (the viewer's left). Treatments finer than a pixel fade out, so at the
// gameplay camera only the shapes are left.

uniform vec4 paper_dark : source_color = vec4(0.235, 0.145, 0.082, 1.0);
uniform vec4 paper_brow : source_color = vec4(0.471, 0.29, 0.173, 1.0);
uniform vec4 paper_cream : source_color = vec4(0.937, 0.863, 0.745, 1.0);
uniform vec4 paper_rose : source_color = vec4(0.827, 0.518, 0.392, 1.0);
// the mouth's paper (FaceStyle.mouth_color): the dark paper unless a face wears lipstick
// (the feminine kit, FaceCast); open, a lipstick mouth keeps a dark inside
uniform vec4 paper_mouth : source_color = vec4(0.235, 0.145, 0.082, 1.0);
uniform vec2 paper_shadow_offset = vec2(-0.004, 0.006);
uniform float paper_shadow_alpha = 0.22;
uniform float paper_shadow_soft = 0.008;
uniform float paper_rim = 0.003;
uniform float paper_rim_alpha = 0.25;
uniform float paper_jag = 0.005;
uniform float paper_grain = 0.03;
// the pieces' sheet paper (PaperSurface; unset = plain): its colour (only its light and dark,
// over its own mean) and its OpenGL normal map, `piece_tex_tile` tiles per face unit
uniform sampler2D piece_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D piece_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float piece_tex_tile = 2.0;
// how much of its light and dark shows (0 = none, 1 = as generated)
uniform float piece_tex_albedo = 1.0;
// its normal's slope, x (0 = flat; lit on the head, a fixed raking light on the 2D sheets)
uniform float piece_tex_normal = 1.5;

// the grain's make-up (paper_fibres): mottling amplitude at 60 / 170 / 420 waves per face
// unit; dark specks (amount, smoothstep from, to); fibres: waves per face unit along and
// across a streak, the noise band that draws one, how far a streak bends (face units),
// light and dark streak strength
const vec3 PAPER_MOTTLE = vec3(0.15, 0.35, 0.3);
const vec3 PAPER_SPECK = vec3(0.35, 0.85, 0.99);
const float FIBRE_LONG = 32.0;
const float FIBRE_WIDE = 300.0;
const vec2 FIBRE_EDGE = vec2(0.78, 0.98);
const float FIBRE_BEND = 0.02;
const float FIBRE_LIGHT = 0.3;
const float FIBRE_DARK = 0.25;

// the triangle noses' corners, rounded by this x their smaller half-size: a soft tip, not a
// point (guide: round ends everywhere)
const float NOSE_TRI_ROUND = 0.15;
// a shut lid's crescent at its ends, as a fraction of its middle thickness (round caps)
const float LID_STRIP_END = 0.8;

// the nose shield (nose kind 4), measured on J1: x in half-widths, y in half-heights (down),
// wide flat top, the left shoulder cut a little wider than the right, the point down
const vec2 NOSE_SHIELD[7] = vec2[7](
	vec2(-0.02, -1.0), vec2(0.77, -0.88), vec2(0.87, -0.11), vec2(0.83, 0.41),
	vec2(0.0, 1.0), vec2(-1.12, 0.08), vec2(-0.73, -0.88)
);

// --- Distance primitives -------------------------------------------------------------

float fs_dot2(vec2 v) {
	return dot(v, v);
}

// Intersection of two distances with the corner rounded by r (both shrunk by r first).
float fs_round_max(float a, float b, float r) {
	vec2 v = vec2(a + r, b + r);
	return length(max(v, vec2(0.0))) + min(max(v.x, v.y), 0.0) - r;
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
// y = where along it the nearest point lies, -1 at -x1 .. 1 at x1.
vec2 fs_sd_parabola(vec2 p, float y0, float y2, float x1) {
	float ye = y0 + y2 * x1 * x1;
	vec2 B = vec2(0.0, y0 - y2 * x1 * x1);
	vec2 h = fs_sd_bezier(p, vec2(-x1, ye), B, vec2(x1, ye));
	return vec2(h.x, 2.0 * h.y - 1.0);
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

// The NOSE_SHIELD polygon scaled by k (Inigo Quilez's polygon distance).
float fs_sd_shield(vec2 p, vec2 k) {
	vec2 v0 = NOSE_SHIELD[0] * k;
	float d = fs_dot2(p - v0);
	float s = 1.0;
	for (int i = 0; i < 7; i++) {
		int j = i == 0 ? 6 : i - 1;
		vec2 vi = NOSE_SHIELD[i] * k;
		vec2 vj = NOSE_SHIELD[j] * k;
		vec2 e = vj - vi;
		vec2 w = p - vi;
		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));
		bvec3 cond = bvec3(p.y >= vi.y, p.y < vj.y, e.x * w.y > e.y * w.x);
		if (all(cond) || all(not(cond))) {
			s = -s;
		}
	}
	return s * sqrt(d);
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

// Value noise, LINEAR between lattice points (kinks at the lattice lines), in 0..1: an edge
// displaced by it runs in straight facets, like a pair of scissors.
float paper_noise_lin(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = paper_hash(i);
	float b = paper_hash(i + vec2(1.0, 0.0));
	float c = paper_hash(i + vec2(0.0, 1.0));
	float d = paper_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// A hand-cut edge: add to a piece's distance. `perimeter` (face units) sets the facet
// length (a twelfth of it, 0.02..0.06: short straight cuts, a finer octave at a third of
// that), `size` the piece's smaller dimension (a thin strip gets a shallower jag, down to
// a third at 0.03), `seed` keeps pieces apart. About one cell in six carries a small V nick,
// one jag deep and 2.5x as wide.
float paper_cut(vec2 p, float perimeter, float size, float seed) {
	float cell = clamp(perimeter / 12.0, 0.02, 0.06);
	vec2 o = vec2(seed * 7.13, seed * 3.71);
	float n = 0.7 * paper_noise_lin(p / cell + o) + 0.3 * paper_noise_lin(p / (0.33 * cell) - o.yx);
	float amp = paper_jag * clamp(size / 0.09, 0.33, 1.0);
	float d = amp * (2.0 * n - 1.0);
	vec2 nc = p / (1.6 * cell) + 1.37 * o;
	vec2 id = floor(nc);
	if (paper_hash(id + vec2(0.37 * seed, 0.0)) > 0.83) {
		vec2 q = id + 0.3 + 0.4 * vec2(paper_hash(id + 17.1), paper_hash(id + 41.7));
		// a cone 2.5x wider than deep: shallower than the edge's own slope, so it only ever
		// bites into the edge, never punches a hole beside it
		float depth = amp;
		d += depth * max(1.0 - length(nc - q) * 1.6 * cell / (2.5 * depth), 0.0);
	}
	return d;
}

// How much of a pattern `freq` waves per face unit survives at a pixel `px` wide.
float paper_fade(float freq, float px) {
	return 1.0 - smoothstep(0.25, 0.6, freq * px);
}

// Paper grain, about -1..1 (x) plus light fibre streaks, 0..1 (y): soft mottling in three
// octaves (each fading out once it gets finer than a pixel), a few soft dark specks, and
// long soft fibres along two crossing directions (and a few dark ones across them).
vec2 paper_fibres(vec2 p, float seed, float px) {
	vec2 o = vec2(seed * 17.3, seed * 9.1);
	float g = PAPER_MOTTLE.x * (2.0 * paper_noise(p * 60.0 + o) - 1.0) * paper_fade(60.0, px);
	g += PAPER_MOTTLE.y * (2.0 * paper_noise(p * 170.0 - o) - 1.0) * paper_fade(170.0, px);
	g += PAPER_MOTTLE.z * (2.0 * paper_noise(p * 420.0 + o.yx) - 1.0) * paper_fade(420.0, px);
	// dark specks
	float sk = smoothstep(PAPER_SPECK.y, PAPER_SPECK.z, paper_noise(p * 260.0 + o.yx * 1.7));
	g -= PAPER_SPECK.x * sk * paper_fade(260.0, px);
	// fibres: long thin soft streaks (FIBRE_LONG waves per face unit along them, FIBRE_WIDE
	// across), light ones on two crossing directions, a few dark ones across those
	// each streak bends gently (FIBRE_BEND face units over ~0.04), so they read as fibres,
	// not a woven grid
	vec2 bend = FIBRE_BEND * (vec2(paper_noise(p * 25.0 + o), paper_noise(p * 21.0 - o)) - 0.5);
	vec2 a = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * p + vec2(0.0, bend.x);
	vec2 b = mat2(vec2(0.97, -0.26), vec2(0.26, 0.97)) * p + vec2(0.0, bend.y);
	float fade = paper_fade(FIBRE_WIDE, px);
	vec2 k = vec2(FIBRE_LONG, FIBRE_WIDE);
	float lo = FIBRE_EDGE.x;
	float hi = FIBRE_EDGE.y;
	float f1 = smoothstep(lo, hi, paper_noise(a * k + o));
	float f2 = smoothstep(lo + 0.02, hi, paper_noise(b * k * vec2(0.9, 0.95) - o));
	float f3 = smoothstep(lo + 0.04, hi, paper_noise(a.yx * k * vec2(1.1, 1.05) + o.yx));
	g -= FIBRE_DARK * f3 * fade;
	return vec2(g, FIBRE_LIGHT * (f1 + f2) * fade);
}

// A fill with grain `grain` laid on it (g from paper_fibres). The light fibres lift a dark
// paper less (to 0.3 of a white one's), else they read as scratches on pupils and hair.
vec3 paper_grained(vec3 fill, vec2 g, float grain) {
	float lum = dot(fill, vec3(0.299, 0.587, 0.114));
	return fill * (1.0 + grain * g.x) + vec3(0.9 * grain * g.y * (0.3 + 0.7 * lum));
}

// A whole paper surface (skin, hair): `fill` with the grain at the mesh's own UV1, `tile`
// face units per UV unit (so the fibres come out face-sized on any mesh), fixed to the
// surface (it never swims as the rig walks or turns). Seams only break the noise.
vec3 paper_surface(vec3 fill, vec2 uv, float tile, float grain, float seed) {
	vec2 q = uv * tile;
	float px = 0.5 * (fwidth(q.x) + fwidth(q.y));
	return paper_grained(fill, paper_fibres(q, seed, px), grain);
}

// The pieces' sheet paper at p (face units), `px` one pixel: x = its luminance over its own
// mean (the last mip), yz = its normal as a slope (height per face unit, y down), both before
// the piece_tex_* strengths. Read at a mip picked from px, not from screen derivatives, so it
// is safe inside the pieces' branches; finer than a pixel it averages out to 1 and flat.
vec3 piece_paper(vec2 p, float px) {
	vec2 uv = p * piece_tex_tile;
	float texels = px * piece_tex_tile;
	float la = log2(max(texels * float(textureSize(piece_tex, 0).x), 1e-6));
	float ln = log2(max(texels * float(textureSize(piece_normal_tex, 0).x), 1e-6));
	const vec3 LUM = vec3(0.299, 0.587, 0.114);
	float lum = dot(textureLod(piece_tex, uv, la).rgb, LUM);
	float mean = dot(textureLod(piece_tex, uv, 20.0).rgb, LUM);
	vec2 n = textureLod(piece_normal_tex, uv, ln).rg * 2.0 - 1.0;
	float nz = sqrt(max(1.0 - dot(n, n), 0.04));
	// GL green points up the image, toward -y
	return vec3(lum / max(mean, 0.02), vec2(-n.x, n.y) / nz);
}

// Lay one paper piece on `under`: `d` is the piece's (cut) distance at p, `d_rim` the
// distance to the edges that show a cut rim (usually d), `d_shadow` the distance sampled
// at p - paper_shadow_offset (where its shadow falls), `grain` the grain contrast, `tex` how
// much of the sheet paper (piece_paper) it is cut from (0 = none: the 2D sheets' skin disc).
vec3 paper_piece_ex(
	vec3 under, float d, float d_rim, float d_shadow, vec3 fill, float grain, vec2 p, float seed,
	float px, float tex
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
	vec3 f = fill;
	if (tex > 0.0) {
		vec3 pp = piece_paper(p, px);
		f *= mix(1.0, pp.x, piece_tex_albedo * tex);
#ifdef PIECE_TEX_SHADE
		// flat sheets (face_canvas.gdshader): the normal under a fixed light from the top left
		f *= 1.0 + PIECE_TEX_SHADE * piece_tex_normal * tex * (pp.y + pp.z);
#endif
	}
	f = paper_grained(f, paper_fibres(p, seed, px), grain);
	// the cream core shows at the cut of light papers only, skin and cream (on darker ones
	// it reads as an outline)
	float light = smoothstep(0.62, 0.8, dot(fill, vec3(0.299, 0.587, 0.114)));
	float rim_on = smoothstep(0.4, 1.2, paper_rim / max(px, 1e-6)) * light;
	float rim = clamp((d_rim + paper_rim) / max(px, 1e-6) + 0.5, 0.0, 1.0);
	f = mix(f, paper_cream.rgb, paper_rim_alpha * rim_on * rim);
	return mix(col, f, cover);
}

// How far a face piece's step ramps either side of its cut (face units), `px` a pixel: a few
// thousandths, so the step's derivative stays smooth.
float piece_ramp(float px) {
	return max(0.003, 1.5 * px);
}

// Add a face piece's step to `lift` (piece layers): `d` is its distance (face units), `px`
// a pixel (the step ramps over piece_ramp).
float piece_lift(float lift, float d, float px) {
	float r = piece_ramp(px);
	return lift + 1.0 - smoothstep(-r, r, d);
}

// The usual piece: rim along its whole edge, the sheet paper and the shared grain.
vec3 paper_piece(vec3 under, float d, float d_shadow, vec3 fill, vec2 p, float seed, float px) {
	return paper_piece_ex(under, d, d, d_shadow, fill, paper_grain, p, seed, px, 1.0);
}

// The sheet paper's slope under the pieces (skin_face.gdshader: added to the lit height where
// `cover` of a piece lies; height per face unit).
vec2 piece_paper_grad(vec2 p, float px, float cover) {
	return piece_tex_normal * cover * piece_paper(p, px).yz;
}

// --- Pieces (distances, face units, y down) ----------------------------------------------
// `side` is -1 for the eye/brow/cheek on the viewer's left, +1 on the right; inner (toward
// the nose) is -side in x.

// Brow: a CUT STRIP of paper (owner, 2026-09-26: a tapered stroke reads as drawn): even
// `thick` all along, `len` long end to end, its ends cut square to the chord (not to the
// bent tips, so a drooping outer end stays upright, as on J1) with corners rounded by
// `corner` x half the thickness (0.5 = a quarter of the thickness, the shared look).
// `angle` (radians, > 0 lifts the inner end), `arch` = how far the middle rises, as a
// fraction of half the core length (a gentle bend; the strip never thins). `cut` is the
// hand-cut displacement (paper_cut); with `ends_straight` the two ends are clean straight
// cuts and only the long edges take it.
float piece_brow(
	vec2 p, vec2 c, float side, float len, float thick, float angle, float arch, float corner,
	float cut, bool ends_straight
) {
	vec2 e = p - c;
	e.x *= -side;  // +x = inner end
	float rc = clamp(corner, 0.0, 1.0) * 0.5 * thick;
	float l = max(len - 2.0 * rc, 1e-3);
	vec2 dir = vec2(cos(angle), -sin(angle));
	vec2 n = vec2(-sin(angle), -cos(angle));  // up, square to the strip
	float sag = 0.5 * arch * l;
	vec2 A = -0.5 * l * dir - 0.5 * sag * n;
	vec2 C = 0.5 * l * dir - 0.5 * sag * n;
	vec2 B = 1.5 * sag * n;
	float body = fs_sd_bezier(e, A, B, C).x - (0.5 * thick - rc);
	float ends = max(dot(e - A, -dir), dot(e - C, dir));
	if (ends_straight) {
		vec2 v = vec2(body + cut, ends);
		return length(max(v, vec2(0.0))) + min(max(v.x, v.y), 0.0) - rc;
	}
	vec2 v = vec2(body, ends);
	return length(max(v, vec2(0.0))) + min(max(v.x, v.y), 0.0) - rc + cut;
}

// Pupil: a dark ellipse with an optional 60 degree wedge cut out of it, opening along `dir`
// (y down); `wedge` = how far into the pupil it cuts, as a fraction of the radius. `cut` is
// the hand-cut displacement (paper_cut) for the round edge; the wedge's two edges take it
// too, or with `wedge_straight` they are clean straight cuts (a real snip is straight).
float piece_pupil(vec2 p, vec2 c, vec2 dir, vec2 r, float wedge, float cut, bool wedge_straight) {
	vec2 e = p - c;
	float d = fs_sd_ellipse(e, r) + cut;
	if (wedge > 0.01) {
		vec2 apex = dir * min(r.x, r.y) * (1.0 - clamp(wedge, 0.0, 1.0));
		vec2 q = e - apex;
		vec2 w = vec2(dot(q, vec2(-dir.y, dir.x)), dot(q, dir));
		float pie = fs_sd_pie(w, vec2(0.5, 0.866), 4.0 * max(r.x, r.y));
		d = max(d, -pie + (wedge_straight ? 0.0 : cut));
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

// The dark crescent along a shut lid's lower edge, the eye's width: a cut strip `thick` in
// the middle, easing to LID_STRIP_END of that at its ends, which are round caps (owner,
// 2026-09-26: ends that thinned to points read sharp).
float piece_lid_strip(vec2 p, vec2 c, vec2 r, vec2 edge, float margin, float thick) {
	vec2 e = p - c;
	float rx = r.x + margin;
	float x1 = max(rx - 0.5 * LID_STRIP_END * thick, 1e-3);
	vec2 h = fs_sd_parabola(e, edge.x, -edge.y / (rx * rx), x1);
	return h.x - 0.5 * thick * mix(1.0, LID_STRIP_END, h.y * h.y);
}

// Nose: kind 0 disc (radius r.x), 1 oval (radii r), 2 teardrop with its round point up
// (half-width r.x at the bottom, half-height r.y), 3 strip: a tall rounded trapezoid,
// narrow at the top (half-width r.x at the bottom, half-height r.y), 4 shield: J1's cut
// pentagon, wide flat top, pointing down (half-width r.x at the shoulders, half-height r.y),
// 5 triangle: a flat top r.x half-wide, pointing down, r.y half-height (straight snips),
// 6 triangle_up: the same flipped, a flat base r.x half-wide at the bottom, its point up.
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
	} else if (kind == 4) {
		// corners a touch soft, as scissors leave them
		float rr = 0.06 * min(r.x, r.y);
		return fs_sd_shield(e, max(r - rr, vec2(1e-3))) - rr;
	} else if (kind == 5) {
		float rr = NOSE_TRI_ROUND * min(r.x, r.y);
		return fs_sd_trapezoid(up, 0.0, max(r.x - rr, 1e-3), max(r.y - rr, 1e-3)) - rr;
	} else if (kind == 6) {
		float rr = NOSE_TRI_ROUND * min(r.x, r.y);
		return fs_sd_trapezoid(up, max(r.x - rr, 1e-3), 0.0, max(r.y - rr, 1e-3)) - rr;
	}
	return length(e) - r.x;
}

// Mouth line: a strip along the parabola that sits `sag` lower in the middle than at the
// corners (> 0 smiles), round ends, `width` cap to cap.
float piece_mouth_line(vec2 p, vec2 c, float width, float thick, float sag) {
	vec2 e = p - c;
	float hw = 0.5 * width;
	float x1 = max(hw - 0.5 * thick, 1e-3);
	float y2 = -sag / (hw * hw);
	return fs_sd_parabola(e, 0.5 * sag, y2, x1).x - 0.5 * thick;
}

// Open mouth: a paper "D" hanging from a straight top edge `y0` below c, half-width hw and
// `depth` deep; `top` = how far it rounds up above the edge (0 = the flat-topped D of a
// smile, about the depth = an "o"). Corners rounded by rc.
float piece_mouth_open(vec2 p, vec2 c, float hw, float y0, float depth, float top, float rc) {
	vec2 e = p - c - vec2(0.0, y0 + rc);
	float up = top - rc;
	float rx = max(hw - rc, 1e-3);
	float low = max(depth - rc, 1e-3);
	float d;
	if (up < 2e-3) {
		// the flat D: the lower half-ellipse, cut straight along the top
		d = fs_round_max(fs_sd_ellipse_exact(e, vec2(rx, low)), -e.y, 0.0);
	} else {
		d = fs_sd_ellipse_exact(e, vec2(rx, e.y < 0.0 ? up : low));
	}
	return d - rc;
}

// Teeth: ONE flat cream strip along the open mouth's top edge `y0`, `band` deep, inside the
// mouth by `inset`.
float piece_teeth(vec2 p, vec2 c, float y0, float band, float d_open, float inset) {
	return max(d_open + inset, p.y - c.y - y0 - band);
}

// --- Catalogue pieces (2026-09-26 proposals, IMPORT/faces_proc/catalogue.png) ------------
// Every one is off unless its FaceStyle dial is set; none is in a preset yet.

// Smooth union (polynomial): two pieces cut as one paper, no notch where they meet.
float fs_smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// A box of half-size b, corners rounded by r (inside b).
float fs_sd_rbox(vec2 p, vec2 b, float r) {
	vec2 d = abs(p) - b + r;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// Heart (Inigo Quilez), y UP, its point at the origin, lobes about 0.6 half-wide, 1.1 tall.
float fs_sd_heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return sqrt(fs_dot2(p - vec2(0.25, 0.75))) - 0.353553;
	}
	return sqrt(min(fs_dot2(p - vec2(0.0, 1.0)), fs_dot2(p - 0.5 * max(p.x + p.y, 0.0))))
		* sign(p.x - p.y);
}

// A strip of even `thick` along the ellipse `r` (centred at the origin, y down) from angle
// a0 to a1 (radians, 0 = +x, 90 degrees = up): the quadratic through the arc's two ends and
// its middle. Round ends.
float piece_arc_strip(vec2 e, vec2 r, float a0, float a1, float thick) {
	float am = 0.5 * (a0 + a1);
	vec2 A = r * vec2(cos(a0), -sin(a0));
	vec2 M = r * vec2(cos(am), -sin(am));
	vec2 C = r * vec2(cos(a1), -sin(a1));
	return fs_sd_bezier(e, A, 2.0 * M - 0.5 * (A + C), C).x - 0.5 * thick;
}

// A short straight strip from a, `len` long along `dir`, round ends.
float piece_tick(vec2 e, vec2 a, vec2 dir, float len, float thick) {
	return fs_sd_segment(e, a, a + dir * len).x - 0.5 * thick;
}

// Lash strip (E6): a dark strip `thick` along the outer upper edge of an eye outline `r`
// (e in the eye's frame, +x = outward, y down), from just above the outer corner to past the
// top, and two round-ended ticks flicking up and out of it near the outer end, one piece.
float piece_lash(vec2 e, vec2 r, float thick) {
	// the strip overlaps the white's edge a little, so it reads as the lid's edge
	vec2 rr = r + 0.15 * thick;
	float d = piece_arc_strip(e, rr, radians(8.0), radians(95.0), thick);
	// the ticks are stubby (as long as the strip is thick): longer, thinner ones read as
	// drawn lashes
	for (int k = 0; k < 2; k++) {
		float a = radians(k == 0 ? 14.0 : 38.0);
		vec2 base = rr * vec2(cos(a), -sin(a));
		vec2 n = normalize(vec2(cos(a) / rr.x, -sin(a) / rr.y));
		vec2 dir = normalize(n + vec2(0.6, 0.0));
		d = fs_smin(d, piece_tick(e, base, dir, 1.0 * thick, 0.8 * thick), 0.006);
	}
	return d;
}

// The lash strip on a lid (E6 once the lid comes down: a heavy-lid idle, a blink): the
// same dark strip and two ticks, riding the lid's lower edge (lid_edge) over the outer half
// of the eye instead of the white's outline, which the lid hides. e in the eye's frame
// (+x = outward, y down), r the eye outline.
float piece_lid_lash(vec2 e, vec2 r, vec2 edge, float margin, float thick) {
	float rx = r.x + margin;
	float b = edge.y / (rx * rx);
	// the edge y = edge.x - b x^2, lifted so the strip lies mostly on the lid
	float y0 = edge.x - 0.3 * thick;
	float xa = 0.12 * rx;
	float xb = rx - 0.3 * thick;
	vec2 A = vec2(xa, y0 - b * xa * xa);
	vec2 C = vec2(xb, y0 - b * xb * xb);
	vec2 B = vec2(0.5 * (xa + xb), A.y - b * xa * (xb - xa));
	float d = fs_sd_bezier(e, A, B, C).x - 0.5 * thick;
	for (int k = 0; k < 2; k++) {
		float x = (k == 0 ? 0.92 : 0.7) * xb;
		vec2 base = vec2(x, y0 - b * x * x);
		vec2 n = normalize(vec2(-2.0 * b * x, -1.0));
		vec2 dir = normalize(n + vec2(0.6, 0.0));
		d = fs_smin(d, piece_tick(e, base, dir, 1.0 * thick, 0.8 * thick), 0.006);
	}
	return d;
}

// Crow's feet (X7): two short strips fanning out from an eye's outer corner (outline `r`,
// +x = outward), each gently bent, round ends.
float piece_crease(vec2 e, vec2 r, float thick) {
	float d = 1e3;
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? -0.22 * r.y : 0.2 * r.y;
		vec2 A = vec2(r.x + 0.025, y);
		vec2 dir = normalize(vec2(1.0, k == 0 ? -0.35 : 0.3));
		vec2 C = A + dir * 0.055;
		vec2 B = 0.5 * (A + C) + vec2(0.0, k == 0 ? -0.006 : 0.006);
		d = min(d, fs_sd_bezier(e, A, B, C).x - 0.5 * thick);
	}
	return d;
}

// The brow's inner end in the brow's own frame (piece_brow: +x = inner, y down), for the
// comma's round head (B3).
vec2 brow_inner_end(float len, float thick, float angle, float arch, float corner) {
	float rc = clamp(corner, 0.0, 1.0) * 0.5 * thick;
	float l = max(len - 2.0 * rc, 1e-3);
	vec2 dir = vec2(cos(angle), -sin(angle));
	vec2 n = vec2(-sin(angle), -cos(angle));
	return 0.5 * l * dir - 0.25 * arch * l * n;
}

// Nose kinds from the catalogue: 7 hook (a thick strip bending down and hooking back to the
// viewer's left at the tip, r.x its thickness, r.y its half-height), 8 long (a thin strip,
// 0.35 r.x half-wide, ending in a round tip r.x), 9 teardrop with its point DOWN (kind 2
// flipped: the round end on top). y down, centred on the nose.
float piece_nose_more(vec2 e, int kind, vec2 r) {
	if (kind == 7) {
		float t = r.x;
		vec2 A = vec2(-0.1 * t, -r.y + 0.5 * t);
		vec2 C = vec2(-0.55 * t, r.y - 0.5 * t);
		vec2 B = vec2(1.1 * t, 0.55 * r.y);
		return fs_sd_bezier(e, A, B, C).x - 0.5 * t;
	} else if (kind == 8) {
		float stem = 0.55 * r.x;
		vec2 tip = vec2(0.0, r.y - r.x);
		float d = fs_sd_segment(e, vec2(0.0, -r.y + stem), tip).x - stem;
		return fs_smin(d, length(e - tip) - r.x, 0.01);
	}
	float r1 = r.x;
	float r2 = max(0.4 * r1, 0.01);
	float h = max(2.0 * r.y - r1 - r2, 1e-3);
	return fs_sd_uneven_capsule(e + vec2(0.0, r.y - r1), r1, r2, h);
}

// Lips (M6): a rose lens round the mouth line (the same parabola, `width` and `sag` as
// piece_mouth_line), `lips` wider than the line at the middle, easing to 0.35 of that at
// the corners, which stay round: a lip shape, not the line's outline.
float piece_lips(vec2 e, float width, float thick, float sag, float lips) {
	float hw = 0.5 * width;
	float x1 = max(hw - 0.5 * thick + 0.3 * lips, 1e-3);
	vec2 h = fs_sd_parabola(e, 0.5 * sag, -sag / (hw * hw), x1);
	return h.x - 0.5 * thick - lips * (1.0 - 0.65 * h.y * h.y);
}

// Buck teeth (M5): two cream teeth hanging from under the mouth line's middle (`top` its
// centre line, y below the mouth centre), `len` below the line's lower edge, a skin gap
// between them.
float piece_buck(vec2 e, float width, float thick, float top, float len) {
	float tw = 0.085 * width;
	float gap = 0.004;
	float hh = 0.5 * (0.5 * thick + len);
	vec2 q = vec2(abs(e.x) - (tw + 0.5 * gap), e.y - top - hh);
	return fs_sd_rbox(q, vec2(tw, hh), 0.45 * tw);
}

// Pursed heart mouth (M4): a heart `hw` half-wide, point down, centred on e = 0.
float piece_heart_mouth(vec2 e, float hw) {
	float k = hw / 0.6;
	vec2 q = vec2(e.x, -e.y) / k + vec2(0.0, 0.55);
	float rr = 0.12 * hw;
	return fs_sd_heart(q * (1.0 + rr / hw)) * k - rr;
}

// Moustache (X5): kind 1 one thick strip, round ends, its ends drooping `hw` half-wide;
// kind 2 a chevron: two strips from near the middle down and out, a skin gap between them
// (two papers). s = (half-width, thickness); e from the moustache centre, y down.
float piece_moustache(vec2 e, int kind, vec2 s) {
	float hw = s.x;
	float t = s.y;
	if (kind == 2) {
		vec2 q = vec2(abs(e.x), e.y);
		vec2 A = vec2(0.5 * t + 0.004, -0.35 * t);
		vec2 C = vec2(hw - 0.5 * t, 0.45 * t);
		return fs_sd_segment(q, A, C).x - 0.5 * t;
	}
	float x1 = hw - 0.5 * t;
	vec2 A = vec2(-x1, 0.35 * t);
	vec2 C = vec2(x1, 0.35 * t);
	vec2 B = vec2(0.0, -0.55 * t);
	return fs_sd_bezier(e, A, B, C).x - 0.5 * t;
}

// Chin patch (X6): a rounded trapezoid, wide at the top (s.x half-wide) and narrowing down
// to 0.45 of that, s.y half-tall. y down.
float piece_beard(vec2 e, vec2 s) {
	float rr = 0.35 * min(s.x, s.y);
	vec2 up = vec2(e.x, -e.y);
	float top = max(s.x - rr, 1e-3);
	return fs_sd_trapezoid(up, max(0.45 * s.x - rr, 1e-3), top, max(s.y - rr, 1e-3)) - rr;
}

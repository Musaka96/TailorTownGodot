// Papier-mache surface for a cut-paper character (docs/FACE_STYLE_GUIDE.md, "Papier-mache
// surface"): a scanned paper (its light and dark and its normal map) and a layer of
// overlapping torn paper strips, each with its own tone, a soft glue seam along its visible
// edges and a small lip, raised a paper's thickness over the strips below. The strips and
// the scan are a HEIGHT, and paper_normal() turns that into the lit normal, so the light
// catches the strip edges at a normal viewing distance, not only up close.
// Include after face_sdf.gdshaderinc (piece_lift lives there; the hashes here are own). Used by
// skin_face.gdshader (the head, the face pieces sitting on it) and paper_skin.gdshader
// (hands, arms, hair); the uniforms are written from a PaperSurface (.tres).
//
// Space: q = the mesh UV1 x tile, in FACE UNITS (face_sdf.gdshaderinc), the space the grain
// uses, so the strips come out the same size on the head, the hair and the arms.

// the scan's colour (only its light and dark are used: the palette stays closed) and its
// OpenGL normal map; unset = plain (white, flat)
uniform sampler2D scan_albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// scan tiles per face unit
uniform float scan_scale = 2.0;
// how much of the scan's light and dark shows (0 = none, 1 = as scanned)
uniform float scan_albedo = 0.0;
// the scan normal's slope, x (0 = flat)
uniform float normal_strength = 0.0;
// strip cells per face unit (a strip is up to two cells long and 0.8 wide)
uniform float mache_scale = 4.0;
// strip relief: 1 = each strip a paper's thickness (MACHE_LAYER) proud of the one below
uniform float mache_strength = 0.0;
// the glue seam's darkness along the visible strip edges (and a lighter torn fringe inside)
uniform float mache_seam = 0.0;
// each strip's own tone, +- (0.04 = 4 %); the strips are on when any of the three is > 0
uniform float mache_tone = 0.0;
// the face pieces' own step (skin_face only): 1 = one PIECE_LAYER thick
uniform float piece_relief = 0.0;

// one strip layer, face units (about 1.5 mm on a head)
const float MACHE_LAYER = 0.008;
// a strip's half size in cells (long, wide) and the random extra on top; only this share
// of the cells carries a strip (a full grid of them reads as crazed plaster). A strip must
// stay inside its 3 x 3 cells, seam included: half-length + tear + seam reach (MACHE_REACH)
// under 1.3 (a centre jitters up to 0.2 from its cell's middle), else it is cut off along
// the cell lines
const vec2 MACHE_HALF = vec2(0.75, 0.3);
const vec2 MACHE_HALF_RAND = vec2(0.25, 0.1);
const float MACHE_JITTER = 0.4;
const float MACHE_REACH = 0.16;
const float MACHE_FILL = 0.85;
// the torn edge: how far it wanders (cells) and its two noise frequencies (per cell)
const float MACHE_TEAR = 0.09;
const vec2 MACHE_TEAR_FREQ = vec2(3.0, 11.0);
// the lip along a torn edge (layers) and its width (cells)
const float MACHE_LIP = 0.25;
const float MACHE_LIP_W = 0.05;
// the glue seam's soft shadow just outside a visible edge, and the torn fringe just
// inside (cells); a thin dark seam reads as cracks
const float MACHE_SEAM_W = 0.1;
const float MACHE_FRINGE = 0.5;
// under a face piece the strips' relief shows at this share (the piece smooths it)
const float MACHE_UNDER_PIECE = 0.4;
// one face piece, face units
const float PIECE_LAYER = 0.004;

// A hash of an integer cell and a salt, 0..1. Integer on purpose: paper_hash() is chaotic in
// its float input, and the GPU compiler may fold `id + offset` differently in each unrolled
// neighbour iteration, so the same cell hashed twice came out different and the strips were
// cut off along the cell lines.
float mache_hash(ivec2 c, uint salt) {
	uvec2 q = uvec2(c) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y ^ (salt * 2654435761u)) * 1597334673u;
	n ^= n >> 16u;
	n *= 2246822519u;
	n ^= n >> 13u;
	return float(n) * (1.0 / 4294967295.0);
}

// Value noise on the integer lattice (mache_hash), smooth, 0..1.
float mache_noise(vec2 p, uint salt) {
	vec2 f = fract(p);
	ivec2 i = ivec2(floor(p));
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mache_hash(i, salt);
	float b = mache_hash(i + ivec2(1, 0), salt);
	float c = mache_hash(i + ivec2(0, 1), salt);
	float d = mache_hash(i + ivec2(1, 1), salt);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// The strip field at g (cell units), edges softened over w cells: x = height in layers,
// y = the visible strip's tone (-1..1), z = the glue seam (0..1), w = the torn fringe (0..1).
vec4 mache_field(vec2 g, float w) {
	ivec2 id = ivec2(floor(g));
	float d[9];
	float z[9];
	float cov[9];
	float tone[9];
	for (int k = 0; k < 9; k++) {
		ivec2 cid = id + ivec2(k % 3 - 1, k / 3 - 1);
		vec4 r = vec4(
			mache_hash(cid, 1u), mache_hash(cid, 2u), mache_hash(cid, 3u), mache_hash(cid, 4u)
		);
		vec2 c = vec2(cid) + 0.5 + MACHE_JITTER * (r.xy - 0.5);
		float a = 6.283 * r.z;
		vec2 e = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * (g - c);
		vec2 hs = MACHE_HALF + MACHE_HALF_RAND * vec2(r.w, fract(r.w * 7.31));
		// a rectangle with soft corners, its edge torn by two octaves of noise
		vec2 b = abs(e) - hs + 0.2;
		float dd = length(max(b, vec2(0.0))) + min(max(b.x, b.y), 0.0) - 0.2;
		uint salt = uint(r.w * 65535.0);
		float n = 0.65 * mache_noise(e * MACHE_TEAR_FREQ.x, salt);
		n += 0.35 * mache_noise(e * MACHE_TEAR_FREQ.y, salt + 7u);
		dd += MACHE_TEAR * (2.0 * n - 1.0);
		d[k] = dd;
		z[k] = fract(r.x * 5.13 + r.z * 3.71);
		cov[k] = mache_hash(cid, 5u) < MACHE_FILL ? 1.0 - smoothstep(-w, w, dd) : 0.0;
		tone[k] = 2.0 * fract(r.y * 9.17 + r.w * 2.31) - 1.0;
	}
	float h = 0.0;
	float tn = 0.0;
	float seam = 0.0;
	float fringe = 0.0;
	for (int k = 0; k < 9; k++) {
		// how much of strip k lies under a later (higher) strip
		float occ = 0.0;
		for (int j = 0; j < 9; j++) {
			occ = z[j] > z[k] ? max(occ, cov[j]) : occ;
		}
		float vis = 1.0 - occ;
		// (squares written out: pow() of a negative base is undefined, NaN on some GPUs)
		float t = (d[k] + MACHE_LIP_W) / MACHE_LIP_W;
		float lip = MACHE_LIP * exp(-t * t) * cov[k];
		h += cov[k] + lip * vis;
		tn += cov[k] * vis * tone[k];
		t = (d[k] - 0.5 * MACHE_SEAM_W) / MACHE_SEAM_W;
		float s = exp(-t * t);
		s *= 1.0 - smoothstep(0.6 * MACHE_REACH, MACHE_REACH, d[k]);
		seam = max(seam, s * vis * (1.0 - cov[k]));
		t = (d[k] + 0.4 * MACHE_SEAM_W) / (0.4 * MACHE_SEAM_W);
		float f = exp(-t * t);
		fringe = max(fringe, f * vis * cov[k]);
	}
	return vec4(h, tn, seam, fringe);
}

// The paper at q: `col` with the scan's light and dark, and the strips' tone, seam and fringe
// where `keep` is 1 (0 under a face piece, which is its own paper); `grad` returns the
// height's gradient over q (face units per face unit: scan normal and strips) for
// paper_normal(). Cells under about 15 px fade out (gone under 9 px), so a 25 px head stays
// calm while a ~140 px one shows the strips.
vec3 paper_mache(vec3 col, vec2 q, float keep, out vec2 grad) {
	float px = 0.5 * (fwidth(q.x) + fwidth(q.y));
	grad = vec2(0.0);
	// the scan: its luminance over its own mean (the last mip), and its normal as a slope
	vec2 st = q * scan_scale;
	const vec3 LUM = vec3(0.299, 0.587, 0.114);
	float lum = dot(texture(scan_albedo_tex, st).rgb, LUM);
	float mean = dot(textureLod(scan_albedo_tex, st, 12.0).rgb, LUM);
	col *= mix(1.0, lum / max(mean, 0.02), scan_albedo);
	vec2 sn = texture(scan_normal_tex, st).rg * 2.0 - 1.0;
	float snz = sqrt(max(1.0 - dot(sn, sn), 0.04));
	// GL green points up the image, toward -v
	grad += normal_strength * vec2(-sn.x, sn.y) / snz;
	if (mache_strength <= 0.0 && mache_seam <= 0.0 && mache_tone <= 0.0) {
		return col;
	}
	float pc = px * mache_scale;  // one pixel in cells
	float fade = 1.0 - smoothstep(0.05, 0.11, pc);
	if (fade <= 0.0) {
		return col;
	}
	vec2 g = q * mache_scale;
	float w = max(0.03, pc);
	float eps = max(0.75 * pc, 0.01);
	vec4 m = mache_field(g, w);
	float hx = mache_field(g + vec2(eps, 0.0), w).x;
	float hy = mache_field(g + vec2(0.0, eps), w).x;
	float relief = fade * mache_strength * mix(MACHE_UNDER_PIECE, 1.0, keep);
	grad += relief * MACHE_LAYER * mache_scale * vec2(hx - m.x, hy - m.x) / eps;
	float k = fade * keep;
	col *= 1.0 + mache_tone * m.y * k;
	col *= 1.0 - mache_seam * k * (m.z - MACHE_FRINGE * m.w);
	return col;
}

// The screen derivatives (x, y) of a height (face units) that rises by `grad` over q.
vec2 paper_slope(vec2 q, vec2 grad) {
	return vec2(dot(grad, dFdx(q)), dot(grad, dFdy(q)));
}

// How big a pixel is in q: the summed squared screen derivatives (face units squared).
float paper_texel(vec2 q) {
	vec2 a = dFdx(q);
	vec2 b = dFdy(q);
	return dot(a, a) + dot(b, b);
}

// The lit normal (view space) for a height whose screen derivatives are `dh` (face units,
// paper_slope), `texel` = paper_texel of the face-unit coordinates it was measured in: the
// surface gradient (Mikkelsen) from the screen derivatives of the position, so no mesh
// tangents are needed. Degenerate derivatives leave N as it is.
vec3 paper_normal(vec3 n, vec3 pos, vec2 dh, float texel) {
	if (texel < 1e-16) {
		return n;
	}
	vec3 dpx = dFdx(pos);
	vec3 dpy = dFdy(pos);
	// metres per face unit here
	float m = sqrt((dot(dpx, dpx) + dot(dpy, dpy)) / texel);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * m * (dh.x * r1 + dh.y * r2);
	vec3 v = abs(det) * n - g;
	float l = dot(v, v);
	if (!(l > 1e-30) || abs(det) < 1e-16) {
		return n;
	}
	return v * inversesqrt(l);
}

// The characters' paper laid on the world (PaperWorld, scenes/world/paper_world.gd): the
// grain (face_sdf.gdshaderinc, paper_surface) and a scanned paper (paper_mache.gdshaderinc,
// one of the four world papers per material) projected on the three world planes and
// blended by the normal, because world meshes have no paper-sized UVs. Include after
// face_sdf.gdshaderinc and paper_mache.gdshaderinc. Used by paper_world.gdshader and by the
// wall cutaway (materials/wall_cutaway.gdshader) when its paper is on.
//
// `paper_tile` = face units per metre (the head's paper is ~5; the world uses 1.25, so its
// creases read from across the room).

uniform float paper_tile = 1.25;
uniform float paper_grain_amount = 0.14;
uniform float paper_seed = 0.0;
// how hard the three projections part at an edge (higher = crisper seam, less smear)
uniform float paper_blend_sharp = 6.0;

// One projection: the paper at q (face units), its colour and its lit normal (view space).
vec3 paper_world_plane(vec3 base, vec2 q, float s, vec3 n, vec3 pos, out vec3 nrm) {
	vec3 col = paper_surface(base, q, 1.0, paper_grain_amount, s);
	vec2 grad;
	col = paper_mache(col, q + 7.3 * s, 1.0, grad);
	nrm = paper_normal(n, pos, paper_slope(q, grad), paper_texel(q));
	return col;
}

// `base` laid on paper at world position `wpos` with world normal `wnrm`; `n` / `pos` are
// the view-space NORMAL and VERTEX; returns the colour, `nrm` the lit view-space normal.
vec3 paper_world(vec3 base, vec3 wpos, vec3 wnrm, vec3 n, vec3 pos, out vec3 nrm) {
	vec3 w = pow(abs(normalize(wnrm)), vec3(paper_blend_sharp));
	w /= max(w.x + w.y + w.z, 1e-5);
	vec3 p = wpos * paper_tile;
	vec3 nx;
	vec3 ny;
	vec3 nz;
	vec3 cx = paper_world_plane(base, p.zy, paper_seed, n, pos, nx);
	vec3 cy = paper_world_plane(base, p.xz, paper_seed + 1.0, n, pos, ny);
	vec3 cz = paper_world_plane(base, p.xy, paper_seed + 2.0, n, pos, nz);
	nrm = normalize(nx * w.x + ny * w.y + nz * w.z);
	return cx * w.x + cy * w.y + cz * w.z;
}

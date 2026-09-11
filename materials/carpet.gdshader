shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Carpet pile made of REAL tuft geometry: carpet.gd scatters thousands of curved, tapered
// tuft strands as a MultiMesh. Each tuft's colour is the per-instance COLOR (sampled from
// the carpet pattern), shaded darker toward its base so the pile reads with depth.

uniform float base_shade : hint_range(0.0, 1.0, 0.01) = 0.45;

varying vec3 tuft_color;
varying float tuft_h;

void vertex() {
	tuft_color = COLOR.rgb;  // per-instance colour set by the MultiMesh
	tuft_h = UV.y;           // 0 at the base of the strand, 1 at the tip
}

void fragment() {
	ALBEDO = tuft_color * mix(1.0 - base_shade, 1.0, tuft_h);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

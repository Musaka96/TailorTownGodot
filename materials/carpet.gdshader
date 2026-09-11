shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley;

// Carpet with real 3D pile via SHELL TEXTURING. The rug is drawn as N stacked "shells"
// (a MultiMesh of N instances; the vertex shader lifts each shell up along the normal).
// Each shell keeps only the pixels inside a tuft that is tall enough to reach that height,
// so tufts taper to points — real pile whose height, density and shape you can set.
// carpet.gd (@tool) builds the shells and keeps shell_count in sync with the instances.
// Base shader family: "Billboard Grass with Wind" by binbun (godotshaders.com, CC0).

group_uniforms Carpet;
uniform sampler2D carpet_texture : source_color, hint_default_white;
uniform bool use_texture = true;
uniform vec4 tint : source_color = vec4(0.62, 0.20, 0.22, 1.0);
uniform vec2 tiling = vec2(1.0, 1.0);

group_uniforms Pile;
// Number of shell layers — kept equal to the MultiMesh instance count by carpet.gd.
// More layers = smoother, denser-looking strands (at more overdraw).
uniform int shell_count = 16;
// How tall the pile stands, in metres.
uniform float pile_height : hint_range(0.0, 0.3, 0.001) = 0.06;
// Tufts across one UV tile (higher = denser, finer pile).
uniform float tuft_density : hint_range(2.0, 200.0, 1.0) = 48.0;
// Base thickness of each tuft (fraction of a cell).
uniform float tuft_thickness : hint_range(0.05, 1.0, 0.01) = 0.7;
// Tuft cross-section shape.
uniform int tuft_shape : hint_enum("Round", "Square", "Diamond") = 0;
// Random height variation between tufts (0 = all equal length).
uniform float length_variation : hint_range(0.0, 1.0, 0.01) = 0.4;
// How much the pile darkens toward its base — fake occlusion that reads as depth.
uniform float base_shade : hint_range(0.0, 1.0, 0.01) = 0.45;

varying float shell_h;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float denom = float(max(shell_count - 1, 1));
	shell_h = float(INSTANCE_ID) / denom;  // 0 at the backing, 1 at the tips
	VERTEX += NORMAL * shell_h * pile_height;
}

void fragment() {
	vec2 uv = UV * tiling;
	bool is_base = shell_h <= 0.001;

	vec2 cell = uv * tuft_density;
	vec2 id = floor(cell);
	vec2 f = fract(cell) - 0.5;

	if (!is_base) {
		// This tuft's length (some are shorter). Above it, nothing.
		float tuft_len = mix(1.0 - length_variation, 1.0, hash21(id + 3.7));
		if (shell_h > tuft_len) {
			discard;
		}
		// Cross-section distance, per shape.
		float d;
		if (tuft_shape == 1) {
			d = max(abs(f.x), abs(f.y));
		} else if (tuft_shape == 2) {
			d = abs(f.x) + abs(f.y);
		} else {
			d = length(f);
		}
		// Radius shrinks toward the tip so the strand tapers to a point.
		float radius = tuft_thickness * 0.5 * (1.0 - shell_h / max(tuft_len, 0.001));
		if (d > radius) {
			discard;
		}
	}

	// Colour: the backing samples the pattern normally; strands take one colour per tuft.
	vec2 sample_uv = is_base ? uv : (id + 0.5) / tuft_density;
	vec3 col = tint.rgb;
	if (use_texture) {
		col *= texture(carpet_texture, sample_uv).rgb;
	}
	col *= mix(1.0 - base_shade, 1.0, shell_h);  // darker deep in the pile

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

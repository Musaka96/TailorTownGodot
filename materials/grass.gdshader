shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

// Billboard grass with wind.
// Original: "Billboard Grass with Wind" by binbun (godotshaders.com), CC0.
// Adapted for TailorTown: the external `util/dither.gdshaderinc` include was inlined
// (bayer4 below) so the shader is self-contained.

uniform bool billboard = true;

uniform sampler2D shape_texture : source_color;
uniform sampler2D shape_atlas : source_color;
uniform bool use_atlas = false;

group_uniforms Colors;
uniform sampler2D noise_texture : source_color;
uniform sampler2D color_gradient : source_color;
uniform float random_variation : hint_range(0.0, 1.0, 0.001) = 0.002;

group_uniforms Wind;
uniform sampler2D wind_texture : source_color;
uniform vec2 wind_velocity = vec2(1.0, 0.4);

group_uniforms Transparency;
uniform float alpha_cut_start : hint_range(0.0, 1.0, 0.05) = 0.1;
uniform float alpha_cut_end : hint_range(0.0, 1.0, 0.05) = 0.9;
uniform int alpha_mode : hint_enum("Smooth", "Dithered", "Cut") = 2;

varying flat int id;
varying vec3 world_pos;

// Inlined 4x4 ordered (Bayer) dither, replacing the original util include.
float bayer4(vec2 fc) {
	int x = int(mod(fc.x, 4.0));
	int y = int(mod(fc.y, 4.0));
	int index = x + y * 4;
	float m[16] = float[16](
			0.0, 8.0, 2.0, 10.0,
			12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0,
			15.0, 7.0, 13.0, 5.0);
	return m[index] / 16.0;
}

vec2 atlas_uv(vec2 uv, int index, int size) {
	int tile_count = size * size;
	int i = index % tile_count;
	float x = float(i % size);
	float y = float(i / size);
	vec2 tile_size = 1.0 / vec2(float(size));
	return uv * tile_size + (vec2(x, y) * tile_size);
}

float randomf(int index, int seed) {
	float value = sin(float(index + seed)) * 0.5 + 0.5;
	return value;
}

float wind_noise() {
	float value = texture(wind_texture, (world_pos.xz * 0.03) - (vec2(TIME * 0.01) * wind_velocity)).r;
	return value;
}

vec3 wind(vec2 uv) {
	float wn = wind_noise();
	float wind_affect = pow(1.0 - uv.y, 2.0);
	vec3 value = vec3(wn * (wind_velocity.x), 0.0, wn * (wind_velocity.y)) * 0.25;
	value *= wind_affect;
	return value;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	id = INSTANCE_ID;

	if (billboard) {
		mat4 billboard_matrix = mat4(
				MAIN_CAM_INV_VIEW_MATRIX[0],
				MAIN_CAM_INV_VIEW_MATRIX[1],
				MAIN_CAM_INV_VIEW_MATRIX[2],
				MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * billboard_matrix;
		VERTEX += (VIEW_MATRIX * vec4(wind(UV), 0.0)).xyz;
	} else {
		VERTEX += wind(UV);
	}
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float shape_value = texture(shape_texture, UV).r;
	if (use_atlas) {
		vec2 a_uv = atlas_uv(UV, id, 2);
		shape_value = texture(shape_atlas, a_uv).r;
	}

	float noise_value = texture(noise_texture, world_pos.xz * 0.1).r;
	if (randomf(id, 1) < random_variation) {
		noise_value += 0.4;
	}
	vec4 color = texture(color_gradient, vec2(noise_value, 0.0));
	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;  // matte — no shiny/blown-out blades
	SPECULAR = 0.0;

	float alpha = shape_value;
	if (alpha_mode == 0) {
		ALPHA = alpha;
	} else {
		alpha = clamp((shape_value - alpha_cut_start) / (alpha_cut_end - alpha_cut_start), 0.0, 1.0);
		if (alpha_mode == 1) {
			alpha = step(bayer4(FRAGCOORD.xy) + 0.01, alpha);
		}
		if (alpha < 0.1) {
			discard;
		}
	}
}

// No custom light() — use Godot's standard matte diffuse so blades never over-brighten.

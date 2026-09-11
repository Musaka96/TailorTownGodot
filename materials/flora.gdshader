shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley;

// A grass/flower sprite card that bobs in the wind. Colour from color_texture, alpha from
// mask_texture's red channel. Every fragment is lit as if facing straight up (world-up
// normal) so both sides read the same — no dark/black backs — and it stays matte.
// `billboard` makes the card turn to face the camera (upright). Horizontal cards are laid
// flat by the FloraPatch scatter (billboard off for those).
// Wind idea from "Billboard Grass with Wind" by binbun (godotshaders.com, CC0).

uniform sampler2D color_texture : source_color, hint_default_white;
uniform sampler2D mask_texture : hint_default_white;  // .r = alpha (silhouette)
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_clip : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform bool billboard = false;

group_uniforms Wind;
uniform sampler2D wind_noise : hint_default_black;
uniform vec2 wind_velocity = vec2(1.0, 0.4);
uniform float sway : hint_range(0.0, 1.0, 0.01) = 0.15;

varying vec3 up_view;  // world-up expressed in view space, for even foliage lighting

vec3 wind_offset(vec3 world_v, float top) {
	float n = texture(wind_noise, world_v.xz * 0.06 - TIME * 0.04 * wind_velocity).r - 0.5;
	return vec3(n * sway * wind_velocity.x * top, 0.0, n * sway * wind_velocity.y * top);
}

void vertex() {
	up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float top = 1.0 - UV.y;  // sway grows toward the top of the card
	vec3 world_v;
	if (billboard) {
		// Cylindrical billboard: rebuild the model-view so the card faces the camera
		// horizontally, stays upright and keeps its instance position + scale. (We change
		// MODELVIEW rather than POSITION so the normal auto path stays intact.)
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		vec3 cam_right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 fwd = cross(cam_right, up);
		mat4 m = mat4(
				vec4(cam_right * sx, 0.0),
				vec4(up * sy, 0.0),
				vec4(fwd * sx, 0.0),
				MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * m;
		world_v = (m * vec4(VERTEX, 1.0)).xyz;
	} else {
		world_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	vec3 w = wind_offset(world_v, top);
	VERTEX.x += w.x;
	VERTEX.z += w.z;
}

void fragment() {
	float a = texture(mask_texture, UV).r;
	if (a < alpha_clip) {
		discard;
	}
	ALBEDO = texture(color_texture, UV).rgb * tint.rgb;
	ALPHA = a;
	NORMAL = up_view;  // lit as if facing up → both faces evenly lit, never black
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley;

// A grass/flower sprite card that bobs in the wind. Upright (not billboarded) so instances
// can be randomly rotated and scaled by the FloraPatch scatter. Colour comes from
// color_texture, alpha from mask_texture's red channel. Matte (no custom light(), rough=1,
// spec=0) so it never looks shiny — fixing the over-bright grass.
// Wind idea from "Billboard Grass with Wind" by binbun (godotshaders.com, CC0).

uniform sampler2D color_texture : source_color, hint_default_white;
uniform sampler2D mask_texture : hint_default_white;  // .r = alpha (silhouette)
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_clip : hint_range(0.0, 1.0, 0.01) = 0.4;

group_uniforms Wind;
uniform sampler2D wind_noise : hint_default_black;
uniform vec2 wind_velocity = vec2(1.0, 0.4);
uniform float sway : hint_range(0.0, 1.0, 0.01) = 0.15;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Sway grows toward the top of the card (UV.y = 0 at the top of a QuadMesh).
	float top = 1.0 - UV.y;
	float n = texture(wind_noise, world_pos.xz * 0.06 - TIME * 0.04 * wind_velocity).r - 0.5;
	VERTEX.x += n * sway * wind_velocity.x * top;
	VERTEX.z += n * sway * wind_velocity.y * top;
	// Face up so foliage is lit evenly and softly (no dark backs), and stays matte.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float a = texture(mask_texture, UV).r;
	if (a < alpha_clip) {
		discard;
	}
	ALBEDO = texture(color_texture, UV).rgb * tint.rgb;
	ALPHA = a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

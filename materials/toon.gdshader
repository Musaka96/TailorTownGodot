shader_type spatial;

// Flexible Toon Shader (Godot 4).
// Original by CaptainProton42; Godot 4 port by atzuk4451 (godotshaders.com). MIT licensed.
// A per-material cel shader: stepped (banded) diffuse, hard specular, rim light, and
// optional dark borders. Applied to a mesh's material_override. (For a global toon LOOK,
// TailorTown also has a screen-space toon in the PostFX system — see PostFxProfile.toon_*.)

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool clamp_diffuse_to_max = false;

uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0, 2.0) = 0.0;
uniform float steepness : hint_range(1.0, 8.0) = 1.0;

uniform bool use_attenuation = true;

uniform bool use_specular = true;
uniform float specular_strength : hint_range(0.0, 1.0) = 1.0;
uniform float specular_shininess : hint_range(0.0, 32.0) = 16.0;
uniform sampler2D specular_map : source_color, hint_default_white;

uniform bool use_rim = true;
uniform float rim_width : hint_range(0.0, 16.0) = 8.0;
uniform vec4 rim_color : source_color = vec4(1.0);

uniform bool use_ramp = false;
uniform sampler2D ramp : source_color, hint_default_white;

uniform bool use_borders = false;
uniform float border_width = 0.01;

float split_specular(float specular) {
	return step(0.5, specular);
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
}

void light() {
	float attenuation = 1.0;
	if (use_attenuation) {
		attenuation = ATTENUATION;
	}

	// Stepped (banded) diffuse.
	float ndotl = dot(NORMAL, LIGHT);
	float diffuse_amount = ndotl + (attenuation - 1.0) + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0 / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0 - diffuse_amount, cuts_inv), 0.0, 1.0);

	// Dark borders between bands.
	float border = 0.0;
	if (use_borders) {
		float corr_border_width = length(cross(NORMAL, LIGHT)) * border_width * steepness;
		border = (
			step(diffuse_stepped - corr_border_width, diffuse_amount)
			- step(1.0 - corr_border_width, diffuse_amount));
	}

	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	if (use_ramp) {
		diffuse *= texture(ramp, vec2(diffuse_stepped * (1.0 - border), 0.0)).rgb;
	} else {
		diffuse *= diffuse_stepped * (1.0 - border);
	}

	if (clamp_diffuse_to_max) {
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
	} else {
		DIFFUSE_LIGHT += diffuse;
	}

	// Hard (stepped) specular.
	if (use_specular) {
		vec3 h = normalize(LIGHT + VIEW);
		float ndoth = dot(NORMAL, h);
		float specular_amount = max(pow(ndoth, specular_shininess * specular_shininess), 0.0)
			* texture(specular_map, UV).r
			* attenuation;
		specular_amount = split_specular(specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}

	// Rim light.
	if (use_rim) {
		float ndotv = dot(NORMAL, VIEW);
		float rim_light = pow(1.0 - ndotv, rim_width);
		SPECULAR_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
	}
}

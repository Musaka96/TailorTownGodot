shader_type spatial;
// A wall that tears away above a given height instead of being sawn off flat.
//
// The cut is a world-space height, not geometry: below `cut_height` the wall is a
// normal opaque wall, above it the pixels are discarded, and the `band` in between is
// eaten away along a hand-torn edge (world-space value noise, so it never crawls as the
// camera moves). The exposed inside of the slab paints itself `section_color`, which is
// what makes a hollow wall read as a solid plaster cross-section — no cap geometry.
//
// It stays in the OPAQUE pass on purpose. `discard` keeps depth writing, so the depth
// pre-pass, SSAO, the DOF blur and the screen-space outline all see a real surface and
// the outline inks the torn edge like any other silhouette. Alpha would skip the
// pre-pass and let the room's outlines draw straight through the wall — the same trap
// documented in scenes/world/roof_manager.gd.
//
// Everything above the Cutaway group just replays a glTF metallic-roughness material,
// so a converted wall looks identical to its imported one until the cut comes down.
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool normal_on = false;
uniform float normal_strength : hint_range(0.0, 4.0) = 1.0;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool rough_tex_on = false;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

group_uniforms Cutaway;
// World Y the wall is cut at. Parked far above the roof (the node's `up_height`) when
// the wall is whole, tweened down to sill height when the player steps inside.
uniform float cut_height = 99.0;
// Metres of wall eaten away along the tear, from "first nibble" to "all gone".
uniform float band : hint_range(0.02, 2.0) = 0.35;
// Tears per metre. Higher = finer, papery; lower = big torn chunks.
uniform float tear_scale : hint_range(0.2, 12.0) = 2.6;
// The plaster the sliced wall shows where you look down into it.
uniform vec4 section_color : source_color = vec4(0.937, 0.882, 0.804, 1.0);
// The fringe darkens as it thins out, the way a torn paper edge catches the light.
uniform vec4 edge_color : source_color = vec4(0.42, 0.31, 0.21, 1.0);
// The wall dips a little lower right where the player stands, so the shop makes way.
uniform vec3 player_pos = vec3(0.0, -999.0, 0.0);
uniform float dip : hint_range(0.0, 1.5) = 0.25;
uniform float dip_radius : hint_range(0.2, 8.0) = 1.8;

varying vec3 world_pos;


float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	// Two octaves: the coarse one makes the edge wander along the wall, the fine one
	// frays it. Sampled in world space, so the tear is nailed to the wall, not to the
	// screen — a screen-space dither would crawl as the camera eases after the player
	// and would turn into black speckle under the outline pass.
	float reach = length((world_pos - player_pos).xz);
	float h = cut_height - dip * (1.0 - smoothstep(0.0, dip_radius, reach));
	float t = (world_pos.y - h) / band;
	float fringe = 0.0;
	if (t > 0.0) {
		vec2 p = world_pos.xz * tear_scale + world_pos.y * 0.8;
		float n = 0.62 * vnoise(p) + 0.38 * vnoise(p * 3.7);
		if (t >= 1.0 || n < t) {
			discard;
		}
		fringe = smoothstep(0.0, 1.0, t) * 0.55;
	}

	vec2 uv = UV * uv1_scale.xy + uv1_offset.xy;
	if (FRONT_FACING) {
		ALBEDO = mix(albedo.rgb * texture(albedo_tex, uv).rgb, edge_color.rgb, fringe);
		ROUGHNESS = rough_tex_on ? texture(rough_tex, uv).g * roughness : roughness;
		METALLIC = metallic;
		if (normal_on) {
			NORMAL_MAP = texture(normal_tex, uv).rgb;
			NORMAL_MAP_DEPTH = normal_strength;
		}
	} else {
		// Looking down into the slab: solid plaster, no cap geometry needed.
		ALBEDO = mix(section_color.rgb, edge_color.rgb, fringe);
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
	}
}

shader_type spatial;
// A cut-away wall that FADES OUT at the top instead of ending in a flat saw line.
//
// The street fronts are cut at 1.1 m in Blender (build_v8_grandpa.py, CUT = 1.1) and the
// upper half is hidden while you are inside. What is left reads as a wall someone sawed
// in half: a hard horizontal edge with a dark cap sitting on it. This eases that edge
// out — the wall is solid up to `fade_from`, then thins away to nothing by `cut_height`,
// so it dissolves into the room rather than stopping.
//
// `depth_prepass_alpha` is the important render mode. The mostly-solid part of the wall
// still goes through the depth pre-pass, so the screen-space outline pass sees a real
// surface there and the street behind does not get its silhouettes inked over the wall —
// the trap documented in scenes/world/roof_manager.gd. The thin top of the fade falls
// below the pre-pass cutoff, so it draws no line of its own and the fade stays soft.
//
// Everything above the Cutaway group just replays a glTF metallic-roughness material,
// so a converted wall looks identical to its imported one until the fade comes down.
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Paper (PaperWorld, scenes/world/paper_world.gd): with `paper_on` the solid wall is drawn
// in the world's paper (paper_world.gdshaderinc) instead of the glTF material, its texture
// softened by `paper_flatten`; the fade, the haze and the cut section stay as they are.
#include "res://assets/shaders/face_sdf.gdshaderinc"
#include "res://assets/shaders/paper_mache.gdshaderinc"
#include "res://assets/shaders/paper_world.gdshaderinc"

uniform bool paper_on = false;
uniform float paper_flatten = 2.5;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool normal_on = false;
uniform float normal_map_strength : hint_range(0.0, 4.0) = 1.0;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool rough_tex_on = false;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

group_uniforms Cutaway;
// World Y the wall has faded away to nothing by. Parked far above the roof (the node's
// `up_height`) when the wall is whole, eased down to sill height when you step inside.
uniform float cut_height = 99.0;
// Metres below `cut_height` where the wall starts thinning. Bigger = softer, longer melt.
uniform float fade_band : hint_range(0.05, 3.0) = 0.55;
// How far the fade line wanders up and down, in METRES. 0 = a ruled, level line.
uniform float wobble : hint_range(0.0, 1.5) = 0.18;
// Wobbles per metre along the wall.
uniform float wobble_scale : hint_range(0.1, 6.0) = 0.9;
// What is left of the wall dims a touch as it thins, so the fade has some body to it
// rather than just going see-through.
uniform vec4 haze_color : source_color = vec4(0.90, 0.86, 0.78, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.35;
// The plaster the slab shows where you can still see down into its open top.
uniform vec4 section_color : source_color = vec4(0.937, 0.882, 0.804, 1.0);
// The wall thins a little sooner right where the player stands, so the shop makes way.
uniform vec3 player_pos = vec3(0.0, -999.0, 0.0);
uniform float dip : hint_range(0.0, 1.5) = 0.0;
uniform float dip_radius : hint_range(0.2, 8.0) = 1.8;
// Back faces are drawn (for the plaster section above), which means the hidden back of
// every sill, frame and plinth sitting flush on a wall now shares that wall's plane and
// fights it for the pixel. They are pushed this much further away (a share of the
// reverse-Z depth, about a centimetre at the camera's distance) so a back face only ever
// shows where nothing else is in front of it.
uniform float back_depth_bias = 0.0007;

varying vec3 world_pos;
varying vec3 world_nrm;


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
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	// Where this column of wall gives out: the cut height, pulled down a little by the
	// player standing near it, and wandering along the wall so it is not a ruled line.
	// The wander is sampled in world space, so it is nailed to the wall and does not
	// crawl as the camera eases after the player.
	float reach = length((world_pos - player_pos).xz);
	float h = cut_height - dip * (1.0 - smoothstep(0.0, dip_radius, reach));
	h += wobble * 2.0 * (vnoise(world_pos.xz * wobble_scale) - 0.5);
	// 0 where the wall is still solid, 1 where it has gone.
	float t = clamp((world_pos.y - (h - fade_band)) / max(fade_band, 0.001), 0.0, 1.0);
	float a = 1.0 - smoothstep(0.0, 1.0, t);

	vec2 uv = UV * uv1_scale.xy + uv1_offset.xy;
	if (FRONT_FACING && paper_on) {
		vec3 base = albedo.rgb * texture(albedo_tex, uv, paper_flatten).rgb;
		vec3 nrm;
		base = paper_world(base, world_pos, world_nrm, NORMAL, VERTEX, nrm);
		NORMAL = nrm;
		ALBEDO = mix(base, haze_color.rgb, (1.0 - a) * haze);
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
		SPECULAR = 0.0;
		DEPTH = FRAGCOORD.z;
	} else if (FRONT_FACING) {
		vec3 base = albedo.rgb * texture(albedo_tex, uv).rgb;
		ALBEDO = mix(base, haze_color.rgb, (1.0 - a) * haze);
		ROUGHNESS = rough_tex_on ? texture(rough_tex, uv).g * roughness : roughness;
		METALLIC = metallic;
		if (normal_on) {
			NORMAL_MAP = texture(normal_tex, uv).rgb;
			NORMAL_MAP_DEPTH = normal_map_strength;
		}
		DEPTH = FRAGCOORD.z;
	} else {
		DEPTH = FRAGCOORD.z * (1.0 - back_depth_bias);
		// Looking down into the open top of the slab: plaster, not a dark hollow.
		ALBEDO = mix(section_color.rgb, haze_color.rgb, (1.0 - a) * haze);
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
	}
	ALPHA = a;
}

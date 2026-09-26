shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

// Window glass that lets the sun in (PaperWorld swaps it onto every material named
// "glass"): see-through, a faint tint of its old colour, and no shadow of its own, so the
// light falls through the panes onto the floor.

uniform vec4 tint : source_color = vec4(0.85, 0.93, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	if (IN_SHADOW_PASS) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = opacity;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}

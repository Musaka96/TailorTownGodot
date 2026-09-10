shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, specular_disabled;

// Inverted-hull outline, meant as a next_pass on the cloth material: the hull is grown
// along the normals and its front faces are culled, so only the back faces show — a solid
// dark rim around every garment part's silhouette (lapels, hem, collar, the line where the
// jacket sits over the shirt, jacket-over-pants, etc.), which reads each suit element apart.

uniform float outline_width = 0.006;  // metres the hull grows along the normal
uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.07, 1.0);

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}

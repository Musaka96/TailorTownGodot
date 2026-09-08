shader_type spatial;

// Silhouette outline for the currently-focused interactable. Applied as a
// MeshInstance3D `material_overlay` (per-instance, so it never touches shared
// materials). Renders the back faces grown along their normals, so only a thin
// rim spills past the object's edges — a clean cartoon outline that suits the
// cozy atelier look. Unshaded and depth-tested so it hugs the real silhouette.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.788, 0.635, 0.290, 1.0);
// Thickness in view space, so it stays roughly constant on screen regardless of
// how far the object is or how big its mesh is.
uniform float thickness = 4.0;

void vertex() {
	// Grow the vertex along its normal in view space, scaled by distance so the
	// rim keeps a steady on-screen width.
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float px = thickness * 0.001 * -view.z;
	view.xyz += n * px;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}

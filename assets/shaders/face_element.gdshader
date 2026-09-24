shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, depth_test_default;

// One procedural face element (eye / brow / nose / mouth) on a rig face Sprite3D. Every
// look parameter is an instance uniform, so this one material serves every character;
// FaceStyle.apply() pushes the values with set_instance_shader_parameter. Godot allows
// at most 16 instance uniforms per shader, hence the packed fp0..fp5 / fc0..fc3 vectors (their
// meaning per element is documented in FaceStyle.pack()). Pixels under alpha 0.5 are
// discarded to match the old alpha-cut sprites.

#include "res://assets/shaders/face_sdf.gdshaderinc"

instance uniform int element = 0;
instance uniform vec4 fp0 = vec4(0.0);
instance uniform vec4 fp1 = vec4(0.0);
instance uniform vec4 fp2 = vec4(0.0);
instance uniform vec4 fp3 = vec4(0.0);
instance uniform vec4 fp4 = vec4(0.0);
instance uniform vec4 fp5 = vec4(0.0);
instance uniform vec4 fc0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
instance uniform vec4 fc1 : source_color = vec4(1.0);
instance uniform vec4 fc2 : source_color = vec4(1.0);
instance uniform vec4 fc3 : source_color = vec4(1.0);

void fragment() {
	vec2 q = face_q(UV);
	float px = 0.5 * (fwidth(q.x) + fwidth(q.y));
	vec4 col = face_element(element, q, px, fp0, fp1, fp2, fp3, fp4, fp5, fc0, fc1, fc2, fc3);
	if (col.a < 0.5) {
		discard;
	}
	ALBEDO = col.rgb;
}

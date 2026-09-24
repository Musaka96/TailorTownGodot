shader_type canvas_item;

// 2D twin of face_element.gdshader for the review sheets (tools/shot_faces.gd): same
// packed parameters as plain uniforms, one ShaderMaterial per element. `alpha_cut` makes
// it draw like the in-game alpha-cut sprite (hard edges) instead of soft-edged.

#include "res://assets/shaders/face_sdf.gdshaderinc"

uniform int element = 0;
uniform vec4 fp0 = vec4(0.0);
uniform vec4 fp1 = vec4(0.0);
uniform vec4 fp2 = vec4(0.0);
uniform vec4 fp3 = vec4(0.0);
uniform vec4 fp4 = vec4(0.0);
uniform vec4 fp5 = vec4(0.0);
uniform vec4 fc0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 fc1 : source_color = vec4(1.0);
uniform vec4 fc2 : source_color = vec4(1.0);
uniform vec4 fc3 : source_color = vec4(1.0);
uniform bool alpha_cut = false;

void fragment() {
	vec2 q = face_q(UV);
	float px = 0.5 * (fwidth(q.x) + fwidth(q.y));
	vec4 col = face_element(element, q, px, fp0, fp1, fp2, fp3, fp4, fp5, fc0, fc1, fc2, fc3);
	if (alpha_cut) {
		col.a = col.a < 0.5 ? 0.0 : 1.0;
	}
	COLOR = col;
}

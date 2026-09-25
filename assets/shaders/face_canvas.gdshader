shader_type canvas_item;

// 2D twin of skin_face.gdshader for the review sheets (tools/shot_faces.gd): one square
// rect draws a whole cut-paper face, the head disc itself a paper piece lying on the page
// with its shadow, the FaceStyle pieces on it (face_paper.gdshaderinc, the same code the
// head runs). The disc is the reference head: 1 face unit across, `pad` face units fill the
// rect. `zoom` / `zoom_center` look closer at one spot (the paper treatment sheet). The disc
// is the skin's paper (`skin_grain`, no sheet paper); the pieces' sheet paper normal is shown
// under a fixed light from the top left (PIECE_TEX_SHADE: brightness per unit of slope along it).

#define PIECE_TEX_SHADE 0.2
#include "res://assets/shaders/face_paper.gdshaderinc"

uniform vec4 page_color : source_color = vec4(0.969, 0.945, 0.902, 1.0);
uniform vec4 skin_color : source_color = vec4(0.949, 0.788, 0.651, 1.0);
uniform float skin_grain = 0.1;
uniform float pad = 1.1;
uniform float zoom = 1.0;
uniform vec2 zoom_center = vec2(0.0);

void fragment() {
	vec2 p = (UV - 0.5) * pad / max(zoom, 1e-3) + zoom_center;
	float px = 0.5 * (fwidth(p.x) + fwidth(p.y));
	vec2 sh = p - paper_shadow_offset;
	float d = length(p) - 0.5 + paper_cut(p, 3.1416, 1.0, 0.0);
	float ds = length(sh) - 0.5 + paper_cut(sh, 3.1416, 1.0, 0.0);
	vec3 skin = skin_color.rgb;
	vec3 col = paper_piece_ex(page_color.rgb, d, d, ds, skin, skin_grain, p, 0.0, px, 0.0);
	if (d < 0.02) {
		// flat sheet: the pieces' step is not lit here
		float lift = 0.0;
		float sheet = 0.0;
		float still = 0.0;
		col = face_paper(col, p, px, 1.0, lift, sheet, still);
	}
	COLOR = vec4(col, 1.0);
}

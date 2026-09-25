shader_type spatial;
render_mode cull_back, specular_disabled;

// A flat paper surface for the rest of a cut-paper character (docs/FACE_STYLE_GUIDE.md,
// "Paper skin and hair"): the hands/arms skin and the hair. Lit like the rig's flat
// material (matte: roughness 1, no metal, no specular), one flat colour with the face's
// paper grain (face_sdf.gdshaderinc, paper_surface) at the mesh's own UV1, so it stays on
// the surface as the rig walks and turns. `tile` = face units per UV unit, set per mesh
// family so the fibres come out the same size as on the face (CharacterRig.PAPER_TILE_*).

#include "res://assets/shaders/face_sdf.gdshaderinc"

uniform vec4 fill_color : source_color = vec4(0.86, 0.72, 0.6, 1.0);
uniform float tile = 1.35;
uniform float grain = 0.1;
// keeps two surfaces' grain apart (skin 0, hair 1)
uniform float seed = 0.0;

void fragment() {
	ALBEDO = paper_surface(fill_color.rgb, UV, tile, grain, seed);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

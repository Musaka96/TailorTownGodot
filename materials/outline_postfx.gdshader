shader_type spatial;

render_mode
	unshaded,
	fog_disabled,
	depth_draw_never,
	depth_test_disabled,
	cull_disabled;


// ============================================================
// SCREEN-SPACE OBJECT OUTLINE
// ============================================================
//
// Draws one clean black line around the SILHOUETTE of each object and nothing on the
// inside. It finds edges from DEPTH discontinuities: depth is continuous across a hard
// crease or a seam between two sub-meshes of the same object (which is why an
// inverted-hull outline drew lines between the suit's jacket/shirt/pants), but it jumps
// at a real object boundary. So only true silhouettes get a line.
//
// Interior creases are available too via `crease_strength`, but that is 0 by default.
//
// This runs as a full-screen quad parented to the camera by the Outline autoload, because
// only a `spatial` shader can read the depth buffer (a CanvasLayer one cannot).
//
// ============================================================

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;


group_uniforms Outline;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Line width, in pixels.
uniform float thickness : hint_range(0.5, 8.0, 0.1) = 1.6;

// Overall strength of the line (0 = invisible, 1 = solid).
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;


group_uniforms Detection;

// How big a depth jump counts as an edge. LOWER = more lines (more sensitive).
uniform float depth_threshold : hint_range(0.001, 0.5, 0.001) = 0.02;

// Softness of the line's edge. 0 = hard/aliased, higher = smoother.
uniform float edge_softness : hint_range(0.0, 2.0, 0.01) = 0.6;

// Suppresses false lines across surfaces seen at a steep angle (floors, walls receding
// from the camera naturally have a big depth slope). 0 = off, 1 = strongest.
uniform float grazing_guard : hint_range(0.0, 1.0, 0.01) = 0.75;

// Interior creases from normals. Keep at 0 for pure silhouettes (what you asked for);
// raise it if you ever want folds/corners drawn too.
uniform float crease_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float crease_threshold : hint_range(0.0, 1.0, 0.01) = 0.35;


group_uniforms Distance;

// Lines fade out between these distances (metres) so the far background stays clean.
uniform float fade_start : hint_range(0.0, 200.0, 0.5) = 30.0;
uniform float fade_end : hint_range(0.0, 400.0, 0.5) = 80.0;


void vertex()
{
	// Cover the screen: the quad is 2x2, so VERTEX.xy is already in clip space.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


float linear_depth(vec2 uv, mat4 inv_proj)
{
	float d = texture(depth_tex, uv).x;

	vec3 ndc = vec3(uv * 2.0 - 1.0, d);

	vec4 view = inv_proj * vec4(ndc, 1.0);

	return -(view.xyz / view.w).z;
}


vec3 view_normal(vec2 uv)
{
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}


void fragment()
{
	vec2 uv = SCREEN_UV;

	vec3 base = texture(screen_tex, uv).rgb;

	// Spatial shaders have VIEWPORT_SIZE (SCREEN_PIXEL_SIZE is canvas_item only).
	vec2 px = thickness / VIEWPORT_SIZE;

	float dc = linear_depth(uv, INV_PROJECTION_MATRIX);

	// Roberts cross around the pixel.
	float d0 = linear_depth(uv + vec2(px.x, px.y), INV_PROJECTION_MATRIX);
	float d1 = linear_depth(uv + vec2(-px.x, -px.y), INV_PROJECTION_MATRIX);
	float d2 = linear_depth(uv + vec2(px.x, -px.y), INV_PROJECTION_MATRIX);
	float d3 = linear_depth(uv + vec2(-px.x, px.y), INV_PROJECTION_MATRIX);

	float dd = max(
		max(abs(d0 - dc), abs(d1 - dc)),
		max(abs(d2 - dc), abs(d3 - dc))
	);

	// Relative to distance, so far-away objects don't get thicker detection.
	float rel = dd / max(dc, 0.001);

	// Raise the threshold on steeply-angled surfaces to kill false lines on the floor.
	vec3 n = view_normal(uv);
	float facing = clamp(abs(n.z), 0.05, 1.0);
	float thr = depth_threshold / mix(1.0, facing, grazing_guard);

	float line = smoothstep(thr, thr * (1.0 + edge_softness), rel);

	// Optional interior creases (off by default).
	if (crease_strength > 0.0)
	{
		vec3 n0 = view_normal(uv + vec2(px.x, px.y));
		vec3 n1 = view_normal(uv + vec2(-px.x, -px.y));
		vec3 n2 = view_normal(uv + vec2(px.x, -px.y));
		vec3 n3 = view_normal(uv + vec2(-px.x, px.y));

		float nd = max(
			max(1.0 - dot(n, n0), 1.0 - dot(n, n1)),
			max(1.0 - dot(n, n2), 1.0 - dot(n, n3))
		);

		float crease = smoothstep(crease_threshold, crease_threshold + 0.25, nd);

		line = max(line, crease * crease_strength);
	}

	// Distance fade.
	line *= 1.0 - smoothstep(fade_start, fade_end, dc);

	float amount = clamp(line, 0.0, 1.0) * opacity * outline_color.a;

	ALBEDO = mix(base, outline_color.rgb, amount);
}

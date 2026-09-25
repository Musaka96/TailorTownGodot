// A CRT tube warming up over whatever is drawn beneath it: a dot, a white line
// across the middle, the picture opening out of the line, then the scanlines,
// curve and colour fringe settling away. `progress` runs 0 (black) to 1 (clear).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_count = 270.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float t = progress;
	float line_in = smoothstep(0.0, 0.14, t);  // the line runs out sideways
	float open = smoothstep(0.14, 0.42, t);  // the picture opens vertically
	open = 1.0 - pow(1.0 - open, 3.0);
	float settle = smoothstep(0.38, 1.0, t);  // the tube calms down

	// Barrel curve of the glass, easing flat as it settles.
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float bend = 0.10 * (1.0 - settle);
	c *= 1.0 + bend * dot(c, c);
	uv = c + 0.5;

	float half_w = mix(0.002, 0.5, line_in);
	float half_h = mix(0.0015, 0.5, open);
	float px_h = SCREEN_PIXEL_SIZE.y;

	// Soft edges on the lit area, so the line has a glow rather than a hard cut.
	float edge_y = 1.0 - smoothstep(half_h, half_h + px_h * 3.0 + 0.01 * (1.0 - open), abs(c.y));
	float edge_x = 1.0 - smoothstep(half_w - 0.02, half_w + 0.01, abs(c.x));
	float lit = edge_y * edge_x;

	// The picture is squashed into the lit band and stretches as it opens.
	vec2 src = vec2(uv.x, 0.5 + c.y * (0.5 / half_h));
	float ca = 0.006 * (1.0 - settle);
	vec3 col;
	col.r = texture(screen, vec2(src.x + ca, src.y)).r;
	col.g = texture(screen, src).g;
	col.b = texture(screen, vec2(src.x - ca, src.y)).b;
	if (src.y < 0.0 || src.y > 1.0 || uv.x < 0.0 || uv.x > 1.0) {
		col = vec3(0.0);
	}

	// Overbright while the phosphor is hot: pure white at the line, fading to the image.
	float white = 1.0 - smoothstep(0.1, 0.5, t);
	col = mix(col * (1.0 + 1.2 * (1.0 - settle)), vec3(1.0, 0.98, 0.94), white);

	// Scanlines, flicker and a vignette that all ease out.
	float scan = 0.5 + 0.5 * sin(SCREEN_UV.y * scanline_count * 6.2831853);
	col *= 1.0 - 0.35 * (1.0 - settle) * scan;
	float flicker = hash(vec2(floor(TIME * 30.0), 1.7)) - 0.5;
	col *= 1.0 + 0.12 * flicker * (1.0 - settle);
	float vig = 1.0 - dot(c, c) * 1.6 * (1.0 - settle);
	col *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(col * lit, 1.0);
}

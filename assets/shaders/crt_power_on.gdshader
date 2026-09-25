// A CRT tube switching on over whatever is drawn beneath it: a white line across the
// middle, the picture opening out of the line, the glare fading off. Scanlines only
// show while it opens; once open the picture is clean. `progress` runs 0 (black) to 1.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_count = 270.0;

void fragment() {
	float t = progress;
	float line_in = smoothstep(0.0, 0.2, t);  // the line runs out sideways
	line_in = 1.0 - pow(1.0 - line_in, 2.0);
	float open = smoothstep(0.18, 0.6, t);  // the picture opens vertically
	open = 1.0 - pow(1.0 - open, 3.0);
	float glare = 1.0 - smoothstep(0.15, 0.75, t);  // white-hot, cooling to the picture

	vec2 c = SCREEN_UV - 0.5;
	float half_w = mix(0.0, 0.5, line_in);
	float half_h = mix(0.0015, 0.5, open);
	float px_h = SCREEN_PIXEL_SIZE.y;

	// Soft edges on the lit band so the line glows; they sharpen to nothing when open.
	float soft_y = px_h * 2.0 + 0.012 * (1.0 - open);
	float lit_y = 1.0 - smoothstep(half_h, half_h + soft_y, abs(c.y));
	float lit_x = 1.0 - smoothstep(half_w - 0.03 * (1.0 - line_in), half_w + 0.002, abs(c.x));
	float lit = open >= 0.999 ? 1.0 : lit_y * lit_x;

	// The picture is squashed into the band and stretches as it opens.
	vec2 src = vec2(SCREEN_UV.x, 0.5 + c.y * (0.5 / half_h));
	vec3 col = texture(screen, clamp(src, 0.0, 1.0)).rgb;
	col = mix(col * (1.0 + 0.8 * glare), vec3(1.0, 0.98, 0.94), glare * glare);

	float scan = 0.5 + 0.5 * sin(SCREEN_UV.y * scanline_count * 6.2831853);
	col *= 1.0 - 0.3 * (1.0 - open) * scan;

	COLOR = vec4(col * lit, 1.0);
}

shader_type canvas_item;
render_mode unshaded;

// Full-screen stylise pass: 70s/80s TV/CRT/VHS retro looks AND "cute 3D" looks
// (Animal-Crossing-style tilt-shift diorama, posterised storybook, pixel-toy).
// Applied by the PostFX autoload on a screen-reading ColorRect above everything.
// Every effect is gated by a strength/size uniform (0 = off) that the PostFxProfile
// resource drives, so the whole look is data-editable. See globals/postfx.gd.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float master_strength : hint_range(0.0, 1.0) = 1.0;

// Colour grade.
uniform float temperature : hint_range(-1.0, 1.0) = 0.0;  // warm(+) / cool(-)
uniform float tint : hint_range(-1.0, 1.0) = 0.0;  // green(+) / magenta(-)
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

// Film emulation (0 none,1 Kodachrome,2 VHS,3 Sepia,4 Technicolor,5 B&W,6 Green,7 Amber).
uniform int film_preset = 0;
uniform float film_strength : hint_range(0.0, 1.0) = 0.0;

// Stylise ("cute 3D").
uniform float pixel_size : hint_range(0.0, 24.0) = 0.0;  // block size in px (<2 = off)
uniform float posterize_levels : hint_range(0.0, 32.0) = 0.0;  // colour steps (<2 = off)
uniform float tilt_shift : hint_range(0.0, 1.0) = 0.0;  // miniature/diorama blur
uniform float tilt_focus : hint_range(0.0, 1.0) = 0.5;  // vertical focus band centre
uniform float tilt_focus_size : hint_range(0.0, 1.0) = 0.18;  // sharp band half-height
uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;  // soft ink edges

// Screen effects (retro).
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_count : hint_range(0.0, 2000.0) = 480.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 1.0) = 0.0;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.0;
uniform float barrel : hint_range(0.0, 1.0) = 0.0;
uniform float vhs_strength : hint_range(0.0, 1.0) = 0.0;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


vec3 scr(vec2 uv) {
	return texture(screen_tex, uv).rgb;
}


// CRT tube curvature: push pixels outward from the centre by the squared radius.
vec2 barrel_uv(vec2 uv, float amt) {
	vec2 cc = uv - 0.5;
	return uv + cc * dot(cc, cc) * amt;
}


// 9-tap box blur, radius in pixels — used for the tilt-shift out-of-focus areas.
vec3 box_blur(vec2 uv, float radius) {
	vec2 px = radius / vec2(textureSize(screen_tex, 0));
	vec3 c = scr(uv);
	c += scr(uv + vec2(px.x, 0.0));
	c += scr(uv - vec2(px.x, 0.0));
	c += scr(uv + vec2(0.0, px.y));
	c += scr(uv - vec2(0.0, px.y));
	c += scr(uv + px * 0.7071);
	c += scr(uv - px * 0.7071);
	c += scr(uv + vec2(px.x, -px.y) * 0.7071);
	c += scr(uv + vec2(-px.x, px.y) * 0.7071);
	return c / 9.0;
}


// Cheap bloom: 4-tap cross average, kept only where it is already bright.
vec3 bloom(vec2 uv) {
	vec2 o = 2.0 / vec2(textureSize(screen_tex, 0));
	vec3 b = scr(uv + vec2(o.x, 0.0)) + scr(uv - vec2(o.x, 0.0));
	b += scr(uv + vec2(0.0, o.y)) + scr(uv - vec2(0.0, o.y));
	b *= 0.25;
	return b * smoothstep(0.55, 1.0, dot(b, LUMA));
}


vec3 grade(vec3 c) {
	c.r += temperature * 0.10;
	c.b -= temperature * 0.10;
	c.g += tint * 0.10;
	c += brightness;
	c = (c - 0.5) * contrast + 0.5;
	c = mix(vec3(dot(c, LUMA)), c, saturation);
	return c;
}


vec3 film_look(vec3 c, int p) {
	float l = dot(c, LUMA);
	if (p == 1) {  // Kodachrome: warm, rich, deep primaries
		vec3 k = vec3(pow(c.r, 0.9) * 1.06, c.g, c.b * 0.90);
		return clamp(mix(vec3(l), k, 1.30), 0.0, 1.0);
	} else if (p == 2) {  // VHS: desaturated, cool shadows, warm highs
		vec3 v = mix(vec3(l), c, 0.80);
		v.b += 0.05 * (1.0 - l);
		v.r += 0.04 * l;
		return clamp(v, 0.0, 1.0);
	} else if (p == 3) {  // Sepia old-TV
		return clamp(vec3(l * 1.07 + 0.10, l * 0.90 + 0.05, l * 0.66), 0.0, 1.0);
	} else if (p == 4) {  // Technicolor: exaggerated channel separation
		return clamp(
			vec3(
				c.r * 1.4 - (c.g + c.b) * 0.2,
				c.g * 1.4 - (c.r + c.b) * 0.2,
				c.b * 1.4 - (c.r + c.g) * 0.2
			),
			0.0,
			1.0
		);
	} else if (p == 5) {  // Black & white
		return vec3(clamp(l, 0.0, 1.0));
	} else if (p == 6) {  // Green phosphor monitor
		return vec3(l * 0.12, clamp(l * 1.15, 0.0, 1.0), l * 0.12);
	} else if (p == 7) {  // Amber monochrome
		return vec3(clamp(l * 1.15, 0.0, 1.0), l * 0.72, l * 0.12);
	}
	return c;
}


void fragment() {
	vec2 res = vec2(textureSize(screen_tex, 0));
	vec2 raw = SCREEN_UV;
	vec2 uv = barrel_uv(raw, barrel * 0.35);
	// VHS horizontal tracking wobble (per-scanline jitter over time).
	uv.x += (hash(vec2(floor(uv.y * 160.0), floor(TIME * 15.0))) - 0.5) * vhs_strength * 0.02;
	// Pixelate: snap the sampling coordinate to a block grid.
	if (pixel_size >= 2.0) {
		vec2 grid = res / pixel_size;
		uv = (floor(uv * grid) + 0.5) / grid;
	}

	vec3 col;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		col = vec3(0.0);  // outside the curved tube = black bezel
	} else {
		vec2 dir = uv - 0.5;
		float amt = aberration * 0.006;
		col.r = scr(uv + dir * amt).r;
		col.g = scr(uv).g;
		col.b = scr(uv - dir * amt).b;

		col += bloom(uv) * bloom_strength;

		// Tilt-shift diorama: sharp focus band, blur ramping toward top/bottom.
		if (tilt_shift > 0.001) {
			float t = smoothstep(
				tilt_focus_size, tilt_focus_size + 0.28, abs(raw.y - tilt_focus)
			);
			if (t > 0.001) {
				col = mix(col, box_blur(uv, tilt_shift * 10.0), t);
			}
		}

		col = grade(col);
		col = mix(col, film_look(col, film_preset), film_strength);

		// Posterise: quantise each channel to N steps for a flat storybook look.
		if (posterize_levels >= 2.0) {
			col = floor(col * posterize_levels) / (posterize_levels - 1.0);
		}

		// Soft ink outline from screen-space luma edges.
		if (outline_strength > 0.001) {
			vec2 px = 1.0 / res;
			float l0 = dot(scr(uv), LUMA);
			float e = abs(l0 - dot(scr(uv + vec2(px.x, 0.0)), LUMA));
			e += abs(l0 - dot(scr(uv + vec2(0.0, px.y)), LUMA));
			col *= 1.0 - clamp(e * 6.0, 0.0, 1.0) * outline_strength;
		}

		float sl = 0.5 + 0.5 * sin(uv.y * scanline_count * TAU);
		col *= 1.0 - scanline_strength * (1.0 - sl);

		col += (hash(raw * vec2(1280.0, 720.0) + fract(TIME)) - 0.5) * grain_strength;

		float vig = smoothstep(0.85, 0.35, distance(raw, vec2(0.5)));
		col *= mix(1.0, vig, vignette_strength);

		col *= 1.0 - flicker_strength * 0.06 * (0.5 + 0.5 * sin(TIME * 48.0));
	}

	COLOR = vec4(mix(scr(SCREEN_UV), col, master_strength), 1.0);
}

shader_type spatial;

render_mode
	cull_disabled,
	diffuse_burley,
	specular_disabled;


// ============================================================
// CARPET TEXTURE
// ============================================================

uniform sampler2D carpet_texture : source_color, filter_linear, repeat_enable;


// ============================================================
// PLUSH
// ============================================================

uniform float bump_height = 0.006;
uniform float bump_scale = 12.0;
uniform float plush_roundness = 0.75;

uniform float fiber_scale = 140.0;
uniform float fiber_strength = 0.22;

uniform float depth_shading = 0.18;


// ============================================================
// CUTE STYLE
// ============================================================

uniform float color_variation = 0.06;
uniform float pattern_softness = 0.15;
uniform float pattern_brightness = 1.0;


// ============================================================
// WEAVE
// ============================================================

uniform float weave_strength = 0.12;
uniform float weave_scale = 100.0;


varying float carpet_height;


// ============================================================
// HASH
// ============================================================

float hash(vec2 p)
{
	p = fract(p * vec2(
		123.34,
		456.21
	));

	p += dot(
		p,
		p + 45.32
	);

	return fract(
		p.x * p.y
	);
}


// ============================================================
// BASIC NOISE
// ============================================================

float noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (
		3.0 -
		2.0 * f
	);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}


// ============================================================
// SOFT NOISE
// ============================================================

float soft_noise(vec2 p)
{
	float n = 0.0;

	n += noise(p) * 0.55;
	n += noise(p * 2.0) * 0.25;
	n += noise(p * 4.0) * 0.12;
	n += noise(p * 8.0) * 0.08;

	return n;
}


// ============================================================
// PLUSH HEIGHT
// ============================================================
//
// Instead of sharp spikes, we make broad rounded hills.
// This is the important part that makes it feel like fabric.
//
// ============================================================

float plush_height(vec2 uv)
{
	float large = noise(
		uv * bump_scale
	);

	float medium = noise(
		uv * bump_scale * 2.0
	);

	float fine = noise(
		uv * fiber_scale
	);


	// Make the noise form rounded "puffs".
	float rounded = large;

	rounded = pow(
		rounded,
		mix(
			1.0,
			2.5,
			plush_roundness
		)
	);


	// Blend in medium-scale surface variation.
	rounded += (
		medium -
		0.5
	) * 0.18;


	// Very subtle fiber-scale movement.
	rounded += (
		fine -
		0.5
	) * fiber_strength * 0.08;


	return rounded;
}


// ============================================================
// VERTEX
// ============================================================

void vertex()
{
	float h = plush_height(UV);

	// Center around zero.
	h -= 0.5;

	// Very soft physical deformation.
	VERTEX.y += h * bump_height;

	carpet_height = h;
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment()
{
	// ========================================================
	// BASE PATTERN
	// ========================================================

	vec3 carpet = texture(
		carpet_texture,
		UV
	).rgb;


	// Slightly soften the texture.
	vec3 softened = mix(
		carpet,
		vec3(
			dot(
				carpet,
				vec3(
					0.299,
					0.587,
					0.114
				)
			)
		),
		pattern_softness * 0.12
	);

	carpet = mix(
		carpet,
		softened,
		pattern_softness
	);


	// ========================================================
	// CUTE COLOR VARIATION
	// ========================================================

	float variation = noise(
		UV * 9.0
	);

	variation = mix(
		1.0 - color_variation,
		1.0 + color_variation,
		variation
	);

	carpet *= variation;


	// ========================================================
	// WOVEN FIBERS
	// ========================================================
	//
	// Two perpendicular soft lines give the surface a tiny
	// woven/fabric character.
	//

	float weave_x = noise(
		vec2(
			UV.x * weave_scale,
			UV.y * 8.0
		)
	);

	float weave_y = noise(
		vec2(
			UV.x * 8.0,
			UV.y * weave_scale
		)
	);

	float weave = (
		weave_x +
		weave_y
	) * 0.5;

	weave = mix(
		1.0,
		mix(
			0.94,
			1.06,
			weave
		),
		weave_strength
	);

	carpet *= weave;


	// ========================================================
	// PLUSH DEPTH
	// ========================================================

	float depth = carpet_height;

	float depth_factor =
		1.0 +
		depth *
		depth_shading *
		3.0;

	carpet *= depth_factor;


	// ========================================================
	// FINAL
	// ========================================================

	ALBEDO = carpet * pattern_brightness;

	ROUGHNESS = 1.0;

	SPECULAR = 0.0;
}
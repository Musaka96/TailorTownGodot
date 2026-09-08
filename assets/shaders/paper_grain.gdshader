shader_type canvas_item;

// Aged-newsprint overlay for the Gazette: fine fibres, broad foxing/mottle, a
// couple of soft stains, one faint coffee ring, and darkened edges. It only paints
// translucent ink over darker patches, so it tints whatever paper colour sits
// behind it (the panel's fill) rather than replacing it. Keep `strength` subtle.

uniform vec4 ink : source_color = vec4(0.24, 0.17, 0.10, 1.0);
uniform float strength = 0.22;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float grain = fbm(uv * vec2(240.0, 150.0)) - 0.5;  // fine paper fibres
	float mottle = fbm(uv * 6.0) - 0.5;  // broad foxing blotches
	// Two soft stains.
	float st = smoothstep(0.13, 0.0, distance(uv, vec2(0.80, 0.18)));
	st += smoothstep(0.10, 0.0, distance(uv, vec2(0.16, 0.82)));
	// One faint coffee ring.
	float d = distance(uv, vec2(0.72, 0.70));
	float ring = smoothstep(0.02, 0.0, abs(d - 0.08)) * smoothstep(0.13, 0.05, d);
	// Aged, darkened edges.
	float edge = smoothstep(0.5, 0.02, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	float dark = 0.10 * grain + 0.22 * max(mottle, 0.0) + 0.14 * st + 0.18 * ring + 0.16 * edge;
	dark = clamp(dark, 0.0, 1.0);
	COLOR = vec4(ink.rgb, dark * strength);
}

shader_type spatial;

render_mode diffuse_burley, specular_disabled, cull_disabled;


uniform vec4 grass_dark : source_color =
	vec4(0.24, 0.48, 0.12, 1.0);

uniform vec4 grass_light : source_color =
	vec4(0.45, 0.67, 0.18, 1.0);

uniform vec4 grass_yellow : source_color =
	vec4(0.68, 0.72, 0.22, 1.0);


uniform float wind_strength = 0.025;

uniform float wind_speed = 1.0;


void vertex()
{
	float height = UV.y;


	float wind = sin(
		TIME * wind_speed
		+ VERTEX.x * 5.0
		+ VERTEX.z * 3.0
	);


	VERTEX.x +=
		wind
		* wind_strength
		* height
		* height;
}


void fragment()
{
	vec3 color = mix(
		grass_dark.rgb,
		grass_light.rgb,
		UV.y
	);


	float yellow = smoothstep(
		0.55,
		1.0,
		UV.y
	);


	color = mix(
		color,
		grass_yellow.rgb,
		yellow * 0.18
	);


	ALBEDO = color;

	ROUGHNESS = 1.0;
}
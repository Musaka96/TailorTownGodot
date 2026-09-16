shader_type spatial;

render_mode diffuse_burley, specular_disabled, cull_disabled;


/* =========================================================
   BASE GRASS
   ========================================================= */

uniform vec4 base_color : source_color =
	vec4(0.32, 0.62, 0.18, 1.0);

uniform vec4 base_variation_color : source_color =
	vec4(0.36, 0.66, 0.20, 1.0);

uniform float base_variation_strength : hint_range(0.0, 1.0, 0.01) = 0.08;


/* =========================================================
   LEAF COLORS
   ========================================================= */

uniform vec4 leaf_color_1 : source_color =
	vec4(0.45, 0.72, 0.20, 1.0);

uniform vec4 leaf_color_2 : source_color =
	vec4(0.52, 0.76, 0.24, 1.0);

uniform vec4 leaf_color_3 : source_color =
	vec4(0.39, 0.67, 0.16, 1.0);


/* =========================================================
   LEAF GENERATION
   ========================================================= */

/*
	How frequently decorative motifs appear.
*/

uniform float leaf_density : hint_range(0.0, 1.0, 0.01) = 0.24;


/*
	Size of individual leaf motifs.
*/

uniform float leaf_size : hint_range(0.05, 1.0, 0.01) = 0.18;


/*
	Overall pattern scale.

	Low values  = larger motifs / wider spacing
	High values = smaller motifs / tighter spacing
*/

uniform float texture_scale : hint_range(1.0, 30.0, 0.5) = 7.0;


/*
	Changes the random arrangement.
*/

uniform float random_seed = 12.37;


/* =========================================================
   RANDOM
   ========================================================= */

float hash(vec2 p)
{
	return fract(
		sin(
			dot(
				p,
				vec2(127.1, 311.7)
			)
			+ random_seed
		)
		* 43758.5453
	);
}


/* =========================================================
   SUBTLE BASE VARIATION
   ========================================================= */

float smooth_noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	float x1 = mix(a, b, f.x);
	float x2 = mix(c, d, f.x);

	return mix(x1, x2, f.y);
}


/* =========================================================
   ROTATION
   ========================================================= */

vec2 rotate_2d(vec2 p, float angle)
{
	float s = sin(angle);
	float c = cos(angle);

	return vec2(
		p.x * c - p.y * s,
		p.x * s + p.y * c
	);
}


/* =========================================================
   LEAF SHAPE
   ========================================================= */

float leaf_shape(
	vec2 p,
	vec2 position,
	float angle,
	float size
)
{
	p -= position;

	p = rotate_2d(p, angle);

	/*
		Make the leaf elongated.
	*/

	p.y /= 1.55;


	/*
		Rounded body.
	*/

	float distance_from_center =
		length(
			p / vec2(size, size)
		);

	float shape =
		1.0 - smoothstep(
			0.58,
			1.0,
			distance_from_center
		);


	/*
		Slight taper toward the top.
	*/

	float point_factor =
		smoothstep(
			0.0,
			size,
			p.y
		);

	shape *= mix(
		1.0,
		1.0 - point_factor,
		0.35
	);

	return shape;
}


/* =========================================================
   LEAF CLUSTER
   ========================================================= */

float leaf_cluster(
	vec2 p,
	vec2 cell
)
{
	/*
		Random position inside the area.
	*/

	float random_x =
		hash(cell + vec2(14.7, 8.3));

	float random_y =
		hash(cell + vec2(31.2, 19.6));

	vec2 position =
		vec2(
			mix(-0.40, 0.40, random_x),
			mix(-0.40, 0.40, random_y)
		);


	/*
		Decide whether this area gets
		a decorative motif.
	*/

	float chance =
		hash(cell + vec2(52.8, 41.7));

	if (chance > leaf_density)
	{
		return 0.0;
	}


	/*
		Random rotation.
	*/

	float angle =
		hash(cell + vec2(72.1, 63.4))
		* 6.28318;


	/*
		Random size variation.
	*/

	float size =
		leaf_size *
		mix(
			0.65,
			1.15,
			hash(cell + vec2(91.4, 22.8))
		);


	float mask = 0.0;


	/*
		Three leaves form one little
		grass/leaf decoration.
	*/

	mask = max(
		mask,
		leaf_shape(
			p,
			position + vec2(-0.08, -0.03),
			angle - 0.55,
			size
		)
	);


	mask = max(
		mask,
		leaf_shape(
			p,
			position + vec2(0.08, -0.03),
			angle + 0.55,
			size
		)
	);


	mask = max(
		mask,
		leaf_shape(
			p,
			position + vec2(0.0, 0.07),
			angle,
			size
		)
	);


	return mask;
}


/* =========================================================
   FRAGMENT
   ========================================================= */

void fragment()
{
	/*
		Create the decorative pattern space.
	*/

	vec2 pattern_uv =
		UV * texture_scale;


	vec2 cell =
		floor(pattern_uv);


	vec2 local_uv =
		fract(pattern_uv) - 0.5;


	/* =====================================================
	   BASE GRASS
	   ===================================================== */

	float subtle_variation =
		smooth_noise(
			UV * texture_scale * 0.35
		);


	vec3 grass =
		mix(
			base_color.rgb,
			base_variation_color.rgb,
			subtle_variation * base_variation_strength
		);


	/* =====================================================
	   LEAF MOTIFS
	   ===================================================== */

	for (int x = -1; x <= 1; x++)
	{
		for (int y = -1; y <= 1; y++)
		{
			vec2 neighbor_cell =
				cell + vec2(
					float(x),
					float(y)
				);


			vec2 neighbor_offset =
				vec2(
					float(x),
					float(y)
				);


			vec2 relative_position =
				local_uv - neighbor_offset;


			float leaves =
				leaf_cluster(
					relative_position,
					neighbor_cell
				);


			/* =============================================
			   RANDOM LEAF COLOR
			   ============================================= */

			float color_random =
				hash(
					neighbor_cell
					+ vec2(200.0, 137.0)
				);


			vec3 leaf_color;


			if (color_random < 0.33)
			{
				leaf_color =
					leaf_color_1.rgb;
			}
			else if (color_random < 0.66)
			{
				leaf_color =
					leaf_color_2.rgb;
			}
			else
			{
				leaf_color =
					leaf_color_3.rgb;
			}


			/* =============================================
			   APPLY LEAF
			   ============================================= */

			grass =
				mix(
					grass,
					leaf_color,
					leaves
				);
		}
	}


	/* =====================================================
	   FINAL MATERIAL
	   ===================================================== */

	ALBEDO = grass;

	ROUGHNESS = 1.0;
}
@tool
extends MultiMeshInstance3D


@export_category("Clump Settings")

@export var patch_size: Vector2 = Vector2(10.0, 10.0)

@export_range(10, 1000, 10)
var clump_amount: int = 180

@export_range(0.1, 1.0, 0.01)
var clump_width: float = 0.35

@export_range(0.1, 2.0, 0.01)
var clump_height: float = 0.55

@export_range(0.0, 1.0, 0.01)
var height_variation: float = 0.35


@export_category("Random")

@export var random_seed: int = 54321


@export_category("Generate")

@export_tool_button("Generate Clumps", "Callable")
var generate_button = generate_clumps


func _ready() -> void:
	generate_clumps()


func generate_clumps() -> void:

	var new_mesh := create_clump_mesh()

	var new_multimesh := MultiMesh.new()

	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D

	new_multimesh.mesh = new_mesh

	new_multimesh.instance_count = clump_amount


	var rng := RandomNumberGenerator.new()

	rng.seed = random_seed


	for i in range(clump_amount):

		var x: float = rng.randf_range(
			-patch_size.x * 0.5,
			patch_size.x * 0.5
		)

		var z: float = rng.randf_range(
			-patch_size.y * 0.5,
			patch_size.y * 0.5
		)


		var random_height: float = rng.randf_range(
			1.0 - height_variation,
			1.0 + height_variation
		)


		var final_height: float = clump_height * random_height

		var final_width: float = clump_width * rng.randf_range(
			0.8,
			1.2
		)


		var rotation_y: float = rng.randf_range(
			0.0,
			TAU
		)


		var transform := Transform3D.IDENTITY


		transform = transform.scaled(
			Vector3(
				final_width,
				final_height,
				final_width
			)
		)


		transform = transform.rotated(
			Vector3.UP,
			rotation_y
		)


		transform.origin = Vector3(
			x,
			0.0,
			z
		)


		new_multimesh.set_instance_transform(
			i,
			transform
		)


	multimesh = new_multimesh


	print("Generated ", clump_amount, " grass clumps.")


func create_clump_mesh() -> ArrayMesh:

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()


	# --------------------------------------------------
	# Make 7 broad curved blades around the center.
	# --------------------------------------------------

	var blade_count := 7


	for blade in range(blade_count):

		var angle: float = (
			float(blade) / float(blade_count)
		) * TAU


		var direction := Vector3(
			cos(angle),
			0.0,
			sin(angle)
		)


		var side := Vector3(
			-direction.z,
			0.0,
			direction.x
		)


		# Each blade gets a slightly different size.

		var width: float = 0.45

		var height: float = 0.85


		if blade % 3 == 0:
			height = 1.0
		elif blade % 3 == 1:
			height = 0.75


		# Slightly different outward bend.

		var bend: float = 0.18


		# --------------------------------------------------
		# Five sections make the blade rounded.
		# --------------------------------------------------

		var sections := 5

		var start_index: int = vertices.size()


		for section in range(sections):

			var t: float = (
				float(section)
				/ float(sections - 1)
			)


			# Wide in the middle, narrow at the tip.

			var width_factor: float


			if t < 0.2:

				width_factor = lerp(
					0.25,
					1.0,
					t / 0.2
				)

			elif t > 0.72:

				width_factor = lerp(
					1.0,
					0.0,
					(t - 0.72) / 0.28
				)

			else:

				width_factor = 1.0


			var current_width: float = (
				width
				* width_factor
			)


			# Curve the blade outward.

			var forward: float = (
				sin(t * PI * 0.5)
				* bend
			)


			var y: float = (
				t
				* height
			)


			var center := (
				direction
				* forward
			)


			var left := (
				center
				- side * current_width
			)


			var right := (
				center
				+ side * current_width
			)


			vertices.append(left)
			vertices.append(right)


			normals.append(Vector3.UP)
			normals.append(Vector3.UP)


			uvs.append(
				Vector2(0.0, t)
			)

			uvs.append(
				Vector2(1.0, t)
			)


		# --------------------------------------------------
		# Connect the blade sections.
		# --------------------------------------------------

		for section in range(sections - 1):

			var current: int = (
				start_index
				+ section * 2
			)

			var next: int = current + 2


			indices.append(current)
			indices.append(current + 1)
			indices.append(next)


			indices.append(current + 1)
			indices.append(next + 1)
			indices.append(next)


	# --------------------------------------------------
	# Build mesh.
	# --------------------------------------------------

	var arrays: Array = []

	arrays.resize(Mesh.ARRAY_MAX)


	arrays[Mesh.ARRAY_VERTEX] = vertices

	arrays[Mesh.ARRAY_NORMAL] = normals

	arrays[Mesh.ARRAY_TEX_UV] = uvs

	arrays[Mesh.ARRAY_INDEX] = indices


	var mesh := ArrayMesh.new()


	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)


	return mesh

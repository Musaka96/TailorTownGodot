@tool
extends MultiMeshInstance3D


@export_category("Edge Settings")

@export var patch_size: Vector2 = Vector2(10.0, 10.0)

@export_range(10, 3000, 10)
var blade_amount: int = 800

@export_range(0.05, 1.0, 0.01)
var blade_width: float = 0.18

@export_range(0.05, 1.5, 0.01)
var blade_height: float = 0.38

@export_range(0.0, 2.0, 0.01)
var edge_width: float = 0.5

@export_range(0.0, 0.5, 0.01)
var outward_lean: float = 0.12


@export_category("Random")

@export var random_seed: int = 24680


@export_category("Generate")

@export_tool_button("Generate Edge Grass", "Callable")
var generate_button = generate_edge_grass


func _ready() -> void:
	generate_edge_grass()


func generate_edge_grass() -> void:

	var new_mesh := create_blade_mesh()

	var new_multimesh := MultiMesh.new()

	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D

	new_multimesh.mesh = new_mesh

	new_multimesh.instance_count = blade_amount


	var rng := RandomNumberGenerator.new()

	rng.seed = random_seed


	for i in range(blade_amount):

		# Pick one of the four edges.

		var edge: int = rng.randi_range(0, 3)

		var x: float = 0.0
		var z: float = 0.0

		var direction := Vector3.ZERO


		if edge == 0:
			# Front edge

			x = rng.randf_range(
				-patch_size.x * 0.5,
				patch_size.x * 0.5
			)

			z = rng.randf_range(
				-patch_size.y * 0.5 - edge_width,
				-patch_size.y * 0.5 + edge_width
			)

			direction = Vector3(0.0, 0.0, -1.0)


		elif edge == 1:
			# Back edge

			x = rng.randf_range(
				-patch_size.x * 0.5,
				patch_size.x * 0.5
			)

			z = rng.randf_range(
				patch_size.y * 0.5 - edge_width,
				patch_size.y * 0.5 + edge_width
			)

			direction = Vector3(0.0, 0.0, 1.0)


		elif edge == 2:
			# Left edge

			x = rng.randf_range(
				-patch_size.x * 0.5 - edge_width,
				-patch_size.x * 0.5 + edge_width
			)

			z = rng.randf_range(
				-patch_size.y * 0.5,
				patch_size.y * 0.5
			)

			direction = Vector3(-1.0, 0.0, 0.0)


		else:
			# Right edge

			x = rng.randf_range(
				patch_size.x * 0.5 - edge_width,
				patch_size.x * 0.5 + edge_width
			)

			z = rng.randf_range(
				-patch_size.y * 0.5,
				patch_size.y * 0.5
			)

			direction = Vector3(1.0, 0.0, 0.0)


		var height_scale: float = rng.randf_range(0.65, 1.35)

		var width_scale: float = rng.randf_range(0.7, 1.3)

		var rotation_y: float = rng.randf_range(0.0, TAU)


		var transform := Transform3D.IDENTITY


		transform = transform.scaled(
			Vector3(
				blade_width * width_scale,
				blade_height * height_scale,
				blade_width * width_scale
			)
		)


		transform = transform.rotated(
			Vector3.UP,
			rotation_y
		)


		# Lean outward from the terrain.

		var lean_rotation := Basis(
			Vector3.UP,
			0.0
		)


		if direction != Vector3.ZERO:

			var lean_axis := Vector3(
				-direction.z,
				0.0,
				direction.x
			)

			transform = transform.rotated(
				lean_axis,
				-outward_lean
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


	print(
		"Generated ",
		blade_amount,
		" edge grass blades."
	)


func create_blade_mesh() -> ArrayMesh:

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# --------------------------------------------------
	# Create a soft leaf-shaped blade.
	#
	# The blade is made from several horizontal sections
	# so it has a little belly instead of being a triangle.
	# --------------------------------------------------

	var width := 0.65
	var height := 1.0

	var sections := 5

	for i in range(sections):

		var t: float = float(i) / float(sections - 1)

		# Width is widest around the lower-middle section.
		var width_factor: float = sin(t * PI) * 0.5 + 0.5

		# Make the bottom fairly narrow, middle wider,
		# and tip narrow again.
		if t < 0.25:
			width_factor = lerp(0.35, 1.0, t / 0.25)
		elif t > 0.75:
			width_factor = lerp(1.0, 0.0, (t - 0.75) / 0.25)

		var current_width: float = width * width_factor

		# Slight forward bend as the blade gets taller.
		var bend: float = sin(t * PI * 0.5) * 0.18

		var y: float = height * t

		var left := Vector3(
			-current_width,
			y,
			bend
		)

		var right := Vector3(
			current_width,
			y,
			bend
		)

		vertices.append(left)
		vertices.append(right)

		normals.append(Vector3.UP)
		normals.append(Vector3.UP)

		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))


	# --------------------------------------------------
	# Connect the sections.
	# --------------------------------------------------

	for i in range(sections - 1):

		var current: int = i * 2
		var next: int = (i + 1) * 2

		indices.append(current)
		indices.append(current + 1)
		indices.append(next)

		indices.append(current + 1)
		indices.append(next + 1)
		indices.append(next)


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

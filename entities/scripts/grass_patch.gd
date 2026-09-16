@tool
extends Node3D


# =========================================================
# GRASS SETTINGS
# =========================================================

@export_category("Grass Settings")

@export var patch_size: Vector2 = Vector2(10.0, 10.0)

@export_range(10, 3000, 10)
var grass_amount: int = 500

@export_range(0.05, 1.0, 0.01)
var tuft_width: float = 0.18

@export_range(0.05, 1.5, 0.01)
var tuft_height: float = 0.38

@export_range(0.0, 1.0, 0.01)
var height_variation: float = 0.75


# =========================================================
# RANDOM
# =========================================================

@export_category("Random")

@export var random_seed: int = 12345


# =========================================================
# GENERATE BUTTON
# =========================================================

@export_category("Generate")

@export_tool_button("Generate Grass", "Callable")
var generate_button = generate_grass


# =========================================================
# GENERATE
# =========================================================

func _ready() -> void:
	generate_grass()


func generate_grass() -> void:

	var grass_node = $GrassTufts

	if grass_node == null:
		push_warning("GrassTufts node was not found.")
		return

	if not grass_node is MultiMeshInstance3D:
		push_warning("GrassTufts must be a MultiMeshInstance3D.")
		return


	# Create the actual grass mesh.

	var grass_mesh = create_grass_mesh()


	# Create MultiMesh.

	var multimesh := MultiMesh.new()

	multimesh.transform_format = MultiMesh.TRANSFORM_3D

	multimesh.mesh = grass_mesh

	multimesh.instance_count = grass_amount


	# Random generator.

	var rng := RandomNumberGenerator.new()

	rng.seed = random_seed


	# Create all grass instances.

	for i in range(grass_amount):

		# Random position.

		var x = rng.randf_range(
			-patch_size.x * 0.5,
			patch_size.x * 0.5
		)

		var z = rng.randf_range(
			-patch_size.y * 0.5,
			patch_size.y * 0.5
		)


		# Random height.

		var random_height = rng.randf_range(
			1.0 - height_variation,
			1.0 + height_variation
		)

		var final_height = tuft_height * random_height


		# Random width.

		var final_width = rng.randf_range(
			tuft_width * 0.75,
			tuft_width * 1.25
		)


		# Random rotation.

		var rotation_y = rng.randf_range(
			0.0,
			TAU
		)


		# Create transform.

		var transform := Transform3D.IDENTITY


		# Scale the grass first.

		transform = transform.scaled(
			Vector3(
				final_width,
				final_height,
				final_width
			)
		)


		# Rotate the grass.

		transform = transform.rotated(
			Vector3.UP,
			rotation_y
		)


		# IMPORTANT:
		# Set the position LAST so scaling does not
		# shrink the grass distribution toward the center.

		transform.origin = Vector3(
			x,
			0.0,
			z
		)


		# Store instance.

		multimesh.set_instance_transform(
			i,
			transform
		)


	# Give MultiMesh to GrassTufts.

	grass_node.multimesh = multimesh

	print("Generated ", grass_amount, " grass tufts.")


# =========================================================
# CREATE GRASS MESH
# =========================================================

func create_grass_mesh() -> ArrayMesh:

	var vertices := PackedVector3Array()

	var normals := PackedVector3Array()

	var uvs := PackedVector2Array()

	var indices := PackedInt32Array()


	var w: float = 0.5
	var h: float = 1.0


	# =====================================================
	# BLADE 1
	# =====================================================

	var base: int = vertices.size()


	vertices.append(
		Vector3(-w, 0.0, 0.0)
	)

	vertices.append(
		Vector3(w, 0.0, 0.0)
	)

	vertices.append(
		Vector3(0.0, h, 0.0)
	)


	normals.append(Vector3.UP)
	normals.append(Vector3.UP)
	normals.append(Vector3.UP)


	uvs.append(Vector2(0.0, 0.0))
	uvs.append(Vector2(1.0, 0.0))
	uvs.append(Vector2(0.5, 1.0))


	indices.append(base + 0)
	indices.append(base + 1)
	indices.append(base + 2)


	# =====================================================
	# BLADE 2
	# =====================================================

	base = vertices.size()


	vertices.append(
		Vector3(0.0, 0.0, -w)
	)

	vertices.append(
		Vector3(0.0, 0.0, w)
	)

	vertices.append(
		Vector3(0.0, h, 0.0)
	)


	normals.append(Vector3.UP)
	normals.append(Vector3.UP)
	normals.append(Vector3.UP)


	uvs.append(Vector2(0.0, 0.0))
	uvs.append(Vector2(1.0, 0.0))
	uvs.append(Vector2(0.5, 1.0))


	indices.append(base + 0)
	indices.append(base + 1)
	indices.append(base + 2)


	# =====================================================
	# BUILD MESH
	# =====================================================

	var arrays: Array = []

	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices

	arrays[Mesh.ARRAY_NORMAL] = normals

	arrays[Mesh.ARRAY_TEX_UV] = uvs

	arrays[Mesh.ARRAY_INDEX] = indices


	var array_mesh := ArrayMesh.new()


	array_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)


	return array_mesh

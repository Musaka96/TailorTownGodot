@tool
extends Node3D

## A ground patch with scattered grass + flower sprites.
##
## FloraElement.count represents the amount of flora on a 3x3 patch.
##
## The scatter is deterministic:
## - Resizing the patch does NOT move existing flora.
## - Making the patch larger adds flora in the new area.
## - Making the patch smaller removes flora outside the new area.
## - Changing scatter_seed creates a new layout.
##
## Each FloraElement maintains its own density/settings.


const BASE_PATCH_SIZE: Vector2 = Vector2(3.0, 3.0)
const BASE_PATCH_AREA: float = 9.0

# Smaller cells = more possible positions.
const SCATTER_CELL_SIZE: float = 0.5

# Number of possible positions inside each cell.
const SLOTS_PER_CELL: int = 4


@export var patch_size: Vector2 = Vector2(3.0, 3.0):
	set(value):
		patch_size = value
		_rebuild()


@export var ground_material: Material:
	set(value):
		ground_material = value
		_rebuild()


@export_group("Wind")


@export var wind_velocity: Vector2 = Vector2(1.0, 0.4):
	set(value):
		wind_velocity = value
		_rebuild()


@export_group("Scatter")


## The plants.
##
## count = amount of this flora on a 3x3 patch.
@export var elements: Array[FloraElement] = []:
	set(value):
		_disconnect_elements()
		elements = value
		_rebuild()


@export var scatter_seed: int = 7:
	set(value):
		scatter_seed = value
		_rebuild()


var _wind_noise: NoiseTexture2D

# True once this instance owns its own (non-shared) ground mesh.
var _own_mesh: bool = false


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var ground: MeshInstance3D = get_node_or_null("Ground") as MeshInstance3D

	if ground != null:
		# Give THIS instance its own PlaneMesh, cloned once, BEFORE resizing it — so
		# changing one patch's size never edits the ground of the other patches (a shared
		# sub-resource would be mutated by every instance at once).
		if not (ground.mesh is PlaneMesh):
			ground.mesh = PlaneMesh.new()
			_own_mesh = true
		elif not _own_mesh:
			ground.mesh = (ground.mesh as PlaneMesh).duplicate()
			_own_mesh = true

		(ground.mesh as PlaneMesh).size = patch_size

		if ground_material != null:
			ground.material_override = ground_material

	_scatter()


func _scatter() -> void:
	var container: Node = get_node_or_null("Flora")

	if container == null:
		return

	# Remove previous generated flora.
	for child: Node in container.get_children():
		child.queue_free()

	if _wind_noise == null:
		_wind_noise = _make_wind_noise()

	var patch_area: float = patch_size.x * patch_size.y

	var area_multiplier: float = (
		patch_area /
		BASE_PATCH_AREA
	)

	var idx: int = 0

	for el: FloraElement in elements:
		if el == null:
			continue

		# Update automatically when this FloraElement changes.
		if not el.changed.is_connected(_rebuild):
			el.changed.connect(_rebuild)

		# Count is based on a 3x3 patch.
		var target_count: int = maxi(
			roundi(
				float(el.count) *
				area_multiplier
			),
			0
		)

		var layer: Node = _build_layer(
			el,
			idx,
			target_count
		)

		container.add_child(layer)

		idx += 1


func _build_layer(
	el: FloraElement,
	idx: int,
	target_count: int
) -> Node:

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()

	mmi.name = "Elem%d" % idx

	var flat: bool = el.horizontal

	var quad: QuadMesh = QuadMesh.new()

	quad.size = Vector2(
		el.width,
		el.height
	)

	# Upright cards pivot at their base.
	# Flat cards lie centred on the ground.
	if flat:
		quad.center_offset = Vector3.ZERO
	else:
		quad.center_offset = Vector3(
			0.0,
			el.height * 0.5,
			0.0
		)

	var positions: Array[Vector3] = _generate_positions(
		el,
		idx,
		target_count
	)

	var mm: MultiMesh = MultiMesh.new()

	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = positions.size()

	for i: int in positions.size():

		var pos: Vector3 = positions[i]

		# Generate deterministic size/rotation based on
		# the position.
		var random_data: Vector2 = _position_random(
			pos.x,
			pos.z,
			idx
		)

		var s: float = lerp(
			el.size_min,
			el.size_max,
			random_data.x
		)

		var rotation: float = (
			random_data.y *
			TAU
		)

		var basis: Basis = Basis(
			Vector3.UP,
			rotation
		)

		if flat:
			basis = basis * Basis(
				Vector3.RIGHT,
				-PI * 0.5
			)

		basis = basis.scaled(
			Vector3(s, s, s)
		)

		mm.set_instance_transform(
			i,
			Transform3D(
				basis,
				pos
			)
		)

	mmi.multimesh = mm

	mmi.material_override = _flora_material(
		el,
		flat
	)

	return mmi


func _generate_positions(
	el: FloraElement,
	idx: int,
	target_count: int
) -> Array[Vector3]:

	var positions: Array[Vector3] = []

	if target_count <= 0:
		return positions

	var hx: float = patch_size.x * 0.5
	var hz: float = patch_size.y * 0.5

	var density: float = (
		float(el.count) /
		BASE_PATCH_AREA
	)

	if density <= 0.0:
		return positions

	var cell_area: float = (
		SCATTER_CELL_SIZE *
		SCATTER_CELL_SIZE
	)

	# Expected amount of flora per cell.
	var expected_per_cell: float = (
		density *
		cell_area
	)

	# Probability that each slot gets used.
	var probability: float = (
		expected_per_cell /
		float(SLOTS_PER_CELL)
	)

	probability = clamp(
		probability,
		0.0,
		1.0
	)

	var min_cell_x: int = floori(
		-hx / SCATTER_CELL_SIZE
	)

	var max_cell_x: int = ceili(
		hx / SCATTER_CELL_SIZE
	)

	var min_cell_z: int = floori(
		-hz / SCATTER_CELL_SIZE
	)

	var max_cell_z: int = ceili(
		hz / SCATTER_CELL_SIZE
	)

	for cell_x: int in range(
		min_cell_x,
		max_cell_x + 1
	):

		for cell_z: int in range(
			min_cell_z,
			max_cell_z + 1
		):

			for slot: int in SLOTS_PER_CELL:

				var random_data: Vector3 = _cell_random(
					cell_x,
					cell_z,
					slot,
					idx
				)

				# Decide if this slot contains flora.
				if random_data.x > probability:
					continue

				var px: float = (
					float(cell_x) +
					random_data.y
				) * SCATTER_CELL_SIZE

				var pz: float = (
					float(cell_z) +
					random_data.z
				) * SCATTER_CELL_SIZE

				# Keep the position inside the patch.
				if px < -hx or px > hx:
					continue

				if pz < -hz or pz > hz:
					continue

				positions.append(
					Vector3(
						px,
						0.0,
						pz
					)
				)

	# Don't exceed requested amount.
	if positions.size() > target_count:
		positions.resize(target_count)

	return positions


func _cell_random(
	cell_x: int,
	cell_z: int,
	slot: int,
	layer: int
) -> Vector3:

	# Use separate deterministic hashes for each random value.
	#
	# IMPORTANT:
	# We mask the hash to 32 bits so the values remain
	# predictable and convert correctly to 0-1.

	var h1: int = _hash_int(
		cell_x,
		cell_z,
		slot,
		layer,
		0
	)

	var h2: int = _hash_int(
		cell_x,
		cell_z,
		slot,
		layer,
		1
	)

	var h3: int = _hash_int(
		cell_x,
		cell_z,
		slot,
		layer,
		2
	)

	return Vector3(
		_hash_to_float(h1),
		_hash_to_float(h2),
		_hash_to_float(h3)
	)


func _position_random(
	x: float,
	z: float,
	layer: int
) -> Vector2:

	# Quantize the position so the same plant always gets
	# the same random size and rotation.

	var ix: int = roundi(x * 1000.0)
	var iz: int = roundi(z * 1000.0)

	var h1: int = _hash_int(
		ix,
		iz,
		layer,
		0,
		10
	)

	var h2: int = _hash_int(
		ix,
		iz,
		layer,
		0,
		20
	)

	return Vector2(
		_hash_to_float(h1),
		_hash_to_float(h2)
	)


func _hash_int(
	a: int,
	b: int,
	c: int,
	d: int,
	e: int
) -> int:

	# Combine the inputs into a deterministic 32-bit hash.

	var value: int = (
		a * 374761393 +
		b * 668265263 +
		c * 1274126177 +
		d * 2246822519 +
		e * 3266489917 +
		scatter_seed * 1442695041
	)

	# Force the value into unsigned 32-bit range.
	value = value & 0xFFFFFFFF

	# Integer mixing.
	value = value ^ (value >> 16)
	value = (value * 0x45D9F3B) & 0xFFFFFFFF

	value = value ^ (value >> 16)
	value = (value * 0x45D9F3B) & 0xFFFFFFFF

	value = value ^ (value >> 16)
	value = value & 0xFFFFFFFF

	return value


func _hash_to_float(value: int) -> float:
	# Convert 32-bit integer into a clean 0-1 value.

	var normalized: float = (
		float(value) /
		4294967295.0
	)

	return clamp(
		normalized,
		0.0,
		1.0
	)


func _flora_material(
	el: FloraElement,
	flat: bool
) -> ShaderMaterial:

	var m: ShaderMaterial = ShaderMaterial.new()

	m.shader = load(
		"res://materials/flora.gdshader"
	)

	m.set_shader_parameter(
		"color_texture",
		el.color_texture
	)

	m.set_shader_parameter(
		"mask_texture",
		el.mask_texture
	)

	m.set_shader_parameter(
		"tint",
		el.tint
	)

	m.set_shader_parameter(
		"billboard",
		el.billboard and not flat
	)

	m.set_shader_parameter(
		"wind_noise",
		_wind_noise
	)

	m.set_shader_parameter(
		"wind_velocity",
		wind_velocity
	)

	m.set_shader_parameter(
		"sway",
		el.sway
	)

	return m


func _disconnect_elements() -> void:

	for el: FloraElement in elements:

		if el != null and el.changed.is_connected(_rebuild):
			el.changed.disconnect(_rebuild)


func _make_wind_noise() -> NoiseTexture2D:

	var n: FastNoiseLite = FastNoiseLite.new()

	n.frequency = 0.4

	var t: NoiseTexture2D = NoiseTexture2D.new()

	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n

	return t

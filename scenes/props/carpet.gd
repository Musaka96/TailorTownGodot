@tool
extends Node3D

## Cute stylized carpet.
##
## Uses a single subdivided plane with a procedural plush/fabric shader.
## No individual strands are generated.
##
## The shader creates:
## - soft rounded carpet bumps
## - subtle fuzzy fibers
## - woven directional variation
## - soft valley shading
## - gentle color variation
##
## The old "Tufts" node is automatically hidden.


@export_group("Carpet")

@export var carpet_texture: Texture2D:
	set(value):
		carpet_texture = value
		_rebuild()


@export var rug_size: Vector2 = Vector2(2.4, 1.6):
	set(value):
		rug_size = value
		_rebuild()


@export_group("Plush Surface")


## Overall height of the carpet bumps.
@export_range(0.0, 0.03, 0.0005) var bump_height: float = 0.006:
	set(value):
		bump_height = value
		_rebuild()


## Size of the large soft bumps.
@export_range(2.0, 60.0, 1.0) var bump_scale: float = 12.0:
	set(value):
		bump_scale = value
		_rebuild()


## Roundness of the larger bumps.
@export_range(0.0, 1.0, 0.01) var plush_roundness: float = 0.75:
	set(value):
		plush_roundness = value
		_rebuild()


## Fine fuzzy detail.
@export_range(20.0, 500.0, 1.0) var fiber_scale: float = 140.0:
	set(value):
		fiber_scale = value
		_rebuild()


## Amount of tiny fiber variation.
@export_range(0.0, 1.0, 0.01) var fiber_strength: float = 0.22:
	set(value):
		fiber_strength = value
		_rebuild()


## How dark the valleys become.
@export_range(0.0, 1.0, 0.01) var depth_shading: float = 0.18:
	set(value):
		depth_shading = value
		_rebuild()


@export_group("Cute Style")


## Slight soft color variation across the carpet.
@export_range(0.0, 0.25, 0.01) var color_variation: float = 0.06:
	set(value):
		color_variation = value
		_rebuild()


## Softness of the carpet pattern.
@export_range(0.0, 1.0, 0.01) var pattern_softness: float = 0.15:
	set(value):
		pattern_softness = value
		_rebuild()


## Overall brightness.
@export_range(0.0, 2.0, 0.01) var pattern_brightness: float = 1.0:
	set(value):
		pattern_brightness = value
		_rebuild()


@export_group("Woven Fibers")


## Directional woven appearance.
@export_range(0.0, 1.0, 0.01) var weave_strength: float = 0.12:
	set(value):
		weave_strength = value
		_rebuild()


@export_range(10.0, 300.0, 1.0) var weave_scale: float = 100.0:
	set(value):
		weave_scale = value
		_rebuild()


@export_group("Geometry")


## Subdivision needed for the subtle physical deformation.
@export_range(16, 128, 1) var subdivisions: int = 64:
	set(value):
		subdivisions = value
		_rebuild()


var _material: ShaderMaterial


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var backing: MeshInstance3D = get_node_or_null(
		"Backing"
	) as MeshInstance3D

	if backing == null:
		return

	# --------------------------------------------------------
	# IMPORTANT:
	# Disable the old individual tuft geometry.
	# --------------------------------------------------------

	var tufts: Node3D = get_node_or_null(
		"Tufts"
	) as Node3D

	if tufts != null:
		tufts.visible = false


	_update_mesh(backing)
	_update_material(backing)


func _update_mesh(backing: MeshInstance3D) -> void:

	var mesh: PlaneMesh = backing.mesh as PlaneMesh

	if mesh == null:
		mesh = PlaneMesh.new()
		backing.mesh = mesh

	mesh.size = rug_size

	# Enough geometry for subtle plush deformation.
	mesh.subdivide_width = subdivisions
	mesh.subdivide_depth = subdivisions


func _update_material(backing: MeshInstance3D) -> void:

	if _material == null:
		_material = ShaderMaterial.new()

	if _material.shader == null:
		_material.shader = load(
			"res://materials/carpet.gdshader"
		)

	_material.set_shader_parameter(
		"carpet_texture",
		carpet_texture
	)

	_material.set_shader_parameter(
		"bump_height",
		bump_height
	)

	_material.set_shader_parameter(
		"bump_scale",
		bump_scale
	)

	_material.set_shader_parameter(
		"plush_roundness",
		plush_roundness
	)

	_material.set_shader_parameter(
		"fiber_scale",
		fiber_scale
	)

	_material.set_shader_parameter(
		"fiber_strength",
		fiber_strength
	)

	_material.set_shader_parameter(
		"depth_shading",
		depth_shading
	)

	_material.set_shader_parameter(
		"color_variation",
		color_variation
	)

	_material.set_shader_parameter(
		"pattern_softness",
		pattern_softness
	)

	_material.set_shader_parameter(
		"pattern_brightness",
		pattern_brightness
	)

	_material.set_shader_parameter(
		"weave_strength",
		weave_strength
	)

	_material.set_shader_parameter(
		"weave_scale",
		weave_scale
	)

	backing.material_override = _material

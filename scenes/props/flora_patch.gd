@tool
extends Node3D

## A ground patch with scattered grass + flower sprites. The ground is a matte patchy-green
## plane; on top, each FloraElement in `elements` is scattered as its own MultiMesh of
## wind-swayed sprite cards (its own textures, count/spawn-rate, size range and sway). All
## generated in-editor (@tool) so you tweak and see it live; the scatter is runtime-built and
## not saved into the scene.

@export var patch_size := Vector2(3.0, 3.0):
	set(value):
		patch_size = value
		_rebuild()
## The matte ground material (ground.gdshader). Tweak its patch colours/scale/amount on it.
@export var ground_material: Material:
	set(value):
		ground_material = value
		_rebuild()

@export_group("Wind")
@export var wind_velocity := Vector2(1.0, 0.4):
	set(value):
		wind_velocity = value
		_rebuild()

@export_group("Scatter")
## The plants: add grass/flower layers, each with its own textures, count, size and sway.
@export var elements: Array[FloraElement] = []:
	set(value):
		_disconnect_elements()
		elements = value
		_rebuild()
@export var scatter_seed := 7:
	set(value):
		scatter_seed = value
		_rebuild()

var _wind_noise: NoiseTexture2D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground != null:
		if not (ground.mesh is PlaneMesh):
			ground.mesh = PlaneMesh.new()
		(ground.mesh as PlaneMesh).size = patch_size
		if ground_material != null:
			ground.material_override = ground_material
	_scatter()


func _scatter() -> void:
	var container := get_node_or_null("Flora")
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	if _wind_noise == null:
		_wind_noise = _make_wind_noise()
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var hx := patch_size.x * 0.5
	var hz := patch_size.y * 0.5
	var idx := 0
	for el in elements:
		if el == null:
			continue
		# Live-update when an element's own fields are edited in the inspector.
		if not el.changed.is_connected(_rebuild):
			el.changed.connect(_rebuild)
		container.add_child(_build_layer(el, idx, rng, hx, hz))
		idx += 1


func _build_layer(
	el: FloraElement, idx: int, rng: RandomNumberGenerator, hx: float, hz: float
) -> Node:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Elem%d" % idx
	var quad := QuadMesh.new()
	quad.size = Vector2(el.width, el.height)
	quad.center_offset = Vector3(0, el.height * 0.5, 0)  # sit the card base on the ground
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = maxi(el.count, 0)
	for i in el.count:
		var pos := Vector3(rng.randf_range(-hx, hx), 0.0, rng.randf_range(-hz, hz))
		var s := rng.randf_range(el.size_min, el.size_max)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, pos))
	mmi.multimesh = mm
	mmi.material_override = _flora_material(el)
	return mmi


func _flora_material(el: FloraElement) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/flora.gdshader")
	m.set_shader_parameter("color_texture", el.color_texture)
	m.set_shader_parameter("mask_texture", el.mask_texture)
	m.set_shader_parameter("tint", el.tint)
	m.set_shader_parameter("wind_noise", _wind_noise)
	m.set_shader_parameter("wind_velocity", wind_velocity)
	m.set_shader_parameter("sway", el.sway)
	return m


func _disconnect_elements() -> void:
	for el in elements:
		if el != null and el.changed.is_connected(_rebuild):
			el.changed.disconnect(_rebuild)


func _make_wind_noise() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = 0.4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	return t

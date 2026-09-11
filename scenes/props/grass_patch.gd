@tool
extends Node3D

## Scatters the billboard grass blades over the turf. The blade transforms are generated
## here (not baked into the scene) because a MultiMesh's instance buffer doesn't serialise
## reliably when the scene is authored headlessly.
##
## This is a @tool script, so the blades also appear IN THE EDITOR — open the scene, tweak
## the exports below or the Blades node's Material Override (the grass shader params), and
## the patch updates live in the viewport.

@export var block_size: float = 2.0:
	set(value):
		block_size = value
		_refresh()
@export var blade_count: int = 420:
	set(value):
		blade_count = maxi(value, 0)
		_refresh()
@export var scatter_seed: int = 4242:
	set(value):
		scatter_seed = value
		_refresh()


func _ready() -> void:
	_populate()


## Re-scatter when an export changes in the inspector (guarded so it no-ops during load,
## before the node is in the tree).
func _refresh() -> void:
	if is_inside_tree():
		_populate()


## Fill the MultiMesh with randomly-placed, slightly-varied blades over the turf top.
func _populate() -> void:
	var blades := get_node_or_null("Blades") as MultiMeshInstance3D
	if blades == null or blades.multimesh == null:
		return
	var mm := blades.multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = blade_count
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var h := block_size * 0.5 - 0.08
	for i in blade_count:
		var pos := Vector3(rng.randf_range(-h, h), 0.0, rng.randf_range(-h, h))
		var s := rng.randf_range(0.75, 1.25)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), pos))

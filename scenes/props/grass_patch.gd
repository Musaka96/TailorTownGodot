extends Node3D

## Scatters the billboard grass blades over the turf on load. The blade transforms are
## generated here (not baked into the scene) because a MultiMesh's instance buffer does not
## serialise reliably when the scene is authored headlessly. Tweak the exports in the
## inspector; the patch repopulates when the scene runs.

@export var block_size: float = 2.0
@export var blade_count: int = 420
@export var scatter_seed: int = 4242

@onready var _blades: MultiMeshInstance3D = $Blades


func _ready() -> void:
	_populate()


## Fill the MultiMesh with randomly-placed, slightly-varied blades over the turf top.
func _populate() -> void:
	if _blades == null or _blades.multimesh == null:
		return
	var mm := _blades.multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = blade_count
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var h := block_size * 0.5 - 0.08
	for i in blade_count:
		var pos := Vector3(rng.randf_range(-h, h), 0.0, rng.randf_range(-h, h))
		var s := rng.randf_range(0.75, 1.25)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), pos))

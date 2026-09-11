@tool
extends Node3D

## The rug prop. Its pile is drawn with shell texturing: the "Pile" MultiMesh holds
## `shell_count` copies of the rug plane, and the carpet shader lifts each one along the
## normal and carves it into tufts. This @tool script (re)builds the shells so the pile
## shows and edits live in the editor.
##
## Live pile controls: Rug Size + Shell Count here on the root; the tuft look
## (pile_height, tuft_density, tuft_thickness, tuft_shape, length_variation, base_shade,
## texture/tint/tiling) is on the Pile node's Material Override.

const MAX_SHELLS := 64

@export var rug_size := Vector2(2.4, 1.6):
	set(value):
		rug_size = value
		_rebuild()
## More shells = smoother, denser-looking pile (at the cost of more overdraw).
@export_range(1, MAX_SHELLS) var shell_count := 16:
	set(value):
		shell_count = clampi(value, 1, MAX_SHELLS)
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var pile := get_node_or_null("Pile") as MultiMeshInstance3D
	if pile == null:
		return
	if pile.multimesh == null:
		pile.multimesh = MultiMesh.new()
	var mm := pile.multimesh
	if not (mm.mesh is PlaneMesh):
		mm.mesh = PlaneMesh.new()
	(mm.mesh as PlaneMesh).size = rug_size
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = shell_count
	for i in shell_count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)  # shells are lifted in the shader
	# Keep the shader's shell count in step with the instance count.
	if pile.material_override is ShaderMaterial:
		(pile.material_override as ShaderMaterial).set_shader_parameter("shell_count", shell_count)

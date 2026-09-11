@tool
extends Node3D

## The rug prop. It already previews in the editor (a static mesh), but this @tool script
## adds a root-level Rug Size export so you can resize it live — and the carpet shader
## params (texture, tiling, pile, fringe) live on the Rug node's Material Override.

@export var rug_size := Vector2(2.4, 1.6):
	set(value):
		rug_size = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var rug := get_node_or_null("Rug") as MeshInstance3D
	if rug == null or not (rug.mesh is PlaneMesh):
		return
	(rug.mesh as PlaneMesh).size = rug_size

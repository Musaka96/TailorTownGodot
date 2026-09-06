class_name CameraRig
extends Node3D

## A follow camera for a top-down 3D game.
##
## The rig node tracks the target's position with smooth damping while the child
## Camera3D holds a fixed downward angle. Because only the rig *translates* (it
## never rotates), the camera angle stays constant — that steady, non-swivelling
## framing is what makes a top-down game readable.

## The node to follow (usually the Player). Set per-instance in the scene.
@export var target_path: NodePath
## Follow responsiveness. Higher = the camera catches up faster; lower = looser,
## more cinematic lag. Frame-rate independent.
@export var follow_speed: float = 8.0

@onready var _target: Node3D = get_node_or_null(target_path) as Node3D


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	# Exponential smoothing toward the target; clamped so it can't overshoot on
	# long frames.
	var weight := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(_target.global_position, weight)


## Lets other systems (e.g. a level loader) assign the target at runtime.
func set_target(node: Node3D) -> void:
	_target = node

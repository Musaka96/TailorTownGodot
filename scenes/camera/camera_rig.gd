class_name CameraRig
extends Node3D

## Top-down follow camera that can also smoothly focus on a point (used by the
## mirror's suit builder to frame the customer and zoom to each part).
##
## FOLLOW: the rig tracks the target and the camera eases back to its home
## (top-down) offset. FOCUS: the camera glides to a given eye position looking at
## a given point, independent of the rig.

enum Mode { FOLLOW, FOCUS }

## The node to follow (usually the Player). Set per-instance in the scene.
@export var target_path: NodePath
## Follow responsiveness (frame-rate independent).
@export var follow_speed: float = 8.0
## How fast the camera glides when focusing.
@export var focus_speed: float = 5.0

var _mode := Mode.FOLLOW
var _focus_pos := Vector3.ZERO
var _focus_look := Vector3.ZERO
var _cam_home: Transform3D

@onready var _target: Node3D = get_node_or_null(target_path) as Node3D
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	add_to_group("camera_rig")
	_cam_home = _camera.transform


func _physics_process(delta: float) -> void:
	if _mode == Mode.FOLLOW:
		if _target != null:
			var w := clampf(follow_speed * delta, 0.0, 1.0)
			global_position = global_position.lerp(_target.global_position, w)
		# Ease the camera back to its top-down home pose.
		var cw := clampf(follow_speed * delta, 0.0, 1.0)
		_camera.transform = _camera.transform.interpolate_with(_cam_home, cw)
	else:
		var w := clampf(focus_speed * delta, 0.0, 1.0)
		var dir := _focus_look - _focus_pos
		if dir.length() > 0.01:
			var target := Transform3D(Basis.looking_at(dir, Vector3.UP), _focus_pos)
			_camera.global_transform = _camera.global_transform.interpolate_with(target, w)


## Glide the camera to `eye`, looking at `look`.
func focus(eye: Vector3, look: Vector3) -> void:
	_focus_pos = eye
	_focus_look = look
	_mode = Mode.FOCUS


## Return to following the player.
func unfocus() -> void:
	_mode = Mode.FOLLOW


func set_target(node: Node3D) -> void:
	_target = node

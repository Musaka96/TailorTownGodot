class_name HeadWobble
extends SkeletonModifier3D

## Adds a small extra rotation to the head bone AFTER the AnimationTree has posed the
## skeleton, so a scripted nod/shake turns the real head bone — and everything riding
## on it, the 2D face included — instead of just swinging the face sprites. The
## CharacterRig tweens `pitch` (nod) and `yaw` (shake); both rest at 0.

var bone := -1
var pitch := 0.0  # nod, about the bone's local X
var yaw := 0.0  # shake, about the bone's local Y


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or bone < 0:
		return
	if is_zero_approx(pitch) and is_zero_approx(yaw):
		return
	var extra := Quaternion.from_euler(Vector3(pitch, yaw, 0.0))
	sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone) * extra)

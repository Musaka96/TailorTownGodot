class_name CharacterAnimations
extends Resource

## The editable character-animation asset (data/animations/default_animations.tres).
## A list of AnimEntry rows mapping each gameplay name (idle / walk / wave / accept)
## to a clip inside a source .glb. build_library() bakes them into one runtime
## AnimationLibrary; CharacterRig loads that at _ready via the CharAnims facade, so
## editing this asset changes the animations on the NEXT run — no rebuild command.
##
## To change an animation: open the .tres, pick the row (e.g. "walk"), and set its
## `clip` to another clip in the same pack (Walking_A/B/C, Running_A/B, …). To add
## one: append a row with a new `name`, then play it from code by that name.

const _ANIM_DIR := "res://assets/characters/anim/"
## Calm idle: the "idle" row keeps Idle_A's breathing (spine / chest / head) but hangs
## both arms straight down at the sides and stands the legs as straight columns, a
## figurine stance. false plays the untouched KayKit clip (loose arms, wide left foot).
const CALM_IDLE := true
## How far each calm arm splays out from vertical, so the sleeve clears the jacket.
const CALM_ARM_SPLAY_DEG := 6.0
## Limb bones the calm idle holds still: upper arms in the arms-down pose, the rest at
## their bind pose (the Rig_Medium rest is already straight arms and straight legs).
const _CALM_BONES := [
	"upperarm.l",
	"lowerarm.l",
	"wrist.l",
	"hand.l",
	"upperarm.r",
	"lowerarm.r",
	"wrist.r",
	"hand.r",
	"upperleg.l",
	"lowerleg.l",
	"foot.l",
	"toes.l",
	"upperleg.r",
	"lowerleg.r",
	"foot.r",
	"toes.r",
]
## Bones whose yaw the calm idle drops (Idle_A turns the hips 5 degrees and counters
## with the head), so the figure faces straight ahead; their nod / breathing stays.
const _CALM_FACE_FRONT := ["hips", "head"]

## The mapping rows. Order is display-only; the code plays by `name`.
@export var entries: Array[AnimEntry] = []


## Bake every entry into one AnimationLibrary (clip pulled from its source .glb, its
## Skin binds by bone name so it drives the shared Rig_Medium with no retargeting).
func build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for entry in entries:
		if entry == null or entry.source == null or entry.name == "":
			continue
		var clip := _extract(entry.source, entry.clip, CALM_IDLE and entry.name == "idle")
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR if entry.loop else Animation.LOOP_NONE
			lib.add_animation(entry.name, clip)
	return lib


func _extract(source: PackedScene, clip_name: String, calm := false) -> Animation:
	var inst := source.instantiate()
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	var out: Animation = null
	if not players.is_empty():
		var ap := players[0] as AnimationPlayer
		if ap.has_animation(clip_name):
			out = ap.get_animation(clip_name).duplicate() as Animation
	if out != null and calm and not skels.is_empty():
		_calm(out, skels[0] as Skeleton3D)
	inst.queue_free()
	return out


## Turn an idle clip into the calm idle (see CALM_IDLE), in place. Every track keeps its
## path and type so the idle<->walk blend still lines up; only the key values change.
## Poses come from `skel`'s rest, the skeleton the clip was authored on.
static func _calm(anim: Animation, skel: Skeleton3D) -> void:
	for t in anim.get_track_count():
		var bone_name := String(anim.track_get_path(t).get_subname(0))
		var bone := skel.find_bone(bone_name)
		if bone < 0:
			continue
		var kind := anim.track_get_type(t)
		if kind == Animation.TYPE_ROTATION_3D and bone_name in _CALM_BONES:
			_clear_keys(anim, t)
			anim.rotation_track_insert_key(t, 0.0, _calm_rotation(skel, bone))
		elif kind == Animation.TYPE_ROTATION_3D and bone_name in _CALM_FACE_FRONT:
			for k in anim.track_get_key_count(t):
				var euler := Basis(anim.track_get_key_value(t, k) as Quaternion).get_euler()
				euler.y = 0.0
				anim.track_set_key_value(t, k, Quaternion.from_euler(euler))
		elif kind == Animation.TYPE_POSITION_3D and bone_name == "hips":
			# Straight legs need the hips at rest height, or the feet sink into the
			# floor (Idle_A crouches 1.4-2.2 cm); the breathing lives in the spine.
			_clear_keys(anim, t)
			anim.position_track_insert_key(t, 0.0, skel.get_bone_rest(bone).origin)


## Local rotation holding `bone` still: its rest, except an upper arm, which is swung
## (shortest arc, in the chest's space) so the whole arm, shoulder to hand, points
## straight down with CALM_ARM_SPLAY_DEG of outward splay.
static func _calm_rotation(skel: Skeleton3D, bone: int) -> Quaternion:
	var rest := skel.get_bone_rest(bone).basis.get_rotation_quaternion()
	var bone_name := skel.get_bone_name(bone)
	if not bone_name.begins_with("upperarm"):
		return rest
	var hand := skel.find_bone(bone_name.replace("upperarm", "hand"))
	var chest := skel.get_bone_global_rest(skel.get_bone_parent(bone)).basis
	var shoulder := skel.get_bone_global_rest(bone).origin
	var arm := chest.inverse() * (skel.get_bone_global_rest(hand).origin - shoulder)
	var splay := deg_to_rad(CALM_ARM_SPLAY_DEG)
	var down := Vector3(signf(arm.x) * sin(splay), -cos(splay), 0.0)
	return Quaternion(arm.normalized(), down) * rest


static func _clear_keys(anim: Animation, track: int) -> void:
	while anim.track_get_key_count(track) > 0:
		anim.track_remove_key(track, 0)


## The shipped default set — source for build_animations.gd and the CharAnims
## fallback if the .tres is ever missing. Mirrors the KayKit clips used before.
static func make_default() -> CharacterAnimations:
	var res := CharacterAnimations.new()
	var general := load(_ANIM_DIR + "Rig_Medium_General.glb") as PackedScene
	var movement := load(_ANIM_DIR + "Rig_Medium_MovementBasic.glb") as PackedScene
	var tools := load(_ANIM_DIR + "Rig_Medium_Tools.glb") as PackedScene
	res.entries.append(AnimEntry.make("idle", general, "Idle_A", true))
	res.entries.append(AnimEntry.make("walk", movement, "Walking_A", true))
	res.entries.append(AnimEntry.make("wave", general, "Interact", false))
	res.entries.append(AnimEntry.make("accept", movement, "Jump_Full_Short", false))
	# Two-handed holding pose used while carrying an item (KayKit tools pack).
	res.entries.append(AnimEntry.make("carry", tools, "Holding_B", true))
	return res

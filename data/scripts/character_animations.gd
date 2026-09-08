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

## The mapping rows. Order is display-only; the code plays by `name`.
@export var entries: Array[AnimEntry] = []


## Bake every entry into one AnimationLibrary (clip pulled from its source .glb, its
## Skin binds by bone name so it drives the shared Rig_Medium with no retargeting).
func build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for entry in entries:
		if entry == null or entry.source == null or entry.name == "":
			continue
		var clip := _extract(entry.source, entry.clip)
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR if entry.loop else Animation.LOOP_NONE
			lib.add_animation(entry.name, clip)
	return lib


func _extract(source: PackedScene, clip_name: String) -> Animation:
	var inst := source.instantiate()
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	var out: Animation = null
	if not players.is_empty():
		var ap := players[0] as AnimationPlayer
		if ap.has_animation(clip_name):
			out = ap.get_animation(clip_name).duplicate() as Animation
	inst.queue_free()
	return out


## The shipped default set — source for build_animations.gd and the CharAnims
## fallback if the .tres is ever missing. Mirrors the KayKit clips used before.
static func make_default() -> CharacterAnimations:
	var res := CharacterAnimations.new()
	var general := load(_ANIM_DIR + "Rig_Medium_General.glb") as PackedScene
	var movement := load(_ANIM_DIR + "Rig_Medium_MovementBasic.glb") as PackedScene
	res.entries.append(AnimEntry.make("idle", general, "Idle_A", true))
	res.entries.append(AnimEntry.make("walk", movement, "Walking_A", true))
	res.entries.append(AnimEntry.make("wave", general, "Interact", false))
	res.entries.append(AnimEntry.make("accept", movement, "Jump_Full_Short", false))
	return res

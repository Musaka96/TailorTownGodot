class_name AnimEntry
extends Resource

## One named animation the character can play. `name` is the gameplay name the code
## asks for (idle / walk / wave / accept); `source` is the .glb that contains the
## clip (a KayKit Rig_Medium animation pack imports as a PackedScene with its own
## AnimationPlayer); `clip` is the clip's name inside that source; `loop` makes it
## repeat (true for cycles like walk/idle, false for one-shot gestures). To change
## the walk, point `clip` at another movement clip (e.g. "Walking_C", "Running_A").

## Gameplay name the code plays (idle / walk / wave / accept).
@export var name: String = ""
## The animation source .glb. Drag one in from assets/characters/anim/.
@export var source: PackedScene
## The clip's name inside `source` (e.g. "Walking_A", "Walking_C", "Running_A").
@export var clip: String = ""
## Loop the clip (true for walk/idle cycles, false for one-shot gestures).
@export var loop: bool = false


static func make(
	anim_name: String, src: PackedScene, clip_name: String, looping: bool
) -> AnimEntry:
	var entry := AnimEntry.new()
	entry.name = anim_name
	entry.source = src
	entry.clip = clip_name
	entry.loop = looping
	return entry

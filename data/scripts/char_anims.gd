class_name CharAnims

## Facade over the editable animation asset (data/animations/default_animations.tres,
## a CharacterAnimations). Builds the runtime AnimationLibrary once and caches it so
## every character shares it. CharacterRig calls library() at _ready and installs it
## on its AnimationPlayer, so editing the .tres changes the animations on the next
## run with no rebuild. Regenerate the default asset with tools/build_animations.gd.

const LIBRARY_PATH := "res://data/animations/default_animations.tres"

static var _lib: AnimationLibrary


## The baked animation library (cached). Falls back to the in-code default if the
## asset is missing so a fresh checkout still animates.
static func library() -> AnimationLibrary:
	if _lib == null:
		var res := load(LIBRARY_PATH) as CharacterAnimations
		if res == null:
			res = CharacterAnimations.make_default()
		_lib = res.build_library()
	return _lib

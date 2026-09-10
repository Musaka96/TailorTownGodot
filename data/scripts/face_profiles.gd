class_name FaceProfiles
extends Resource

## Per-head face PROFILES: each head/hair combo (index) gets its own FaceLayout, and a flag
## for whether the combo is used in-game. The rig loads the profile for the head it's showing,
## so different heads carry different face tuning; the char preview edits and saves them.
## Stored at res://data/face_profiles.tres. Falls back to the legacy global face_layout.tres
## for any head without its own profile yet, so old tuning still applies until overridden.

const PATH := "res://data/face_profiles.tres"

static var _cache: FaceProfiles

## head index (int) -> FaceLayout for that combo.
@export var layouts: Dictionary = {}
## head index (int) -> true means "don't use this combo" (absent = enabled).
@export var disabled: Dictionary = {}


static func load_or_default() -> FaceProfiles:
	if _cache != null:
		return _cache
	if ResourceLoader.exists(PATH):
		var r := load(PATH) as FaceProfiles
		if r != null:
			_cache = r
			return r
	_cache = FaceProfiles.new()
	return _cache


func has_layout(head: int) -> bool:
	return layouts.get(head) is FaceLayout


## The stored layout for a head, or the legacy global layout as a fallback default.
func layout_for(head: int) -> FaceLayout:
	var l: Variant = layouts.get(head)
	return l if l is FaceLayout else FaceLayout.load_or_default()


func set_layout(head: int, layout: FaceLayout) -> void:
	layouts[head] = layout


func is_enabled(head: int) -> bool:
	return not bool(disabled.get(head, false))


func set_enabled(head: int, on: bool) -> void:
	if on:
		disabled.erase(head)
	else:
		disabled[head] = true


## Save to disk and refresh the shared cache so the game picks up the change.
func save() -> void:
	ResourceSaver.save(self, PATH)
	_cache = self

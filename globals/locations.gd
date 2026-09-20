extends Node

## The places the game is played in — autoloaded as "Locations".
##
## A new game opens in Mr. Hemming's shop (the apprenticeship: the tutorial, with the player
## kept indoors), then moves to grandpa's shop, which is the one that is saved and lived
## in. Hemming's shop is never saved, so a save still describes a single world. SaveManager
## asks this registry which scene to load; the scene tells it where it is on arrival
## (sync_to_scene), so booting any of the scenes directly (dev, tests) works too.
## See docs/STORY_AND_RENOVATION.md.

const HEMMING := &"hemming"
const GRANDPA := &"grandpa"
## Saves written before locations existed were made in main.tscn.
const LEGACY := HEMMING

const PLACES := {
	HEMMING: {"name": "Mr. Hemming's, on the Row", "scene": "res://main.tscn"},
	GRANDPA:
	{
		"name": "Grandpa's shop",
		"scene": "res://scenes/world/grandpa/main_grandpa.tscn",
	},
}

var current: StringName = HEMMING


func scene_of(id: StringName) -> String:
	var place: Dictionary = PLACES.get(id, PLACES[LEGACY])
	return str(place["scene"])


func name_of(id: StringName) -> String:
	var place: Dictionary = PLACES.get(id, PLACES[LEGACY])
	return str(place["name"])


## A known id, or the legacy place for anything else (old saves have none).
func valid(id: Variant) -> StringName:
	var key := StringName(str(id))
	return key if PLACES.has(key) else LEGACY


## Called by the game scene once it is up: work out which place it is from its file.
func sync_to_scene(scene_path: String) -> void:
	for id: StringName in PLACES:
		if str(PLACES[id]["scene"]) == scene_path:
			current = id
			return

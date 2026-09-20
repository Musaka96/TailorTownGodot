class_name UpgradeStation
extends Node3D

## A piece of shop furniture that only exists once its upgrade is bought: until then it
## is hidden, solid-less and can't be interacted with, so it can sit in the shop scene
## from day one and simply appear the moment the phone order goes through (or the F3
## panel grants it). Subclasses set `upgrade_id` and implement the station itself.

@export var upgrade_id := ""
## In grandpa's shop: the Renovation room this station stands in. It only appears once
## that room is done as well ("" = no room to wait for, as at Mr. Hemming's).
@export var room := ""

var _owned := false


func _ready() -> void:
	Upgrades.changed.connect(_refresh)
	Renovation.changed.connect(_refresh)
	_refresh()


func is_owned() -> bool:
	return _owned


func _refresh() -> void:
	_owned = upgrade_id == "" or Upgrades.has(upgrade_id)
	if room != "" and Renovation.room_state(room) != Renovation.RoomState.DONE:
		_owned = false
	visible = _owned
	for body in find_children("*", "CollisionObject3D", true, false):
		var co := body as CollisionObject3D
		if co is Interactable:
			(co as Interactable).set_enabled(_owned)
		else:
			co.process_mode = Node.PROCESS_MODE_INHERIT if _owned else Node.PROCESS_MODE_DISABLED


## Freeze the player for a short bit of handwork (pressing, pouring), then let them go.
func _busy(seconds: float) -> void:
	GameState.input_locked = true
	await get_tree().create_timer(seconds).timeout
	GameState.input_locked = false

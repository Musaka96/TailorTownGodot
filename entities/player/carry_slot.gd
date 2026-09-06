class_name CarrySlot
extends Node3D

## The player's hands — holds exactly one carryable at a time, parented to the
## HoldPoint marker so it visually follows the player.

var _held: Node = null

@onready var hold_point: Marker3D = $HoldPoint


func is_empty() -> bool:
	return _held == null


func get_held() -> Node:
	return _held


## Pick an item up off the floor. Returns false if hands are full.
func try_pick_up(item: Node) -> bool:
	if _held != null:
		return false
	_held = item
	item.attach_to(hold_point)
	EventBus.item_picked_up.emit(item)
	return true


## Put an item into the hands from a station (already removed from that station).
func take_item(item: Node) -> void:
	if _held != null:
		return
	_held = item
	item.attach_to(hold_point)


## Give up the held item; caller is responsible for reparenting it.
func release() -> Node:
	var item := _held
	_held = null
	return item

class_name CarrySlot
extends Node3D

## The player's hands — holds exactly one carryable at a time, parented to the
## HoldPoint marker so it visually follows the player.

var _held: Node = null
var _external_hold: Node3D = null

@onready var hold_point: Marker3D = $HoldPoint


func is_empty() -> bool:
	return _held == null


func get_held() -> Node:
	return _held


## Override where held items sit — the Player points this at the rig's hand-bone
## attachment so carried items follow the hand and turn with the character.
func set_hold_point(point: Node3D) -> void:
	_external_hold = point


## Pick an item up off the floor. Returns false if hands are full.
func try_pick_up(item: Node) -> bool:
	if _held != null:
		return false
	_held = item
	item.attach_to(_point())
	EventBus.item_picked_up.emit(item)
	return true


## Put an item into the hands from a station (already removed from that station).
## Returns false (leaving the item untouched) if the hands are already full, so callers
## never silently orphan the node.
func take_item(item: Node) -> bool:
	if _held != null:
		return false
	_held = item
	item.attach_to(_point())
	return true


## Where held items attach: the rig's hand point if set, else the local marker.
func _point() -> Node3D:
	return _external_hold if _external_hold != null else hold_point


## Give up the held item; caller is responsible for reparenting it.
func release() -> Node:
	var item := _held
	_held = null
	return item

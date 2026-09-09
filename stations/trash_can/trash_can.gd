class_name TrashCan
extends Node3D

## Discard whatever the player is carrying — drop it in the bin and it's gone for
## good. Handy for scrapping mismatched cloth, a wrong piece, or an unclaimed suit.


func get_interaction_prompt(actor) -> String:
	if actor.carry.is_empty():
		return "Bin — carry something to throw away"
	return "Throw away"


func interact(actor) -> void:
	if actor.carry.is_empty():
		return
	var item: Node = actor.carry.release()
	if item.get_parent() != null:
		item.get_parent().remove_child(item)  # release() only clears the slot, not the hand
	item.queue_free()
	if Sfx != null:
		Sfx.play("putdown")

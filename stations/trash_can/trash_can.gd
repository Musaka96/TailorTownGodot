class_name TrashCan
extends Node3D

## The recycling bin on the pavement outside the shop. Drop whatever you carry in and
## it's gone for good, but the cloth in it pays back a little: SCRAP_SHARE of what that
## cloth cost off the bolt (see docs/ECONOMY.md "Recycling"). A safety net for a wrong
## piece or an unclaimed suit, never worth buying cloth just to scrap it.

## Share of the cloth's value the bin pays back.
const SCRAP_SHARE := 0.2
## A made piece or suit whose cloth can't be read still pays this.
const MADE_FALLBACK := 2

@onready var _poof: GPUParticles3D = $Poof


## What recycling `item` pays: SCRAP_SHARE of its cloth value, rounded up, at least $1.
## Rolls and cut lengths count their metres; a garment piece counts the cloth its part
## takes; a suit counts every part. Anything without cloth pays $1.
static func scrap_value(item: Node) -> int:
	if item is MaterialRoll:
		var roll := item as MaterialRoll
		var metres := roll.remaining_length_m
		if metres < 0.0 and roll.material != null:
			metres = roll.material.roll_length_m  # not in the tree yet: still a full bolt
		return _share(_cloth_value(roll.material, metres))
	if item is FabricPiece:
		var piece := item as FabricPiece
		return _share(_cloth_value(piece.material, piece.length_m))
	if item is GarmentPiece:
		var garment := item as GarmentPiece
		var metres := Pricing.part_meters(garment.garment_type, garment.size)
		return _made_share(_cloth_value(garment.material, metres))
	if item is Suit:
		var total := 0
		for garment_type: int in (item as Suit).parts:
			var part: Dictionary = (item as Suit).parts[garment_type]
			var metres := Pricing.part_meters(garment_type, int(part.get("size", Enums.Size.M)))
			total += _cloth_value(part.get("material") as MaterialType, metres)
		return _made_share(total)
	return 1


static func _cloth_value(mat: MaterialType, metres: float) -> int:
	if mat == null or metres <= 0.0:
		return 0
	return Pricing.roll_price(mat, metres)


static func _share(value: int) -> int:
	return maxi(ceili(float(value) * SCRAP_SHARE - 0.001), 1)


static func _made_share(value: int) -> int:
	return _share(value) if value > 0 else MADE_FALLBACK


func get_interaction_prompt(actor) -> String:
	if actor.carry.is_empty():
		return "Recycling bin — carry something to recycle"
	return "Recycle for $%d" % scrap_value(actor.carry.get_held())


func interact(actor) -> void:
	if actor.carry.is_empty():
		return
	var item: Node = actor.carry.release()
	var value := scrap_value(item)
	GameState.earn(value)  # the purse floats its own "+$" (hud.gd _spawn_delta)
	if item.get_parent() != null:
		item.get_parent().remove_child(item)  # release() only clears the slot, not the hand
	item.queue_free()
	if _poof != null:
		_poof.restart()  # one-shot puff of dust at the bin's mouth
	if Sfx != null:
		Sfx.play("putdown")
		Sfx.play("cloth_rustle", -3.0, 1.15, 1.3)  # airy poof over the thunk
		Sfx.play("coins", -4.0)

class_name Phone
extends Node3D

## Ordering station. Opens the phone menu; delivered rolls appear at the spot
## next to it ("shipped immediately").

const ROLL_SCENE := preload("res://entities/items/material_roll.tscn")

@onready var _delivery: Node3D = $DeliverySpot


func get_interaction_prompt(_actor) -> String:
	return "Use phone   ($%d)" % GameState.money


func interact(actor) -> void:
	UI.open_phone(self, actor)


## Spawn a full bolt of `mat` with `length` metres at the delivery spot.
func deliver_roll(mat: MaterialType, length: float) -> Node:
	var roll: Node = ROLL_SCENE.instantiate()
	roll.material = mat
	roll.remaining_length_m = length
	get_parent().add_child(roll)
	# Small jitter so stacked deliveries don't perfectly overlap.
	var base := _delivery.global_position
	roll.global_position = base + Vector3(randf_range(-0.25, 0.25), 0.13, randf_range(-0.25, 0.25))
	EventBus.order_delivered.emit(roll)
	return roll

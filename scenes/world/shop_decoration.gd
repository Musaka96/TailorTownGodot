@tool
class_name ShopDecoration
extends Node3D

## Marks a prop as shop decoration that makes the place nicer to visit: every order's
## reputation gain is raised by `reputation_bonus` (summed over all visible decorations,
## capped by Reputation.DECOR_CAP). Attach this script to any prop in the shop scene (or
## wrap a prop in a node with it) and set the bonus; hide the node to switch it off.
## There's no shop to buy decorations yet - this is the hook that system will use.
## See docs/ECONOMY.md.

const GROUP := &"decoration"

## Extra share of reputation per order (0.02 = +2%).
@export_range(0.0, 0.25, 0.005) var reputation_bonus: float = 0.02


func _enter_tree() -> void:
	add_to_group(GROUP)

class_name GarmentPiece
extends Node3D

## A cut garment panel produced at the worktable: a specific garment type, size
## and style, cut from a material with a quality score from the cutting minigame.
## Next stop is the sewing machine (later phase). Carryable like the other items.

## Child node names inside the model, NOT display text: _apply_visual() shows the one
## whose node name matches. The player-facing word is Enums.garment_type_name(), which
## says "Trousers"; renaming this would need the node in garment_piece.tscn renamed too.
## A marker carrying this meta is a rack hook: a piece placed on it hangs, on a hanger of
## its own when the meta is true (a GarmentSet's layers pass false: the set has one).
const HOOK_META := &"rack_hook"
const MODEL_NAME := {
	Enums.GarmentType.SHIRT: "Shirt",
	Enums.GarmentType.PANTS: "Pants",
	Enums.GarmentType.JACKET: "Jacket",
}

@export var material: MaterialType
@export var garment_type: Enums.GarmentType = Enums.GarmentType.SHIRT
@export var size: Enums.Size = Enums.Size.M
@export var style: String = "Classic"
@export var quality: float = 1.0
@export var stage: Enums.Stage = Enums.Stage.CUT
## Given a press on the ironing board (Pressing Iron upgrade) — once per piece.
@export var pressed := false
## The order number this piece was checked off against when sewn (0 = not matched to
## any order — a speculative/spare piece).
@export var order_id: int = 0

var _hanging: Node3D

@onready var _models: Node3D = $Models
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_apply_visual()


func get_interaction_prompt(_actor) -> String:
	var st := "sewn" if stage == Enums.Stage.SEWN else "cut"
	return (
		"Pick up %s (%s, %s)" % [Enums.garment_type_name(garment_type), Enums.size_name(size), st]
	)


func attach_to(point: Node3D) -> void:
	_sit_at(point)
	set_pickable(false)
	_show_hanging(false, false)


func place_on(marker: Node3D) -> void:
	attach_to(marker)
	if marker.has_meta(HOOK_META):
		_show_hanging(true, bool(marker.get_meta(HOOK_META)))


## On a rack the piece hangs as the garment it will be; anywhere else it is the flat,
## folded piece.
func _show_hanging(on: bool, with_hanger: bool) -> void:
	if _hanging != null:
		_hanging.queue_free()
		_hanging = null
	if _models != null:
		_models.visible = not on
	if on:
		_hanging = HangingModel.make({int(garment_type): material}, with_hanger)
		add_child(_hanging)


func interact(actor) -> void:
	actor.carry.try_pick_up(self)


func set_pickable(enabled: bool) -> void:
	if _interactable:
		_interactable.set_enabled(enabled)


func _sit_at(new_parent: Node3D) -> void:
	reparent(new_parent)
	transform = Transform3D.IDENTITY


func _apply_visual() -> void:
	if _models == null:
		return
	var show_name: String = MODEL_NAME.get(garment_type, "Shirt")
	var cloth := ClothMaterial.build(material, 2.2)
	for model in _models.get_children():
		var visible_now: bool = model.name == show_name
		model.visible = visible_now
		if visible_now:
			for piece in model.get_children():
				if piece is MeshInstance3D:
					piece.material_override = cloth

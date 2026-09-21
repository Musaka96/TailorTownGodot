class_name Suit
extends Node3D

## A packaged, complete suit (shirt + pants + jacket): made when the last part for an
## order joins its set on a clothing rack (see GarmentSet), or at the mannequin.
## Carryable; `parts` holds each piece's material/quality/size/style for the
## selling phase, and `quality` is their average.

@export var quality: float = 1.0
@export var primary_color: Color = Color(0.2, 0.2, 0.24)
## The order this suit fulfils, stamped at assembly (0 = a speculative suit for no order).
@export var order_id: int = 0

## GarmentType(int) -> { material, quality, size, style }
var parts := {}

var _model: Node3D

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_apply_visual()


## A finished suit built from sewn parts: one entry per part with its cloth, quality, size
## and style, the suit's quality their average, its colour the jacket's cloth. It isn't in
## the tree yet and the pieces are left alone — the caller places the suit and frees them.
static func from_pieces(pieces: Array, for_order: int) -> Node:
	var suit: Node = load("res://entities/items/suit.tscn").instantiate()
	var parts := {}
	var quality_sum := 0.0
	for piece: Node in pieces:
		parts[int(piece.garment_type)] = {
			"material": piece.material,
			"quality": piece.quality,
			"size": piece.size,
			"style": piece.style,
		}
		quality_sum += piece.quality
		if int(piece.garment_type) == Enums.GarmentType.JACKET and piece.material != null:
			suit.primary_color = piece.material.cloth_color
	suit.parts = parts
	suit.quality = quality_sum / maxf(pieces.size(), 1.0)
	suit.order_id = for_order
	return suit


func get_interaction_prompt(_actor) -> String:
	if order_id > 0:
		return "Pick up suit for order #%d  (Q %d%%)" % [order_id, roundi(quality * 100.0)]
	return "Pick up finished suit  (Q %d%%)" % roundi(quality * 100.0)


func attach_to(point: Node3D) -> void:
	_sit_at(point)
	set_pickable(false)


func place_on(marker: Node3D) -> void:
	attach_to(marker)


func interact(actor) -> void:
	actor.carry.try_pick_up(self)


func set_pickable(enabled: bool) -> void:
	if _interactable:
		_interactable.set_enabled(enabled)
	_lie_down(enabled)  # pickable = set down loose on the floor


## On a hook or in the hand the suit hangs from its hanger; set down loose it lies flat on
## its back, a little above the floor it was dropped over.
func _lie_down(flat: bool) -> void:
	if _model == null:
		return
	if flat:
		_model.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, -0.1, 0.1))
	else:
		_model.transform = Transform3D.IDENTITY


func _sit_at(new_parent: Node3D) -> void:
	reparent(new_parent)
	transform = Transform3D.IDENTITY
	_lie_down(false)


## The whole suit on one hanger, each part in its own cloth. A suit made with no parts
## (a test one) is a jacket and trousers in its flat primary colour.
func _apply_visual() -> void:
	if _mesh != null:
		_mesh.visible = false  # the old stand-in block
	if _model != null:
		_model.queue_free()
	var cloths := {}
	for t: int in parts:
		var mat: Variant = parts[t].get("material")
		if mat != null:
			cloths[t] = mat
	if cloths.is_empty():
		var plain := StandardMaterial3D.new()
		plain.albedo_color = primary_color
		cloths = {Enums.GarmentType.JACKET: plain, Enums.GarmentType.PANTS: plain}
	_model = HangingModel.make(cloths)
	add_child(_model)
	_lie_down(_interactable != null and _interactable.monitorable)

class_name Customer
extends Node3D

## A walk-in customer. Spawned on the street by the CustomerManager, it walks a
## list of waypoints (no navmesh — straight legs between markers, which is plenty
## for the greybox). Pedestrians just pass by; shoppers enter, wait to be greeted,
## get sent to the fitting mirror, and leave once their suit is designed.
##
## The manager owns the geometry (where the door / mirror / street ends are) and
## drives routing; this node only knows how to walk a path, face a direction, and
## offer the right interaction for its current mode. Anchor helpers (center /
## facing / part_position) are used by the suit builder to frame the camera.

signal arrived  ## the current path finished
signal departed(customer: Node)  ## about to remove itself

## What interacting with the customer does right now.
enum Mode { NONE, GREET, MIRROR, COLLECT }

# Reaction kinds passed to react() (see there): momentary like/dislike, a lasting
# accepted-happy, and back to the resting face.
const REACT_NEUTRAL := 0
const REACT_LIKE := 1
const REACT_DISLIKE := -1
const REACT_ACCEPT := 2

@export var walk_speed: float = 2.6
@export var turn_speed: float = 8.0

## Taste + budget (null for a plain pedestrian).
var preference: CustomerPreference = null
## Skin tone + hairstyle + hair colour, remembered so a returning customer matches.
var skin_color := Color(0.87, 0.72, 0.60)
var hair_index := 0
var hair_color := Color(0.14, 0.11, 0.09)
## Which head mesh + which gender's wardrobe this customer uses.
var head_index := 0
var gender := Enums.Gender.MALE
## Face look, remembered so the speech-bubble portrait can match this customer.
var eye_color := "brown"
var glasses := ""
## The order this customer is returning to collect (COLLECT mode only).
var collect_order: SuitOrder = null
## Injected by the manager so interactions can reach the fitting station / routing.
var mirror: Node = null
var manager: Node = null

var _points: Array = []
var _done: Callable = Callable()
var _mode := Mode.NONE
var _face_target := NAN

@onready var _interactable: Interactable = $Interactable
@onready var _rig: Node = $Rig


func _ready() -> void:
	_set_interactable(false)


func _physics_process(delta: float) -> void:
	if _rig != null:
		_rig.set_moving(not _points.is_empty())
	if _points.is_empty():
		if not is_nan(_face_target):
			rotation.y = lerp_angle(rotation.y, _face_target, turn_speed * delta)
		return
	var target: Vector3 = _points[0]
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var dist := to.length()
	if dist < 0.08:
		global_position = Vector3(target.x, global_position.y, target.z)
		_points.remove_at(0)
		if _points.is_empty():
			_on_path_done()
		return
	var dir := to / dist
	global_position += dir * minf(walk_speed * delta, dist)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), turn_speed * delta)


# --- Movement --------------------------------------------------------------


## Walk through `points` (Array of Vector3); `done` fires once on arrival, and
## `face` (yaw radians, NAN to keep last heading) is held while idle.
func walk(points: Array, done := Callable(), face := NAN) -> void:
	_points = points.duplicate()
	_done = done
	_face_target = face
	if _points.is_empty():
		_on_path_done()


func _on_path_done() -> void:
	var cb := _done
	_done = Callable()
	if cb.is_valid():
		cb.call()
	arrived.emit()


## Remove itself from the world (end of a walk-by or after leaving).
func despawn() -> void:
	departed.emit(self)
	queue_free()


# --- Interaction mode ------------------------------------------------------


func offer_greeting() -> void:
	_mode = Mode.GREET
	_set_interactable(true)
	if _rig != null:
		_rig.wave()


## Set skin colour, head mesh, and optionally eye colour + glasses (called by the
## manager on spawn). Empty eye_color / glasses keep the rig defaults.
func apply_look(skin: Color, eyes := "", glasses_kind := "", head := 0) -> void:
	skin_color = skin
	head_index = head
	eye_color = eyes if eyes != "" else "brown"
	glasses = glasses_kind
	if _rig == null:
		return
	_rig.set_head(head)
	_rig.set_palette(skin)
	_rig.set_face_look(eyes, glasses_kind)


## Pick a hairstyle from the wardrobe library.
## Flap the mouth while a line is being said (driven by the greeting/request UI).
func set_talking(on: bool) -> void:
	if _rig != null:
		_rig.set_talking(on)


## React to a suit design at the mirror. The customer rests on a normal face and only
## reacts when the player suggests a design: LIKE/DISLIKE play a one-off grin+nod or
## frown+shake and settle back to normal; ACCEPT holds a lasting happy face (they keep
## it as they leave); NEUTRAL returns to rest (menu closed).
func react(kind: int) -> void:
	if _rig == null or not _rig.has_method("express_once"):
		return
	match kind:
		REACT_LIKE:
			_rig.express_once(true)
		REACT_DISLIKE:
			_rig.express_once(false)
		REACT_ACCEPT:
			_rig.set_expression(true)
		_:
			_rig.reset_expression()


func set_hair(index: int) -> void:
	hair_index = index
	if _rig != null:
		_rig.set_hair(index)


## Tint the hair with a colour from the wardrobe palette.
func set_hair_color(color: Color) -> void:
	hair_color = color
	if _rig != null:
		_rig.set_hair_color(color)


## Wear the casual street outfit (on arrival, before a suit is made).
func wear_street() -> void:
	if _rig != null:
		_rig.wear_street()


## Wait at the counter for the player to hand over a finished order.
func offer_collection(order: SuitOrder) -> void:
	_mode = Mode.COLLECT
	collect_order = order
	_set_interactable(true)
	if _rig != null:
		_rig.wave()


## Dress the customer in a suit: cloth materials + the chosen jacket/pants styles
## (which swap the actual models).
func wear_suit(
	jacket_mat: MaterialType,
	shirt_mat: MaterialType,
	trousers_mat: MaterialType,
	jacket_style := 0,
	pants_style := 0
) -> void:
	if _rig != null:
		_rig.set_outfit(jacket_mat, shirt_mat, trousers_mat, jacket_style, pants_style)


## Dress from a finished order's design (used when the customer collects the suit).
func wear_suit_from_design(design: Dictionary) -> void:
	var jacket := _design_material(design, Enums.GarmentType.JACKET)
	var shirt := _design_material(design, Enums.GarmentType.SHIRT)
	var pants := _design_material(design, Enums.GarmentType.PANTS)
	var jacket_style := int(design.get(Enums.GarmentType.JACKET, {}).get("style_idx", 0))
	var pants_style := int(design.get(Enums.GarmentType.PANTS, {}).get("style_idx", 0))
	wear_suit(jacket, shirt, pants, jacket_style, pants_style)


func _design_material(design: Dictionary, garment_type: int) -> MaterialType:
	var c: Dictionary = design.get(garment_type, {})
	if c.is_empty():
		return null
	return MaterialFactory.make(
		int(c.get("fabric", 0)), int(c.get("pattern", 0)), int(c.get("color", 0)), 1.0
	)


func offer_mirror() -> void:
	_mode = Mode.MIRROR
	if mirror != null:
		mirror.set("customer", self)
	_set_interactable(true)


## Player greeted the customer and chose to seat them at the mirror.
func begin_fitting() -> void:
	_set_interactable(false)
	_mode = Mode.NONE
	if manager != null:
		manager.route_to_mirror(self)


## Design approved — play a happy gesture, then head for the exit.
func finish_and_leave() -> void:
	_set_interactable(false)
	_mode = Mode.NONE
	if mirror != null and mirror.get("customer") == self:
		mirror.set("customer", null)
	if _rig != null and _rig.has_method("celebrate"):
		_rig.celebrate(_leave)
	else:
		_leave()


func _leave() -> void:
	if manager != null:
		manager.dismiss(self)


func get_interaction_prompt(_actor) -> String:
	match _mode:
		Mode.GREET:
			return "Greet %s" % _label()
		Mode.MIRROR:
			return "Design %s's suit" % _label()
		Mode.COLLECT:
			var pay := collect_order.payout() if collect_order != null else 0
			return "Hand %s their suit  (+$%d)" % [_label(), pay]
	return ""


func interact(actor) -> void:
	match _mode:
		Mode.GREET:
			UI.open_customer_request(self, actor)
		Mode.MIRROR:
			if mirror != null:
				UI.open_suit_builder(mirror, actor)
		Mode.COLLECT:
			var order := collect_order
			Orders.collect(order)
			collect_order = null
			if order != null:
				wear_suit_from_design(order.design)  # put the finished suit on
			finish_and_leave()


func _label() -> String:
	if preference != null:
		return preference.display_name
	if collect_order != null:
		return collect_order.customer_name
	return "the customer"


func _set_interactable(on: bool) -> void:
	if _interactable != null:
		_interactable.set_enabled(on)


# --- Camera anchors (used by the suit builder) -----------------------------


func center() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func facing() -> Vector3:
	return global_transform.basis.z


func part_position(garment_type: int) -> Vector3:
	match garment_type:
		Enums.GarmentType.SHIRT:
			return $ShirtAnchor.global_position
		Enums.GarmentType.PANTS:
			return $PantsAnchor.global_position
		Enums.GarmentType.JACKET:
			return $JacketAnchor.global_position
	return center()

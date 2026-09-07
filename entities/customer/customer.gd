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
enum Mode { NONE, GREET, MIRROR }

@export var walk_speed: float = 2.6
@export var turn_speed: float = 8.0

## Taste + budget (null for a plain pedestrian).
var preference: CustomerPreference = null
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


## Set skin colour (called by the manager on spawn).
func apply_look(skin: Color) -> void:
	if _rig != null:
		_rig.set_palette(skin)


## Dress the customer in a suit made from real cloth materials.
func wear_suit(
	jacket_mat: MaterialType, shirt_mat: MaterialType, trousers_mat: MaterialType
) -> void:
	if _rig != null:
		_rig.set_outfit(jacket_mat, shirt_mat, trousers_mat)


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
	return ""


func interact(actor) -> void:
	match _mode:
		Mode.GREET:
			UI.open_customer_request(self, actor)
		Mode.MIRROR:
			if mirror != null:
				UI.open_suit_builder(mirror, actor)


func _label() -> String:
	return preference.display_name if preference != null else "the customer"


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

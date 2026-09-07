class_name CustomerManager
extends Node3D

## Spawns pedestrians on the street and turns some of them into shoppers. Owns the
## storefront geometry (door / greet / mirror / street-end markers) and routes a
## customer through the flow: enter → wait to be greeted → walk to the fitting
## mirror → (design approved) → leave. Only one shopper is served at a time; extra
## shoppers just walk past until the shop is free.

const CUSTOMER_SCENE := preload("res://entities/customer/customer.tscn")

# Skin + hair pools for spawned characters (suits come from the material catalog).
const SKINS := [
	Color(0.87, 0.72, 0.60),
	Color(0.80, 0.62, 0.48),
	Color(0.93, 0.81, 0.69),
	Color(0.66, 0.48, 0.35)
]
const HAIRS := [
	Color(0.15, 0.12, 0.10),
	Color(0.35, 0.24, 0.16),
	Color(0.72, 0.60, 0.34),
	Color(0.55, 0.55, 0.58)
]

@export var mirror_path: NodePath
@export var greet_path: NodePath
@export var mirror_spot_path: NodePath
@export var door_in_path: NodePath
@export var door_out_path: NodePath
@export var street_west_path: NodePath
@export var street_east_path: NodePath
## Seconds between pedestrian spawns.
@export var spawn_interval: float = 9.0
## Chance a spawned pedestrian is a shopper (only enters if the shop is free).
@export var shopper_chance: float = 0.5
## Cap on simultaneous customers in the world (keeps the street from clogging).
@export var max_alive: int = 6

var _mirror: Node = null
var _greet := Vector3.ZERO
var _mirror_spot := Vector3.ZERO
var _door_in := Vector3.ZERO
var _door_out := Vector3.ZERO
var _street_west := Vector3.ZERO
var _street_east := Vector3.ZERO
var _served: Customer = null
var _alive := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Defer so all sibling markers/stations exist and report global positions.
	call_deferred("_start")


func _start() -> void:
	_rng.randomize()
	_mirror = get_node_or_null(mirror_path)
	_greet = _pos(greet_path)
	_mirror_spot = _pos(mirror_spot_path)
	_door_in = _pos(door_in_path)
	_door_out = _pos(door_out_path)
	_street_west = _pos(street_west_path)
	_street_east = _pos(street_east_path)

	# One customer is already inside, waiting to be greeted.
	var first := _spawn(_greet, true)
	_served = first
	first.offer_greeting()
	EventBus.customer_waiting.emit(first)

	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_spawn_tick)


# --- Spawning --------------------------------------------------------------


func _spawn_tick() -> void:
	if _alive >= max_alive:
		return
	var from_west := _rng.randf() < 0.5
	var start := _street_west if from_west else _street_east
	var far_end := _street_east if from_west else _street_west
	var shopper := _served == null and _rng.randf() < shopper_chance
	if shopper:
		_send_shopper(start)
	else:
		var walker := _spawn(start, false)
		walker.walk([far_end], walker.despawn)


func _send_shopper(start: Vector3) -> void:
	var cust := _spawn(start, true)
	_served = cust
	cust.walk([_door_out, _door_in, _greet], func() -> void: _on_shopper_waiting(cust))


func _on_shopper_waiting(cust: Customer) -> void:
	cust.offer_greeting()
	EventBus.customer_waiting.emit(cust)


func _spawn(pos: Vector3, with_pref: bool) -> Customer:
	var cust: Customer = CUSTOMER_SCENE.instantiate()
	add_child(cust)
	cust.global_position = Vector3(pos.x, 0.0, pos.z)
	cust.mirror = _mirror
	cust.manager = self
	if with_pref:
		cust.preference = CustomerPreference.random_pref(_rng)
	_dress(cust)
	cust.departed.connect(_on_departed)
	_alive += 1
	return cust


func _dress(cust: Customer) -> void:
	cust.apply_look(SKINS[_rng.randi() % SKINS.size()], HAIRS[_rng.randi() % HAIRS.size()])
	var mats := Catalog.all_materials()
	if not mats.is_empty():
		var suit: MaterialType = mats[_rng.randi() % mats.size()]
		cust.wear_suit(suit, suit)


# --- Routing (called by Customer / UI) -------------------------------------


func route_to_mirror(cust: Customer) -> void:
	cust.walk([_mirror_spot], func() -> void: _on_seated(cust), 0.0)


func _on_seated(cust: Customer) -> void:
	cust.offer_mirror()
	EventBus.customer_seated.emit(cust)


func dismiss(cust: Customer) -> void:
	var exit := _street_west if _rng.randf() < 0.5 else _street_east
	cust.walk([_door_in, _door_out, exit], cust.despawn)


func _on_departed(cust: Node) -> void:
	_alive = maxi(_alive - 1, 0)
	if _served == cust:
		_served = null


func _pos(path: NodePath) -> Vector3:
	var node := get_node_or_null(path)
	return (node as Node3D).global_position if node is Node3D else Vector3.ZERO

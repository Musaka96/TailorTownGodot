class_name CustomerManager
extends Node3D

## Spawns pedestrians on the street and turns some of them into shoppers. Owns the
## storefront geometry (door / greet / mirror / street-end markers) and routes a
## customer through the flow: enter → wait to be greeted → walk to the fitting
## mirror → (design approved) → leave. Only one shopper is served at a time; extra
## shoppers just walk past until the shop is free.

const CUSTOMER_SCENE := preload("res://entities/customer/customer.tscn")

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
	EventBus.order_due.connect(_on_order_due)
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
	# Labour laws: once the shift's over, no new shoppers wander in.
	if Shift != null and not Shift.is_open():
		return
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


# --- Debug hooks (used by the F3 debug menu) -------------------------------


## Force a shopper to walk in now, regardless of the spawn chance or shop state.
func debug_call_shopper() -> void:
	if not is_inside_tree():
		return
	var start := _street_west if _rng.randf() < 0.5 else _street_east
	_send_shopper(start)


## Remove every customer currently in the world.
func debug_clear_customers() -> void:
	for child in get_children():
		if child is Customer:
			child.despawn()


# --- Returning collectors --------------------------------------------------


## An order's deadline arrived: the customer walks back in to collect it. This is
## independent of the fitting queue (collectors don't use the mirror).
func _on_order_due(order: SuitOrder) -> void:
	if not is_inside_tree() or _door_in == Vector3.ZERO:
		return
	var start := _street_west if _rng.randf() < 0.5 else _street_east
	var cust := _spawn(start, false)
	cust.collect_order = order
	cust.apply_look(order.skin)
	cust.set_hair(order.hair_index)  # match the customer who ordered
	cust.set_hair_color(order.hair_color)
	cust.walk([_door_out, _door_in, _collect_spot()], func() -> void: _on_collector_arrived(cust))


func _on_collector_arrived(cust: Customer) -> void:
	var order: SuitOrder = cust.collect_order
	if order != null and Orders.is_ready(order):
		cust.offer_collection(order)
	else:
		# Deadline passed unfinished — the customer leaves empty-handed.
		if order != null:
			Orders.expire(order)
		cust.collect_order = null
		dismiss(cust)


## Where a returning customer waits — just inside the door, clear of the mirror.
func _collect_spot() -> Vector3:
	return _door_in + Vector3(0.9, 0.0, 0.0)


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
		_apply_event_bias(cust.preference)
	_dress(cust)
	cust.departed.connect(_on_departed)
	_alive += 1
	return cust


## A looming city event (from the paper) skews some briefs toward its occasion/style,
## so the player who read the paper and prepared is rewarded.
func _apply_event_bias(pref: CustomerPreference) -> void:
	if pref == null or News == null:
		return
	var day: int = Shift.day if Shift != null else 1
	var bias := News.event_bias(day, _rng)
	if bias.has("occasion"):
		pref.occasion = int(bias["occasion"])
	if bias.has("style"):
		pref.style = int(bias["style"])


func _dress(cust: Customer) -> void:
	cust.apply_look(Wardrobe.random_skin(_rng))
	cust.set_hair(_rng.randi() % maxi(1, Wardrobe.hair_count()))
	cust.set_hair_color(Wardrobe.random_hair_color(_rng))
	cust.wear_street()


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

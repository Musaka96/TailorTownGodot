class_name CustomerManager
extends Node3D

## Spawns pedestrians on the street and turns some of them into shoppers. Owns the
## storefront geometry (door / greet / mirror / street-end markers) and routes a
## customer through the flow: enter → wait to be greeted → walk to the fitting
## mirror → (design approved) → leave. Only one shopper is served at a time; extra
## shoppers just walk past until the shop is free.

const CUSTOMER_SCENE := preload("res://entities/customer/customer.tscn")
## Roughly one in five customers wears glasses, split between shades and readers.
const GLASSES_CHANCE := 0.2

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
## Which way a fitted customer turns to face — taken from the MirrorSpot marker's
## rotation, so moving/rotating that waypoint also re-aims the fitting camera (the
## suit builder frames the customer from their front, i.e. along their facing).
var _mirror_spot_yaw := 0.0
var _door_in := Vector3.ZERO
var _door_out := Vector3.ZERO
var _street_west := Vector3.ZERO
var _street_east := Vector3.ZERO
var _served: Customer = null
var _alive := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("customer_manager")  # the tutorial finds us here to poof a customer in
	EventBus.order_due.connect(_on_order_due)
	# Defer so all sibling markers/stations exist and report global positions.
	call_deferred("_start")


func _start() -> void:
	_rng.randomize()
	_mirror = get_node_or_null(mirror_path)
	_greet = _pos(greet_path)
	_mirror_spot = _pos(mirror_spot_path)
	_mirror_spot_yaw = _yaw(mirror_spot_path)
	_door_in = _pos(door_in_path)
	_door_out = _pos(door_out_path)
	_street_west = _pos(street_west_path)
	_street_east = _pos(street_east_path)

	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_spawn_tick)


# --- Spawning --------------------------------------------------------------


func _spawn_tick() -> void:
	# During the tutorial the day hasn't started — no street traffic (the only customer is
	# the one the tutorial poofs in for the fitting step).
	if Tutorial != null and Tutorial.is_active():
		return
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


## Poof a customer into the shop at the greet spot for the tutorial fitting step.
func spawn_tutorial_customer() -> void:
	if _served != null or _greet == Vector3.ZERO:
		return
	var cust := _spawn(_greet, true)
	# The tutorial teaches a fixed, premade brief so it can spell out exactly what to make.
	if Tutorial != null and Tutorial.is_active() and Tutorial.has_method("tutorial_pref"):
		cust.preference = Tutorial.tutorial_pref()
	_served = cust
	# Hide them inside a magic cloud, then reveal once it's billowed up — so the player never
	# sees the figure pop into existence.
	cust.visible = false
	_poof_at(cust.global_position)
	get_tree().create_timer(0.22).timeout.connect(
		func() -> void:
			if is_instance_valid(cust):
				cust.visible = true
	)
	cust.offer_greeting()
	EventBus.customer_waiting.emit(cust)


## A big magic cloud that engulfs a whole figure at `pos` (feet position) — used to hide a
## customer poofing into the shop. Emits soft puffs throughout a body-sized volume.
func _poof_at(pos: Vector3) -> void:
	if Sfx != null:
		Sfx.play("cloth_rustle", 0.0, 1.0, 1.2)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)  # big soft puffs
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	qm.material = mat
	var p := CPUParticles3D.new()
	p.mesh = qm
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 72
	p.lifetime = 1.1
	# Spawn puffs all through a body-sized box (feet→head) so the whole figure is covered.
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.45, 0.9, 0.45)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.5, 0)  # drifts gently upward like smoke
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.color = Color(0.98, 0.96, 0.9)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	add_child(p)
	p.global_position = pos + Vector3(0, 0.9, 0)  # centre on the body
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


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
	var gender := Enums.Gender.MALE if _rng.randf() < 0.5 else Enums.Gender.FEMALE
	cust.gender = gender
	var eye: String = CharacterRig.EYE_COLORS[_rng.randi() % CharacterRig.EYE_COLORS.size()]
	var glasses := ""
	if _rng.randf() < GLASSES_CHANCE:
		glasses = "sun" if _rng.randf() < 0.5 else "round"
	# A head and its own hair are one combo (same glb, same index) — never mixed. Only
	# the skin and hair COLOURS vary independently.
	var combo := maxi(0, Wardrobe.random_head_index(gender, _rng))
	cust.apply_look(Wardrobe.random_skin(_rng), eye, glasses, combo)
	cust.set_hair(combo)
	cust.set_hair_color(Wardrobe.random_hair_color(_rng))
	cust.wear_street()


# --- Routing (called by Customer / UI) -------------------------------------


func route_to_mirror(cust: Customer) -> void:
	cust.walk([_mirror_spot], func() -> void: _on_seated(cust), _mirror_spot_yaw)


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


## Global yaw a marker points along (its +Z), so a customer set to this heading has
## the marker's facing — and the camera, which sits along that facing, respects it.
func _yaw(path: NodePath) -> float:
	var node := get_node_or_null(path)
	if node is Node3D:
		var z: Vector3 = (node as Node3D).global_transform.basis.z
		return atan2(z.x, z.z)
	return 0.0

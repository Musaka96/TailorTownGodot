class_name Player
extends CharacterBody3D

## Top-down player controller.
##
## Movement is *camera-relative*: pushing "forward" always moves the character
## away from the camera regardless of where the camera is pointing, which is the
## behaviour players expect in a top-down 3D game. Works identically for
## keyboard (WASD / arrows) and an analog gamepad stick, because it reads the
## input as a single Vector2 via Input.get_vector().

## Seconds between footstep sounds while walking — a calm, steady cadence that
## reads as cute rather than a realistic run.
const STEP_TIME := 0.5
## Sprint (hold Shift / right shoulder): faster move speed, a quicker walk cycle and
## snappier footsteps to match.
const SPRINT_SPEED_MULT := 1.7
const SPRINT_ANIM_MULT := 1.6

## Peak horizontal speed in metres/second.
@export var move_speed: float = 6.0
## How quickly velocity blends toward the target (m/s^2). Higher = snappier,
## less "ice". This gives us acceleration and deceleration for free.
@export var acceleration: float = 45.0
## How quickly the visual model turns to face the travel direction (rad/s-ish).
@export var turn_speed: float = 12.0
## Upward velocity applied on jump (m/s).
@export var jump_velocity: float = 5.0

# Read the gravity from Project Settings so it stays consistent with the rest of
# the physics world instead of being a magic number.
var _step_t := 0.0
var _was_moving := false
var _sprinting := false

## The player's hands. Stations reach it as `actor.carry`.
@onready var carry: CarrySlot = $Carry
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
@onready var _model: Node3D = $Model


func _ready() -> void:
	# So systems like the roof fader can find us without a wired-up NodePath.
	add_to_group("player")
	# The shopkeeper wears a sharp charcoal suit over a white shirt.
	if _model.has_method("set_palette"):
		_model.set_palette(Color(0.90, 0.76, 0.66))
	if _model.has_method("set_outfit"):
		var suit: MaterialType = Catalog.get_material(&"charcoal_worsted_solid")
		if suit != null:
			_model.set_outfit(suit, null, suit)
	# Carry items from the rig's hand bone so they follow the hand and turn with us.
	if _model.has_method("carry_point"):
		var point: Node3D = _model.carry_point()
		if point != null:
			carry.set_hold_point(point)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not GameState.input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _to_world_direction(input)

	_sprinting = (
		not GameState.input_locked
		and Input.is_action_pressed("sprint")
		and input.length_squared() > 0.01
	)
	var top_speed := move_speed * (SPRINT_SPEED_MULT if _sprinting else 1.0)

	# Horizontal movement with smooth accel/decel on the XZ plane.
	var target := direction * top_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	# Vertical movement (gravity + jump).
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not GameState.input_locked:
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

	move_and_slide()

	if direction.length_squared() > 0.001:
		_face(direction, delta)

	var speed := Vector2(velocity.x, velocity.z).length()
	if _model.has_method("set_locomotion"):
		_model.set_locomotion(speed / maxf(move_speed, 0.01))  # smooth speed blend
	elif _model.has_method("set_moving"):
		_model.set_moving(speed > 0.4)
	if _model.has_method("set_locomotion_speed"):
		_model.set_locomotion_speed(SPRINT_ANIM_MULT if _sprinting else 1.0)
	if _model.has_method("set_carrying"):
		_model.set_carrying(not carry.is_empty())

	_footsteps(delta)


## Set the held item down on the floor just ahead of the player. Returns whether
## anything was put down. Called by the interaction controller when the interact
## button is pressed with nothing else to interact with.
func drop_held() -> bool:
	if carry.is_empty():
		return false
	var item: Node = carry.release()
	if item.get_parent() != null:
		item.get_parent().remove_child(item)  # release() only clears the slot, not the hand
	var parent: Node = _drop_parent()
	parent.add_child(item)
	var ahead := _model.global_transform.basis.z  # the way the model is facing
	ahead.y = 0.0
	item.global_position = global_position + ahead.normalized() * 0.7 + Vector3(0.0, 0.15, 0.0)
	if item.has_method("set_pickable"):
		item.set_pickable(true)
	EventBus.item_dropped.emit(item)
	return true


## Loose items live under ShopRoom (so they're saved), falling back to the scene.
func _drop_parent() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		var room := scene.get_node_or_null("ShopRoom")
		if room != null:
			return room
		return scene
	return get_parent()


## Soft footstep pats on a steady, gentle cadence while walking.
func _footsteps(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.6 and is_on_floor()
	var interval := STEP_TIME / (SPRINT_ANIM_MULT if _sprinting else 1.0)
	if moving:
		if not _was_moving:
			_step_t = interval  # land the first step promptly on setting off
		_step_t += delta
		if _step_t >= interval:
			_step_t = 0.0
			Sfx.play("footstep_wood", -7.0)
	_was_moving = moving


## Converts a 2D input vector into a world-space direction on the ground plane,
## rotated so that "up" on the stick points away from the active camera.
func _to_world_direction(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		# Fall back to world axes if there is no camera yet.
		return Vector3(input.x, 0.0, input.y)

	var basis := cam.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	# input.y is negative when pushing "forward", so negate it to move along +forward.
	return (right * input.x + forward * -input.y).limit_length(1.0)


## Smoothly rotates the model so its +Z face points along the travel direction.
func _face(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(direction.x, direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, turn_speed * delta)

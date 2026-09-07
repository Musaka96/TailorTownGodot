class_name Player
extends CharacterBody3D

## Top-down player controller.
##
## Movement is *camera-relative*: pushing "forward" always moves the character
## away from the camera regardless of where the camera is pointing, which is the
## behaviour players expect in a top-down 3D game. Works identically for
## keyboard (WASD / arrows) and an analog gamepad stick, because it reads the
## input as a single Vector2 via Input.get_vector().

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
## The player's hands. Stations reach it as `actor.carry`.
@onready var carry: CarrySlot = $Carry
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
@onready var _model: Node3D = $Model


func _ready() -> void:
	# The shopkeeper is a toon character too — skin/hair + a sharp charcoal suit.
	if _model.has_method("set_palette"):
		_model.set_palette(Color(0.90, 0.76, 0.66), Color(0.28, 0.20, 0.13))
	if _model.has_method("set_outfit"):
		var suit: MaterialType = Catalog.get_material(&"charcoal_worsted_solid")
		if suit != null:
			_model.set_outfit(suit, suit)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not GameState.input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _to_world_direction(input)

	# Horizontal movement with smooth accel/decel on the XZ plane.
	var target := direction * move_speed
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

	if _model.has_method("set_moving"):
		_model.set_moving(Vector2(velocity.x, velocity.z).length() > 0.4)


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

class_name RackSway
extends Node

## Life for a clothing rack: whatever hangs on its hooks swings from the bar — a slow
## idle breath, a swing when something is hung or taken, and a stir when the player brushes
## past. Each hook is a damped spring, rotated about the bar above it, so garments settle
## rather than stop. Purely cosmetic; add as a child of the rack and hand it the hooks' root.
##   var sway := RackSway.new(); sway.hooks = $Slots; add_child(sway)

## How far above a hook the bar (the swing's pivot) sits.
const BAR_ABOVE := 0.25
const IDLE_ANGLE := 0.014
const STIFFNESS := 22.0
const DAMPING := 2.6
const BRUSH_RADIUS := 1.1
const BRUSH_PUSH := 1.6
const MAX_ANGLE := 0.30

var hooks: Node3D

var _rest := {}  # hook -> Transform3D at rest
var _angle := {}  # hook -> radians
var _speed := {}  # hook -> radians / second
var _time := 0.0


func _process(delta: float) -> void:
	if hooks == null:
		return
	_time += delta
	var brush := _brush()
	for hook in hooks.get_children():
		if hook is Marker3D:
			_swing(hook as Marker3D, delta, brush)


## Set a hook swinging (index into the hooks' root), e.g. as something is hung on it.
func kick(index: int, strength := 1.0) -> void:
	var list := hooks.get_children() if hooks != null else []
	if index < 0 or index >= list.size():
		return
	var hook: Node = list[index]
	_speed[hook] = float(_speed.get(hook, 0.0)) + 1.8 * strength
	# The neighbours catch a little of it.
	for near: int in [index - 1, index + 1]:
		if near >= 0 and near < list.size():
			_speed[list[near]] = float(_speed.get(list[near], 0.0)) + 0.5 * strength


func _swing(hook: Marker3D, delta: float, brush: Vector3) -> void:
	if not _rest.has(hook):
		_rest[hook] = hook.transform
		_angle[hook] = 0.0
		_speed[hook] = float(_speed.get(hook, 0.0))
	if hook.get_child_count() == 0:
		hook.transform = _rest[hook]
		_angle[hook] = 0.0
		_speed[hook] = 0.0
		return
	var rest: Transform3D = _rest[hook]
	var angle: float = _angle[hook]
	var speed: float = _speed[hook]
	if brush != Vector3.ZERO:
		var away := hook.global_position - brush
		away.y = 0.0
		if away.length() < BRUSH_RADIUS:
			# Pushed along the rack's depth, away from whoever is walking by.
			var depth := hooks.global_transform.basis.z
			speed += signf(away.dot(depth)) * BRUSH_PUSH * delta * 6.0
	var idle := sin(_time * 0.9 + rest.origin.x * 5.0) * IDLE_ANGLE
	speed += (-STIFFNESS * (angle - idle) - DAMPING * speed) * delta
	angle = clampf(angle + speed * delta, -MAX_ANGLE, MAX_ANGLE)
	_angle[hook] = angle
	_speed[hook] = speed
	var pivot := rest.origin + Vector3(0.0, BAR_ABOVE, 0.0)
	var turn := Basis(Vector3.RIGHT, angle)
	hook.transform = Transform3D(turn * rest.basis, pivot + turn * (rest.origin - pivot))


## Where the player is, if they're on the move (standing still stirs nothing).
func _brush() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or player.velocity.length() < 0.5:
		return Vector3.ZERO
	return player.global_position

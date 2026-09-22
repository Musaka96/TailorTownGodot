class_name DeliveryBox
extends Node3D

## The postal box a phone-ordered bolt arrives in. It pops in with a poof, the top flaps
## swing open, then the four sides fold down flat and leave the bolt lying on a cross of
## cardboard. The bolt can't be picked up until the box is open; once it is, the flat box
## poofs away. Built entirely in code, no textures.
##   DeliveryBox.wrap(roll)  # right after placing a delivered roll

const WIDTH := 0.42  # inside, across the bolt (local X)
const LENGTH := 0.72  # inside, along the bolt (local Z)
const HEIGHT := 0.32
const THICK := 0.012
const SHORT_FLAP := 0.20
## Roll origin sits this far above the floor (its radius).
const ROLL_LIFT := 0.13
const KRAFT := Color(0.78, 0.60, 0.40)
const TAPE := Color(0.93, 0.86, 0.72)
const LABEL := Color(0.97, 0.96, 0.93)
const INK := Color(0.30, 0.30, 0.32)
const PUFF := Color(1.0, 0.97, 0.90)
## Flaps swing open to stand a touch past upright; as their wall falls they fold the rest
## of the way over onto the wall's inside face, so they end lying on top of the flat wall.
const FLAP_OPEN := 100.0
const FLAP_FOLDED := -90.0
const FLAPS_AT := 0.7
const SIDES_AT := 1.4
const FALL := 0.28

var _roll: Node3D
var _unpacked := false
var _gone := false
var _tween: Tween
var _cardboard: StandardMaterial3D
## Each entry: {hinge: Node3D, axis: "x"/"z", fold: float (deg), flap: Node3D, sign: float}
## `sign` turns a flap outward (open) about its axis.
var _long: Array[Dictionary] = []
var _short: Array[Dictionary] = []


## Box `roll` where it lies: the box sits on the floor under it, turned to match, and the
## roll stays out of reach until the box has unpacked.
static func wrap(roll: Node3D) -> DeliveryBox:
	var box := DeliveryBox.new()
	box._roll = roll
	# Place it before it enters the tree: _ready starts the show at the box's position.
	var at := roll.global_position
	var floor_at := Vector3(at.x, at.y - ROLL_LIFT + 0.002, at.z)
	var world := Transform3D(Basis(Vector3.UP, roll.global_rotation.y), floor_at)
	var parent := roll.get_parent()
	box.transform = world
	if parent is Node3D:
		box.transform = (parent as Node3D).global_transform.affine_inverse() * world
	parent.add_child(box)
	roll.global_position = floor_at + Vector3.UP * (ROLL_LIFT + THICK)  # on the base panel
	if roll.has_method("set_pickable"):
		roll.set_pickable(false)
	roll.visible = false
	return box


func _ready() -> void:
	_build()
	if EventBus != null:
		EventBus.item_picked_up.connect(_on_picked_up)
	if is_instance_valid(_roll):
		_roll.tree_exited.connect(_on_roll_left)
	_play()


# --- Timeline ----------------------------------------------------------------------


func _play() -> void:
	if Sfx != null:
		Sfx.play("reno_poof", -2.0, 0.95, 1.1)
	_poof(14, 0.5)
	scale = Vector3.ONE * 0.01
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector3(1.15, 0.7, 1.15), 0.12)
	(
		_tween
		. tween_property(self, "scale", Vector3.ONE, 0.18)
		. from(Vector3(1.15, 0.7, 1.15))
		. set_delay(0.12)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.tween_callback(_show_roll).set_delay(0.3)
	# The long flaps lie on top, so they open first; the short ones tucked under follow.
	var t := FLAPS_AT
	for side: Dictionary in _long + _short:
		_open_flap(side, t)
		t += 0.08
	t = SIDES_AT
	for side: Dictionary in _short + _long:
		_fold_side(side, t)
		t += 0.06
	_tween.tween_callback(_on_unpacked).set_delay(t - 0.06 + FALL + 0.2)


func _open_flap(side: Dictionary, at: float) -> void:
	var flap: Node3D = side["flap"]
	var prop := "rotation_degrees:%s" % side["axis"]
	(
		_tween
		. tween_property(flap, prop, FLAP_OPEN * side["sign"], 0.35)
		. from(0.0)
		. set_delay(at)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


## The side falls outward (speeding up like it would), slaps the floor, hops up a few
## degrees and settles. On the same curve its flap folds over onto the wall's inside
## face: it keeps pointing up-and-inward the whole way (mirroring the wall), so it never
## reaches the floor or the roll, and lands on top of the flat wall, tape side up.
func _fold_side(side: Dictionary, at: float) -> void:
	var hinge: Node3D = side["hinge"]
	var flap: Node3D = side["flap"]
	var prop := "rotation_degrees:%s" % side["axis"]
	var fold: float = side["fold"]
	var sgn: float = side["sign"]
	(
		_tween
		. tween_property(hinge, prop, fold, FALL)
		. from(0.0)
		. set_delay(at)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_tween
		. tween_property(flap, prop, FLAP_FOLDED * sgn, FALL)
		. from(FLAP_OPEN * sgn)
		. set_delay(at)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_tween
		. tween_property(hinge, prop, fold * 0.88, 0.08)
		. from(fold)
		. set_delay(at + FALL)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(hinge, prop, fold, 0.1)
		. from(fold * 0.88)
		. set_delay(at + FALL + 0.08)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)


func _show_roll() -> void:
	if is_instance_valid(_roll):
		_roll.visible = true


func _on_unpacked() -> void:
	_unpacked = true
	if is_instance_valid(_roll) and _roll.has_method("set_pickable"):
		_roll.set_pickable(true)


# --- Leaving -------------------------------------------------------------------------


func _on_picked_up(item: Node) -> void:
	if item == _roll:
		_vanish()


## The roll left the floor: picked up (reparented to the hand) or freed. Wait a frame and
## go if it's no longer lying beside the box.
func _on_roll_left() -> void:
	_check_roll.call_deferred()


func _check_roll() -> void:
	if _gone:
		return
	if (
		not is_instance_valid(_roll)
		or not _roll.is_inside_tree()
		or _roll.get_parent() != get_parent()
	):
		_vanish()


func _vanish() -> void:
	if _gone or not is_inside_tree():
		return
	_gone = true
	if is_instance_valid(_roll):
		_roll.visible = true
	if _tween != null:
		_tween.kill()
	if Sfx != null:
		Sfx.play("reno_poof", -5.0, 1.1, 1.25)
	_poof(8, 0.4)
	var out := create_tween()
	(
		out
		. tween_property(self, "scale", Vector3.ONE * 0.01, 0.22)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	out.tween_callback(queue_free)


# --- Poof ------------------------------------------------------------------------------


## Soft cream puffs from the middle of the box. They live under the box's parent so
## freeing the box doesn't cut them off.
func _poof(count: int, life: float) -> void:
	var host := get_parent()
	if host == null:
		return
	var p := CPUParticles3D.new()
	p.mesh = _puff_quad()
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.5
	p.damping_min = 2.0
	p.damping_max = 3.5
	p.gravity = Vector3(0, 0.4, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.5, 0.85))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	p.color = PUFF
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0.3))
	p.color_ramp = ramp
	# Place it before it enters the tree: a one-shot burst fires on its first frame, before
	# a global_position set after add_child has reached it, so it would puff at the origin.
	var at := global_position + Vector3.UP * HEIGHT * 0.5
	p.position = (host as Node3D).to_local(at) if host is Node3D else at
	host.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


func _puff_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = ContactShadow.soft_dot()
	quad.material = mat
	return quad


# --- Build -----------------------------------------------------------------------------


func _build() -> void:
	_cardboard = _flat(KRAFT)
	_panel(
		self, Vector3(WIDTH + THICK * 2.0, THICK, LENGTH + THICK * 2.0), Vector3(0, THICK * 0.5, 0)
	)
	for s: float in [1.0, -1.0]:
		_long.append(_long_side(s))
		_short.append(_short_side(s))
	_label(_long[0]["flap"])


## A long side (±X), a flap longer than the box that meets its twin in the middle, and
## half of the tape strip along that seam. One wall-thickness taller than the short
## sides, so its flap lies over theirs. Flaps hinge on the wall's inner top edge, so a
## flap folded onto the inside face lies on the wall, not in it.
func _long_side(s: float) -> Dictionary:
	var tall := HEIGHT + THICK
	var hinge := _hinge(self, Vector3(s * (WIDTH * 0.5 + THICK), THICK, 0))
	_panel(hinge, Vector3(THICK, tall, LENGTH), Vector3(-s * THICK * 0.5, tall * 0.5, 0))
	var reach := WIDTH * 0.5
	var flap := _hinge(hinge, Vector3(-s * THICK, tall, 0))
	_panel(
		flap, Vector3(reach, THICK, LENGTH + THICK * 2.0), Vector3(-s * reach * 0.5, THICK * 0.5, 0)
	)
	var tape := _panel(
		flap,
		Vector3(0.03, 0.002, LENGTH + THICK * 2.0),
		Vector3(-s * (reach - 0.015), THICK + 0.001, 0)
	)
	tape.material_override = _flat(TAPE)
	return {"hinge": hinge, "flap": flap, "axis": "z", "fold": -s * 90.0, "sign": -s}


## A short end (±Z) and its flap, which tucks under the long ones.
func _short_side(s: float) -> Dictionary:
	var hinge := _hinge(self, Vector3(0, THICK, s * (LENGTH * 0.5 + THICK)))
	_panel(
		hinge,
		Vector3(WIDTH + THICK * 2.0, HEIGHT, THICK),
		Vector3(0, HEIGHT * 0.5, -s * THICK * 0.5)
	)
	var flap := _hinge(hinge, Vector3(0, HEIGHT, -s * THICK))
	_panel(flap, Vector3(WIDTH, THICK, SHORT_FLAP), Vector3(0, THICK * 0.5, -s * SHORT_FLAP * 0.5))
	return {"hinge": hinge, "flap": flap, "axis": "x", "fold": s * 90.0, "sign": s}


## The address label on the +X long flap's top, near its wall: a white card with two
## lines of "writing". Up on the closed box and still up once the flap lies on its wall.
func _label(flap: Node3D) -> void:
	var x := -0.07
	var card := _panel(flap, Vector3(0.07, 0.002, 0.10), Vector3(x, THICK + 0.001, LENGTH * 0.2))
	card.material_override = _flat(LABEL)
	var ink := _flat(INK)
	for line: Vector2 in [Vector2(0.013, 0.07), Vector2(-0.012, 0.05)]:
		var at := Vector3(x + line.x, THICK + 0.0025, LENGTH * 0.2 - (0.07 - line.y) * 0.5)
		var mark := _panel(flap, Vector3(0.007, 0.001, line.y), at)
		mark.material_override = ink


func _hinge(parent: Node3D, at: Vector3) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = at
	parent.add_child(hinge)
	return hinge


func _panel(parent: Node3D, size: Vector3, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var panel := MeshInstance3D.new()
	panel.mesh = mesh
	panel.material_override = _cardboard
	panel.position = at
	parent.add_child(panel)
	return panel


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat

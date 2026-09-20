class_name DoorSign
extends Node3D

## The OPEN / CLOSED sign on its stand just inside the shop door — how the day is opened
## and closed (see the Shift autoload for the phases):
##   morning      flip to OPEN  -> the clock starts, customers come.
##   open         flip to CLOSED -> close early and finish the day. It asks first: the
##                next flip within CONFIRM_SECONDS confirms.
##   after hours  flip to CLOSED -> lock up, finish the day.
##
## Built entirely in code and placed from the level's DoorInside waypoint, so the
## hand-owned map needs no edit: DoorSign.attach(root), called from main.gd.

const OFFSET := Vector3(1.5, 0.0, -2.2)  # from DoorInside: beside the way in, clear of the wall
const POST_H := 1.3
const BOARD := Vector3(0.9, 0.5, 0.05)
const FLIP_SECONDS := 0.45
const CONFIRM_SECONDS := 5.0
const REACH := 1.5

var _board: Node3D
var _shows_open := false
var _confirm_until := 0.0
var _tween: Tween


## Stand a sign by the door of the level under `root` (once).
static func attach(root: Node) -> void:
	if root.find_child("DoorSign", true, false) != null:
		return
	var marker := root.find_child("DoorInside", true, false) as Node3D
	var at := marker.global_position if marker != null else Vector3(0.66, 0.0, 7.2)
	# A shop with a different doorway says where its sign stands ("DoorSignSpot" marker).
	var spot := root.find_child("DoorSignSpot", true, false) as Node3D
	var sign := DoorSign.new()
	sign.name = "DoorSign"
	root.add_child(sign)
	sign.global_position = spot.global_position if spot != null else at + OFFSET


func _ready() -> void:
	_build()
	EventBus.day_began.connect(func(_day: int) -> void: _show(false))
	EventBus.shift_started.connect(func(_hour: float) -> void: _show(true))
	_show(Shift.is_open(), false)


# --- Interactable target ---------------------------------------------------


func get_interaction_prompt(_actor) -> String:
	if Tutorial != null and Tutorial.is_active():
		return ""  # the lesson runs outside the working day
	match Shift.phase:
		Shift.Phase.MORNING:
			return "Flip the sign — open the shop"
		Shift.Phase.OPEN:
			if _confirming():
				return "Flip again — close early and finish day %d" % Shift.day
			return "Flip the sign — close early"
	return "Flip the sign — finish day %d" % Shift.day


func interact(_actor) -> void:
	if Tutorial != null and Tutorial.is_active():
		return
	match Shift.phase:
		Shift.Phase.MORNING:
			Shift.open_shop()  # shift_started flips the board
		Shift.Phase.OPEN:
			_close_early()
		_:
			_show(false)
			Shift.close_shop()


func _close_early() -> void:
	if not _confirming():
		_confirm_until = _now() + CONFIRM_SECONDS
		var due := Shift.callers_still_due()
		var warn := ""
		if due > 0:
			warn = (
				" %d customer%s still due today will call tomorrow."
				% [due, "" if due == 1 else "s"]
			)
		UI.toast("Close early and finish the day?%s Flip the sign again to confirm." % warn)
		return
	_confirm_until = 0.0
	_show(false)
	Shift.close_shop(true)


func _confirming() -> bool:
	return _now() < _confirm_until


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- The board -------------------------------------------------------------


## Swing the board round to its OPEN (forest) or CLOSED (burgundy) face.
func _show(open_face: bool, animate := true) -> void:
	if _board == null:
		return
	var changed := open_face != _shows_open
	_shows_open = open_face
	var goal := 0.0 if open_face else PI
	if _tween != null:
		_tween.kill()
	if not animate or not changed:
		_board.rotation.y = goal
		return
	Sfx.play("page_turn", -3.0, 1.25, 1.35)
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_board, "rotation:y", goal, FLIP_SECONDS)


func _build() -> void:
	var wood := _mat(Style.WALNUT)
	var brass := _mat(Style.BRASS)
	_add_mesh(self, _cylinder(0.26, 0.06), wood, Vector3(0, 0.025, 0))
	_add_mesh(self, _cylinder(0.045, POST_H), wood, Vector3(0, POST_H * 0.5, 0))
	_add_mesh(self, _sphere(0.08), brass, Vector3(0, POST_H + 0.03, 0))
	# The board hangs from the post's top, turned up a little toward the camera.
	var tilt := Node3D.new()
	tilt.position = Vector3(0, POST_H - BOARD.y * 0.5 - 0.06, 0.06)
	tilt.rotation.x = deg_to_rad(-32.0)
	add_child(tilt)
	_board = Node3D.new()
	tilt.add_child(_board)
	var frame := BoxMesh.new()
	frame.size = BOARD + Vector3(0.08, 0.08, -0.015)
	_add_mesh(_board, frame, wood, Vector3.ZERO)
	var face := BoxMesh.new()
	face.size = BOARD
	_add_mesh(_board, face, _mat(Style.CREAM), Vector3.ZERO)
	_board.add_child(_label("OPEN", Style.FOREST, 1.0))
	_board.add_child(_label("CLOSED", Style.BURGUNDY, -1.0))
	_add_interactable()


func _label(text: String, col: Color, facing: float) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font = Style.bold_font()
	lbl.font_size = 128
	lbl.pixel_size = 0.0019
	lbl.modulate = col
	lbl.outline_size = 0
	# Cut out, not blended: the outline post-pass would otherwise paint over it.
	lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lbl.double_sided = false
	lbl.position = Vector3(0, 0, (BOARD.z * 0.5 + 0.002) * facing)
	lbl.rotation.y = 0.0 if facing > 0.0 else PI
	return lbl


func _add_interactable() -> void:
	var area := Interactable.new()
	area.collision_layer = 4  # the interactable layer the player's Interactor scans
	area.collision_mask = 0
	area.monitorable = true
	area.target = self
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = REACH
	shape.shape = sphere
	area.add_child(shape)
	area.position = Vector3(0, 0.6, 0)
	add_child(area)


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = at
	parent.add_child(inst)


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	return mat

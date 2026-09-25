extends SceneTree

## Integration sheet for the CHARTGEN2 base swap and the jacket-model swap. NOT headless:
##   godot --path . --script res://tools/shot_integration.gd
## Writes IMPORT/CHARREWORK/report/integration/<shot>.png (git-ignored):
##   player_*       the tailor (scenes/player/player.tscn, its own _dress: double-breasted)
##   styles_*       three rigs in one navy cloth via set_outfit, jacket style 0 / 1 / 2
##                  (single-breasted, double-breasted, the tuxedo placeholder)
##   street_*       a customer head in wear_street(): no buttons, pocket square or tie
##   carry_*        a rig holding a box on its carry point (hand.r), arms in the hold pose
##   face_base_*    head 0 (the base CHARTGEN2 head) close up, to check the face depth
## The game's own idle is used (not the calm test idle), so poses read as in play.
##
## With `-- --street` it shoots the street wardrobe instead, to
## IMPORT/CHARREWORK/report/street_game/:
##   street_<outfit>_front / _three_quarter / _back / _walk   each street outfit on a rig
##   street_customer_1_street / _2_suit / _3_street   one customer (customer.tscn) in
##       street clothes, then wear_suit (their own shoes come back), then street again
##
## With `-- --glasses` it shoots the 3D glasses, to IMPORT/CHARREWORK/report/glasses_game/:
##   glasses_<style>_base_front / _side     each style on head 0 (the base head)
##   glasses_<style>_tripo_front / _side    and on a tripo head with a deeper face
##   glasses_lineup_front / _three_quarter  customers (customer.tscn) with random glasses

# rig slots in the row
enum Slot { PLAYER, SB, DB, TUX, STREET, CARRY }

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const SUIT := "res://data/materials/navy_worsted_solid.tres"
const OUT_DIR := "res://IMPORT/CHARREWORK/report/integration"
const STREET_DIR := "res://IMPORT/CHARREWORK/report/street_game"
const GLASSES_DIR := "res://IMPORT/CHARREWORK/report/glasses_game"
const GLASSES_TRIPO_HEAD := 5  # tripo_head_bl: face depth 0.467, well in front of 0.421
const LINEUP := 6
const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const STREET_HEADS := [3, 6]
const SKIN := Color(0.86, 0.72, 0.60)
const HAIR := Color(0.28, 0.18, 0.10)
const STREET_HEAD := 3
const GAP := 1.4
const GAME_OFFSET := Vector3(0.0, 6.271325, 4.392928)
const SETTLE := 40

var _rigs: Array[Node3D] = []  # by Slot; the player's entry is the player body
var _cam: Camera3D
# [file name, [slots shown], camera position, look at, fov, optional Callable run first]
var _shots: Array = []
var _shot := 0
var _frame := 0
var _street := false
var _glasses := false
var _out_dir := OUT_DIR


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1200, 900))
	var world := Node3D.new()
	root.add_child(world)
	_add_lights(world)
	_add_floor(world)
	_cam = Camera3D.new()
	world.add_child(_cam)
	_cam.make_current()
	process_frame.connect(_on_frame)
	if "--street" in OS.get_cmdline_user_args():
		_street = true
		_out_dir = STREET_DIR
		_init_street(world)
		return
	if "--glasses" in OS.get_cmdline_user_args():
		_glasses = true
		_out_dir = GLASSES_DIR
		_init_glasses(world)
		return
	var rig_scene := load(RIG_SCENE) as PackedScene
	for slot in Slot.size():
		var node: Node3D
		if slot == Slot.PLAYER:
			node = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
		else:
			node = rig_scene.instantiate() as Node3D
		node.position.x = (slot - (Slot.size() - 1) * 0.5) * GAP
		world.add_child(node)
		_rigs.append(node)


## Street mode: per outfit a standing rig and a walking one, then one customer.
func _init_street(world: Node3D) -> void:
	var rig_scene := load(RIG_SCENE) as PackedScene
	var count: int = Wardrobe.library().street_outfits.size()
	for k in count * 2:
		var rig := rig_scene.instantiate() as Node3D
		rig.position.x = k * GAP * 2.0
		world.add_child(rig)
		_rigs.append(rig)
	var cust := (load(CUSTOMER_SCENE) as PackedScene).instantiate() as Node3D
	cust.position.x = count * 2 * GAP * 2.0
	world.add_child(cust)
	_rigs.append(cust)


func _dress_street() -> void:
	var count: int = Wardrobe.library().street_outfits.size()
	for k in count * 2:
		var rig := _rigs[k]
		var head: int = STREET_HEADS[floori(k / 2.0) % STREET_HEADS.size()]
		rig.call("set_head", head)
		rig.call("set_hair", head)
		rig.call("set_palette", SKIN)
		rig.call("set_hair_color", HAIR)
		rig.call("set_face_look", "brown", "", 0, 0)
		rig.call("wear_street", Wardrobe.street_outfit(floori(k / 2.0)))
		rig.call("set_moving", k % 2 == 1)
	var cust := _rigs[count * 2]
	cust.set("street_index", 0)
	cust.set("shoes", {"color": "oxblood", "finish": "calf"})
	cust.call("apply_look", SKIN, "green", "", STREET_HEADS[0])
	cust.call("set_hair", STREET_HEADS[0])
	cust.call("set_hair_color", HAIR)
	cust.call("wear_street")


func _plan_street() -> void:
	var target := Vector3(0.0, 0.9, 0.0)
	var count: int = Wardrobe.library().street_outfits.size()
	for i in count:
		var tag := "street_" + Wardrobe.street_outfit(i).display_name.to_lower()
		var s := _x(i * 2)
		var w := _x(i * 2 + 1)
		var one := [i * 2]
		_shots.append([tag + "_front", one, s + Vector3(0, 1.1, 4.2), s + target, 30.0])
		var quarter := s + Vector3(2.4, 1.6, 3.2)
		_shots.append([tag + "_three_quarter", one, quarter, s + target, 30.0])
		_shots.append([tag + "_back", one, s + Vector3(0, 1.1, -4.2), s + target, 30.0])
		var walk := w + Vector3(2.4, 1.6, 3.2)
		_shots.append([tag + "_walk", [i * 2 + 1], walk, w + target, 30.0])
	var c := count * 2
	var cx := _x(c)
	var cam := cx + Vector3(1.6, 1.4, 3.6)
	var suit := load(SUIT) as Resource
	var to_suit := func() -> void: _rigs[c].call("wear_suit", suit, null, suit, 1, 0)
	var to_street := func() -> void: _rigs[c].call("wear_street")
	_shots.append(["street_customer_1_street", [c], cam, cx + target, 30.0])
	_shots.append(["street_customer_2_suit", [c], cam, cx + target, 30.0, to_suit])
	_shots.append(["street_customer_3_street", [c], cam, cx + target, 30.0, to_street])


## Glasses mode: per style a base-head rig and a tripo-head rig, then a customer lineup.
func _init_glasses(world: Node3D) -> void:
	var rig_scene := load(RIG_SCENE) as PackedScene
	for k in Wardrobe.glasses_kinds().size() * 2:
		var rig := rig_scene.instantiate() as Node3D
		rig.position.x = k * GAP * 2.0
		world.add_child(rig)
		_rigs.append(rig)
	var start := _rigs.size() * GAP * 2.0 + 4.0
	var cust_scene := load(CUSTOMER_SCENE) as PackedScene
	for k in LINEUP:
		var cust := cust_scene.instantiate() as Node3D
		cust.position.x = start + k * 1.1
		world.add_child(cust)
		_rigs.append(cust)


func _dress_glasses() -> void:
	var kinds := Wardrobe.glasses_kinds()
	# By path: the class name drags Config-dependent scripts into this --script compile.
	var colors: Array = load("res://entities/character/character_rig.gd").GLASSES_COLORS.keys()
	for k in kinds.size() * 2:
		var rig := _rigs[k]
		var head: int = 0 if k % 2 == 0 else GLASSES_TRIPO_HEAD
		rig.call("set_head", head)
		rig.call("set_hair", head)
		rig.call("set_palette", SKIN)
		rig.call("set_hair_color", HAIR)
		rig.call("wear_street", Wardrobe.street_outfit(0))
		rig.set("glasses_color", colors[floori(k / 2.0) % colors.size()])
		rig.call("set_face_look", "brown", kinds[floori(k / 2.0)], 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in LINEUP:
		var cust := _rigs[kinds.size() * 2 + k]
		var head := 1 + rng.randi() % (Wardrobe.head_count() - 1)
		cust.set("street_index", rng.randi() % Wardrobe.library().street_outfits.size())
		cust.set("glasses_color", colors[rng.randi() % colors.size()])
		var skin := Wardrobe.skin(rng.randi_range(0, Wardrobe.skin_count() - 1))
		cust.call("apply_look", skin, "brown", kinds[k % kinds.size()], head)
		cust.call("set_hair", head)
		cust.call("set_hair_color", Wardrobe.hair_color(rng.randi_range(0, 5)))
		cust.call("wear_street")
		cust.rotation.y = rng.randf_range(-0.4, 0.4)


func _plan_glasses() -> void:
	var kinds := Wardrobe.glasses_kinds()
	for i in kinds.size():
		for v in 2:
			var k := i * 2 + v
			var head := _head_position(_rigs[k])
			var tag := "glasses_%s_%s" % [kinds[i], "base" if v == 0 else "tripo"]
			var front := head + Vector3(0.0, 0.05, 2.3)
			_shots.append([tag + "_front", [k], front, head, 30.0])
			_shots.append([tag + "_side", [k], head + Vector3(2.3, 0.05, 0.0), head, 30.0])
	var first := kinds.size() * 2
	var group: Array = range(first, first + LINEUP)
	var mid := (_x(first) + _x(first + LINEUP - 1)) * 0.5
	var look := mid + Vector3(0, 1.2, 0)
	_shots.append(["glasses_lineup_front", group, mid + Vector3(0, 1.4, 9.0), look, 30.0])
	var quarter := mid + Vector3(4.0, 3.0, 8.0)
	_shots.append(["glasses_lineup_three_quarter", group, quarter, look, 30.0])


func _dress() -> void:
	var suit := load(SUIT) as Resource
	for slot in [Slot.SB, Slot.DB, Slot.TUX, Slot.CARRY]:
		var rig := _rigs[slot]
		rig.call("set_palette", SKIN)
		rig.call("set_hair_color", HAIR)
		var style: int = {Slot.SB: 0, Slot.DB: 1, Slot.TUX: 2, Slot.CARRY: 0}[slot]
		rig.call("set_outfit", suit, null, suit, style, 0)
		rig.call("set_face_look", "brown", "", 0, 0)
	var street := _rigs[Slot.STREET]
	street.call("set_head", STREET_HEAD)
	street.call("set_hair", STREET_HEAD)
	street.call("set_palette", SKIN)
	street.call("set_hair_color", HAIR)
	street.call("wear_street")
	street.call("set_face_look", "green", "", 1, 1)
	var carrier := _rigs[Slot.CARRY]
	carrier.call("set_carrying", true)
	var point := carrier.call("carry_point") as Node3D
	print("carry point: ", point.get_path() if point != null else "MISSING")
	if point != null:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 0.12, 0.3)
		box.mesh = mesh
		point.add_child(box)
	for slot in Slot.size():
		var skel := _rigs[slot].find_child("Skeleton3D", true, false) as Skeleton3D
		var face := _rigs[slot].find_child("FaceAttach", true, false)
		print(
			(
				"slot %d: head_2=%d face=%s scale=%s"
				% [slot, skel.find_bone("head_2"), face != null, _rigs[slot].scale]
			)
		)


func _plan() -> void:
	var target := Vector3(0.0, 0.9, 0.0)
	var p := _x(Slot.PLAYER)
	_shots.append(
		["player_front", [Slot.PLAYER], p + Vector3(0, 1.1, 4.2), p + Vector3(0, 0.9, 0), 30.0]
	)
	_shots.append(
		["player_game", [Slot.PLAYER], p + GAME_OFFSET * 0.55, p + Vector3(0, 0.7, 0), 75.0]
	)
	var mid := (_x(Slot.SB) + _x(Slot.TUX)) * 0.5
	var styles := [Slot.SB, Slot.DB, Slot.TUX]
	_shots.append(["styles_front", styles, mid + Vector3(0, 1.1, 7.0), mid + target, 30.0])
	var quarter := Vector3(3.0, 1.9, 6.5)
	_shots.append(["styles_three_quarter", styles, mid + quarter, mid + target, 30.0])
	_shots.append(
		["styles_torso", styles, mid + Vector3(0, 1.2, 4.6), mid + Vector3(0, 1.0, 0), 30.0]
	)
	var s := _x(Slot.STREET)
	_shots.append(["street_front", [Slot.STREET], s + Vector3(0, 1.1, 4.2), s + target, 30.0])
	var sq := s + Vector3(2.4, 1.6, 3.2)
	_shots.append(["street_three_quarter", [Slot.STREET], sq, s + target, 30.0])
	var c := _x(Slot.CARRY)
	_shots.append(
		["carry_three_quarter", [Slot.CARRY], c + Vector3(2.4, 1.7, 3.2), c + target, 30.0]
	)
	var head := _head_position(_rigs[Slot.SB])
	var sb := [Slot.SB]
	_shots.append(["face_base_front", sb, head + Vector3(0.0, 0.05, 2.3), head, 35.0])
	_shots.append(["face_base_side", sb, head + Vector3(2.3, 0.05, 0.0), head, 35.0])
	var three := head + Vector3(1.6, 0.3, 1.6)
	_shots.append(["face_base_three_quarter", sb, three, head, 35.0])


func _x(slot: int) -> Vector3:
	return Vector3(_rigs[slot].global_position.x, 0.0, 0.0)


func _head_position(rig: Node3D) -> Vector3:
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skel.find_bone("head_2")
	var p := skel.global_transform * skel.get_bone_global_pose(bone).origin
	return p + Vector3(0.0, 0.35, 0.0)  # the bone sits at the neck; aim at mid-skull


func _on_frame() -> void:
	_frame += 1
	if _frame == 2 and _shot == 0:
		_hide_hud(root)
		if _street:
			_dress_street()
		elif _glasses:
			_dress_glasses()
		else:
			_dress()
	if _frame == SETTLE and _shots.is_empty():
		if _street:
			_plan_street()
		elif _glasses:
			_plan_glasses()
		else:
			_plan()
	if _shots.is_empty() or _frame < SETTLE:
		return
	if _frame == SETTLE + 1:
		var shot: Array = _shots[_shot]
		if shot.size() > 5:
			(shot[5] as Callable).call()
		for slot in _rigs.size():
			_rigs[slot].visible = slot in shot[1]
		_cam.fov = float(shot[4])
		_cam.look_at_from_position(shot[2], shot[3], Vector3.UP)
	elif _frame == SETTLE + 8:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
		var path := "%s/%s.png" % [_out_dir, _shots[_shot][0]]
		var image := root.get_texture().get_image()
		if image != null and image.save_png(ProjectSettings.globalize_path(path)) == OK:
			print("Saved " + path)
		_shot += 1
		_frame = SETTLE
		if _shot >= _shots.size():
			quit(0)


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		elif child is Control:
			(child as Control).visible = false
		else:
			_hide_hud(child)


func _add_floor(world: Node3D) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 0.2, 120.0)
	shape.shape = box
	shape.position.y = -0.1
	body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.58, 0.52)
	floor_mesh.material_override = mat
	body.add_child(floor_mesh)
	world.add_child(body)


func _add_lights(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.76, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 200, 0)
	fill.light_energy = 0.4
	world.add_child(fill)

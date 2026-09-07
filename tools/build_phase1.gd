extends SceneTree

## Generates the Phase 1 scenes (carry / interaction / shelf / UI / shop room)
## through the engine so the .tscn are valid. Run headless AFTER --import:
##   godot --headless --path . --script res://tools/build_phase1.gd

const ROLL_SCENE := "res://entities/items/material_roll.tscn"
const SHELF_SCENE := "res://stations/shelf/shelf.tscn"
const UI_SCENE := "res://ui/ui.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const ROOM_SCENE := "res://scenes/world/shop_room.tscn"
const MAIN_SCENE := "res://main.tscn"

const INTERACT_LAYER := 4  # collision layer bit 3
const INTERACTABLE_SCRIPT := "res://entities/scripts/interactable.gd"

# Floor rolls: [material id, position x, z, remaining metres]
const FLOOR_ROLLS := [
	["navy_worsted_solid", -3.0, 2.0, 20.0],
	["charcoal_worsted_pinstripe", -1.2, 3.2, 9.5],
	["brown_tweed_herringbone", 1.4, 2.6, 15.0],
	["tan_linen_solid", 3.0, 1.4, 4.0],
	["blue_worsted_glencheck", -2.4, 0.4, 16.0],
	["midgrey_flannel_solid", 2.2, -0.6, 12.5],
	["black_worsted_solid", 0.2, 1.0, 20.0],
	["burgundy_mohair_birdseye", -0.8, -1.4, 6.0],
]


func _initialize() -> void:
	_build_roll_scene()
	_build_shelf_scene()
	_build_ui_scene()
	_build_player_scene()
	_build_room_scene()
	_build_main_scene()
	print("build_phase1: done.")
	quit(0)


# --- Material roll ---------------------------------------------------------

func _build_roll_scene() -> void:
	var root := Node3D.new()
	root.name = "MaterialRoll"
	root.set_script(load("res://entities/items/material_roll.gd"))

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.13
	cyl.height = 0.55
	mesh.mesh = cyl
	# Lay the cylinder on its side (axis along Z).
	mesh.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(mesh)

	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	col.shape = sphere
	area.add_child(col)
	root.add_child(area)

	_save(root, ROLL_SCENE)


# --- Shelf -----------------------------------------------------------------

func _build_shelf_scene() -> void:
	var root := Node3D.new()
	root.name = "Shelf"
	root.set_script(load("res://stations/shelf/shelf.gd"))

	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.33, 0.22)
	_add_box_mesh(body, "Back", Vector3(2.0, 1.6, 0.1), Vector3(0, 0.9, -0.2), wood)
	_add_box_mesh(body, "Plank1", Vector3(2.0, 0.08, 0.42), Vector3(0, 0.55, 0.0), wood)
	_add_box_mesh(body, "Plank2", Vector3(2.0, 0.08, 0.42), Vector3(0, 1.15, 0.0), wood)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.7, 0.42)
	col.shape = box
	col.position = Vector3(0, 0.85, 0)
	body.add_child(col)

	var slots := Node3D.new()
	slots.name = "Slots"
	root.add_child(slots)
	var xs := [-0.6, 0.0, 0.6]
	var ys := [0.72, 1.32]  # plank top + roll radius
	for y in ys:
		for x in xs:
			var m := Marker3D.new()
			m.name = "Slot_%d_%d" % [int(y * 100), int(x * 100)]
			m.position = Vector3(x, y, 0.06)
			slots.add_child(m)

	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.set("target", root)
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(2.2, 1.8, 1.3)
	acol.shape = abox
	acol.position = Vector3(0, 0.9, 0.6)
	area.add_child(acol)
	root.add_child(area)

	_save(root, SHELF_SCENE)


# --- UI --------------------------------------------------------------------

func _build_ui_scene() -> void:
	var root := CanvasLayer.new()
	root.name = "UI"
	root.set_script(load("res://ui/ui.gd"))

	# HUD
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_script(load("res://ui/hud.gd"))
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -84
	prompt.offset_bottom = -44
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 22)
	hud.add_child(prompt)

	var held := Label.new()
	held.name = "Held"
	held.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	held.offset_left = 16
	held.offset_top = 12
	held.add_theme_font_size_override("font_size", 18)
	hud.add_child(held)

	# Shelf menu
	var menu := Control.new()
	menu.name = "ShelfMenu"
	menu.set_script(load("res://ui/shelf_menu.gd"))
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)

	# CenterContainer centers the auto-sized panel.
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.name = "Title"
	box.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	box.add_child(hint)

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 8)
	box.add_child(list)

	_save(root, UI_SCENE)


# --- Player (rebuild with Carry + Interactor) ------------------------------

func _build_player_scene() -> void:
	var root := CharacterBody3D.new()
	root.name = "Player"
	root.set_script(load("res://scenes/player/player.gd"))

	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	root.add_child(collision)

	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.20, 0.55, 0.90)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = capsule
	body.material_override = body_mat
	body.position = Vector3(0, 0.9, 0)
	model.add_child(body)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.95, 0.85, 0.25)
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.25, 0.25, 0.35)
	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	nose.mesh = nose_mesh
	nose.material_override = nose_mat
	nose.position = Vector3(0, 0.9, 0.45)
	model.add_child(nose)

	# Hands
	var carry := Node3D.new()
	carry.name = "Carry"
	carry.set_script(load("res://entities/player/carry_slot.gd"))
	root.add_child(carry)
	var hold := Marker3D.new()
	hold.name = "HoldPoint"
	hold.position = Vector3(0, 1.15, 0.6)
	carry.add_child(hold)

	# Interaction detector
	var interactor := Area3D.new()
	interactor.name = "Interactor"
	interactor.set_script(load("res://entities/player/interaction_controller.gd"))
	interactor.set("player_path", NodePath(".."))
	interactor.collision_layer = 0
	interactor.collision_mask = INTERACT_LAYER
	interactor.monitoring = true
	interactor.monitorable = false
	var icol := CollisionShape3D.new()
	var isphere := SphereShape3D.new()
	isphere.radius = 1.6
	icol.shape = isphere
	icol.position = Vector3(0, 0.9, 0)
	interactor.add_child(icol)
	root.add_child(interactor)

	_save(root, PLAYER_SCENE)


# --- Shop room -------------------------------------------------------------

func _build_room_scene() -> void:
	var root := Node3D.new()
	root.name = "ShopRoom"

	# Environment + sun
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)

	# Floor + walls
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	root.add_child(floor_body)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.34, 0.30, 0.27)
	_add_box_collider(floor_body, "Ground", Vector3(16, 1, 16), Vector3(0, -0.5, 0), floor_mat)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.62, 0.60, 0.56)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	root.add_child(walls)
	var t := 0.3
	var h := 3.0
	_add_box_collider(walls, "N", Vector3(16, h, t), Vector3(0, h / 2, -8), wall_mat)
	_add_box_collider(walls, "S", Vector3(16, h, t), Vector3(0, h / 2, 8), wall_mat)
	_add_box_collider(walls, "E", Vector3(t, h, 16), Vector3(8, h / 2, 0), wall_mat)
	_add_box_collider(walls, "W", Vector3(t, h, 16), Vector3(-8, h / 2, 0), wall_mat)

	# Shelf against the back wall, facing into the room (+Z)
	var shelf: Node = load(SHELF_SCENE).instantiate()
	shelf.position = Vector3(0, 0, -7.0)
	root.add_child(shelf)

	# Scatter material rolls on the floor
	var roll_scene: PackedScene = load(ROLL_SCENE)
	for entry in FLOOR_ROLLS:
		var roll: Node = roll_scene.instantiate()
		roll.material = load("res://data/materials/%s.tres" % entry[0])
		roll.remaining_length_m = entry[3]
		roll.position = Vector3(entry[1], 0.13, entry[2])
		root.add_child(roll)

	_save(root, ROOM_SCENE)


# --- Main ------------------------------------------------------------------

func _build_main_scene() -> void:
	var root := Node3D.new()
	root.name = "Main"
	root.set_script(load("res://main.gd"))
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	var room: Node = load(ROOM_SCENE).instantiate()
	root.add_child(room)

	var player: Node3D = load(PLAYER_SCENE).instantiate()
	player.position = Vector3(0, 0.1, 4.5)
	root.add_child(player)

	var rig: Node = load("res://scenes/camera/camera_rig.tscn").instantiate()
	rig.set("target_path", NodePath("../Player"))
	root.add_child(rig)

	_save(root, MAIN_SCENE)


# --- Helpers ---------------------------------------------------------------

func _add_box_mesh(
		parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _add_box_collider(
		parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	_add_box_mesh(parent, node_name + "Mesh", size, pos, mat)
	var col := CollisionShape3D.new()
	col.name = node_name + "Col"
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	parent.add_child(col)


func _save(root: Node, path: String) -> void:
	_set_owner(root, root)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed: " + path)
		return
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote ", path)


func _set_owner(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		# Do NOT recurse into instanced sub-scenes: re-owning their internal
		# nodes turns them into editable-children overrides and corrupts the
		# instance (empty slots, duplicated rolls). Own the instance root only.
		if child.scene_file_path == "":
			_set_owner(child, owner_root)

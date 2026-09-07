extends SceneTree

## Generates the Phase 1 scenes (carry / interaction / shelf / UI / shop room)
## through the engine so the .tscn are valid. Run headless AFTER --import:
##   godot --headless --path . --script res://tools/build_phase1.gd

const ROLL_SCENE := "res://entities/items/material_roll.tscn"
const PIECE_SCENE := "res://entities/items/fabric_piece.tscn"
const GARMENT_PIECE_SCENE := "res://entities/items/garment_piece.tscn"
const SUIT_SCENE := "res://entities/items/suit.tscn"
const RACK_SCENE := "res://stations/clothing_rack/clothing_rack.tscn"
const MANNEQUIN_SCENE := "res://stations/mannequin/mannequin.tscn"
const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const CHARACTER_SCENE := "res://entities/character/character_rig.tscn"
const MIRROR_SCENE := "res://stations/mirror/mirror.tscn"
const SHELF_SCENE := "res://stations/shelf/shelf.tscn"
const PHONE_SCENE := "res://stations/phone/phone.tscn"
const WORKTABLE_SCENE := "res://stations/worktable/worktable.tscn"
const SEWING_SCENE := "res://stations/sewing_machine/sewing_machine.tscn"
const UI_SCENE := "res://ui/ui.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const ROOM_SCENE := "res://scenes/world/shop_room.tscn"
const MAIN_SCENE := "res://main.tscn"

const INTERACT_LAYER := 4  # collision layer bit 3
const INTERACTABLE_SCRIPT := "res://entities/scripts/interactable.gd"

# --- Test bench items (organized sample rows near the left-front wall) ---
# Cloth: [material id, length]
const TEST_CLOTH := [
	["navy_worsted_pinstripe", 2.5],
	["brown_tweed_herringbone", 3.0],
	["tan_linen_solid", 1.5],
	["blue_worsted_glencheck", 2.0],
]
# Garment parts: [material id, type(0 shirt/1 pants/2 jacket), size(1 M/2 L), style, quality]
const TEST_CUT := [
	["charcoal_worsted_solid", 0, 1, "Classic", 0.85],
	["midgrey_flannel_solid", 1, 2, "Flat Front", 0.75],
	["navy_worsted_pinstripe", 2, 1, "Single-Breasted", 0.80],
]
const TEST_SEWN := [
	["lightgrey_worsted_sharkskin", 0, 1, "Slim", 0.90],
	["charcoal_worsted_pinstripe", 1, 2, "Pleated", 0.85],
	["black_worsted_solid", 2, 2, "Double-Breasted", 0.95],
]
# Suits: [material id for colour, quality]
const TEST_SUITS := [
	["navy_worsted_solid", 0.90],
	["charcoal_worsted_solid", 0.75],
	["burgundy_mohair_birdseye", 0.60],
]

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
	# Order matters: fabric piece before shelf (shelf preloads it), roll before
	# phone (phone preloads it).
	_build_fabric_piece_scene()
	_build_garment_piece_scene()
	_build_suit_scene()
	_build_roll_scene()
	_build_shelf_scene()
	_build_phone_scene()
	_build_worktable_scene()
	_build_sewing_machine_scene()
	_build_clothing_rack_scene()
	_build_mannequin_scene()
	_build_customer_scene()
	_build_mirror_scene()
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


# --- Fabric piece ----------------------------------------------------------


func _build_fabric_piece_scene() -> void:
	var root := Node3D.new()
	root.name = "FabricPiece"
	root.set_script(load("res://entities/items/fabric_piece.gd"))

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.06, 0.4)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.03, 0)
	root.add_child(mesh)

	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.55, 0.3, 0.45)
	col.shape = box_shape
	col.position = Vector3(0, 0.15, 0)
	area.add_child(col)
	root.add_child(area)

	_save(root, PIECE_SCENE)


# --- Garment piece ---------------------------------------------------------


func _build_garment_piece_scene() -> void:
	var root := Node3D.new()
	root.name = "GarmentPiece"
	root.set_script(load("res://entities/items/garment_piece.gd"))

	# Distinct flat silhouettes per type (garment_piece.gd shows/colours one).
	var models := Node3D.new()
	models.name = "Models"
	root.add_child(models)
	var gray := StandardMaterial3D.new()
	gray.albedo_color = Color(0.6, 0.6, 0.6)

	var shirt := Node3D.new()
	shirt.name = "Shirt"
	models.add_child(shirt)
	_add_box_mesh(shirt, "Torso", Vector3(0.34, 0.05, 0.4), Vector3(0, 0.025, 0), gray)
	_add_box_mesh(shirt, "SleeveL", Vector3(0.14, 0.05, 0.16), Vector3(-0.24, 0.025, 0.12), gray)
	_add_box_mesh(shirt, "SleeveR", Vector3(0.14, 0.05, 0.16), Vector3(0.24, 0.025, 0.12), gray)

	var pants := Node3D.new()
	pants.name = "Pants"
	models.add_child(pants)
	_add_box_mesh(pants, "Waist", Vector3(0.32, 0.05, 0.12), Vector3(0, 0.025, 0.2), gray)
	_add_box_mesh(pants, "LegL", Vector3(0.13, 0.05, 0.42), Vector3(-0.09, 0.025, -0.02), gray)
	_add_box_mesh(pants, "LegR", Vector3(0.13, 0.05, 0.42), Vector3(0.09, 0.025, -0.02), gray)

	var jacket := Node3D.new()
	jacket.name = "Jacket"
	models.add_child(jacket)
	_add_box_mesh(jacket, "Back", Vector3(0.44, 0.06, 0.44), Vector3(0, 0.03, 0), gray)
	_add_box_mesh(jacket, "LapelL", Vector3(0.09, 0.07, 0.3), Vector3(-0.14, 0.035, 0.1), gray)
	_add_box_mesh(jacket, "LapelR", Vector3(0.09, 0.07, 0.3), Vector3(0.14, 0.035, 0.1), gray)
	_add_box_mesh(jacket, "Collar", Vector3(0.3, 0.07, 0.08), Vector3(0, 0.035, 0.24), gray)

	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.6, 0.3, 0.5)
	col.shape = box_shape
	col.position = Vector3(0, 0.15, 0)
	area.add_child(col)
	root.add_child(area)

	_save(root, GARMENT_PIECE_SCENE)


# --- Phone station ---------------------------------------------------------


func _build_phone_scene() -> void:
	var root := Node3D.new()
	root.name = "Phone"
	root.set_script(load("res://stations/phone/phone.gd"))

	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	var table_mat := StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.40, 0.28, 0.20)
	_add_box_collider(body, "Table", Vector3(1.2, 0.9, 0.8), Vector3(0, 0.45, 0), table_mat)
	var phone_mat := StandardMaterial3D.new()
	phone_mat.albedo_color = Color(0.15, 0.15, 0.18)
	_add_box_mesh(body, "Handset", Vector3(0.3, 0.12, 0.45), Vector3(0, 0.96, 0), phone_mat)

	var delivery := Marker3D.new()
	delivery.name = "DeliverySpot"
	delivery.position = Vector3(1.2, 0.0, 0.3)  # on the floor beside the table
	root.add_child(delivery)

	_add_station_interactable(root, Vector3(1.4, 1.6, 1.4), Vector3(0, 0.8, 0.7))
	_save(root, PHONE_SCENE)


# --- Worktable station -----------------------------------------------------


func _build_worktable_scene() -> void:
	var root := Node3D.new()
	root.name = "Worktable"
	root.set_script(load("res://stations/worktable/worktable.gd"))

	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.52, 0.40, 0.28)
	_add_box_collider(body, "Top", Vector3(1.6, 0.12, 1.0), Vector3(0, 0.9, 0), wood)
	var leg := StandardMaterial3D.new()
	leg.albedo_color = Color(0.40, 0.30, 0.20)
	_add_box_mesh(body, "Leg", Vector3(1.5, 0.85, 0.9), Vector3(0, 0.42, 0), leg)

	var slot := Marker3D.new()
	slot.name = "Slot"
	slot.position = Vector3(0, 0.99, 0)  # on the tabletop
	root.add_child(slot)

	_add_station_interactable(root, Vector3(1.8, 1.6, 1.5), Vector3(0, 0.9, 0.6))
	_save(root, WORKTABLE_SCENE)


func _build_sewing_machine_scene() -> void:
	var root := Node3D.new()
	root.name = "SewingMachine"
	root.set_script(load("res://stations/sewing_machine/sewing_machine.gd"))

	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.38, 0.26)
	_add_box_collider(body, "Table", Vector3(1.5, 0.9, 0.8), Vector3(0, 0.45, 0), wood)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.20, 0.22, 0.26)
	_add_box_mesh(body, "Machine", Vector3(0.6, 0.32, 0.28), Vector3(-0.1, 1.06, -0.05), metal)
	_add_box_mesh(body, "Arm", Vector3(0.1, 0.22, 0.1), Vector3(0.2, 1.15, -0.05), metal)

	var slot := Marker3D.new()
	slot.name = "Slot"
	slot.position = Vector3(0.05, 0.95, 0.22)
	root.add_child(slot)

	_add_station_interactable(root, Vector3(1.7, 1.6, 1.5), Vector3(0, 0.9, 0.6))
	_save(root, SEWING_SCENE)


func _build_suit_scene() -> void:
	var root := Node3D.new()
	root.name = "Suit"
	root.set_script(load("res://entities/items/suit.gd"))
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.7, 0.16)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.35, 0)
	root.add_child(mesh)
	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.85, 0.4)
	col.shape = shape
	col.position = Vector3(0, 0.4, 0)
	area.add_child(col)
	root.add_child(area)
	_save(root, SUIT_SCENE)


func _build_clothing_rack_scene() -> void:
	var root := Node3D.new()
	root.name = "ClothingRack"
	root.set_script(load("res://stations/clothing_rack/clothing_rack.gd"))
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.3, 0.31, 0.34)
	_add_box_mesh(body, "PostL", Vector3(0.06, 1.6, 0.06), Vector3(-0.7, 0.8, 0), metal)
	_add_box_mesh(body, "PostR", Vector3(0.06, 1.6, 0.06), Vector3(0.7, 0.8, 0), metal)
	_add_box_mesh(body, "Bar", Vector3(1.55, 0.06, 0.06), Vector3(0, 1.55, 0), metal)
	_add_box_mesh(body, "Base", Vector3(1.6, 0.06, 0.5), Vector3(0, 0.03, 0), metal)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(1.6, 1.6, 0.5)
	col.shape = cbox
	col.position = Vector3(0, 0.8, 0)
	body.add_child(col)
	var slots := Node3D.new()
	slots.name = "Slots"
	root.add_child(slots)
	for x in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		var m := Marker3D.new()
		m.name = "Hook_%d" % int(x * 100)
		m.position = Vector3(x, 1.3, 0)
		slots.add_child(m)
	_add_station_interactable(root, Vector3(1.8, 1.8, 1.2), Vector3(0, 0.9, 0.5))
	_save(root, RACK_SCENE)


func _build_mannequin_scene() -> void:
	var root := Node3D.new()
	root.name = "Mannequin"
	root.set_script(load("res://stations/mannequin/mannequin.gd"))
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	var form := StandardMaterial3D.new()
	form.albedo_color = Color(0.82, 0.78, 0.72)
	var stand := StandardMaterial3D.new()
	stand.albedo_color = Color(0.3, 0.24, 0.18)
	_add_box_mesh(body, "Base", Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0), stand)
	_add_box_mesh(body, "Post", Vector3(0.08, 0.9, 0.08), Vector3(0, 0.5, 0), stand)
	_add_box_mesh(body, "Torso", Vector3(0.5, 0.7, 0.28), Vector3(0, 1.25, 0), form)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	head.mesh = sphere
	head.material_override = form
	head.position = Vector3(0, 1.75, 0)
	body.add_child(head)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(0.6, 1.9, 0.4)
	col.shape = cbox
	col.position = Vector3(0, 0.95, 0)
	body.add_child(col)
	_add_marker(root, "PantsSlot", Vector3(0, 0.75, 0.16))
	_add_marker(root, "ShirtSlot", Vector3(0, 1.3, 0.16))
	_add_marker(root, "JacketSlot", Vector3(0, 1.28, 0.22))
	_add_station_interactable(root, Vector3(1.4, 2.0, 1.4), Vector3(0, 1.0, 0.5))
	_save(root, MANNEQUIN_SCENE)


func _build_customer_scene() -> void:
	var root := Node3D.new()
	root.name = "Customer"
	root.set_script(load("res://entities/customer/customer.gd"))
	# Collision-only body (the visual is the shared toon rig).
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(0.5, 1.5, 0.42)
	col.shape = cbox
	col.position = Vector3(0, 0.75, 0)
	body.add_child(col)
	var rig: Node = load(CHARACTER_SCENE).instantiate()
	rig.name = "Rig"
	root.add_child(rig)
	# Anchors sized to the rig (used by the suit builder to frame garment parts).
	_add_marker(root, "PantsAnchor", Vector3(0, 0.32, 0.18))
	_add_marker(root, "ShirtAnchor", Vector3(0, 0.64, 0.18))
	_add_marker(root, "JacketAnchor", Vector3(0, 0.66, 0.22))
	# Interaction volume so the player can greet / design at the customer.
	_add_station_interactable(root, Vector3(1.2, 1.6, 1.2), Vector3(0, 0.8, 0))
	_save(root, CUSTOMER_SCENE)


func _build_mirror_scene() -> void:
	var root := Node3D.new()
	root.name = "Mirror"
	root.set_script(load("res://stations/mirror/mirror.gd"))
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.28, 0.2, 0.14)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.68, 0.78, 0.85)
	glass.metallic = 0.6
	glass.roughness = 0.1
	var stool_mat := StandardMaterial3D.new()
	stool_mat.albedo_color = Color(0.5, 0.38, 0.26)
	# Mirror against the back of the station.
	_add_box_mesh(body, "Frame", Vector3(1.2, 2.2, 0.1), Vector3(0, 1.1, -0.5), frame_mat)
	_add_box_mesh(body, "Glass", Vector3(1.0, 1.9, 0.02), Vector3(0, 1.15, -0.44), glass)
	_add_box_mesh(body, "Stool", Vector3(0.4, 0.45, 0.4), Vector3(0.95, 0.22, 0.3), stool_mat)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(1.3, 2.2, 0.3)
	col.shape = cbox
	col.position = Vector3(0, 1.1, -0.45)
	body.add_child(col)
	# No built-in customer: walk-in customers (spawned by the CustomerManager)
	# come here to be fitted; the mirror's `customer` is assigned at runtime.
	_add_station_interactable(root, Vector3(2.0, 1.8, 1.4), Vector3(0, 0.9, 1.0))
	_save(root, MIRROR_SCENE)


func _add_marker(parent: Node, node_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = node_name
	m.position = pos
	parent.add_child(m)


func _add_station_interactable(root: Node3D, box_size: Vector3, box_pos: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.set("target", root)
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	col.shape = box
	col.position = box_pos
	area.add_child(col)
	root.add_child(area)


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

	var money := Label.new()
	money.name = "Money"
	money.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	money.offset_left = -200
	money.offset_top = 10
	money.offset_right = -18
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_theme_font_size_override("font_size", 24)
	hud.add_child(money)

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

	# Phone order screen
	var phone_box := _build_modal(root, "PhoneOrder", "res://ui/phone_order.gd", 660)
	var p_title := Label.new()
	p_title.name = "Title"
	phone_box.add_child(p_title)
	var p_money := Label.new()
	p_money.name = "Money"
	phone_box.add_child(p_money)
	var preview := HBoxContainer.new()
	preview.name = "Preview"
	phone_box.add_child(preview)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	phone_box.add_child(rows)
	var p_hint := Label.new()
	p_hint.name = "Hint"
	phone_box.add_child(p_hint)

	# Worktable screen (config panel + runtime minigame overlay)
	var wt := Control.new()
	wt.name = "WorktableScreen"
	wt.set_script(load("res://ui/worktable_screen.gd"))
	wt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(wt)
	var wt_dim := ColorRect.new()
	wt_dim.name = "Dim"
	wt_dim.color = Color(0, 0, 0, 0.55)
	wt_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wt.add_child(wt_dim)
	var config := Control.new()
	config.name = "Config"
	config.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wt.add_child(config)
	var wt_center := CenterContainer.new()
	wt_center.name = "Center"
	wt_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	config.add_child(wt_center)
	var wt_panel := PanelContainer.new()
	wt_panel.name = "Panel"
	wt_panel.custom_minimum_size = Vector2(600, 0)
	wt_center.add_child(wt_panel)
	var wt_margin := MarginContainer.new()
	wt_margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		wt_margin.add_theme_constant_override("margin_" + side, 8)
	wt_panel.add_child(wt_margin)
	var wt_box := VBoxContainer.new()
	wt_box.name = "Box"
	wt_box.add_theme_constant_override("separation", 8)
	wt_margin.add_child(wt_box)
	var wt_title := Label.new()
	wt_title.name = "Title"
	wt_box.add_child(wt_title)
	var wt_preview := HBoxContainer.new()
	wt_preview.name = "Preview"
	wt_box.add_child(wt_preview)
	var wt_rows := VBoxContainer.new()
	wt_rows.name = "Rows"
	wt_rows.add_theme_constant_override("separation", 4)
	wt_box.add_child(wt_rows)
	var wt_hint := Label.new()
	wt_hint.name = "Hint"
	wt_box.add_child(wt_hint)

	# Sewing screen (just hosts the sew minigame at runtime)
	var sew := Control.new()
	sew.name = "SewingScreen"
	sew.set_script(load("res://ui/sewing_screen.gd"))
	sew.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sew)
	var sew_dim := ColorRect.new()
	sew_dim.name = "Dim"
	sew_dim.color = Color(0, 0, 0, 0.55)
	sew_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sew.add_child(sew_dim)

	# Suit builder — a right-side panel (no dim) so the customer stays visible.
	var sb := Control.new()
	sb.name = "SuitBuilder"
	sb.set_script(load("res://ui/suit_builder.gd"))
	sb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sb)
	var sb_panel := PanelContainer.new()
	sb_panel.name = "Panel"
	sb_panel.anchor_left = 1.0
	sb_panel.anchor_top = 0.0
	sb_panel.anchor_right = 1.0
	sb_panel.anchor_bottom = 1.0
	sb_panel.offset_left = -470
	sb_panel.offset_top = 16
	sb_panel.offset_right = -16
	sb_panel.offset_bottom = -16
	sb.add_child(sb_panel)
	var sb_margin := MarginContainer.new()
	sb_margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		sb_margin.add_theme_constant_override("margin_" + side, 8)
	sb_panel.add_child(sb_margin)
	var sb_box := VBoxContainer.new()
	sb_box.name = "Box"
	sb_box.add_theme_constant_override("separation", 8)
	sb_margin.add_child(sb_box)
	var sb_title := Label.new()
	sb_title.name = "Title"
	sb_box.add_child(sb_title)
	var sb_preview := HBoxContainer.new()
	sb_preview.name = "Preview"
	sb_box.add_child(sb_preview)
	var sb_rows := VBoxContainer.new()
	sb_rows.name = "Rows"
	sb_rows.add_theme_constant_override("separation", 4)
	sb_box.add_child(sb_rows)
	var sb_hint := Label.new()
	sb_hint.name = "Hint"
	sb_box.add_child(sb_hint)

	# Customer greeting / request modal
	var cr_box := _build_modal(root, "CustomerRequest", "res://ui/customer_request.gd", 520)
	var cr_title := Label.new()
	cr_title.name = "Title"
	cr_box.add_child(cr_title)
	var cr_brief := Label.new()
	cr_brief.name = "Brief"
	cr_box.add_child(cr_brief)
	var cr_hint := Label.new()
	cr_hint.name = "Hint"
	cr_box.add_child(cr_hint)

	# Orders tracker — top-centre HUD list of open bespoke orders.
	var orders := Control.new()
	orders.name = "OrdersPanel"
	orders.set_script(load("res://ui/orders_panel.gd"))
	orders.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orders.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(orders)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stack.offset_top = 8
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orders.add_child(stack)

	_save(root, UI_SCENE)


## Build a modal overlay (Dim + centered Panel + Margin + Box) under `parent`
## and return the inner VBox to fill with content.
func _build_modal(
	parent: Node, node_name: String, script_path: String, min_width: int
) -> VBoxContainer:
	var modal := Control.new()
	modal.name = node_name
	modal.set_script(load(script_path))
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(modal)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(min_width, 0)
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
	return box


# --- Player (rebuild with Carry + Interactor) ------------------------------


func _build_player_scene() -> void:
	var root := CharacterBody3D.new()
	root.name = "Player"
	root.set_script(load("res://scenes/player/player.gd"))

	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.4
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position = Vector3(0, 0.7, 0)
	root.add_child(collision)

	# The player is a toon character too (same shared rig as customers).
	var model: Node = load(CHARACTER_SCENE).instantiate()
	model.name = "Model"
	root.add_child(model)

	# Hands
	var carry := Node3D.new()
	carry.name = "Carry"
	carry.set_script(load("res://entities/player/carry_slot.gd"))
	root.add_child(carry)
	var hold := Marker3D.new()
	hold.name = "HoldPoint"
	hold.position = Vector3(0, 0.95, 0.5)
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
	# South wall has a 3 m door gap at the centre (customers come and go here).
	_add_box_collider(walls, "S_L", Vector3(6.5, h, t), Vector3(-4.75, h / 2, 8), wall_mat)
	_add_box_collider(walls, "S_R", Vector3(6.5, h, t), Vector3(4.75, h / 2, 8), wall_mat)
	_add_box_mesh(walls, "S_Lintel", Vector3(3.5, 0.6, t), Vector3(0, h - 0.3, 8), wall_mat)
	_add_box_collider(walls, "E", Vector3(t, h, 16), Vector3(8, h / 2, 0), wall_mat)
	_add_box_collider(walls, "W", Vector3(t, h, 16), Vector3(-8, h / 2, 0), wall_mat)

	# Shelf against the back wall, facing into the room (+Z)
	var shelf: Node = load(SHELF_SCENE).instantiate()
	shelf.position = Vector3(0, 0, -7.0)
	root.add_child(shelf)

	# Phone table (left) and worktable (right).
	var phone: Node = load(PHONE_SCENE).instantiate()
	phone.position = Vector3(-6.0, 0, -5.5)
	phone.rotation_degrees = Vector3(0, 35, 0)
	root.add_child(phone)

	var worktable: Node = load(WORKTABLE_SCENE).instantiate()
	worktable.position = Vector3(6.0, 0, -5.0)
	worktable.rotation_degrees = Vector3(0, -35, 0)
	root.add_child(worktable)

	var sewing: Node = load(SEWING_SCENE).instantiate()
	sewing.position = Vector3(6.5, 0, -1.0)
	sewing.rotation_degrees = Vector3(0, -80, 0)
	root.add_child(sewing)

	var rack: Node = load(RACK_SCENE).instantiate()
	rack.position = Vector3(-6.5, 0, -1.0)
	rack.rotation_degrees = Vector3(0, 80, 0)
	root.add_child(rack)

	var mannequin: Node = load(MANNEQUIN_SCENE).instantiate()
	mannequin.position = Vector3(-2.5, 0, -6.7)
	root.add_child(mannequin)

	# Mirror, facing the room so the camera can frame a customer from the front.
	var mirror: Node = load(MIRROR_SCENE).instantiate()
	mirror.position = Vector3(3.0, 0, -6.5)
	root.add_child(mirror)

	# Street outside the door + the customer spawner and its waypoints.
	_build_storefront(root)
	_build_customer_system(root)

	# Scatter material rolls on the floor
	var roll_scene: PackedScene = load(ROLL_SCENE)
	for entry in FLOOR_ROLLS:
		var roll: Node = roll_scene.instantiate()
		roll.material = load("res://data/materials/%s.tres" % entry[0])
		roll.remaining_length_m = entry[3]
		roll.position = Vector3(entry[1], 0.13, entry[2])
		root.add_child(roll)

	_build_test_items(root)
	_save(root, ROOM_SCENE)


# Sidewalk + street outside the shop door, with an awning and shop sign.
func _build_storefront(root: Node3D) -> void:
	var pave := StandardMaterial3D.new()
	pave.albedo_color = Color(0.55, 0.54, 0.5)
	var walk := StaticBody3D.new()
	walk.name = "Sidewalk"
	root.add_child(walk)
	_add_box_collider(walk, "Path", Vector3(48, 1, 4), Vector3(0, -0.5, 10), pave)

	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.22, 0.22, 0.24)
	var road := StaticBody3D.new()
	road.name = "Street"
	root.add_child(road)
	_add_box_collider(road, "Asphalt", Vector3(60, 1, 10), Vector3(0, -0.5, 17), asphalt)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.82, 0.6)
	for i in range(-6, 7):
		_add_box_mesh(
			road, "Lane_%d" % i, Vector3(1.4, 0.02, 0.2), Vector3(i * 4.0, 0.01, 17), paint
		)

	var deco := Node3D.new()
	deco.name = "Storefront"
	root.add_child(deco)
	var awning_mat := StandardMaterial3D.new()
	awning_mat.albedo_color = Color(0.71, 0.28, 0.24)
	_add_box_mesh(deco, "Awning", Vector3(4.2, 0.2, 1.6), Vector3(0, 2.6, 8.9), awning_mat)
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "TAILORTOWN"
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.modulate = Color(0.97, 0.91, 0.78)
	sign.outline_size = 12
	sign.outline_modulate = Color(0.2, 0.08, 0.06)
	sign.rotation_degrees = Vector3(-90, 0, 0)  # lie flat, readable top-down
	sign.position = Vector3(0, 2.72, 8.9)
	deco.add_child(sign)


# Waypoint markers + the CustomerManager that spawns and routes shoppers.
func _build_customer_system(root: Node3D) -> void:
	var wp := Node3D.new()
	wp.name = "Waypoints"
	root.add_child(wp)
	_add_marker(wp, "GreetSpot", Vector3(1.6, 0, 5.2))
	_add_marker(wp, "DoorInside", Vector3(0, 0, 7.2))
	_add_marker(wp, "DoorOutside", Vector3(0, 0, 9.6))
	_add_marker(wp, "MirrorSpot", Vector3(3.0, 0, -5.2))
	_add_marker(wp, "StreetWest", Vector3(-22, 0, 10.2))
	_add_marker(wp, "StreetEast", Vector3(22, 0, 10.2))

	var mgr := Node3D.new()
	mgr.name = "CustomerManager"
	mgr.set_script(load("res://entities/customer/customer_manager.gd"))
	mgr.set("mirror_path", NodePath("../Mirror"))
	mgr.set("greet_path", NodePath("../Waypoints/GreetSpot"))
	mgr.set("mirror_spot_path", NodePath("../Waypoints/MirrorSpot"))
	mgr.set("door_in_path", NodePath("../Waypoints/DoorInside"))
	mgr.set("door_out_path", NodePath("../Waypoints/DoorOutside"))
	mgr.set("street_west_path", NodePath("../Waypoints/StreetWest"))
	mgr.set("street_east_path", NodePath("../Waypoints/StreetEast"))
	root.add_child(mgr)


# Organized sample items for testing, in labelled rows near the left-front wall.
func _build_test_items(room: Node) -> void:
	var x0 := -6.9
	var dx := 0.72

	_test_label(room, "CLOTH", x0 + dx, 5.7)
	for i in TEST_CLOTH.size():
		var c: Array = TEST_CLOTH[i]
		var f: Node = load(PIECE_SCENE).instantiate()
		f.material = load("res://data/materials/%s.tres" % c[0])
		f.length_m = c[1]
		room.add_child(f)
		f.position = Vector3(x0 + i * dx, 0.03, 5.2)

	_test_label(room, "CUT PARTS", x0 + dx, 4.5)
	_place_test_parts(room, TEST_CUT, 2, 4.0, x0, dx)

	_test_label(room, "SEWN PARTS", x0 + dx, 3.3)
	_place_test_parts(room, TEST_SEWN, 3, 2.8, x0, dx)

	_test_label(room, "SUITS", x0 + dx, 2.1)
	for i in TEST_SUITS.size():
		var s: Array = TEST_SUITS[i]
		var suit: Node = load(SUIT_SCENE).instantiate()
		suit.quality = s[1]
		var m: MaterialType = load("res://data/materials/%s.tres" % s[0])
		suit.primary_color = m.cloth_color
		room.add_child(suit)
		suit.position = Vector3(x0 + i * dx, 0.0, 1.6)


func _place_test_parts(
	room: Node, entries: Array, stage: int, z: float, x0: float, dx: float
) -> void:
	for i in entries.size():
		var e: Array = entries[i]
		var g: Node = load(GARMENT_PIECE_SCENE).instantiate()
		g.material = load("res://data/materials/%s.tres" % e[0])
		g.garment_type = e[1]
		g.size = e[2]
		g.style = e[3]
		g.quality = e[4]
		g.stage = stage
		room.add_child(g)
		g.position = Vector3(x0 + i * dx, 0.03, z)


func _test_label(room: Node, text: String, x: float, z: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.006
	label.modulate = Color(0.97, 0.91, 0.78)
	label.outline_size = 14
	label.outline_modulate = Color(0.12, 0.09, 0.06)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(x, 1.4, z)
	room.add_child(label)


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
	parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material
) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _add_box_collider(
	parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material
) -> void:
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

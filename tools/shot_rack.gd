extends SceneTree

## Visual check for the clothing rack: hangs a lone jacket, a set (shirt + trousers waiting
## on their jacket), a finished suit and a spare shirt on the rack in grandpa's shop, frames it
## from the front, and saves a PNG. NOT headless.
##   godot --path . --script res://tools/shot_rack.gd -- [out.png] [frames]

const JACKET := 2
const PANTS := 1
const SHIRT := 0
const SEWN := 3  # Enums.Stage.SEWN

var _out := "res://.dev/rack.png"
var _frames := 90
var _count := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_frames = int(args[1])
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://scenes/world/grandpa/main_grandpa.tscn").instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	var rack: Node3D = main.find_child("ClothingRack", true, false)
	var sheet := rack.find_child("DustSheet", true, false) as Node3D
	if sheet != null:
		sheet.visible = false  # show the rack as it is once the room is cleared
	if OS.get_cmdline_user_args().has("empty"):
		_frame(main, rack)
		return
	var factory: GDScript = load("res://data/scripts/material_factory.gd")
	var orders: Node = root.get_node("Orders")
	var navy: Resource = factory.make(0, 1, 0, 3.0)  # navy pinstripe worsted
	var shirting: Resource = factory.make(5, 0, 10, 3.0)  # white poplin
	# The spares are cut from cloth no open order wants, so none is claimed by the order
	# (a spare that suits an order is checked off against it and gathers with it).
	var tweed: Resource = factory.make(2, 2, 5, 3.0)  # brown herringbone tweed
	var oxford: Resource = factory.make(7, 0, 11, 3.0)  # a sky oxford shirting
	# 1. A set: shirt and trousers of an order still waiting on its jacket.
	var suit_spec := {"fabric": 0, "pattern": 1, "color": 0, "style_idx": 0}
	var shirt_spec := {"fabric": 5, "pattern": 0, "color": 10, "style_idx": 0}
	var order: Resource = orders.create_order(
		"Mr. Ashdown", {JACKET: suit_spec, PANTS: suit_spec, SHIRT: shirt_spec}, 400, Color.WHITE
	)
	rack.hang(_piece(SHIRT, shirting, order.id))
	rack.hang(_piece(PANTS, navy, order.id))
	# 2. A finished suit.
	var parts := [_piece(JACKET, navy, 0), _piece(PANTS, navy, 0), _piece(SHIRT, shirting, 0)]
	var suit: Node = load("res://entities/items/suit.gd").from_pieces(parts, 0)
	for p: Node in parts:
		p.free()
	rack.hang(suit)
	# 3. Spares: a tweed jacket and a sky shirt.
	rack.hang(_piece(JACKET, tweed, 0))
	rack.hang(_piece(SHIRT, oxford, 0))
	var kinds: Array[String] = []
	for hung: Node in rack.stored:
		kinds.append(String(hung.name))
	print("rack holds ", kinds)
	_frame(main, rack)


func _frame(main: Node, rack: Node3D) -> void:
	var player := main.find_child("Player", true, false) as Node3D
	player.global_position = rack.to_global(Vector3(1.6, 0.0, 1.6))
	var rig: Node = get_first_node_in_group("camera_rig")
	var eye := rack.to_global(Vector3(1.1, 1.65, 1.5))
	rig.focus(eye, rack.to_global(Vector3(0.0, 1.0, 0.0)))
	process_frame.connect(_on_frame)


func _piece(kind: int, mat: Resource, order_id: int) -> Node:
	var piece: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	piece.material = mat
	piece.garment_type = kind
	piece.stage = SEWN
	piece.order_id = order_id
	return piece


func _on_frame() -> void:
	_count += 1
	if _count < _frames:
		return
	get_root().get_texture().get_image().save_png(_out)
	print("Saved ", _out)
	quit(0)

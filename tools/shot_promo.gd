extends SceneTree

## Promo screenshots for the Steam store page. Boots main.tscn with a real render
## device, stages a set of moments (a served customer, the menus, the minigames,
## the shopfront), frames the camera the way the in-game one does and writes
## 1920x1080 PNGs to .dev/promo/.
##
## NOT headless — it captures the framebuffer:
##
##   godot --path . --script res://tools/shot_promo.gd -- [shot ...]
##
## With no arguments every shot is rendered; otherwise only the named ones, e.g.
## `-- cutting sewing`. Shot names are the `_want()` keys below.

const OUT_DIR := "res://.dev/promo"
const SHOT_W := 1920
const SHOT_H := 1080
## The in-game camera's home offset (scenes/camera/camera_rig.tscn) — promo shots
## reuse it (scaled) so the framing reads like the framing players get.
const CAM_OFFSET := Vector3(0.0, 6.271325, 4.392928)
const SETTLE := 6

var _main: Node
var _player: Node
var _rig: Node
var _cm: Node
var _mirror: Node
var _wanted: PackedStringArray

# Autoloads are not resolvable as identifiers from a top-level `--script`, so they
# are fetched off the root once the scene is up.
var _ui: Node
var _orders: Node
var _news: Node
var _clock: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	_wanted = PackedStringArray(OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	await _wait(10)
	# Re-assert the capture size after boot: the Settings autoload applies the
	# player's saved window size, which would otherwise win.
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(SHOT_W, SHOT_H))
	get_root().size = Vector2i(SHOT_W, SHOT_H)
	await _wait(20)
	_player = _main.find_child("Player", true, false)
	_rig = _main.find_child("CameraRig", true, false)
	_cm = _main.find_child("CustomerManager", true, false)
	_mirror = _main.find_child("Mirror", true, false)
	_ui = root.get_node("UI")
	_orders = root.get_node("Orders")
	_news = root.get_node("News")
	_clock = root.get_node("DayNight")
	_dismiss_paper()
	print("viewport = %s" % str(get_root().size))
	await _shot_overview()
	await _shot_greeting()
	await _shot_suit_builder()
	await _shot_cutting()
	await _shot_sewing()
	await _shot_shelf()
	await _shot_phone()
	await _shot_handbook()
	await _shot_orders()
	await _shot_newspaper()
	await _shot_storefront()
	print("promo shots written to ", OUT_DIR)
	quit(0)


# --- Shots -----------------------------------------------------------------


## The hero shot: a working shop — tickets on the HUD, a client at the mirror,
## the tailor crossing the floor with a bolt of cloth.
func _shot_overview() -> void:
	if not _want("overview"):
		return
	for _i in 3:
		_orders.debug_add_random()
	await _give_roll("navy_worsted_pinstripe", 14.0)
	_place_player(Vector3(2.3, 0.0, 4.9), PI)
	_seat_customer()
	await _wait(70)
	_frame(Vector3(1.9, 0.7, 4.2), 1.5)
	await _wait(SETTLE)
	_save("01_shop_overview")
	await _clear_hands()


## A walk-in states their occasion, style and budget in the greeting bubble.
func _shot_greeting() -> void:
	if not _want("greeting"):
		return
	var cust: Node = _spawn_customer(Vector3(0.65, 0.0, 4.05), 0.0)
	await _wait(40)
	_ui.open_customer_request(cust, _player)
	_place_player(Vector3(0.7, 0.0, 5.6), PI)
	await _wait(40)
	_frame(Vector3(0.7, 0.9, 4.6), 0.75)
	await _wait(SETTLE)
	_save("02_customer_brief")
	_ui.close_all_menus()
	_despawn(cust)
	await _wait(10)


## Designing the client's suit at the fitting mirror: overview, then a part zoom
## with the cloth changing on the customer in real time.
func _shot_suit_builder() -> void:
	if not _want("mirror"):
		return
	var cust: Node = _seat_customer()
	await _wait(40)
	_ui.open_suit_builder(_mirror, _player)
	var builder: Node = _ui.suit_builder
	await _wait(80)
	_save("03_suit_builder")
	builder._adjust(1)
	await _wait(70)
	var look: Vector3 = cust.center() + Vector3(0.0, 0.1, 0.0)
	_frame_eye(look + cust.facing() * 2.0 + Vector3(0.0, 0.45, 0.0), look)
	await _wait(SETTLE)
	_save("04_suit_builder_zoom")
	_ui.close_all_menus()
	_despawn(cust)
	await _wait(10)


## The cutting minigame, a moment after the lead-in.
func _shot_cutting() -> void:
	if not _want("cutting"):
		return
	var table: Node = _main.find_child("Worktable", true, false)
	var piece: Node = _make_item("fabric_piece", "charcoal_worsted_solid")
	piece.length_m = 6.0
	await _hand_over(piece)
	table.interact(_player)  # place the cloth
	await _wait(6)
	table.interact(_player)  # open the worktable screen
	await _wait(30)
	_ui.worktable_screen._start_cutting()
	await _wait(150)
	_save("05_cutting_minigame")
	_ui.close_all_menus()
	await _wait(10)


## The sewing rhythm minigame mid-seam.
func _shot_sewing() -> void:
	if not _want("sewing"):
		return
	var machine: Node = _main.find_child("SewingMachine", true, false)
	var part: Node = _make_item("garment_piece", "navy_worsted_pinstripe")
	part.garment_type = 2  # JACKET
	part.stage = 2  # CUT
	await _hand_over(part)
	machine.interact(_player)  # place the panel
	await _wait(6)
	machine.interact(_player)  # opens the sewing screen + minigame
	await _wait(140)
	_save("06_sewing_minigame")
	_ui.close_all_menus()
	await _wait(10)


## The cloth shelf: every bolt with its weave, pattern and metres left.
func _shot_shelf() -> void:
	if not _want("shelf"):
		return
	var shelf: Node = _main.find_child("Shelf", true, false)
	var names := [
		"navy_worsted_pinstripe",
		"brown_tweed_herringbone",
		"charcoal_worsted_solid",
		"burgundy_mohair_birdseye",
		"tan_linen_solid",
		"blue_worsted_glencheck",
	]
	for n in names:
		if shelf.stored.size() >= shelf.capacity():
			break
		var roll: Node = _make_item("material_roll", String(n))
		roll.remaining_length_m = 9.0 + shelf.stored.size()
		_main.add_child(roll)
		shelf.stock(roll)
	await _wait(10)
	_ui.open_shelf_menu(shelf, _player)
	await _wait(40)
	_save("07_cloth_shelf")
	_ui.close_all_menus()
	await _wait(10)


## Ordering cloth from the suppliers on the shop phone.
func _shot_phone() -> void:
	if not _want("phone"):
		return
	var phone: Node = _main.find_child("Phone", true, false)
	_place_player(Vector3(0.5, 0.0, 3.0), PI)
	await _wait(20)
	_frame(Vector3(0.5, 0.8, 2.7), 1.0)
	_ui.open_phone(phone, _player)
	await _wait(20)
	_ui.phone_order._screen = 2  # Screen.ORDER — the cloth designer and its swatch
	_ui.phone_order._refresh()
	await _wait(30)
	_save("08_phone_order")
	_ui.close_all_menus()
	await _wait(10)


## The Tailor's Handbook — the in-game dress-code reference.
func _shot_handbook() -> void:
	if not _want("handbook"):
		return
	_ui.open_handbook(_player)
	await _wait(45)
	_save("09_handbook")
	_ui.close_all_menus()
	await _wait(10)


## The order book: who is waiting, for what, and by when.
func _shot_orders() -> void:
	if not _want("orders"):
		return
	while _orders.active.size() < 4:
		_orders.debug_add_random()
	_ui.open_orders_menu(_player)
	await _wait(45)
	_save("10_order_book")
	_ui.close_all_menus()
	await _wait(10)


## The morning paper: the running fashion trend and the town's social calendar.
func _shot_newspaper() -> void:
	if not _want("newspaper"):
		return
	_news.edition()
	if _news.current_edition.is_empty():
		print("no newspaper edition — skipping")
		return
	_ui.newspaper.open()
	await _wait(45)
	_save("11_newspaper")
	_ui.newspaper.close()
	await _wait(10)


## The shopfront from the street in the afternoon, with a client heading in.
func _shot_storefront() -> void:
	if not _want("storefront"):
		return
	_clock.start_shift(0.86)
	_dismiss_paper()
	_place_player(Vector3(1.3, 0.0, 9.4), 0.0)
	_spawn_customer(Vector3(-0.4, 0.0, 9.9), 2.6)
	await _wait(60)
	_frame_eye(Vector3(0.9, 3.1, 15.2), Vector3(0.9, 1.5, 8.6))
	await _wait(SETTLE)
	_save("12_shopfront_street")


# --- Staging helpers -------------------------------------------------------


## The morning paper slides up on its own at day start — fold it away unless the
## shot is about the paper.
func _dismiss_paper() -> void:
	if _ui.newspaper != null and _ui.newspaper.visible:
		_ui.newspaper.close()


func _want(name: String) -> bool:
	return _wanted.is_empty() or _wanted.has(name)


func _wait(frames: int) -> void:
	for _i in frames:
		await process_frame


func _save(name: String) -> void:
	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("no framebuffer — run WITHOUT --headless")
		return
	var path := "%s/%s.png" % [OUT_DIR, name]
	image.save_png(path)
	print("saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])


## Point the camera at `look` from the in-game angle, `zoom`x further out, and snap
## it there so the shot needs no settling time.
func _frame(look: Vector3, zoom: float) -> void:
	if _rig == null:
		return
	_frame_eye(look + CAM_OFFSET * zoom, look)


## Frame from an explicit eye position (for shots the in-game angle can't hold).
func _frame_eye(eye: Vector3, look: Vector3) -> void:
	if _rig == null:
		return
	_rig.focus(eye, look)
	var cam: Camera3D = _rig.get_node("Camera3D")
	cam.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func _place_player(pos: Vector3, yaw: float) -> void:
	if _player == null:
		return
	_player.global_position = pos
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO


func _make_item(kind: String, material_name: String) -> Node:
	var item: Node = load("res://entities/items/%s.tscn" % kind).instantiate()
	item.material = load("res://data/materials/%s.tres" % material_name)
	return item


func _give_roll(material_name: String, metres: float) -> void:
	var roll: Node = _make_item("material_roll", material_name)
	roll.remaining_length_m = metres
	await _hand_over(roll)


## Put a freshly made item into the player's hands (it must be in the tree first,
## because attaching reparents it).
func _hand_over(item: Node) -> void:
	_main.add_child(item)
	await _wait(2)
	_player.carry.take_item(item)
	await _wait(4)


func _clear_hands() -> void:
	var held: Node = _player.carry.release()
	if held != null:
		held.queue_free()
	await _wait(4)


## A client standing at the mirror, ready to be fitted.
func _seat_customer() -> Node:
	var spot: Node3D = _main.find_child("MirrorSpot", true, false)
	var cust: Node = _spawn_customer(spot.global_position, spot.global_rotation.y)
	cust.offer_mirror()
	return cust


func _spawn_customer(pos: Vector3, yaw: float) -> Node:
	var cust: Node = _cm._spawn(pos, true)
	cust.global_position = pos
	cust.rotation.y = yaw
	return cust


func _despawn(cust: Node) -> void:
	if cust != null and cust.has_method("despawn"):
		cust.despawn()

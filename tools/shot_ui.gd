extends SceneTree

## Boots the game (or, for "mainmenu", the title screen), opens one in-game menu, and
## captures it to a PNG so UI changes can be reviewed (and rated against the style
## guide) without a human at the window. Must run WITH a rendering device — NOT with
## --headless:
##
##   godot --path . --script res://tools/shot_ui.gd -- [menu] [out] [frames]
##
## menu:   phone | book | shelf | orders | worktable | customer | mirror | rack |
##         apprentice | pause | settings | controls | hud | mainmenu | all
##         (default: phone)
## out:    res:// PNG path (default: res://.dev/ui_<menu>.png; ignored by "all", which
##         always writes one res://.dev/ui_<name>.png per target it captures)
## frames: extra settle frames after opening (default: 40)
##
## "all" boots the game once and shoots every in-game target above in turn — closing
## each menu (ui.close_all_menus(), or unpausing for pause/settings) before opening the
## next — everything except "mainmenu", which boots a different scene (the title
## screen) and so can't share that run.
##
## Autoload singletons (UI, GameState, ...) aren't resolvable as bare identifiers from
## a top-level --script tool, so they're always fetched off the root once it's up.

const GAME_MENUS := [
	"phone",
	"book",
	"shelf",
	"orders",
	"worktable",
	"customer",
	"mirror",
	"rack",
	"apprentice",
	"pause",
	"settings",
	"controls",
	"hud",
]

var _menu := "phone"
var _out_path := ""
var _settle := 40
var _spawned_customer: Node = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_menu = args[0] if args.size() > 0 else "phone"
	_out_path = args[1] if args.size() > 1 else "res://.dev/ui_%s.png" % _menu
	_settle = int(args[2]) if args.size() > 2 else 40
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_run()


func _run() -> void:
	var ok := true
	match _menu:
		"mainmenu":
			ok = await _shoot_mainmenu()
		"all":
			ok = await _shoot_all()
		_:
			ok = await _shoot_one(_menu, _out_path)
	quit(0 if ok else 1)


## Boot res://main.tscn directly (bypassing the main-menu boot scene entirely) and open
## `menu` in it.
func _shoot_one(menu: String, out_path: String) -> bool:
	var main := _boot_game()
	var ui: Node = get_root().get_node("UI")
	await _settle_boot(ui)
	_open(main, ui, menu)
	await _wait(_settle)
	return _capture(out_path)


## Boot once, shoot every GAME_MENUS target in turn, closing each before the next.
func _shoot_all() -> bool:
	var main := _boot_game()
	var ui: Node = get_root().get_node("UI")
	await _settle_boot(ui)
	var ok := true
	for menu: String in GAME_MENUS:
		_open(main, ui, menu)
		await _wait(_settle)
		if not _capture("res://.dev/ui_%s.png" % menu):
			ok = false
		_close(ui, menu)
		await _wait(6)
	return ok


## The title screen itself is the boot scene, so this loads it in place of main.tscn —
## no menu to open, the scene already shows one.
func _shoot_mainmenu() -> bool:
	if change_scene_to_file("res://scenes/menu/main_menu.tscn") != OK:
		push_error("Could not load main menu scene")
		return false
	await _wait(30 + _settle)
	return _capture(_out_path)


func _boot_game() -> Node:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	return main


## Let main.tscn's own _ready (which calls SaveManager.notify_game_ready) settle in,
## fold away the morning paper so it doesn't cover the shot, then make doubly sure the
## tree is unpaused and the UI layer is visible — the dev-boot path already does both,
## but a prior "pause"/"settings" shot in an "all" run could otherwise leave the tree
## paused for the next one.
func _settle_boot(ui: Node) -> void:
	await process_frame
	await process_frame
	var paper: Node = get_root().find_child("Newspaper", true, false)
	if paper != null:
		if paper.has_method("close"):
			paper.close()
		else:
			paper.visible = false
	await process_frame
	paused = false
	ui.visible = true


func _open(main: Node, ui: Node, menu: String) -> void:
	match menu:
		"book":
			ui.open_handbook(null)
		"orders":
			ui.open_orders_menu(null)
		"shelf":
			var sh := _find(main, "Shelf")
			if sh != null:
				ui.open_shelf_menu(sh, _player())
		"worktable":
			var wt := _find(main, "Worktable")
			if wt != null:
				ui.open_worktable(wt, _player(), null)
		"customer":
			_spawned_customer = _spawn_customer(main)
			if _spawned_customer != null:
				ui.open_customer_request(_spawned_customer, _player())
		"mirror":
			var mirror := _find(main, "Mirror")
			if mirror != null:
				ui.open_suit_builder(mirror, _player())
		"rack":
			var rack := _find(main, "ClothingRack")
			if rack != null:
				ui.open_rack_menu(rack, _player())
		"apprentice":
			var bench := _find(main, "ApprenticeBench")
			if bench != null:
				ui.open_apprentice_menu(bench, _player())
		"pause":
			get_root().get_node("GameState").is_paused = true
		"settings":
			get_root().get_node("GameState").is_paused = true
			ui.pause_menu._show_settings()
		"controls":
			get_root().get_node("GameState").is_paused = true
			ui.pause_menu._show_controls()
		"hud":
			pass
		_:
			ui.open_phone(null, null)


## Undo whatever `_open` did for `menu`, so the next target in an "all" run starts clean.
func _close(ui: Node, menu: String) -> void:
	match menu:
		"controls":
			ui.pause_menu._controls.close()
			get_root().get_node("GameState").is_paused = false
		"hud":
			pass
		"pause", "settings":
			get_root().get_node("GameState").is_paused = false
		"customer":
			ui.close_all_menus()
			if _spawned_customer != null and _spawned_customer.has_method("despawn"):
				_spawned_customer.despawn()
			_spawned_customer = null
		_:
			ui.close_all_menus()


## Poof a real Customer (with a random preference, like a walk-in) in at the greet
## spot, so the request bubble has a brief to show — without waiting on the front
## desk's arrival timers.
func _spawn_customer(main: Node) -> Node:
	var cm: Node = main.find_child("CustomerManager", true, false)
	if cm == null:
		return null
	var greet: Node = main.find_child("GreetSpot", true, false)
	var pos: Vector3 = (greet as Node3D).global_position if greet is Node3D else Vector3.ZERO
	var cust: Node = cm._spawn(pos, true)
	cust.global_position = pos
	return cust


func _find(scene: Node, cls: String) -> Node:
	var found := scene.find_children("*", cls, true, false)
	return found[0] if not found.is_empty() else null


func _player() -> Node:
	return get_first_node_in_group("player")


func _wait(frames: int) -> void:
	for _i in frames:
		await process_frame


func _capture(path: String) -> bool:
	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("No framebuffer — run WITHOUT --headless")
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if image.save_png(path) != OK:
		push_error("save_png failed: %s" % path)
		return false
	print("Saved ", path)
	return true

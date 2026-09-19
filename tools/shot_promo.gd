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
const FRONT_REF := Vector3(0.65, 0.0, 4.05)
const BRIEF_ASIDE := 2.8  # metres the brief shots look to the client's right
## Opt-in shots (only rendered when named on the command line). "clips" records every
## clip; each can also be named alone.
const EXTRA_SHOTS := [
	"cute",
	"clips",
	"clip_shop",
	"clip_mirror",
	"clip_brief",
	"clip_cut",
	"clip_sew",
	"clip_looks",
	"art",
]
## Clip frames: Steam's description column is 1170px wide (780 logical px at 150%).
## Record with `--fixed-fps 30` so every frame advances exactly 1/30 s of game time,
## however slow the capture is; tools/encode_clips.py turns the frames into WebP/GIF.
const CLIP_W := 1170
const CLIP_H := 658
const CLIP_FPS := 30
## Key art (`-- art`): rendered at ART_W x ART_H with the HUD and the screen frame off,
## into .dev/promo/art/; tools/compose_store_art.py cuts the Steam capsules from them.
const ART_W := 3840
const ART_H := 2160
const LOGO_SCALE := 5.0
const ART_SEED := 1907
const ART_CLIENTS := 5  # the client is random: shoot a few, keep the best
## The looks clip: these interiors (data/shop_looks ids), LOOK_HOLD seconds each, ending
## where it began so it loops.
const CLIP_LOOK_IDS := ["fern_damask", "oxblood", "cream_walnut", "navy_atelier", "plum_damask"]
const LOOK_HOLD := 1.0
## The mirror clip designs these CUTE_SUITS looks one after another, part by part.
const CLIP_LOOKS := ["berry", "garden"]
## Game seconds between "button presses" in the mirror clip; the clip is then saved at
## CLIP_SPEEDUP x so it reads as a sped-up play session.
const CLIP_PRESS := 0.15
const CLIP_SPEEDUP := 2
## The upgrades shot: reputation points ("Local Name"), what's already bought, and
## which row is selected.
const UPGRADES_REP := 130
const UPGRADES_MONEY := 2340
const UPGRADES_OWNED := ["cut_weights", "sew_dial", "shop_coffee"]
const UPGRADES_SELECTED := "sew_walking_foot"
## Autoplay: how far down the line the hand aims, when a glowing pin gets pulled, and
## where the start backstitch goes in.
const AUTO_LOOK := 0.035
const AUTO_OUT := 0.007  # the cut hugs the chalk from the allowance side, never inside
const AUTO_PAST := 0.004
const PIN_PULL_AT := 0.12
const START_LOCK_AT := 0.05
## Clip pacing for the v2 benches (the in-game defaults run 12 s and more a piece).
const CLIP_CUT_SECONDS := 7.0
const CLIP_SEW_SPEED := 0.5
## Cheerful looks for the fitting-mirror shots (`-- cute`).
## brief = [Enums.Occasion, Enums.Style] the client asks for (so the brief fits the look).
## parts = jacket, shirt, trousers, each [fabric, pattern, colour, style_idx] — indices
## into Enums.Fabric / Enums.Pattern / MaterialFactory.COLORS / Enums.styles_for(part).
const CUTE_SUITS := {
	"picnic": {"brief": [3, 3], "parts": [[4, 4, 4, 0], [5, 11, 12, 0], [4, 0, 4, 2]]},
	"berry": {"brief": [3, 3], "parts": [[3, 3, 7, 1], [6, 10, 16, 0], [3, 0, 7, 1]]},
	"garden": {"brief": [0, 1], "parts": [[2, 2, 9, 1], [5, 11, 15, 0], [2, 2, 8, 2]]},
	"powder": {"brief": [2, 2], "parts": [[0, 5, 6, 0], [7, 9, 11, 1], [0, 0, 2, 0]]},
	"lavender": {"brief": [0, 3], "parts": [[1, 4, 2, 1], [6, 12, 13, 0], [1, 4, 2, 1]]},
}
const CUTE_BUDGET := 480

var _main: Node
var _player: Node
var _rig: Node
var _cm: Node
var _mirror: Node
var _wanted: PackedStringArray
var _rec_dir := ""
var _rec_frame := 0
var _rec_step := 1
var _rec_tick_n := 0

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
	# The shots drive the v2 cutting / sewing games (Seam Allowance, Pedal & Aim) by
	# hand — _autocut / _autosew reach into their internals — so pin those whatever
	# the config says.
	var cfg: Resource = root.get_node("Config").data
	cfg.cut_variant = 1
	cfg.sew_variant = 1
	_dismiss_paper()
	for timer in _cm.get_children():
		if timer is Timer:
			timer.stop()
	print("viewport = %s" % str(get_root().size))
	await _shot_overview()
	await _shot_greeting()
	await _shot_suit_builder()
	await _shot_cutting()
	await _shot_sewing()
	await _shot_shelf()
	await _shot_phone()
	await _shot_upgrades()
	await _shot_handbook()
	await _shot_orders()
	await _shot_newspaper()
	await _shot_storefront()
	await _shot_cute_suits()
	await _clip_shop()
	await _clip_mirror()
	await _clip_brief()
	await _clip_cut()
	await _clip_sew()
	await _clip_looks()
	await _art()
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
	_place_player(_front(Vector3(2.0, 0.0, 5.3)), 0.5)
	await _seat_customer()
	await _wait(20)
	_frame(_front(Vector3(1.3, 0.5, 4.5)), 1.2)
	await _wait(SETTLE)
	_save("01_shop_overview")
	await _clear_hands()
	await _clear_customers()


## A walk-in states their occasion, style and budget in the greeting bubble.
func _shot_greeting() -> void:
	if not _want("greeting"):
		return
	await _clear_customers()
	var cust: Node = _spawn_customer(_front(Vector3(0.65, 0.0, 4.05)), 0.0)
	await _wait(40)
	_ui.open_customer_request(cust, _player)
	_place_player(_front(Vector3(-0.5, 0.0, 5.2)), PI * 0.75)
	await _wait(40)
	# The brief panel sits mid-screen, so the pair stand in the left third beside it.
	_frame(_front(Vector3(0.65 + BRIEF_ASIDE, 0.9, 4.5)), 0.7)
	await _wait(SETTLE)
	_save("02_customer_brief")
	_ui.close_all_menus()
	await _clear_customers()


## Designing the client's suit at the fitting mirror: overview, then a part zoom
## with the cloth changing on the customer in real time.
func _shot_suit_builder() -> void:
	if not _want("mirror"):
		return
	await _clear_customers()
	_place_player(_by_mirror(), PI * 0.5)
	await _seat_customer()
	_ui.open_suit_builder(_mirror, _player)
	var builder: Node = _ui.suit_builder
	await _wait(120)
	_save("03_suit_builder")
	builder._adjust(1)  # Overview -> Jacket: the builder glides in on the part
	# The jacket frame is tight enough to crop the face; a taller "measured height"
	# makes the builder's own solver frame a bit more of the client.
	builder._height *= 1.4
	await _wait(120)
	_save("04_suit_builder_zoom")
	_ui.close_all_menus()
	_rig.unfocus()
	await _clear_customers()


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
	await _autocut(_ui.worktable_screen._minigame, 0.55)
	_save("05_cutting_minigame")
	_release_controls()
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
	await _autosew(_ui.sewing_screen._minigame, 0.55)
	_save("06_sewing_minigame")
	_release_controls()
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
	_place_player(_at_phone(Vector3(0.3, 0.0, 1.0)), PI)
	await _wait(20)
	_frame(_at_phone(Vector3(0.3, 0.8, 0.7)), 1.0)
	_ui.open_phone(phone, _player)
	await _wait(20)
	_ui.phone_order._screen = 2  # Screen.ORDER — the cloth designer and its swatch
	_ui.phone_order._refresh()
	await _wait(30)
	_save("08_phone_order")
	_ui.close_all_menus()
	await _wait(10)


## The phone's Shop Upgrades page, mid-career: a "Local Name" reputation (so the
## top tier still shows locked), money in the till, a couple of benches already kitted out, and the
## Walking Foot selected with its preview. Everything is put back afterwards.
func _shot_upgrades() -> void:
	if not _want("upgrades"):
		return
	var rep: Node = root.get_node("Reputation")
	var upgrades: Node = root.get_node("Upgrades")
	var state: Node = root.get_node("GameState")
	var old_points: int = rep.points
	var old_money: int = state.money
	rep.points = UPGRADES_REP
	state.money = UPGRADES_MONEY
	for id in UPGRADES_OWNED:
		upgrades._owned[id] = true
	var phone: Node = _main.find_child("Phone", true, false)
	_place_player(_at_phone(Vector3(0.3, 0.0, 1.0)), PI)
	await _wait(20)
	_frame(_at_phone(Vector3(0.3, 0.8, 0.7)), 1.0)
	_ui.open_phone(phone, _player)
	await _wait(20)
	var menu: Node = _ui.phone_order
	menu._screen = 3  # Screen.UPGRADES
	menu._row = maxi(0, menu._upg_ids.find(UPGRADES_SELECTED))
	menu._refresh()
	await _wait(30)
	_save("13_phone_upgrades")
	_ui.close_all_menus()
	for id in UPGRADES_OWNED:
		upgrades._owned.erase(id)
	rep.points = old_points
	state.money = old_money
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


## The fitting mirror dressed in each CUTE_SUITS look, a fresh client per look:
## whole-suit overview and the jacket zoom, into .dev/promo/cute/.
func _shot_cute_suits() -> void:
	if not _want("cute"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/cute"))
	while _orders.active.size() < 3:
		_orders.debug_add_random()
	for look: String in CUTE_SUITS:
		await _clear_customers()
		_place_player(_by_mirror(), PI * 0.5)
		var cust: Node = await _seat_customer()
		var brief: Array = CUTE_SUITS[look]["brief"]
		cust.preference.occasion = brief[0]
		cust.preference.style = brief[1]
		cust.preference.budget = CUTE_BUDGET
		_ui.open_suit_builder(_mirror, _player)
		var builder: Node = _ui.suit_builder
		await _wait(10)
		_dress_design(builder, CUTE_SUITS[look]["parts"])
		await _wait(110)
		_save("cute/%s_overview" % look)
		builder._adjust(1)  # Overview -> Jacket
		builder._height *= 1.4  # keep the face in the jacket frame
		await _wait(120)
		_save("cute/%s_jacket" % look)
		_ui.close_all_menus()
		_rig.unfocus()
	await _clear_customers()


## Write a look into the open suit builder and put it on the client.
func _dress_design(builder: Node, parts: Array) -> void:
	var order := [2, 0, 1]  # GarmentType: JACKET, SHIRT, PANTS
	for i in order.size():
		var p: Array = parts[i]
		builder._design[order[i]] = {
			"fabric": p[0],
			"pattern": p[1],
			"color": p[2],
			"style_idx": p[3],
		}
	builder._apply_to_customer()
	builder._refresh()


# --- Key art (sources for the store capsules) ---------------------------------


## Clean, high-resolution plates: the pair outside the shop (close and wide), the shop
## floor from above, and the wordmark on a transparent ground.
func _art() -> void:
	if not _want("art"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/art"))
	await _clear_customers()
	await _clear_hands()
	_ui.close_all_menus()
	_ui.hud.visible = false
	var fx: Node = root.get_node("PostFX")
	var old_profile: Resource = fx.profile
	var clean: Resource = old_profile.duplicate()
	for prop in ["vignette_strength", "barrel_distortion", "grain_strength"]:
		clean.set(prop, 0.0)
	clean.set("chromatic_aberration", 0.0)
	fx.set_profile(clean)
	get_root().size = Vector2i(ART_W, ART_H)
	await _wait(10)
	# The shop floor, empty and tidy (page background, library hero fallback).
	_place_player(_front(Vector3(2.0, 0.0, 5.3)), 0.5)
	await _give_roll("navy_worsted_pinstripe", 14.0)
	_frame(_front(Vector3(1.3, 0.5, 4.2)), 1.05)
	await _wait(30)
	_save("art/interior")
	# Outside, late afternoon: the tailor with a bolt, a client beside him.
	_clock.start_shift(0.86)
	_dismiss_paper()
	_place_player(Vector3(1.15, 0.0, 9.9), 0.15)
	for i in ART_CLIENTS:
		seed(ART_SEED + i)  # the same five clients every run, so a pick stays picked
		var cust: Node = _spawn_customer(Vector3(-0.15, 0.0, 10.0), -0.2)
		await _wait(60)
		_frame_eye(Vector3(0.5, 2.3, 17.5), Vector3(0.5, 1.9, 8.6))
		await _wait(SETTLE)
		_save("art/street_wide_%d" % i)
		_frame_eye(Vector3(0.5, 1.5, 13.4), Vector3(0.5, 1.25, 9.9))
		await _wait(SETTLE)
		_save("art/pair_%d" % i)
		_frame_eye(Vector3(0.5, 1.3, 12.5), Vector3(0.5, 1.15, 9.9))
		await _wait(SETTLE)
		_save("art/pair_close_%d" % i)
		cust.queue_free()
		await _wait(4)
	await _clear_hands()
	await _art_logo()
	get_root().size = Vector2i(SHOT_W, SHOT_H)
	fx.set_profile(old_profile)
	_ui.hud.visible = true


## The main menu's gold-leaf wordmark, LOGO_SCALE x, on transparency.
func _art_logo() -> void:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(Vector2(360, 178) * LOGO_SCALE)
	vp.oversampling_override = LOGO_SCALE
	vp.canvas_transform = Transform2D().scaled(Vector2.ONE * LOGO_SCALE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var mark := Wordmark.new()
	mark.size = Vector2(360, 178)
	vp.add_child(mark)
	root.add_child(vp)
	await _wait(6)
	var image := vp.get_texture().get_image()
	image.save_png("%s/art/logo.png" % OUT_DIR)
	print("saved logo (%dx%d)" % [image.get_width(), image.get_height()])
	vp.queue_free()


# --- Clips (moving images for About This Game) -------------------------------


## The shop at work: the tailor crosses the floor with a bolt while a client walks in
## off the street and waves hello.
func _clip_shop() -> void:
	if not _want("clip_shop"):
		return
	await _clear_customers()
	while _orders.active.size() < 3:
		_orders.debug_add_random()
	await _clear_hands()
	await _give_roll("navy_worsted_pinstripe", 14.0)
	_place_player(_front(Vector3(5.0, 0.0, 4.4)), -PI * 0.5)
	_frame(_front(Vector3(1.4, 0.7, 4.2)), 1.2)
	var greet: Node3D = _main.find_child("GreetSpot", true, false)
	var door: Node3D = _main.find_child("DoorOutside", true, false)
	var cust: Node = _spawn_customer(door.global_position, PI)
	await _wait(10)
	_start_rec("shop")
	cust.walk([greet.global_position], cust.offer_greeting, PI)
	await _hold_move("move_left", 1.25)
	await _seconds(0.5)
	await _hold_move("move_forward", 0.25)
	await _seconds(2.4)
	_stop_rec()
	await _clear_hands()
	await _clear_customers()


## The same quiet shop, redecorated on the beat: walls, panelling, floor, rugs, curtains.
func _clip_looks() -> void:
	if not _want("clip_looks"):
		return
	var applier: Node = _main.find_child("ShopLookApplier", true, false)
	if applier == null:
		push_warning("clip_looks: no ShopLookApplier in the scene")
		return
	await _clear_customers()
	await _clear_hands()
	var before: int = applier.current
	_place_player(_front(Vector3(2.0, 0.0, 5.3)), 0.5)
	_frame(_front(Vector3(1.3, 0.5, 4.2)), 1.05)
	applier.apply_id(CLIP_LOOK_IDS[0])
	await _wait(10)
	_start_rec("looks")
	for id: String in CLIP_LOOK_IDS:
		applier.apply_id(id)
		await _seconds(LOOK_HOLD)
	_stop_rec()
	applier.apply(before)


## The fitting mirror, played like a (sped-up) session: pick a part, step through its
## fabric / colour / pattern / style, next part, back out to the whole suit — then the
## next look. Each CLIP_LOOKS suit is built one press at a time.
func _clip_mirror() -> void:
	if not _want("clip_mirror"):
		return
	await _clear_customers()
	_place_player(_by_mirror(), PI * 0.5)
	var cust: Node = await _seat_customer()
	cust.preference.occasion = 3  # PARTY — a brief every look in the reel suits
	cust.preference.style = 3  # FASHION
	cust.preference.budget = CUTE_BUDGET
	_ui.open_suit_builder(_mirror, _player)
	var builder: Node = _ui.suit_builder
	await _wait(60)
	_start_rec("mirror", CLIP_SPEEDUP)
	for look: String in CLIP_LOOKS:
		await _design_by_hand(builder, CUTE_SUITS[look]["parts"])
		await _seconds(1.0)  # admire the finished suit
	_stop_rec()
	_ui.close_all_menus()
	_rig.unfocus()
	await _clear_customers()


## Drive the suit builder like a player: for each part select it on the Part row, then
## walk down Fabric / Colour / Pattern / Style pressing left/right the short way round
## to each target value, then return to the whole-suit overview.
func _design_by_hand(builder: Node, parts: Array) -> void:
	var enums: Script = load("res://data/scripts/enums.gd")
	var factory: Script = load("res://data/scripts/material_factory.gd")
	var types := [2, 0, 1]  # JACKET, SHIRT, PANTS — the order parts[] is written in
	var keys := ["fabric", "color", "pattern", "style_idx"]  # the builder's row order
	var src := [0, 2, 1, 3]  # where each key sits in a CUTE_SUITS part entry
	for i in types.size():
		var t: int = types[i]
		await _go_row(builder, 0)
		while builder._type() != t:
			builder._adjust(1)
			await _seconds(CLIP_PRESS)
		await _seconds(CLIP_PRESS * 2.0)  # let the camera glide in on the part
		var styles := PackedInt32Array()
		for n in enums.styles_for(t).size():
			if n < 2:  # skip "Shorts": the trouser model doesn't show them yet
				styles.append(n)
		var options := [
			builder._available_fabrics(t),
			factory.colors_for(t),
			enums.patterns_for(t),
			styles,
		]
		for r in keys.size():
			var opts: PackedInt32Array = options[r]
			var want: int = parts[i][src[r]]
			var have: int = int(builder._design[t][keys[r]])
			if not opts.has(want) or want == have:
				continue
			await _go_row(builder, r + 1)
			var steps := _short_way(opts, have, want)
			for _n in absi(steps):
				builder._adjust(signi(steps))
				await _seconds(CLIP_PRESS)
	await _go_row(builder, 0)
	while builder._part_sel != -1:
		builder._adjust(1)
		await _seconds(CLIP_PRESS)


func _go_row(builder: Node, row: int) -> void:
	while builder._row != row:
		builder._move_row(1 if row > builder._row else -1)
		await _seconds(CLIP_PRESS)


## Signed number of presses from `from` to `to` in a wrapping option list.
func _short_way(opts: PackedInt32Array, from: int, to: int) -> int:
	var a := maxi(opts.find(from), 0)
	var b := opts.find(to)
	var n := opts.size()
	var fwd := (b - a + n) % n
	return fwd if fwd <= n - fwd else fwd - n


## A walk-in comes to the counter, waves, and states the brief.
func _clip_brief() -> void:
	if not _want("clip_brief"):
		return
	await _clear_customers()
	# Stand beside the client's line from the door (it runs straight up x ~ 0.65), not
	# on it and clear of the brief panel, turned to where they'll stop.
	_place_player(_front(Vector3(-0.6, 0.0, 4.9)), atan2(1.25, -0.85))
	_frame(_front(Vector3(0.65 + BRIEF_ASIDE, 0.9, 4.5)), 0.7)
	var greet: Node3D = _main.find_child("GreetSpot", true, false)
	var door: Node3D = _main.find_child("DoorInside", true, false)
	var cust: Node = _spawn_customer(door.global_position + Vector3(0.0, 0.0, 0.4), PI)
	await _wait(10)
	_start_rec("brief")
	var arrived := [false]
	cust.walk([greet.global_position], func() -> void: arrived[0] = true, 0.0)
	for _i in 200:
		if arrived[0]:
			break
		await process_frame
	cust.offer_greeting()
	await _seconds(0.7)
	_ui.open_customer_request(cust, _player)
	await _seconds(2.2)
	_stop_rec()
	_ui.close_all_menus()
	await _clear_customers()


## The whole cut, start to "clean piece", sped up to fit a short loop.
func _clip_cut() -> void:
	if not _want("clip_cut"):
		return
	var table: Node = _main.find_child("Worktable", true, false)
	var piece: Node = _make_item("fabric_piece", "charcoal_worsted_solid")
	piece.length_m = 6.0
	await _hand_over(piece)
	table.interact(_player)
	await _wait(6)
	table.interact(_player)
	await _wait(30)
	_ui.worktable_screen._start_cutting()
	var game: Node = _ui.worktable_screen._minigame
	game._seconds = CLIP_CUT_SECONDS
	_start_rec("cutting")
	await _autocut(game, 1.0)
	_release_controls()
	await _seconds(0.8)
	_stop_rec()
	await _seconds(0.5)
	_ui.close_all_menus()
	await _take_back(table)


## A full seam in rhythm, every stitch on the beat.
func _clip_sew() -> void:
	if not _want("clip_sew"):
		return
	var machine: Node = _main.find_child("SewingMachine", true, false)
	var part: Node = _make_item("garment_piece", "navy_worsted_pinstripe")
	part.garment_type = 2  # JACKET
	part.stage = 2  # CUT
	await _hand_over(part)
	machine.interact(_player)
	await _wait(6)
	machine.interact(_player)
	var game: Node = _ui.sewing_screen._minigame
	game._top = CLIP_SEW_SPEED
	_start_rec("sewing")
	await _autosew(game, 1.0)
	_release_controls()
	await _seconds(0.8)
	_stop_rec()
	await _seconds(0.5)
	_ui.close_all_menus()
	await _take_back(machine)


func _start_rec(name: String, speedup := 1) -> void:
	_rec_dir = "%s/clips/%s" % [OUT_DIR, name]
	var abs_dir := ProjectSettings.globalize_path(_rec_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	_rec_frame = 0
	_rec_step = maxi(speedup, 1)
	_rec_tick_n = 0
	if not process_frame.is_connected(_rec_tick):
		process_frame.connect(_rec_tick)


func _stop_rec() -> void:
	if process_frame.is_connected(_rec_tick):
		process_frame.disconnect(_rec_tick)
	print("recorded %s (%d frames)" % [_rec_dir, _rec_frame])


func _rec_tick() -> void:
	_rec_tick_n += 1
	if (_rec_tick_n - 1) % _rec_step != 0:
		return
	var image := get_root().get_texture().get_image()
	if image == null:
		return
	image.resize(CLIP_W, CLIP_H, Image.INTERPOLATE_LANCZOS)
	image.save_jpg("%s/f%04d.jpg" % [_rec_dir, _rec_frame], 0.95)
	_rec_frame += 1


## Wait `secs` of game time (exact under --fixed-fps CLIP_FPS).
func _seconds(secs: float) -> void:
	await _wait(roundi(secs * CLIP_FPS))


## Hold a movement action like a stick push, then let go.
func _hold_move(action: String, secs: float) -> void:
	root.get_node("GameState").input_locked = false
	Input.action_press(action)
	await _seconds(secs)
	Input.action_release(action)


## Pick a finished piece back up off a station and bin it, so it's free for the next run.
func _take_back(station: Node) -> void:
	await _wait(10)
	station.interact(_player)
	await _clear_hands()


# --- Staging helpers -------------------------------------------------------


## The morning paper slides up on its own at day start — fold it away unless the
## shot is about the paper.
func _dismiss_paper() -> void:
	if _ui.newspaper != null and _ui.newspaper.visible:
		_ui.newspaper.close()


func _want(name: String) -> bool:
	if name.begins_with("clip_") and _wanted.has("clips"):
		return true
	if EXTRA_SHOTS.has(name):
		return _wanted.has(name)
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


## Front-of-shop staging is written against a greeting spot at FRONT_REF and moved to
## wherever the map's GreetSpot really is, so the shots survive a new shop layout.
func _front(pos: Vector3) -> Vector3:
	var greet: Node3D = _main.find_child("GreetSpot", true, false)
	return pos + (greet.global_position - FRONT_REF if greet != null else Vector3.ZERO)


## Where the tailor waits during a fitting: beside the mirror spot, out of the frame.
func _by_mirror() -> Vector3:
	var spot: Node3D = _main.find_child("MirrorSpot", true, false)
	return spot.global_position + Vector3(-1.2, 0.0, 1.8)


func _at_phone(offset: Vector3) -> Vector3:
	var phone: Node3D = _main.find_child("Phone", true, false)
	return phone.global_position * Vector3(1.0, 0.0, 1.0) + offset


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


## A client walked onto the mirror spot by the shop's own routing (exact spot and
## facing), waiting to be fitted. Returns once they've arrived.
func _seat_customer() -> Node:
	var spot: Node3D = _main.find_child("MirrorSpot", true, false)
	var start: Vector3 = spot.global_position + Vector3(-0.8, 0.0, 0.6)
	var cust: Node = _spawn_customer(start, 0.0)
	_cm.route_to_mirror(cust)
	for _i in 300:
		if _mirror.customer == cust:
			break
		await process_frame
	await _wait(30)  # let the walk blend back to idle
	return cust


## Empty the shop floor so a shot never shows a leftover client.
func _clear_customers() -> void:
	var gone: Array[Node] = []
	for child in _cm.get_children():
		if child is Node3D and child.has_method("despawn"):
			# Switch the prompt off first so the player's interactor lets go of them
			# before they're freed (it would otherwise keep a dangling highlight).
			child._set_interactable(false)
			gone.append(child)
	await _wait(4)
	for child in gone:
		child.queue_free()
	_mirror.customer = null
	await _wait(10)


## Drive the Seam Allowance cut like a steady hand: hold Cut and keep the shears
## pointed a little way down the chalk (the game pivots the corners itself) until
## `fraction` of the outline is cut. Cut stays held — `_release_controls()` after.
func _autocut(game: Node, fraction: float) -> void:
	await _wait(2)  # let the bench arm (Cut must read as released first)
	Input.action_press("cut")
	for _i in 3000:
		if game._state > 1 or game._cum[game._seg] / game._total >= fraction:
			break
		if game._pivot_t <= 0.0:
			var along: float = game._cum[game._seg] + _proj(game)
			game._heading = (_cut_aim(game, along) - game._p).angle()
		await process_frame


## Where the shears aim: a little way down the chalk, just on the allowance side. The
## bench only moves on to the next run once the shears pass the end of this one, so at
## a sharp kink (the outline doubling back without a pivot) aim past that end first.
func _cut_aim(game: Node, along: float) -> Vector2:
	var aim := _arc_point(game, along + AUTO_LOOK, AUTO_OUT)
	var i: int = game._seg
	if i + 1 >= game._path.size():
		return aim
	var dir: Vector2 = game._seg_dir(i)
	var end: Vector2 = game._path[i + 1]
	if (aim - end).dot(dir) < AUTO_PAST:
		aim = end + dir * AUTO_PAST + dir.orthogonal() * game._out * AUTO_OUT
	return aim


## Drive Pedal & Aim the way the handbook teaches: a backstitch to lock the start,
## pedal with the cloth aimed down the seam line, pull each pin as it glows, and at the
## end mark backstitch again and cut the thread — or stop, pedal down, once the needle
## is `fraction` of the way along. `_release_controls()` after.
func _autosew(game: Node, fraction: float) -> void:
	await _wait(2)
	Input.action_press("cut")
	for _i in 4000:
		if game._state > 1:
			break
		var s: float = game._arc()
		if fraction < 1.0 and s / game._total >= fraction:
			break
		_sew_backstitch(game, s)
		if game._at_end and game._locked["end"] and not game._reversing:
			game._action()  # cut the thread
		var pin: Dictionary = game._pin_in_reach()
		if not pin.is_empty() and pin["s"] - s < PIN_PULL_AT:
			game._action()
		if not game._reversing:
			game._heading = (_arc_point(game, s + AUTO_LOOK) - game._p).angle()
		await process_frame


## Hold S while inside either lock zone and not yet locked there.
func _sew_backstitch(game: Node, s: float) -> void:
	var start_due: bool = not game._locked["start"] and s > START_LOCK_AT
	var end_due: bool = not game._locked["end"] and game._at_end
	if start_due or end_due:
		Input.action_press("move_back")
	else:
		Input.action_release("move_back")


func _release_controls() -> void:
	for action in ["cut", "move_back"]:
		Input.action_release(action)


## How far along its current segment the tool is.
func _proj(game: Node) -> float:
	var i: int = game._seg
	var span: float = game._cum[i + 1] - game._cum[i] if i + 1 < game._cum.size() else 0.0
	return clampf((game._p - game._path[i]).dot(game._seg_dir(i)), 0.0, span)


## The point `s` along a bench's outline, `out` beyond it (into the allowance).
func _arc_point(game: Node, s: float, out := 0.0) -> Vector2:
	var path: PackedVector2Array = game._path
	var cum: PackedFloat32Array = game._cum
	for i in path.size() - 1:
		if cum[i + 1] >= s:
			var span := cum[i + 1] - cum[i]
			var t := 0.0 if span <= 0.0 else (s - cum[i]) / span
			var normal: Vector2 = (path[i + 1] - path[i]).normalized().orthogonal() * game._out
			return path[i].lerp(path[i + 1], t) + normal * out
	return path[path.size() - 1]


func _spawn_customer(pos: Vector3, yaw: float) -> Node:
	var cust: Node = _cm._spawn(pos, true)
	cust.global_position = pos
	cust.rotation.y = yaw
	return cust

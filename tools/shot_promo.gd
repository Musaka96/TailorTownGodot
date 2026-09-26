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
const FACTORY_PATH := "res://data/scripts/material_factory.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const FRONT_REF := Vector3(0.65, 0.0, 4.05)
const BRIEF_ASIDE := 2.8  # metres the brief shots look to the client's right
## Opt-in shots (only rendered when named on the command line). "clips" records every
## clip; each can also be named alone.
const EXTRA_SHOTS := [
	"cute",
	"reaction",
	"clips",
	"clip_shop",
	"clip_mirror",
	"clip_brief",
	"clip_cut",
	"clip_sew",
	"clip_looks",
	"art",
	"art_mirror",
	"art_work",
	"art_shop",
	"art_named",
	"art_badges",
	"draft",
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
## The mirror plate: which CUTE_SUITS the client wears, and the hand-staged pose.
const ART_MIRROR_LOOKS := ["berry", "garden", "picnic"]
const ART_CLIENT_YAW := -0.25
const ART_TAILOR_OFFSET := Vector3(-1.3, 0.0, 0.3)
const ART_TAILOR_YAW := 0.8
## Where the tailor's hands hold the tape: forward, either side, height (his own frame).
const ART_TAPE_HOLD := Vector3(0.3, 0.74, 0.42)
## The workroom plate.
const ART_AT_TABLE := Vector3(0.1, 0.0, -0.95)
const ART_TABLE_YAW := 0.25
const ART_PERCY_AT_TABLE := Vector3(1.55, 0.0, -0.5)
const ART_PERCY_YAW := -0.55
## The shop plate: extra racks staged for it ([position, yaw]), hung full of suits in
## ART_SHOP_CLOTHS (the cloth shelves are stocked in them too); and each candidate cast:
## the tailor's spot (and a bolt in his arms), the clients ([rng seed, spot, CUTE_SUITS look,
## extra yaw]; the seeds pick a woman and a man), and the camera [eye, look] at
## ART_SHOP_FOV. The eye sits about level with the wall tops so the frame's top edge is
## still wall, and the group stands left of centre: the right side is kept for the logo.
const ART_SHOP_RACKS := [
	[Vector3(0.35, 0.0, -4.85), 0.0],
	[Vector3(-2.75, 0.0, -4.3), 0.35],
]
## A second sewing machine for the plate, against the back wall beside the racks.
const ART_SHOP_MACHINE := [Vector3(1.95, 0.0, -4.95), 0.0]
const ART_SHOP_CLOTHS := [
	Color("c9a23a"),
	Color("2f7f86"),
	Color("b8566a"),
	Color("5f86c0"),
	Color("6f9463"),
	Color("7a2a3a"),
	Color("1b2a4a"),
	Color("c8b48a"),
	Color("7d6db0"),
	Color("d2694b"),
	Color("2f5d3e"),
	Color("5a4633"),
]
const ART_SHOP_FOV := 50.0
const ART_SHOP_CASTS := [
	{
		"tailor": Vector3(-0.8, 0.0, -3.2),
		"roll": "burgundy_mohair_birdseye",
		"clients":
		[
			[2014, Vector3(-1.6, 0.0, -2.95), "powder", 0.0],
			[2010, Vector3(0.0, 0.0, -3.5), "garden", 0.0],
		],
		"cam": [Vector3(1.3, 3.6, 0.7), Vector3(-0.4, 0.3, -4.4)],
	},
	{
		"tailor": Vector3(-0.8, 0.0, -3.2),
		"roll": "burgundy_mohair_birdseye",
		"clients":
		[
			[2016, Vector3(-1.6, 0.0, -2.95), "picnic", 0.0],
			[2019, Vector3(0.0, 0.0, -3.5), "garden", 0.0],
		],
		"cam": [Vector3(1.3, 3.6, 0.7), Vector3(-0.4, 0.3, -4.4)],
	},
	{
		"tailor": Vector3(-0.8, 0.0, -3.2),
		"roll": "tan_linen_solid",
		"clients":
		[
			[2010, Vector3(-1.6, 0.0, -2.95), "berry", 0.0],
			[2022, Vector3(0.0, 0.0, -3.5), "garden", 0.0],
		],
		"cam": [Vector3(1.3, 3.6, 0.7), Vector3(-0.4, 0.3, -4.4)],
	},
]
## The same plate with two of the named cast (their own faces): the shop_1 spots and camera.
const ART_NAMED_CASTS := [
	{
		"tailor": Vector3(-0.8, 0.0, -3.2),
		"roll": "burgundy_mohair_birdseye",
		"clients":
		[
			["Mr. Pettigrew", Vector3(-1.6, 0.0, -2.95), "garden", 0.0],
			["Mr. Dimmock", Vector3(0.0, 0.0, -3.5), "picnic", 0.0],
		],
		"cam": [Vector3(1.3, 3.6, 0.7), Vector3(-0.4, 0.3, -4.4)],
	},
	{
		"tailor": Vector3(-0.8, 0.0, -3.2),
		"roll": "burgundy_mohair_birdseye",
		"clients":
		[
			["Mr. Dimmock", Vector3(-1.6, 0.0, -2.95), "picnic", 0.0],
			["Mr. Pettigrew", Vector3(0.0, 0.0, -3.5), "garden", 0.0],
		],
		"cam": [Vector3(1.3, 3.6, 0.7), Vector3(-0.4, 0.3, -4.4)],
	},
]
const ART_TAKES := 2
## How far (logical px) the sign's chains rise above the board in the capsule art.
const SIGN_CHAIN := 240.0
const WORDMARK_PATH := "res://ui/craft/wordmark.gd"
const ART_CLIENTS := 5  # the client is random: shoot a few, keep the best
## The looks clip: these interiors (data/shop_looks ids), LOOK_HOLD seconds each, ending
## where it began so it loops.
const CLIP_LOOK_IDS := ["fern_damask", "oxblood", "cream_walnut", "navy_atelier", "plum_damask"]
const LOOK_HOLD := 1.0
## The mirror clip, at game speed: a seeded client comes in with the CLIP_MIRROR_BRIEF
## look's brief and a quiet dislike, tries on each CLIP_MIRROR_SUITS look whole and is
## asked each time. The first is wrong for the occasion, the second hits the dislike
## (linen: "Linen creases if you look at it."), the last is the yes.
const CLIP_MIRROR_SEED := 2010  # Mr. Rossi: a man (the feminine kit is not ready)
const CLIP_MIRROR_BRIEF := "berry"
const CLIP_MIRROR_SUITS := ["garden", "picnic", "berry"]
const CLIP_MIRROR_DISLIKE := {"kind": "fabric", "value": 4}
## The second take's client (`-- clip_mirror_dimmock`): a FaceCast member, by name.
const CLIP_MIRROR_CAST := "Mr. Dimmock"
## Seconds on a fresh suit before asking, to read an answer, and on the final yes.
const CLIP_TRY := 0.7
const CLIP_ANSWER := 2.4
const CLIP_SOLD := 1.6
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
	await _shot_reaction()
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
	await _clip_mirror_cast()
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


## Designing the client's suit at the fitting mirror: the suit tab, then the shirt tab
## with the cloth changing on the customer in real time (the camera holds one portrait).
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
	builder._adjust(1)  # Suit -> Shirt
	await _wait(120)
	_save("04_suit_builder_zoom")
	_ui.close_all_menus()
	_rig.unfocus()
	await _clear_customers()


## Asking the client at the mirror (opt-in, for review): a Wedding · Classic brief turns
## down a pinstripe jacket in a bubble at the shoulder, then says yes to a plain one.
func _shot_reaction() -> void:
	if not _want("reaction"):
		return
	await _clear_customers()
	_place_player(_by_mirror(), PI * 0.5)
	var cust: Node = await _seat_customer()
	cust.preference.occasion = 0  # Wedding
	cust.preference.style = 1  # Classic
	cust.preference.budget = 5000
	_ui.open_suit_builder(_mirror, _player)
	var builder: Node = _ui.suit_builder
	await _wait(150)
	_save("reaction_before")
	_dress_for_reaction(builder, 1)  # pinstripe: refused
	builder._confirm()
	await _wait(150)
	_save("reaction_no")
	# The same bubble with no room at either shoulder: it sits over the head instead.
	var bubble: Control = builder._bubble
	if bubble != null:
		var vp: Vector2 = bubble.get_viewport_rect().size
		bubble.bounds = Rect2(Vector2(vp.x * 0.12, 0.0), Vector2(vp.x * 0.4, vp.y))
		await _wait(20)
		_save("reaction_above")
	_dress_for_reaction(builder, 0)  # plain: accepted
	builder._confirm()
	await _wait(70)
	_save("reaction_yes")
	_ui.close_all_menus()
	_rig.unfocus()
	await _clear_customers()


## Navy jacket and trousers in `pattern`, and a white shirt.
func _dress_for_reaction(builder: Node, pattern: int) -> void:
	var suit := {"fabric": 0, "color": 0, "pattern": pattern, "style_idx": 0}
	builder._design[2] = suit.duplicate()
	builder._design[1] = suit.duplicate()
	builder._design[0] = {"fabric": 5, "color": 10, "pattern": 0, "style_idx": 0}
	builder._awaiting = false
	builder._apply_to_customer()


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
## the fitting's one portrait shot, into .dev/promo/cute/.
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
		_save("cute/%s" % look)
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
	if _want("art_badges") and not _want("art"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/art"))
		await _art_logo()
	if not (
		_want("art")
		or _want("art_mirror")
		or _want("art_work")
		or _want("art_shop")
		or _want("art_named")
	):
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
	var draft := _wanted.has("draft")
	get_root().size = Vector2i(ART_W, ART_H) / (3 if draft else 1)
	await _wait(10)
	if _want("art_mirror") or _want("art"):
		await _art_mirror()
	if _want("art_work") or _want("art"):
		await _art_work()
	if _want("art_shop") or _want("art"):
		await _art_shop(ART_SHOP_CASTS, "shop")
	if _want("art_named") or _want("art"):
		await _art_shop(ART_NAMED_CASTS, "shop_named")
	if _want("art"):
		await _art_floor_and_street()
		await _art_logo()
	get_root().size = Vector2i(SHOT_W, SHOT_H)
	fx.set_profile(old_profile)
	_ui.hud.visible = true


## The fitting: a client in a bright showcase suit on the mirror spot, the tailor beside
## them with a tape measure drawn across their shoulders. There is no measuring clip, so
## the tailor's arms are posed by hand for the plate (and the rig rebuilt afterwards).
func _art_mirror() -> void:
	await _clear_customers()
	var spot: Node3D = _main.find_child("MirrorSpot", true, false)
	var at := spot.global_position
	_place_player(at + Vector3(-5.0, 0.0, 3.0), 0.0)  # out of the way while they walk in
	# The racks of finished suits hang right where this camera stands.
	var racks: Array[Node] = [_main.find_child("ClothingRack", true, false)]
	racks.append_array(_main.find_children("int_rack_right_*", "Node3D", true, false))
	for rack: Node3D in racks:
		rack.visible = false
	for i in ART_MIRROR_LOOKS.size():
		_cm._rng.seed = ART_SEED + 10 + i  # the same clients every run
		var cust: Node = await _seat_customer()
		_wear_look(cust, CUTE_SUITS[ART_MIRROR_LOOKS[i]]["parts"])
		cust.rotation.y = ART_CLIENT_YAW
		_place_player(at + ART_TAILOR_OFFSET, 0.0)
		var model: Node3D = _player.get_node("Model")
		model.rotation.y = ART_TAILOR_YAW
		await _wait(20)
		var tape := _pose_measuring(model)
		await _wait(4)
		_frame_eye(at + Vector3(-0.8, 1.2, 3.3), at + Vector3(-0.65, 0.95, 0.0))
		for take in ART_TAKES:  # a few frames apart, so one of them isn't mid-blink
			await _wait(SETTLE + take * 35)
			_save("art/mirror_%d%s" % [i, "abc"[take]])
		tape.queue_free()
		_unpose(model)
		await _clear_customers()
	for rack: Node3D in racks:
		rack.visible = true


## Put a CUTE_SUITS look (jacket, shirt, trousers rows) straight onto a client.
func _wear_look(cust: Node, parts: Array) -> void:
	# Loaded at run time: naming the class here would compile it before the autoloads exist.
	var factory: GDScript = load(FACTORY_PATH)
	var mats: Array = []
	for p: Array in parts:
		mats.append(factory.make(p[0], p[1], p[2], 1.0))
	cust.wear_suit(mats[0], mats[1], mats[2], parts[0][3], parts[2][3])


## Freeze the rig's animation and hold both arms out in front; returns the tape measure
## stretched between the hands.
func _pose_measuring(model: Node3D) -> Node3D:
	var tree: AnimationTree = model.find_children("*", "AnimationTree", true, false)[0]
	tree.active = false
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var fwd := model.global_transform.basis.z.normalized()
	var side := model.global_transform.basis.x.normalized()
	var chest := model.global_position + Vector3.UP * ART_TAPE_HOLD.y + fwd * ART_TAPE_HOLD.z
	_aim_arm(sk, "l", chest + side * ART_TAPE_HOLD.x)
	_aim_arm(sk, "r", chest - side * ART_TAPE_HOLD.x)
	var a := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.l")).origin
	var b := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.r")).origin
	var tape := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.008, a.distance_to(b) + 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.8, 0.25)
	mat.roughness = 0.6
	box.material = mat
	tape.mesh = box
	_main.add_child(tape)
	tape.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	return tape


## Swing one straight arm so the hand points at `target` (world space).
func _aim_arm(sk: Skeleton3D, side: String, target: Vector3) -> void:
	for bone: String in ["lowerarm.", "wrist.", "hand."]:
		sk.reset_bone_pose(sk.find_bone(bone + side))
	var upper := sk.find_bone("upperarm." + side)
	var lower := sk.find_bone("lowerarm." + side)
	var world := sk.global_transform
	var pose := world * sk.get_bone_global_pose(upper)
	var elbow := (world * sk.get_bone_global_pose(lower)).origin
	var turn := Quaternion((elbow - pose.origin).normalized(), (target - pose.origin).normalized())
	pose.basis = Basis(turn) * pose.basis
	sk.set_bone_global_pose(upper, world.affine_inverse() * pose)


func _unpose(model: Node3D) -> void:
	var tree: AnimationTree = model.find_children("*", "AnimationTree", true, false)[0]
	tree.active = true


## The workroom: the tailor at the cutting table with cloth, Percy at his own bench.
func _art_work() -> void:
	await _clear_customers()
	var upgrades: Node = root.get_node("Upgrades")
	var had: bool = upgrades.has("apprentice")
	upgrades._owned["apprentice"] = true
	upgrades.changed.emit()
	var bench: Node3D = _main.find_child("ApprenticeBench", true, false)
	var table: Node3D = _main.find_child("Worktable", true, false)
	var percy: Node3D = bench.get_node("Apprentice")
	var percy_home := percy.global_transform
	percy.global_position = table.global_position + ART_PERCY_AT_TABLE
	percy.global_rotation.y = ART_PERCY_YAW
	_place_player(table.global_position + ART_AT_TABLE, 0.0)
	_player.get_node("Model").rotation.y = ART_TABLE_YAW
	await _give_roll("navy_worsted_pinstripe", 14.0)
	await _wait(30)
	var at := table.global_position
	_frame_eye(at + Vector3(0.85, 1.35, 2.25), at + Vector3(0.75, 0.95, -0.6))
	for take in ART_TAKES:
		await _wait(SETTLE + take * 35)
		_save("art/work_%s" % "abc"[take])
	percy.global_transform = percy_home
	await _clear_hands()
	if not had:
		upgrades._owned.erase("apprentice")
		upgrades.changed.emit()


## The working shop: the tailor and a client or two standing together in the workroom,
## in front of racks crammed with finished suits, the sewing machine and the cloth shelves.
## Extra racks (and their suits) are staged for the plate only and freed afterwards; the
## shelves and upgrades are put back the way they were. Writes art/<prefix>_<n><take>.png.
func _art_shop(casts: Array, prefix: String) -> void:
	await _clear_customers()
	var upgrades: Node = root.get_node("Upgrades")
	var had := {}
	for id: String in ["rack_hooks"]:
		had[id] = upgrades.has(id)
		upgrades._owned[id] = true
	upgrades.changed.emit()
	var staged: Array[Node] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = ART_SEED
	for r: Array in ART_SHOP_RACKS:
		var rack: Node3D = load("res://stations/clothing_rack/clothing_rack.tscn").instantiate()
		rack.position = r[0]
		rack.rotation.y = r[1]
		_main.add_child(rack)
		staged.append(rack)
	var machine: Node3D = load("res://stations/sewing_machine/sewing_machine.tscn").instantiate()
	machine.position = ART_SHOP_MACHINE[0]
	machine.rotation.y = ART_SHOP_MACHINE[1]
	_main.add_child(machine)
	await _wait(4)
	for rack: Node in staged:
		while rack.stored.size() < rack.capacity():
			rack.hang(_rack_suit(rng))
	var shelves: Array[Node] = []
	var shelf_saves: Array[Dictionary] = []
	for n: String in ["Shelf", "Shelf2"]:
		var shelf: Node = _main.find_child(n, true, false)
		shelves.append(shelf)
		shelf_saves.append(shelf.save_state())
		_fill_shelf(shelf, rng)
	# Percy's bench stands between the camera and the group: out of the plate.
	var bench: Node3D = _main.find_child("ApprenticeBench", true, false)
	var bench_shown := bench.visible
	bench.visible = false
	# The wall plaque would peek out from behind the capsules' hanging sign.
	var plaque: Node3D = _main.find_child("int_plaque", true, false)
	if plaque != null:
		plaque.visible = false
	var cam_node: Camera3D = _rig.get_node("Camera3D")
	var old_fov := cam_node.fov
	cam_node.fov = ART_SHOP_FOV
	for i in casts.size():
		await _stage_shop_cast(casts[i])
		var cam: Array = casts[i]["cam"]
		_frame_eye(cam[0], cam[1])
		for take in ART_TAKES:
			await _wait(SETTLE + take * 35)
			_save("art/%s_%d%s" % [prefix, i, "abc"[take]])
		await _clear_customers()
		await _clear_hands()
	cam_node.fov = old_fov
	bench.visible = bench_shown
	if plaque != null:
		plaque.visible = true
	for i in shelves.size():
		shelves[i].load_state(shelf_saves[i])
	machine.queue_free()
	for node in staged:
		node.queue_free()
	for id: String in had:
		if not had[id]:
			upgrades._owned.erase(id)
	upgrades.changed.emit()


## One ART_SHOP_CASTS / ART_NAMED_CASTS entry: the tailor and the clients in their looks,
## each turned to face the camera. A client is a seeded walk-in, or (a name in place of the
## seed) that named cast member, dressed the way the shop dresses them: FaceCast gives them
## their own face, hair colour and glasses.
func _stage_shop_cast(cast: Dictionary) -> void:
	var eye: Vector3 = cast["cam"][0]
	var tailor: Vector3 = cast["tailor"]
	_place_player(tailor, 0.0)
	_player.get_node("Model").rotation.y = _yaw_to(tailor, eye) + cast.get("tailor_turn", 0.0)
	if cast.has("roll"):
		await _give_roll(String(cast["roll"]), 14.0)
	var clients: Array = cast["clients"]
	for c: Array in clients:
		var cust: Node
		if c[0] is String:
			cust = _spawn_named(String(c[0]), c[1], _yaw_to(c[1], eye) + float(c[3]))
		else:
			_cm._rng.seed = int(c[0])
			cust = _spawn_customer(c[1], _yaw_to(c[1], eye) + float(c[3]))
		_wear_look(cust, CUTE_SUITS[String(c[2])]["parts"])
	await _wait(40)


## A named cast member (e.g. "Mr. Dimmock") at `pos`, by the shop's own naming path: a
## brief in their name, then dressed from it.
func _spawn_named(nm: String, pos: Vector3, yaw: float) -> Node:
	var cust: Node = _spawn_customer(pos, yaw)
	var rng := RandomNumberGenerator.new()
	rng.seed = ART_SEED
	cust.preference = load(PREF_SCRIPT).random_pref(rng, nm)
	_cm._dress(cust)
	return cust


## The yaw that turns a figure standing at `from` to face `to` (rigs face +z at yaw 0).
func _yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


## A finished suit in a cheerful cloth for the staged racks: jacket and trousers to match
## (now and then odd trousers), a pale shirt.
func _rack_suit(rng: RandomNumberGenerator) -> Node:
	var factory: GDScript = load(FACTORY_PATH)
	var colour: Color = ART_SHOP_CLOTHS[rng.randi() % ART_SHOP_CLOTHS.size()]
	var jacket: Resource = factory.make(
		rng.randi_range(0, 4), [0, 1, 2, 4, 5][rng.randi() % 5], 0, 1.0
	)
	jacket.cloth_color = colour
	jacket.pattern_color = factory.pattern_color_for(colour, 0)
	var pants: Resource = jacket
	if rng.randf() < 0.25:
		pants = factory.make(jacket.fabric, 0, [0, 1, 2, 4][rng.randi() % 4], 1.0)
	var shirt: Resource = factory.make(5, 0, rng.randi_range(10, 17), 1.0)
	var suit: Node = load("res://entities/items/suit.tscn").instantiate()
	suit.parts = {
		0: {"material": shirt, "quality": 1.0, "size": 1, "style": "Classic"},
		1: {"material": pants, "quality": 1.0, "size": 1, "style": "Classic"},
		2: {"material": jacket, "quality": 1.0, "size": 1, "style": "Classic"},
	}
	suit.primary_color = colour
	return suit


## Stock a cloth shelf to the brim with bolts in the rack palette.
func _fill_shelf(shelf: Node, rng: RandomNumberGenerator) -> void:
	var factory: GDScript = load(FACTORY_PATH)
	while shelf.stored.size() < shelf.capacity():
		var mat: Resource = factory.make(
			rng.randi_range(0, 4), [0, 0, 1, 2, 4][rng.randi() % 5], 0, 12.0
		)
		mat.cloth_color = ART_SHOP_CLOTHS[rng.randi() % ART_SHOP_CLOTHS.size()]
		mat.pattern_color = factory.pattern_color_for(mat.cloth_color, 0)
		var roll: Node = load("res://entities/items/material_roll.tscn").instantiate()
		roll.material = mat
		roll.remaining_length_m = 12.0
		_main.add_child(roll)
		shelf.stock(roll)


## The empty shop floor from above, then the pair outside the shop (five seeded clients).
func _art_floor_and_street() -> void:
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
		_cm._rng.seed = ART_SEED + i  # the same five clients every run, so a pick stays picked
		var cust: Node = _spawn_customer(Vector3(-0.15, 0.0, 10.0), -0.2)
		await _wait(60)
		_frame_eye(Vector3(0.5, 2.3, 17.5), Vector3(0.5, 1.9, 8.6))
		await _wait(SETTLE)
		_save("art/street_wide_%d" % i)
		_frame_eye(Vector3(0.5, 1.5, 13.4), Vector3(0.5, 1.25, 9.9))
		await _wait(SETTLE)
		_save("art/pair_%d" % i)
		cust.queue_free()
		await _wait(4)
	await _clear_hands()


## The main menu's gold-leaf wordmark, LOGO_SCALE x, on transparency; then the same
## lockup on the hanging walnut shop sign (with and without the tagline, chains rising
## to the top of the image), and a long tape measure — the capsule dressing.
func _art_logo() -> void:
	var mark: Control = load(WORDMARK_PATH).new()
	mark.sounds = false
	mark.size = Vector2(360, 178)
	await _render_badge(mark, Vector2(360, 178), "logo")
	for tagline: bool in [true, false]:
		var sign_name := "sign_%s" % ("full" if tagline else "name")
		await _render_badge(_hanging_sign(tagline), Vector2(480, 260 + SIGN_CHAIN), sign_name)
	var tape: Control = load("res://ui/craft/tape_measure.gd").new()
	tape.max_m = 16.0
	tape.value = -1.0
	tape.size = Vector2(1600, 56)
	await _render_badge(tape, tape.size, "tape")


## The shop's fascia sign as the main menu hangs it: walnut board, gold lettering.
func _hanging_sign(tagline: bool) -> Control:
	var holder := Control.new()
	var sign := PanelContainer.new()
	sign.position = Vector2(20, SIGN_CHAIN)
	holder.add_child(sign)
	var board: Control = load("res://ui/craft/sign_board.gd").dress(sign)
	board.plate = false
	board.set_process(false)  # no sway: a still
	var mark: Control = load(WORDMARK_PATH).new()
	mark.sounds = false
	mark.tagline = tagline
	mark.custom_minimum_size = Vector2(360, 178 if tagline else 150)
	sign.add_child(mark)
	return holder


## Draw `node` (logical `size`) at LOGO_SCALE x on transparency into art/<name>.png,
## trimmed to what was drawn.
func _render_badge(node: Control, size: Vector2, name: String) -> void:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(size * LOGO_SCALE)
	vp.oversampling_override = LOGO_SCALE
	vp.canvas_transform = Transform2D().scaled(Vector2.ONE * LOGO_SCALE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(node)
	root.add_child(vp)
	await _wait(8)
	var image := vp.get_texture().get_image()
	var used := image.get_used_rect()
	if name != "logo" and used.size.x > 0:
		image = image.get_region(used)
	image.save_png("%s/art/%s.png" % [OUT_DIR, name])
	print("saved %s (%dx%d)" % [name, image.get_width(), image.get_height()])
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


## The fitting mirror at game speed, played like a session: whole suits go on the client
## one after another and each is put to them the way a player asks (E: "Ask"). Two are
## turned down for different reasons, the third gets the yes and the quote goes green.
func _clip_mirror() -> void:
	if _want("clip_mirror"):
		await _record_mirror("mirror", "")


## The same session with a cast member as the client: his own name, face and voice.
func _clip_mirror_cast() -> void:
	if _want("clip_mirror_dimmock"):
		await _record_mirror("mirror_dimmock", CLIP_MIRROR_CAST)


## Record the mirror session into clips/`clip`. `cast_name` names the client (a FaceCast
## member) through the shop's own naming and dressing; "" keeps the seeded walk-in.
func _record_mirror(clip: String, cast_name: String) -> void:
	await _clear_customers()
	_place_player(_by_mirror(), PI * 0.5)
	_cm._rng.seed = CLIP_MIRROR_SEED  # the same client every run
	var cust: Node = await _seat_customer()
	if cast_name != "":
		var pref_script: GDScript = load("res://data/scripts/customer_preference.gd")
		_cm._rng.seed = CLIP_MIRROR_SEED
		cust.preference = pref_script.random_pref(_cm._rng, cast_name)
	# The walk-in's rolls between the name and the look vary run to run: dress them
	# again from the seed so the face is the same every take too.
	_cm._rng.seed = CLIP_MIRROR_SEED
	_cm._dress(cust)
	_set_mirror_brief(cust.preference)
	_ui.open_suit_builder(_mirror, _player)
	var builder: Node = _ui.suit_builder
	await _wait(60)
	_start_rec(clip)
	await _seconds(0.4)
	for i in CLIP_MIRROR_SUITS.size():
		_try_on(builder, CUTE_SUITS[CLIP_MIRROR_SUITS[i]]["parts"])
		await _seconds(CLIP_TRY)
		builder._confirm()  # the player's first E at the mirror: ask
		print("%s: %s -> %s" % [clip, CLIP_MIRROR_SUITS[i], "yes" if builder._awaiting else "no"])
		var last: bool = i == CLIP_MIRROR_SUITS.size() - 1
		await _seconds(CLIP_SOLD if last else CLIP_ANSWER)
	_stop_rec()
	_ui.close_all_menus()
	_rig.unfocus()
	await _clear_customers()


## The clip's brief, set so every answer is the same each run: the CLIP_MIRROR_BRIEF
## look's occasion and style, no stated taste, and the one quiet dislike.
func _set_mirror_brief(pref: Resource) -> void:
	var brief: Array = CUTE_SUITS[CLIP_MIRROR_BRIEF]["brief"]
	pref.occasion = brief[0]
	pref.style = brief[1]
	pref.budget = CUTE_BUDGET
	pref.rush = false
	pref.picky = false
	pref.likes_color = -1
	pref.dislikes_color = -1
	pref.town_worn = 0
	pref.owned_suits = []
	pref.quiet_dislike = CLIP_MIRROR_DISLIKE.duplicate()
	pref.quiet_known = false


## Put a whole CUTE_SUITS look on the client at once, as a fresh design: the last answer
## goes away and the trousers' link follows whether they match the jacket.
func _try_on(builder: Node, parts: Array) -> void:
	builder._end_reaction()
	builder._awaiting = false
	var jacket: Array = parts[0]
	var pants: Array = parts[2]
	builder._linked = jacket[0] == pants[0] and jacket[1] == pants[1] and jacket[2] == pants[2]
	_dress_design(builder, parts)


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

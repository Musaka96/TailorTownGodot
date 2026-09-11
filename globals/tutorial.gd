extends Node

## Autoloaded as "Tutorial". A guided first-run walkthrough: on a NEW game the player is
## offered the tutorial; if they accept, it steps them through ordering cloth, the make
## pipeline (shelf → worktable → sewing → rack), a customer fitting, and a wrap-up on orders,
## reputation, the handbook and upgrades. Each step shows an instruction bubble and a cute
## hand pointer aimed at the relevant station (projected from 3D) or UI, and completes when
## the matching gameplay event fires. It watches EventBus, so it needs no hooks in stations.

## Point the hand at roughly the upper body of a station (metres above its origin).
const POINT_Y := 1.0
const HAND := "👆"

## The tutorial customer's fixed, premade brief — the archetypal navy business suit, so a
## first-timer (who hasn't read the handbook) is walked through a real, sensible combination:
## a matched jacket + trousers plus a light shirt.
const TUT_OCCASION := Enums.Occasion.BUSINESS
const TUT_STYLE := Enums.Style.CLASSIC
const TUT_BUDGET := 1000
## The tutorial shirt colour — a pale shirting (white) so the shirt reads light, not the
## suit cloth. Shirtings are indices 10..17; 10 is white.
const TUT_SHIRT_COLOR := 10

const T_ORDER := (
	"Welcome to the shop! Let's make your first suit.\n\nGo to the PHONE and order a bolt of "
	+ "cloth: Order Textiles, call a supplier, pick a fabric, then Order."
)
const T_STORE := (
	"Your bolt was delivered by the phone. Pick it up with E, carry it to a SHELF and press "
	+ "E to store it."
)
const T_CUTBOLT := (
	"Empty-handed at the shelf, press E to browse it. Use A/D to set the length, then press "
	+ "F to CUT a piece of fabric off the bolt."
)
const T_WORKTABLE := (
	"Carry the fabric to the WORKTABLE. Configure the part and cut it in the mini-game to "
	+ "shape a garment piece."
)
const T_SEW := "Take the cut piece to the SEWING MACHINE and sew it together in the mini-game."
const T_HANG := (
	"Great work! Hang the finished piece on the CLOTHING RACK to store it " + "until it's needed."
)
const T_GREET := (
	"A customer will walk in. Walk up to them, greet them (E) and seat them at the MIRROR "
	+ "for a fitting."
)
const T_ORDERS := (
	"Order placed! The customer leaves and returns to collect once every part is made. "
	+ "Parts you hang on the rack are matched to open orders automatically, paid on collection."
)
const T_REP := (
	"Fulfilling orders well raises your REPUTATION (the stars, top-left). Higher reputation "
	+ "unlocks premium textile suppliers and new shop upgrades on the phone."
)
const T_HANDBOOK := (
	"Last thing: the HANDBOOK on the bookshelf explains dress codes and styles, and the "
	+ "phone's Shop Upgrades buy faster tools and more storage. That's it — enjoy the shop!"
)
const T_DESIGN := (
	"Match the OCCASION and STYLE — pick the right fabric, colour, pattern and cut for each "
	+ "part (the panel flags what fits), then confirm with E."
)
const T_PROMPT := (
	"New here? Take a quick guided tour of the shop — order cloth, make a suit, and serve "
	+ "your first customer."
)

# Each step: text; `point` = a node name in the current scene to aim the hand at ("" = none);
# `event` = the EventBus signal that completes it ("" = an info step advanced with Next);
# `match` = for item_stored, the station node-name prefix that counts.
const STEPS := [
	{"id": "order", "text": T_ORDER, "point": "Phone", "event": "order_placed"},
	{"id": "store", "text": T_STORE, "point": "Shelf", "event": "item_stored", "match": "Shelf"},
	{"id": "cut_bolt", "text": T_CUTBOLT, "point": "Shelf", "event": "cloth_cut"},
	{"id": "worktable", "text": T_WORKTABLE, "point": "Worktable", "event": "piece_cut"},
	{"id": "sew", "text": T_SEW, "point": "SewingMachine", "event": "piece_sewn"},
	{
		"id": "hang",
		"text": T_HANG,
		"point": "ClothingRack",
		"event": "item_stored",
		"match": "ClothingRack",
	},
	{"id": "greet", "text": T_GREET, "point": "", "event": "customer_seated", "customer": true},
	{"id": "design", "text": "", "point": "Mirror", "event": "design_confirmed"},
	{"id": "orders", "text": T_ORDERS, "point": "", "event": ""},
	{"id": "reputation", "text": T_REP, "point": "", "event": ""},
	{"id": "handbook", "text": T_HANDBOOK, "point": "Bookshelf", "event": ""},
]

# Station node-name prefixes gated during a make step (only the step's own is usable).
const STATIONS := [
	"Phone",
	"Shelf",
	"Worktable",
	"SewingMachine",
	"ClothingRack",
	"Mirror",
	"Bookshelf",
	"Mannequin",
	"TrashCan",
]

var _active := false
var _step := 0
var _customer: Node = null
var _time := 0.0
var _on_choose := Callable()

## The premade suit the tutorial customer wants — all three parts the same simple cloth,
## computed once at start so the order + design steps can spell out exactly what to make.
var _recipe: Dictionary = {}
## The bolt delivered by the phone this run, so the store step can point right at it.
var _delivered_roll: Node = null

var _layer: CanvasLayer
var _bubble: PanelContainer
var _bubble_docked := false
var _text: Label
var _hand: Label
var _next: Button
var _skip: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.order_placed.connect(func(_m, _l, _c): _try("order_placed"))
	EventBus.item_stored.connect(func(_i, station): _try("item_stored", station))
	EventBus.cloth_cut.connect(func(_p, _r): _try("cloth_cut"))
	EventBus.piece_cut.connect(func(_p): _try("piece_cut"))
	EventBus.piece_sewn.connect(func(_p): _try("piece_sewn"))
	EventBus.customer_seated.connect(_on_customer_seated)
	EventBus.customer_waiting.connect(func(cust): _customer = cust)
	EventBus.design_confirmed.connect(func(_d): _try("design_confirmed"))
	EventBus.order_delivered.connect(func(roll): _delivered_roll = roll)


## Offer the tutorial (called on a new game). Shows a yes/no prompt; `on_choose` runs once
## the player picks either way (so the caller can start the day only after the choice).
func offer(on_choose := Callable()) -> void:
	if _active:
		return
	_on_choose = on_choose
	_build()
	_show_prompt()


func is_active() -> bool:
	return _active


## True while a make step is running and `target` is a DIFFERENT station than this step's —
## used to lock the player to the current step's station (items/customer are never blocked).
func blocks(target: Node) -> bool:
	if not _active or target == null:
		return false
	var step: Dictionary = STEPS[_step]
	if step.get("event", "") == "":
		return false  # info steps: roam freely
	var nm := str(target.name)
	var is_station := false
	for s: String in STATIONS:
		if nm.begins_with(s):
			is_station = true
			break
	if not is_station:
		return false
	# Allow the current step's station.
	var want: String = step.get("point", "")
	if want != "" and nm.begins_with(want):
		return false
	# Also allow the PREVIOUS step's station: the piece the player just made (cut, sewn) sits
	# on it, and they must be able to pick it back up to carry it to the next station.
	var prev: String = str(STEPS[_step - 1].get("point", "")) if _step > 0 else ""
	if prev != "" and nm.begins_with(prev):
		return false
	return true


func _on_customer_seated(cust: Node) -> void:
	_customer = cust
	_try("customer_seated")


func _choose_done() -> void:
	if _on_choose.is_valid():
		_on_choose.call()
		_on_choose = Callable()


# --- Flow ------------------------------------------------------------------


func _start() -> void:
	_active = true
	_step = 0
	_recipe = _compute_recipe()  # the exact suit we'll walk the player through making
	# The tutorial is a commitment — no skipping once it's begun (only the prompt offers out).
	if _skip != null:
		_skip.visible = false
	# Fold the morning paper away if it's up — the tutorial takes the stage.
	if UI != null and UI.newspaper != null and UI.newspaper.has_method("close"):
		UI.newspaper.close()
	# Unpause so the player can move/interact, but DON'T start the day — no customers or
	# passing time during the tutorial. Stations work via the _shop_closed() exception; the
	# real day begins in _finish().
	get_tree().paused = false
	_apply_step()


func _finish() -> void:
	_active = false
	_choose_done()  # NOW begin the real day (on completion, or an immediate skip)
	if _layer != null:
		_layer.visible = false


func _try(event: String, station: Node = null) -> void:
	if not _active:
		return
	var step: Dictionary = STEPS[_step]
	if step.get("event", "") != event:
		return
	if event == "item_stored":
		var want: String = step.get("match", "")
		if want != "" and (station == null or not str(station.name).begins_with(want)):
			return
	_advance()


func _advance() -> void:
	_step += 1
	if _step >= STEPS.size():
		_finish()
	else:
		_apply_step()


func _apply_step() -> void:
	var step: Dictionary = STEPS[_step]
	if step.get("id", "") == "greet" and _customer == null:
		_spawn_customer()
	_text.text = _step_text(step)
	# Info steps (no gameplay event) advance with the Next button.
	_next.visible = step.get("event", "") == ""
	if _hand != null:
		_hand.visible = step.get("point", "") != "" or step.get("customer", false)


## Poof a customer into the shop for the fitting step (via the customer manager).
func _spawn_customer() -> void:
	var mgr := get_tree().get_first_node_in_group("customer_manager")
	if mgr != null and mgr.has_method("spawn_tutorial_customer"):
		mgr.spawn_tutorial_customer()


## The step's text. The order and design steps splice in the premade recipe so a
## first-timer is told exactly what cloth to buy and what to make (no handbook needed yet).
func _step_text(step: Dictionary) -> String:
	match str(step.get("id", "")):
		"order":
			return (
				"Welcome to the shop! Let's learn the ropes.\n\n"
				+ "Go to the PHONE → Order Textiles → pick a supplier, then order a bolt of cloth "
				+ "— any fabric, colour and pattern you like (set them with A/D), then Order."
			)
		"design":
			return (
				"This customer wants a %s suit. Design one that fits — " % _brief_desc()
				+ "you don't need the cloth yet, you'll make it after:\n\n"
				+ "•  Jacket:  %s\n" % _part_desc(Enums.GarmentType.JACKET)
				+ "•  Pants:  %s  (match the jacket)\n" % _part_desc(Enums.GarmentType.PANTS)
				+ "•  Shirt:  %s  (shirts are a light cloth)\n\n" % _part_desc(Enums.GarmentType.SHIRT)
				+ "Pick a part with W/S, set its Fabric/Colour/Pattern with A/D, then press E."
			)
	return str(step.get("text", ""))


# --- Premade recipe --------------------------------------------------------


## A CustomerPreference for the tutorial's fixed brief (used by the CustomerManager when it
## poofs the fitting customer in, so the brief matches the recipe we teach).
func tutorial_pref() -> CustomerPreference:
	var p := CustomerPreference.new()
	p.occasion = TUT_OCCASION
	p.style = TUT_STYLE
	p.budget = TUT_BUDGET
	return p


## The brief label, e.g. "Party · Classic".
func _brief_desc() -> String:
	return "%s · %s" % [Enums.occasion_name(TUT_OCCASION), Enums.style_name(TUT_STYLE)]


## One recipe part described for the bubble, e.g. "Navy · Worsted Wool · Solid".
func _part_desc(garment_type: int) -> String:
	var part: Dictionary = _recipe.get(garment_type, {})
	if part.is_empty():
		return "—"
	return "%s · %s · %s" % [
		MaterialFactory.color_name(int(part.get("color", 0))),
		Enums.fabric_name(int(part.get("fabric", 0))),
		Enums.pattern_name(int(part.get("pattern", 0))),
	]


## Build the fixed premade suit for the tutorial brief: a matched jacket + trousers in the
## brief's cloth, plus a proper light shirt (white cotton) — a real, sensible combination.
func _compute_recipe() -> Dictionary:
	var fabric := 0
	var color := 0
	var pattern := int(Enums.Pattern.SOLID)
	var dc = Catalog.dress_code if Catalog != null else null
	var rule = dc.rule_for(TUT_OCCASION, TUT_STYLE) if dc != null else null
	if rule != null:
		if not rule.allowed_fabrics.is_empty():
			fabric = int(rule.allowed_fabrics[0])
		if not rule.allowed_colors.is_empty():
			color = int(rule.allowed_colors[0])
		pattern = _pick_pattern(rule)
	var suit_cloth := {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	# Shirts are a light cloth in a pale colour — white cotton is the safe classic.
	var shirt := {
		"fabric": int(Enums.Fabric.COTTON),
		"color": TUT_SHIRT_COLOR,
		"pattern": int(Enums.Pattern.SOLID),
		"style_idx": 0,
	}
	return {
		Enums.GarmentType.JACKET: suit_cloth.duplicate(),
		Enums.GarmentType.PANTS: suit_cloth.duplicate(),
		Enums.GarmentType.SHIRT: shirt,
	}


## A pattern the jacket rule accepts (a bold one if the rule demands it, else plain).
func _pick_pattern(rule) -> int:
	if rule.require_pattern:
		for p in rule.allowed_patterns:
			if int(p) != Enums.Pattern.SOLID:
				return int(p)
	if rule.allowed_patterns.is_empty() or Enums.Pattern.SOLID in rule.allowed_patterns:
		return int(Enums.Pattern.SOLID)
	return int(rule.allowed_patterns[0])


## The item the player is currently carrying (for the store-step pointer), or null.
func _player_held() -> Node:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.get("carry") != null:
		return p.carry.get_held()
	return null


# --- Pointer ---------------------------------------------------------------


func _process(delta: float) -> void:
	if not _active:
		return
	_position_bubble()
	if _hand == null or not _hand.visible:
		return
	_time += delta
	var pos := _point_screen()
	if pos.x < 0.0:
		_hand.visible = false
		return
	_hand.visible = true
	# Sit just below the target and bob up toward it.
	_hand.position = pos + Vector2(-16, 24 + sin(_time * 6.0) * 6.0)


## True while any full-screen station menu is on screen (so the bubble should step aside).
func _menu_open() -> bool:
	if UI == null:
		return false
	for m in [
		UI.phone_order,
		UI.worktable_screen,
		UI.sewing_screen,
		UI.suit_builder,
		UI.shelf_menu,
		UI.customer_request,
		UI.handbook,
		UI.rack_menu,
		UI.orders_menu,
	]:
		if m != null and m.visible:
			return true
	return false


## Tuck the bubble into the bottom-left corner (narrower) while a station menu is open — the
## menus sit centre-screen, so the corner keeps the tutorial text clear of both the menu and
## the hand pointing into it. With no menu, use the roomy bottom-centre placement.
func _position_bubble() -> void:
	if _bubble == null:
		return
	var docked := _menu_open()
	if docked == _bubble_docked:
		return
	_bubble_docked = docked
	if docked:
		_bubble.anchor_left = 0.0
		_bubble.anchor_right = 0.0
		_bubble.grow_horizontal = Control.GROW_DIRECTION_END
		_bubble.offset_left = 24
		_bubble.offset_bottom = -24
		_bubble.custom_minimum_size = Vector2(360, 0)
		_text.custom_minimum_size = Vector2(320, 0)
	else:
		_bubble.anchor_left = 0.5
		_bubble.anchor_right = 0.5
		_bubble.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_bubble.offset_left = 0
		_bubble.offset_bottom = -84
		_bubble.custom_minimum_size = Vector2(680, 0)
		_text.custom_minimum_size = Vector2(640, 0)


## Screen position of the current step's target, or (-1,-1) if not shown.
func _point_screen() -> Vector2:
	var step: Dictionary = STEPS[_step]
	# While the phone menu is open on the order step, point at the choice to make in it.
	if step.get("id", "") == "order" and UI != null and UI.phone_order != null:
		if UI.phone_order.visible and UI.phone_order.has_method("tutorial_hint_point"):
			var p: Vector2 = UI.phone_order.tutorial_hint_point()
			if p.x >= 0.0:
				return p
	# Store step: point at the bolt the phone just delivered so the player finds it, then
	# (once it's in hand) fall through to the SHELF where it goes.
	if step.get("id", "") == "store" and _delivered_roll != null:
		if is_instance_valid(_delivered_roll) and _delivered_roll != _player_held():
			return _project(_delivered_roll)
	if step.get("customer", false):
		return _project(_customer)
	var name: String = step.get("point", "")
	if name == "":
		return Vector2(-1, -1)
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	return _project(scene.find_child(name, true, false) as Node3D)


## Project a Node3D's upper body to the screen; (-1,-1) if missing or behind the camera.
func _project(node: Node3D) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if node == null or cam == null or not is_instance_valid(node):
		return Vector2(-1, -1)
	var world := node.global_position + Vector3(0, POINT_Y, 0)
	if cam.is_position_behind(world):
		return Vector2(-1, -1)
	return cam.unproject_position(world)


# --- UI --------------------------------------------------------------------


func _build() -> void:
	if _layer != null:
		_layer.visible = true
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128  # above the HUD and open menus (e.g. the phone) so the hand shows on top
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)

	_hand = Label.new()
	_hand.text = HAND
	# Fredoka has no emoji glyph — use a system font that carries the colour hand emoji.
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(
		["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"]
	)
	emoji.allow_system_fallback = true
	_hand.add_theme_font_override("font", emoji)
	_hand.add_theme_font_size_override("font_size", 44)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.visible = false
	root.add_child(_hand)

	_build_bubble(root)


func _build_bubble(root: Control) -> void:
	var center := Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	# Anchor the bubble to the BOTTOM so it never covers the hand pointing at a station.
	_bubble = PanelContainer.new()
	_bubble.anchor_left = 0.5
	_bubble.anchor_right = 0.5
	_bubble.anchor_top = 1.0
	_bubble.anchor_bottom = 1.0
	_bubble.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bubble.offset_bottom = -84
	_bubble.custom_minimum_size = Vector2(680, 0)
	_bubble.add_theme_stylebox_override("panel", Style.skin_base(Style.BRASS, Style.CREAM, 16))
	center.add_child(_bubble)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	_bubble.add_child(box)
	var title := Style.header("Tutorial", Style.ACC_ORDER)
	box.add_child(title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(640, 0)
	_text.add_theme_color_override("font_color", Style.INK)
	_text.add_theme_font_size_override("font_size", 16)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", Style.S2)
	box.add_child(row)
	_next = MenuKit.button("Next  ▶", _advance)
	_next.custom_minimum_size = Vector2(120, 38)
	row.add_child(_next)
	# The decline button, shown ONLY at the opening prompt. Once the tutorial begins it is
	# hidden (see _start) — you can't bail out mid-way any more.
	_skip = MenuKit.button("No thanks", _finish)
	_skip.custom_minimum_size = Vector2(140, 38)
	_skip.visible = false
	row.add_child(_skip)


func _show_prompt() -> void:
	_hand.visible = false
	_text.text = T_PROMPT
	_next.visible = true
	_next.text = "Yes, show me"
	if _skip != null:
		_skip.visible = true
		_skip.text = "No thanks"
	# Rewire Next to start (once).
	for c in _next.pressed.get_connections():
		_next.pressed.disconnect(c["callable"])
	_next.pressed.connect(_start_from_prompt)


func _start_from_prompt() -> void:
	for c in _next.pressed.get_connections():
		_next.pressed.disconnect(c["callable"])
	_next.text = "Next  ▶"
	_next.pressed.connect(_advance)
	_start()

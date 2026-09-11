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

const T_ORDER := (
	"Welcome to the shop! Let's make your first suit.\n\nGo to the PHONE and order a bolt of "
	+ "cloth: Order Textiles, call a supplier, pick a fabric, then Order."
)
const T_STORE := (
	"Your bolt was delivered by the phone. Pick it up with E, carry it to a SHELF and press "
	+ "E to store it."
)
const T_CUTBOLT := (
	"Empty-handed at the shelf, press E to browse it, then CUT a length off the bolt to get "
	+ "a piece of fabric."
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

var _layer: CanvasLayer
var _bubble: PanelContainer
var _text: Label
var _hand: Label
var _next: Button


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
	var want: String = step.get("point", "")
	return want == "" or not nm.begins_with(want)


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
	# Fold the morning paper away if it's up — the tutorial takes the stage.
	if UI != null and UI.newspaper != null and UI.newspaper.has_method("close"):
		UI.newspaper.close()
	_choose_done()  # the player chose the tutorial — let the day begin
	_apply_step()


func _finish() -> void:
	_active = false
	_choose_done()  # skipped before starting: still begin the day
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


## The step's text, with the customer brief spliced into the design step.
func _step_text(step: Dictionary) -> String:
	if step.get("id", "") != "design":
		return str(step.get("text", ""))
	var pref = _customer.get("preference") if _customer != null else null
	if pref == null:
		return "Design a suit at the mirror to match the customer, then press E to confirm."
	return "This customer wants: %s.\n\n%s" % [pref.describe(), T_DESIGN]


# --- Pointer ---------------------------------------------------------------


func _process(delta: float) -> void:
	if not _active or _hand == null or not _hand.visible:
		return
	_time += delta
	var pos := _point_screen()
	if pos.x < 0.0:
		_hand.visible = false
		return
	_hand.visible = true
	# Sit just below the target and bob up toward it.
	_hand.position = pos + Vector2(-16, 24 + sin(_time * 6.0) * 6.0)


## Screen position of the current step's target, or (-1,-1) if not shown.
func _point_screen() -> Vector2:
	var step: Dictionary = STEPS[_step]
	# While the phone menu is open on the order step, point at the choice to make in it.
	if step.get("id", "") == "order" and UI != null and UI.phone_order != null:
		if UI.phone_order.visible and UI.phone_order.has_method("tutorial_hint_point"):
			var p: Vector2 = UI.phone_order.tutorial_hint_point()
			if p.x >= 0.0:
				return p
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
	_layer.layer = 60
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
	var skip := MenuKit.button("Skip tutorial", _finish)
	skip.custom_minimum_size = Vector2(140, 38)
	row.add_child(skip)


func _show_prompt() -> void:
	_hand.visible = false
	_text.text = T_PROMPT
	_next.visible = true
	_next.text = "Yes, show me"
	# Rewire Next to start (once), and add a "No thanks" the first time.
	for c in _next.pressed.get_connections():
		_next.pressed.disconnect(c["callable"])
	_next.pressed.connect(_start_from_prompt)


func _start_from_prompt() -> void:
	for c in _next.pressed.get_connections():
		_next.pressed.disconnect(c["callable"])
	_next.text = "Next  ▶"
	_next.pressed.connect(_advance)
	_start()

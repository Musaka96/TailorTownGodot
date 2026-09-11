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
	{"id": "greet", "text": T_GREET, "point": "Mirror", "event": "customer_seated"},
	{"id": "design", "text": "", "point": "Mirror", "event": "design_confirmed"},
	{"id": "orders", "text": T_ORDERS, "point": "", "event": ""},
	{"id": "reputation", "text": T_REP, "point": "", "event": ""},
	{"id": "handbook", "text": T_HANDBOOK, "point": "Bookshelf", "event": ""},
]

var _active := false
var _step := 0
var _customer: Node = null
var _time := 0.0

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
	EventBus.design_confirmed.connect(func(_d): _try("design_confirmed"))


## Offer the tutorial (called on a new game). Shows a small yes/no prompt.
func offer() -> void:
	if _active:
		return
	_build()
	_show_prompt()


func _on_customer_seated(cust: Node) -> void:
	_customer = cust
	_try("customer_seated")


# --- Flow ------------------------------------------------------------------


func _start() -> void:
	_active = true
	_step = 0
	_next.get_parent().get_parent().visible = true  # the bubble
	_apply_step()


func _finish() -> void:
	_active = false
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
	_text.text = _step_text(step)
	# Info steps (no gameplay event) advance with the Next button.
	_next.visible = step.get("event", "") == ""
	if _hand != null:
		_hand.visible = step.get("point", "") != ""


## The step's text, with the customer brief spliced into the design step.
func _step_text(step: Dictionary) -> String:
	if step.get("id", "") != "design":
		return str(step.get("text", ""))
	var pref = _customer.get("preference") if _customer != null else null
	if pref == null:
		return "Design a suit at the mirror to match the customer, then press E to confirm."
	return "This customer wants: %s.\n\n%s" % [pref.summary(), T_DESIGN]


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


## Screen position of the current step's target, or (-1,-1) if not visible.
func _point_screen() -> Vector2:
	var name: String = STEPS[_step].get("point", "")
	if name == "":
		return Vector2(-1, -1)
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var cam := get_viewport().get_camera_3d()
	if scene == null or cam == null:
		return Vector2(-1, -1)
	var node := scene.find_child(name, true, false) as Node3D
	if node == null:
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
	emoji.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
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

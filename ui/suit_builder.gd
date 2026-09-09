extends Control

## The mirror's suit builder. A side panel (keeps the customer visible) where you
## design each part of the suit. Selecting a part glides the camera to zoom onto
## it; "Overview" frames the whole customer. E confirms the design.

enum Row { PART, FABRIC, COLOR, PATTERN, STYLE }
const ROW_NAME := {
	Row.PART: "Part",
	Row.FABRIC: "Fabric",
	Row.COLOR: "Colour",
	Row.PATTERN: "Pattern",
	Row.STYLE: "Style",
}
# Display order of the parts.
const PARTS := [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS]
# Data fallbacks when there's no seated customer (not UI styling).
const _SKIN_FALLBACK := Color(0.87, 0.72, 0.60)  # ui-check-ignore: skin data
const _HAIR_FALLBACK := Color(0.14, 0.11, 0.09)  # ui-check-ignore: hair data

var _mirror = null
var _actor = null
var _customer = null
var _pref = null  # CustomerPreference when fitting a real customer, else null
var _awaiting := false  # customer loved it; next E finalises the order
var _rig = null
var _part_sel := -1  # -1 = overview, else index into PARTS
var _row := 0
var _status := ""
var _design := {}  # GarmentType -> { fabric, color, pattern, style_idx }
var _swatch: MaterialSwatch
var _name_label: Label
var _sub_label: Label
var _brief_label: Label
var _hint_bar: HBoxContainer
var _stock_badge: HBoxContainer
var _stock_dot: Panel
var _stock_label: Label
var _decor_built := false

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _preview: HBoxContainer = $Panel/Margin/Box/Preview
@onready var _rows: VBoxContainer = $Panel/Margin/Box/Rows
@onready var _hint: Label = $Panel/Margin/Box/Hint


func _ready() -> void:
	_build_preview()


func open(mirror, actor) -> void:
	_mirror = mirror
	_actor = actor
	_customer = mirror.customer
	_pref = _customer.get("preference") if _customer != null else null
	_awaiting = false
	_rig = get_tree().get_first_node_in_group("camera_rig")
	_part_sel = -1
	_row = 0
	_status = ""
	_design = {}
	for t in PARTS:
		_design[t] = {"fabric": 0, "color": 0, "pattern": 0, "style_idx": 0}
	GameState.input_locked = true
	visible = true
	_style()
	_update_camera()
	_apply_to_customer()
	_refresh()


func close() -> void:
	visible = false
	GameState.input_locked = false
	if _rig != null:
		_rig.unfocus()
	if _customer != null and _customer.has_method("react"):
		_customer.react(Customer.REACT_NEUTRAL)
	_mirror = null


func _build_preview() -> void:
	_swatch = MaterialSwatch.new()
	_swatch.swatch_size = 96
	_preview.add_child(_swatch)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview.add_child(info)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	info.add_child(_name_label)
	_sub_label = Label.new()
	_sub_label.add_theme_font_size_override("font_size", 14)
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_sub_label)
	# A small "do I already have this cloth?" badge (dot + word) under the sub-line.
	_stock_badge = HBoxContainer.new()
	_stock_badge.add_theme_constant_override("separation", Style.S1 + 2)
	_stock_dot = Panel.new()
	_stock_dot.custom_minimum_size = Vector2(12, 12)
	_stock_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stock_badge.add_child(_stock_dot)
	_stock_label = Label.new()
	_stock_label.add_theme_font_size_override("font_size", 13)
	_stock_badge.add_child(_stock_label)
	info.add_child(_stock_badge)


func _style() -> void:
	# Fitting-room skin (arched, brass). Side panel — the customer stays visible.
	_panel.custom_minimum_size = Vector2(440, 560)
	Style.apply_skin(_panel, Style.MenuSkin.MIRROR)
	_preview.add_theme_constant_override("separation", Style.S3)
	_title.add_theme_font_override("font", Style.bold_font())
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Style.ACC_MIRROR.darkened(0.2))
	_name_label.add_theme_color_override("font_color", Style.INK)
	_sub_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_rows.add_theme_constant_override("separation", Style.S1)
	_rows.custom_minimum_size = Vector2(0, 236)
	_build_decor_once()


## The scene Hint label is retired for an informational brief/quote line plus a
## rebuilt key-cap bar (the keys change with mode/debug). Skin applied in _style().
func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	_hint.visible = false
	var box := _hint.get_parent()
	_brief_label = Label.new()
	_brief_label.add_theme_font_size_override("font_size", 14)
	_brief_label.add_theme_color_override("font_color", Style.INK)
	_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_brief_label)
	_hint_bar = HBoxContainer.new()
	box.add_child(_hint_bar)


# --- State -----------------------------------------------------------------


func _type() -> int:
	return PARTS[_part_sel] if _part_sel >= 0 else -1


func _cfg() -> Dictionary:
	return _design[_type()] if _part_sel >= 0 else {}


func _active_rows() -> Array:
	if _part_sel < 0:
		return [Row.PART]
	return [Row.PART, Row.FABRIC, Row.COLOR, Row.PATTERN, Row.STYLE]


func _material() -> MaterialType:
	var t := _type() if _part_sel >= 0 else int(Enums.GarmentType.JACKET)
	var c: Dictionary = _design[t]
	return MaterialFactory.make(c["fabric"], c["pattern"], c["color"], 1.0)


func _value_text(row: int) -> String:
	if row == Row.PART:
		return "Overview" if _part_sel < 0 else Enums.garment_type_name(_type())
	var c := _cfg()
	if row == Row.FABRIC:
		return Enums.fabric_name(c["fabric"])
	if row == Row.COLOR:
		return MaterialFactory.color_name(c["color"])
	if row == Row.PATTERN:
		return Enums.pattern_name(c["pattern"])
	return Enums.styles_for(_type())[c["style_idx"]]


# --- Camera ----------------------------------------------------------------


func _update_camera() -> void:
	if _rig == null or _customer == null:
		return
	var front: Vector3 = _customer.facing()
	if _part_sel < 0:
		var c: Vector3 = _customer.center()
		_rig.focus(c + front * 3.2 + Vector3(0, 0.7, 0), c)
	else:
		var p: Vector3 = _customer.part_position(_type())
		_rig.focus(p + front * 1.7 + Vector3(0, 0.2, 0), p)


# --- Rendering -------------------------------------------------------------


func _refresh() -> void:
	_title.text = ("Fitting: %s" % _pref.display_name) if _pref != null else "Suit Builder"
	var mat := _material()
	_swatch.setup(mat, mat.roll_length_m)
	if _part_sel < 0:
		_name_label.text = "Whole suit"
		_sub_label.text = "Pick a part to design and zoom in."
	else:
		_name_label.text = "%s — %s" % [Enums.garment_type_name(_type()), mat.display_name]
		_sub_label.text = (
			"%s  ·  %s" % [mat.summary(), Enums.styles_for(_type())[_cfg()["style_idx"]]]
		)
	if _pref != null:
		var quote := Pricing.suit_quote(_design)
		var over := "  (OVER)" if quote > _pref.budget else ""
		_brief_label.text = (
			"For: %s   ·   Budget $%d   ·   Quote $%d%s%s"
			% [_pref.describe(), _pref.budget, quote, over, _status]
		)
	else:
		_brief_label.text = _status.strip_edges()
	_update_stock()
	_rebuild_hint_bar()

	var rows := _active_rows()
	_row = clampi(_row, 0, rows.size() - 1)
	for child in _rows.get_children():
		child.queue_free()
	for i in rows.size():
		_rows.add_child(_make_row(rows[i], i == _row))


## Rebuild the key-cap bar — the confirm verb and the debug auto-fit key vary.
func _rebuild_hint_bar() -> void:
	for child in _hint_bar.get_children():
		child.queue_free()
	var pairs := [["W/S", "Select"], ["A/D", "Change"]]
	pairs.append(["E", "Ask / confirm"] if _pref != null else ["E", "Confirm"])
	if OS.is_debug_build():
		pairs.append(["F2", "Auto-fit"])
	pairs.append(["Esc", "Close"])
	_hint_bar.add_child(Style.hint_bar(pairs))


func _make_row(row: int, selected: bool) -> Control:
	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override(
			"panel", Style.card(Style.CARD_SELECTED, 12, 3, Style.ACC_MIRROR)
		)
	else:
		card.add_theme_stylebox_override("panel", Style.card())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var name_label := Label.new()
	name_label.text = ROW_NAME[row]
	name_label.custom_minimum_size = Vector2(96, 0)
	name_label.add_theme_color_override("font_color", Style.INK_SOFT)
	name_label.add_theme_font_size_override("font_size", 17)
	hbox.add_child(name_label)
	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text = ("‹ %s ›" % _value_text(row)) if selected else _value_text(row)
	value.add_theme_color_override("font_color", Style.INK)
	value.add_theme_font_size_override("font_size", 18)
	hbox.add_child(value)
	return card


# --- Input -----------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	Sfx.ui(event)
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_move_row(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_move_row(-1)
	elif event.is_action_pressed("move_right"):
		_adjust(1)
	elif event.is_action_pressed("move_left"):
		_adjust(-1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_confirm()
	elif OS.is_debug_build() and event.is_action_pressed("debug"):
		_debug_autocomplete()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _move_row(delta: int) -> void:
	_status = ""
	var n := _active_rows().size()
	_row = (_row + delta + n) % n
	_refresh()


func _adjust(dir: int) -> void:
	_status = ""
	_awaiting = false
	var row: int = _active_rows()[_row]
	if row == Row.PART:
		_part_sel = wrapi(_part_sel + dir, -1, PARTS.size())
		_update_camera()
	else:
		var c := _cfg()
		match row:
			Row.FABRIC:
				c["fabric"] = wrapi(c["fabric"] + dir, 0, 5)
			Row.COLOR:
				c["color"] = wrapi(c["color"] + dir, 0, MaterialFactory.color_count())
			Row.PATTERN:
				c["pattern"] = wrapi(c["pattern"] + dir, 0, 9)
			Row.STYLE:
				c["style_idx"] = wrapi(c["style_idx"] + dir, 0, Enums.styles_for(_type()).size())
	_apply_to_customer()
	_refresh()


## Dress the seated customer in the current design so they change live as you edit.
func _apply_to_customer() -> void:
	if _customer == null or not _customer.has_method("wear_suit"):
		return
	(
		_customer
		. wear_suit(
			_part_material(Enums.GarmentType.JACKET),
			_part_material(Enums.GarmentType.SHIRT),
			_part_material(Enums.GarmentType.PANTS),
			int(_design[Enums.GarmentType.JACKET]["style_idx"]),
			int(_design[Enums.GarmentType.PANTS]["style_idx"]),
		)
	)


func _part_material(garment_type: int) -> MaterialType:
	var c: Dictionary = _design[garment_type]
	return MaterialFactory.make(c["fabric"], c["pattern"], c["color"], 1.0)


# --- Stock indicator -------------------------------------------------------


## Flag whether the shop already holds cloth matching the shown part's design, so
## the player knows a fitting fabric is on hand (vs. one they'd have to order).
func _update_stock() -> void:
	if _stock_dot == null:
		return
	var c: Dictionary = _design[_type()] if _part_sel >= 0 else _design[Enums.GarmentType.JACKET]
	var have := _cloth_in_stock(int(c["fabric"]), int(c["pattern"]), int(c["color"]))
	var tint: Color = Style.FOREST if have else Style.CLAY
	_stock_dot.add_theme_stylebox_override("panel", Style.bar(tint, 6))
	_stock_label.text = "In stock" if have else "Not in your shop"
	_stock_label.add_theme_color_override("font_color", tint)


## True if any non-empty roll or cut piece in the shop matches this fabric + pattern
## + colour (the three things that define a bolt of cloth).
func _cloth_in_stock(fabric: int, pattern: int, color_index: int) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var target := MaterialFactory.color_value(color_index)
	for n in scene.find_children("*", "MaterialRoll", true, false):
		var roll := n as MaterialRoll
		if roll != null and not roll.is_empty() and _mat_matches(roll.material, fabric, pattern, target):
			return true
	for n in scene.find_children("*", "FabricPiece", true, false):
		var piece := n as FabricPiece
		if piece != null and _mat_matches(piece.material, fabric, pattern, target):
			return true
	return false


func _mat_matches(mat: MaterialType, fabric: int, pattern: int, target: Color) -> bool:
	if mat == null or int(mat.fabric) != fabric or int(mat.pattern) != pattern:
		return false
	var c := mat.cloth_color
	return absf(c.r - target.r) + absf(c.g - target.g) + absf(c.b - target.b) < 0.06


func _confirm() -> void:
	# Free-design mode (no customer): just announce the design.
	if _pref == null:
		EventBus.design_confirmed.emit(_design.duplicate(true))
		_status = "     Design saved!"
		_refresh()
		return
	# First E asks the customer for their reaction — they light up or shake their head
	# for a moment, then settle back to their normal face.
	if not _awaiting:
		var reaction: Dictionary = _pref.evaluate(_design)
		var suitable: bool = reaction.get("suitable", false)
		if _customer != null and _customer.has_method("react"):
			_customer.react(Customer.REACT_LIKE if suitable else Customer.REACT_DISLIKE)
		_status = "     %s: %s" % [_pref.display_name, reaction["reason"]]
		_awaiting = suitable
		_refresh()
		return
	# Second E finalises: create the order and send the customer on their way.
	_finalize()


## Create the order for the current design and send the customer off happy.
func _finalize() -> void:
	var quote: int = Pricing.suit_quote(_design)
	var skin: Color = _customer.skin_color if _customer != null else _SKIN_FALLBACK
	var hair: int = _customer.hair_index if _customer != null else 0
	var hair_col: Color = _customer.hair_color if _customer != null else _HAIR_FALLBACK
	Orders.create_order(_pref.display_name, _design, quote, skin, hair, hair_col)
	EventBus.design_confirmed.emit(_design.duplicate(true))
	var cust = _customer
	close()
	if cust != null:
		if cust.has_method("react"):
			cust.react(Customer.REACT_ACCEPT)  # keep a happy face as they leave
		cust.finish_and_leave()


# --- Debug (F2, debug builds only) -----------------------------------------


## Instantly design a suit this customer would accept, then confirm the order.
func _debug_autocomplete() -> void:
	if _pref == null:
		EventBus.design_confirmed.emit(_design.duplicate(true))
		_status = "     Design saved! (debug)"
		_refresh()
		return
	_design = _acceptable_design()
	_apply_to_customer()
	_finalize()


## A design that satisfies this customer's dress-code brief and budget: allowed
## colour, the required/allowed pattern, and the cheapest allowed cloth.
func _acceptable_design() -> Dictionary:
	var color := 0
	var pattern := 0
	var fabric := 0
	var rule: DressRule = null
	if Catalog.dress_code != null:
		rule = Catalog.dress_code.rule_for(_pref.occasion, _pref.style)
	if rule != null:
		if not rule.allowed_colors.is_empty():
			color = int(rule.allowed_colors[0])
		fabric = _cheapest_fabric(rule.allowed_fabrics)
		if rule.require_pattern:
			for p in rule.allowed_patterns:
				if int(p) != Enums.Pattern.SOLID:
					pattern = int(p)
					break
		elif not rule.allowed_patterns.is_empty():
			pattern = int(rule.allowed_patterns[0])
	var design := {}
	for t in PARTS:
		design[t] = {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	return design


## Cheapest fabric among `allowed` (or all fabrics if unrestricted), to stay in budget.
func _cheapest_fabric(allowed: Array) -> int:
	var prices: Array = Config.data.fabric_price_per_m if Config.data != null else []
	var pool: Array = []
	if allowed != null and not allowed.is_empty():
		for f in allowed:
			pool.append(int(f))
	else:
		for i in prices.size():
			pool.append(i)
	if pool.is_empty():
		return 0
	var best: int = pool[0]
	for f in pool:
		if f < prices.size() and best < prices.size() and prices[f] < prices[best]:
			best = f
	return best

extends Control

## The phone. Opens onto a small HUB anchored up by the phone where you pick what to
## do, then drills in (Esc steps back a screen):
##  - Order Textiles -> a phonebook of suppliers you can browse (locked mills included,
##    so you can see what better cloth awaits). Choose an unlocked one to open its order
##    form (fabric / colour / pattern / length) — the supplier decides which fabrics stock.
##  - Shop Upgrades -> buy reputation-gated shop upgrades, grouped by machine.

enum Screen { HUB, SUPPLIERS, ORDER, UPGRADES }
enum ORow { FABRIC, COLOR, PATTERN, PATTERN_COLOR, LENGTH }

const PANEL_W := 520
const LENGTH_MIN := 4.0
const LENGTH_STEP := 2.0
const HUB_OPTIONS := [
	{"title": "Order Textiles", "desc": "Ring a supplier and order a bolt of cloth."},
	{"title": "Shop Upgrades", "desc": "Spend your standing on better tools and kit."},
]
const OROW_NAME := {
	ORow.FABRIC: "Fabric",
	ORow.COLOR: "Colour",
	ORow.PATTERN: "Pattern",
	ORow.PATTERN_COLOR: "Pattern Dye",
	ORow.LENGTH: "Length",
}
## Short flavour per supplier (indexes Upgrades.VENDORS).
const VENDOR_BLURB := [
	"Reliable local staples.",
	"Finer weaves and tweeds.",
	"Premium silks and mohair.",
]

var _phone = null
var _actor = null
var _screen := Screen.HUB
var _hub_sel := 0
var _vendor := 0
var _fabric := 0
var _color := 0
var _pattern := 0
var _pattern_dye := 0  # 0 = auto-contrast; else a chosen PATTERN_ACCENTS dye
var _length := 10.0
var _row := 0
var _status := ""
var _upg_ids: Array = []
var _placed := false
var _swatch: MaterialSwatch
var _contacts: VBoxContainer
var _name_label: Label
var _summary_label: Label
var _price_label: Label
var _hint_bar: Control

@onready var _panel: PanelContainer = $Center/Panel
@onready var _dim: ColorRect = $Dim
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _money: Label = $Center/Panel/Margin/Box/Money
@onready var _preview: HBoxContainer = $Center/Panel/Margin/Box/Preview
@onready var _rows: VBoxContainer = $Center/Panel/Margin/Box/Rows
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func _ready() -> void:
	_build_preview()
	_upg_ids = Upgrades.all_ids()


func open(phone, actor) -> void:
	_phone = phone
	_actor = actor
	_screen = Screen.HUB
	_row = 0
	_hub_sel = 0
	_status = ""
	_vendor = clampi(_vendor, 0, Upgrades.VENDORS.size() - 1)
	if _vendor_locked(_vendor):
		_vendor = 0
	_length = clampf(_length, LENGTH_MIN, Upgrades.max_roll_length())
	GameState.input_locked = true
	visible = true
	_style()
	_place_panel()
	_refresh()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_phone = null


# --- Layout ----------------------------------------------------------------


func _build_preview() -> void:
	_contacts = VBoxContainer.new()
	_contacts.custom_minimum_size = Vector2(230, 0)
	_contacts.add_theme_constant_override("separation", Style.S1)
	_preview.add_child(_contacts)

	_swatch = MaterialSwatch.new()
	_swatch.swatch_size = 96
	_preview.add_child(_swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", Style.S1)
	_preview.add_child(info)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 21)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_name_label)
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 15)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_summary_label)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 18)
	_price_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_price_label)


## Move the panel out of the centre and pin it top-right, near where the phone sits.
func _place_panel() -> void:
	if not _placed:
		_placed = true
		if _panel.get_parent() != self:
			_panel.get_parent().remove_child(_panel)
			add_child(_panel)
		_panel.anchor_left = 1.0
		_panel.anchor_right = 1.0
		_panel.anchor_top = 0.0
		_panel.anchor_bottom = 0.0
		_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.offset_left = -(PANEL_W + 28)
	_panel.offset_right = -28
	_panel.offset_top = 72
	_panel.offset_bottom = 72


func _style() -> void:
	_dim.color = Color(0, 0, 0, 0.22)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	Style.apply_skin(_panel, Style.MenuSkin.ORDER)
	_preview.add_theme_constant_override("separation", Style.S3)
	_title.add_theme_font_override("font", Style.bold_font())
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Style.ACC_ORDER.darkened(0.2))
	_money.add_theme_font_size_override("font_size", 17)
	_name_label.add_theme_color_override("font_color", Style.INK)
	_summary_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_rows.add_theme_constant_override("separation", Style.S1)
	_hint.visible = false


func _set_hint(pairs: Array) -> void:
	if _hint_bar != null:
		_hint_bar.queue_free()
	_hint_bar = Style.hint_bar(pairs)
	_hint.get_parent().add_child(_hint_bar)


# --- Rendering -------------------------------------------------------------


func _refresh() -> void:
	_money.text = "Budget:  $ %d" % GameState.money
	_money.add_theme_color_override("font_color", Style.INK)
	for child in _rows.get_children():
		child.queue_free()
	match _screen:
		Screen.HUB:
			_refresh_hub()
		Screen.SUPPLIERS:
			_refresh_suppliers()
		Screen.ORDER:
			_refresh_order()
		Screen.UPGRADES:
			_refresh_upgrades()


func _refresh_hub() -> void:
	_title.text = "Phone"
	_preview.visible = false
	_row = clampi(_row, 0, HUB_OPTIONS.size() - 1)
	_hub_sel = _row
	for i in HUB_OPTIONS.size():
		var opt: Dictionary = HUB_OPTIONS[i]
		_rows.add_child(_make_hub_card(opt["title"], opt["desc"], i == _row))
	_set_hint([["W/S", "Select"], ["E", "Open"], ["Esc", "Hang up"]])


## The supplier phonebook: browse every mill (locked ones too) and read what they stock.
func _refresh_suppliers() -> void:
	_title.text = "Suppliers"
	_preview.visible = true
	_contacts.visible = true
	_swatch.visible = false
	_row = clampi(_row, 0, Upgrades.VENDORS.size() - 1)
	_build_contacts()
	_show_vendor_detail(_row)
	_set_hint([["W/S", "Browse"], ["E", "Call"], ["Esc", "Back"]])


func _refresh_order() -> void:
	_preview.visible = true
	_contacts.visible = false
	_swatch.visible = true
	_title.text = "Order · %s" % str(Upgrades.VENDORS[_vendor]["name"])
	var rows := _order_rows()
	_row = clampi(_row, 0, rows.size() - 1)
	var mat := MaterialFactory.make(_fabric, _pattern, _color, _length, _pattern_dye)
	var cost := Pricing.roll_price(mat, _length) if mat != null else 0
	var afford := GameState.can_afford(cost)
	if mat != null:
		_swatch.setup(mat, mat.roll_length_m)
		_name_label.text = mat.display_name
		_summary_label.text = mat.summary()
	_price_label.text = "Order:  $ %d   for %.0f m%s" % [cost, _length, _status]
	_price_label.add_theme_color_override("font_color", Style.FOREST if afford else Style.CLAY)
	for i in rows.size():
		_rows.add_child(_make_cfg_row(rows[i], _row == i))
	_set_hint([["W/S", "Select"], ["A/D", "Change"], ["E", "Order"], ["Esc", "Back"]])


## Order-form rows for the current supplier. The Pattern Dye row only appears for premium
## mills that offer it, and only when a pattern (not Solid) is chosen.
func _order_rows() -> Array:
	var rows := [ORow.FABRIC, ORow.COLOR, ORow.PATTERN]
	if _vendor_dyes() and _pattern != Enums.Pattern.SOLID:
		rows.append(ORow.PATTERN_COLOR)
	rows.append(ORow.LENGTH)
	return rows


func _refresh_upgrades() -> void:
	_preview.visible = true
	_contacts.visible = false
	_swatch.visible = false
	_title.text = "Shop Upgrades"
	_row = clampi(_row, 0, _upg_ids.size() - 1)
	_show_upgrade_preview(_upg_ids[_row])
	var last_cat := ""
	for i in _upg_ids.size():
		var id: String = _upg_ids[i]
		var cat := str(Upgrades.data(id).get("category", ""))
		if cat != last_cat:
			last_cat = cat
			_rows.add_child(Style.header(cat, Style.ACC_ORDER))
		_rows.add_child(_make_upgrade_row(id, _row == i))
	_set_hint([["W/S", "Select"], ["E", "Buy"], ["Esc", "Back"]])


func _build_contacts() -> void:
	for child in _contacts.get_children():
		child.queue_free()
	_contacts.add_child(Style.header("Contacts", Style.ACC_ORDER))
	for i in Upgrades.VENDORS.size():
		_contacts.add_child(_make_contact_card(i, i == _row))


## Right-hand detail for the highlighted supplier: what they stock, and whether it's open.
func _show_vendor_detail(i: int) -> void:
	var v: Dictionary = Upgrades.VENDORS[i]
	var stars := "★".repeat(i + 1) + "☆".repeat(maxi(0, 2 - i))
	_name_label.text = "%s  %s" % [str(v["name"]), stars]
	var blurb: String = VENDOR_BLURB[i] if i < VENDOR_BLURB.size() else ""
	_summary_label.text = "%s\n%s" % [blurb, _fabrics_text(v)]
	if _vendor_locked(i):
		_price_label.text = "Locked — unlocks at %s" % _tier_name(int(v["tier"]))
		_price_label.add_theme_color_override("font_color", Style.CLAY)
	else:
		_price_label.text = "E — call this supplier"
		_price_label.add_theme_color_override("font_color", Style.FOREST)


func _fabrics_text(v: Dictionary) -> String:
	var names: Array = []
	for f in v["fabrics"]:
		names.append(Enums.fabric_name(int(f)))
	return "Stocks: %s" % ", ".join(names)


func _show_upgrade_preview(id: String) -> void:
	var d := Upgrades.data(id)
	_name_label.text = str(d.get("name", "?"))
	_summary_label.text = str(d.get("desc", ""))
	if Upgrades.has(id):
		_price_label.text = "Owned ✓%s" % _status
		_price_label.add_theme_color_override("font_color", Style.FOREST)
	elif not Upgrades.tier_met(id):
		_price_label.text = "Locked — %s%s" % [_tier_name(int(d.get("tier", 0))), _status]
		_price_label.add_theme_color_override("font_color", Style.CLAY)
	else:
		var cost := int(d.get("cost", 0))
		_price_label.text = "Buy:  $ %d%s" % [cost, _status]
		var ok := GameState.can_afford(cost)
		_price_label.add_theme_color_override("font_color", Style.FOREST if ok else Style.CLAY)


func _tier_name(t: int) -> String:
	return str(Reputation.TIERS[clampi(t, 0, Reputation.TIERS.size() - 1)]["name"])


# --- Cards -----------------------------------------------------------------


func _card_panel(selected: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var skin := (
		Style.card(Style.CARD_SELECTED, 12, 3, Style.ACC_ORDER) if selected else Style.card()
	)
	card.add_theme_stylebox_override("panel", skin)
	return card


func _make_hub_card(title: String, desc: String, selected: bool) -> Control:
	var card := _card_panel(selected)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var head := Label.new()
	head.text = ("▸  %s" % title) if selected else title
	head.add_theme_font_override("font", Style.bold_font())
	head.add_theme_font_size_override("font_size", 21)
	head.add_theme_color_override("font_color", Style.INK)
	box.add_child(head)
	var sub := Label.new()
	sub.text = desc
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Style.INK_SOFT)
	box.add_child(sub)
	return card


func _make_cfg_row(row: int, selected: bool) -> Control:
	var card := _card_panel(selected)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var name_label := Label.new()
	name_label.text = OROW_NAME[row]
	name_label.custom_minimum_size = Vector2(96, 0)
	name_label.add_theme_color_override("font_color", Style.INK_SOFT)
	name_label.add_theme_font_size_override("font_size", 17)
	hbox.add_child(name_label)
	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text = ("‹  %s  ›" % _cfg_value(row)) if selected else _cfg_value(row)
	value.add_theme_color_override("font_color", Style.INK)
	value.add_theme_font_size_override("font_size", 18)
	hbox.add_child(value)
	return card


func _cfg_value(row: int) -> String:
	match row:
		ORow.FABRIC:
			return Enums.fabric_name(_fabric)
		ORow.COLOR:
			return MaterialFactory.color_name(_color)
		ORow.PATTERN:
			return Enums.pattern_name(_pattern)
		ORow.PATTERN_COLOR:
			return MaterialFactory.pattern_accent_name(_pattern_dye)
	return "%.0f m" % _length


func _make_contact_card(i: int, selected: bool) -> Control:
	var v: Dictionary = Upgrades.VENDORS[i]
	var locked := _vendor_locked(i)
	var card := _card_panel(selected)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	card.add_child(box)
	box.add_child(_contact_title(v, i, locked, selected))
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 12)
	if locked:
		sub.text = "Unlocks at %s" % _tier_name(int(v["tier"]))
		sub.add_theme_color_override("font_color", Style.CLAY)
	else:
		sub.text = VENDOR_BLURB[i] if i < VENDOR_BLURB.size() else ""
		sub.add_theme_color_override("font_color", Style.INK_SOFT)
	box.add_child(sub)
	return card


func _contact_title(v: Dictionary, i: int, locked: bool, selected: bool) -> Label:
	var head := Label.new()
	var stars := "★".repeat(i + 1) + "☆".repeat(maxi(0, 2 - i))
	var mark := "🔒 " if locked else ("▸ " if selected else "")
	head.text = "%s%s  %s" % [mark, str(v["name"]), stars]
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Style.INK_SOFT if locked else Style.INK)
	return head


func _make_upgrade_row(id: String, selected: bool) -> Control:
	var d := Upgrades.data(id)
	var card := _card_panel(selected)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var name_label := Label.new()
	name_label.text = str(d.get("name", "?"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Style.INK)
	name_label.add_theme_font_size_override("font_size", 17)
	hbox.add_child(name_label)
	hbox.add_child(_upgrade_status(id, d))
	return card


func _upgrade_status(id: String, d: Dictionary) -> Label:
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 17)
	if Upgrades.has(id):
		status.text = "Owned ✓"
		status.add_theme_color_override("font_color", Style.FOREST)
	elif not Upgrades.tier_met(id):
		status.text = "🔒"
		status.add_theme_color_override("font_color", Style.CLAY)
	else:
		status.text = "$ %d" % int(d.get("cost", 0))
		status.add_theme_color_override("font_color", Style.INK_SOFT)
	return status


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
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _row_count() -> int:
	match _screen:
		Screen.HUB:
			return HUB_OPTIONS.size()
		Screen.SUPPLIERS:
			return Upgrades.VENDORS.size()
		Screen.ORDER:
			return _order_rows().size()
	return _upg_ids.size()


func _move_row(delta: int) -> void:
	_status = ""
	var n := _row_count()
	_row = (_row + delta + n) % n
	_refresh()


func _adjust(dir: int) -> void:
	if _screen != Screen.ORDER:
		return
	_status = ""
	match _order_rows()[_row]:
		ORow.FABRIC:
			_cycle_fabric(dir)
		ORow.COLOR:
			var c := MaterialFactory.color_count()
			_color = (_color + dir + c) % c
		ORow.PATTERN:
			_pattern = (_pattern + dir + Enums.Pattern.size()) % Enums.Pattern.size()
		ORow.PATTERN_COLOR:
			var n := MaterialFactory.pattern_accent_count()
			_pattern_dye = (_pattern_dye + dir + n) % n
		ORow.LENGTH:
			_length = clampf(_length + dir * LENGTH_STEP, LENGTH_MIN, Upgrades.max_roll_length())
	_refresh()


func _confirm() -> void:
	match _screen:
		Screen.HUB:
			_open_hub_choice()
		Screen.SUPPLIERS:
			_choose_supplier()
		Screen.ORDER:
			_order_roll()
		Screen.UPGRADES:
			_buy_upgrade()


func _back() -> void:
	_status = ""
	match _screen:
		Screen.HUB:
			close()
		Screen.ORDER:
			_screen = Screen.SUPPLIERS
			_row = _vendor
			_refresh()
		_:
			_screen = Screen.HUB
			_row = 0
			_refresh()


# --- Suppliers & orders ----------------------------------------------------


func _open_hub_choice() -> void:
	_screen = Screen.SUPPLIERS if _hub_sel == 0 else Screen.UPGRADES
	_row = _vendor if _hub_sel == 0 else 0
	_status = ""
	_refresh()


## Call the highlighted supplier — locked mills refuse; unlocked ones open the order form.
func _choose_supplier() -> void:
	if _vendor_locked(_row):
		_status = ""
		_refresh()
		return
	_vendor = _row
	_snap_fabric_to_vendor()
	_screen = Screen.ORDER
	_row = 0
	_refresh()


func _vendor_locked(i: int) -> bool:
	var t: int = Reputation.tier() if Reputation != null else 0
	return t < int(Upgrades.VENDORS[i]["tier"])


func _vendor_fabrics() -> Array:
	return Upgrades.VENDORS[_vendor]["fabrics"]


## Premium mills let you choose the pattern's thread colour (the Pattern Dye row).
func _vendor_dyes() -> bool:
	return bool(Upgrades.VENDORS[_vendor].get("pattern_dye", false))


## Step the fabric within the current supplier's offered list (wrapping).
func _cycle_fabric(dir: int) -> void:
	var fabrics := _vendor_fabrics()
	if fabrics.is_empty():
		return
	var idx := fabrics.find(_fabric)
	if idx < 0:
		idx = 0
	_fabric = int(fabrics[(idx + dir + fabrics.size()) % fabrics.size()])


func _snap_fabric_to_vendor() -> void:
	var fabrics := _vendor_fabrics()
	if not fabrics.has(_fabric) and not fabrics.is_empty():
		_fabric = int(fabrics[0])


func _order_roll() -> void:
	var mat := MaterialFactory.make(_fabric, _pattern, _color, _length, _pattern_dye)
	if mat == null:
		return
	var cost := Pricing.roll_price(mat, _length)
	if not GameState.can_afford(cost):
		_status = "     Not enough money!"
		_refresh()
		return
	GameState.spend(cost)
	_phone.deliver_roll(mat, _length)
	EventBus.order_placed.emit(mat, _length, cost)
	_status = "     Ordered!  (-$%d)" % cost
	_refresh()


func _buy_upgrade() -> void:
	var id: String = _upg_ids[_row]
	if Upgrades.has(id):
		_status = "  (already owned)"
	elif not Upgrades.tier_met(id):
		_status = "  (need more reputation)"
	elif not GameState.can_afford(int(Upgrades.data(id).get("cost", 0))):
		_status = "  (not enough money)"
	elif Upgrades.buy(id):
		Sfx.play("coins")
		_status = "  — purchased!"
	_refresh()

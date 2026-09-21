extends Control

## The phone. Opens onto a small HUB anchored up by the phone where you pick what to
## do, then drills in (Esc steps back a screen):
##  - Order Textiles -> a phonebook of suppliers you can browse (locked mills included,
##    so you can see what better cloth awaits). Choose an unlocked one to open its order
##    form (fabric / colour / pattern / length) — the supplier decides which fabrics stock.
##  - Shop Upgrades -> buy reputation-gated shop upgrades, grouped by machine.
##  - Builders (grandpa's shop only) -> order BUILD renovation projects, grouped by room.

enum Screen { HUB, SUPPLIERS, ORDER, UPGRADES, BUILDERS }
enum ORow { FABRIC, COLOR, PATTERN, PATTERN_COLOR, LENGTH }

const PANEL_W := 520
const LIST_MARGIN := 28.0  # breathing room kept below the panel when the list scrolls
## The tallest the panel gets (a long list fills this and scrolls inside it).
const PANEL_MAX_H := 660.0
## Room around the cards inside the scroll area, so a card's outline, drop shadow and
## selection flourish aren't clipped at the list's edges.
const LIST_PAD := 6
const LENGTH_MIN := 2.0  # fallbacks; Config.roll_min_m / roll_step_m win
const LENGTH_STEP := 1.0
const HUB_OPTIONS := [
	{"title": "Order Textiles", "desc": "Ring a supplier and order a bolt of cloth."},
	{"title": "Shop Upgrades", "desc": "Spend your standing on better tools and kit."},
	{"title": "Shop Sign", "desc": ""},  # text filled live (see _hub_card_text)
]
const HUB_SIGN := 2
## Appended after HUB_OPTIONS (grandpa's shop only, see _hub_options) — its index there
## is HUB_OPTIONS.size(), never earlier, so it can't shift the sign card or the tutorial.
const BUILDERS_CARD := {"title": "Builders", "desc": "Book the renovation work on the shop."}
const KICKER := "Order pad"
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
var _build_ids: Array = []
var _list_scroll: ScrollContainer
var _list_pad: MarginContainer
var _selected_row: Control = null
var _placed := false
var _head: TitleBlock
var _swatch: MaterialSwatch
var _big_icon: UpgradeIcon
var _contacts: VBoxContainer
var _name_label: Label
var _summary_label: Label
var _price_label: Label
var _hint_bar: Control
var _total_slot: VBoxContainer
var _ledger: ClothLedger

@onready var _panel: PanelContainer = $Center/Panel
@onready var _dim: ColorRect = $Dim
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _money: Label = $Center/Panel/Margin/Box/Money
@onready var _preview: HBoxContainer = $Center/Panel/Margin/Box/Preview
@onready var _rows: VBoxContainer = $Center/Panel/Margin/Box/Rows
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func _ready() -> void:
	_build_preview()
	_wrap_rows()
	_upg_ids = Upgrades.all_ids()
	_build_ids = _builder_ids()
	Renovation.changed.connect(_on_renovation_changed)


## The builders' work may finish (or its cost/lock state may change) while this screen
## is open, e.g. at dawn (EventBus.day_began) — refresh so the row/preview stay honest.
func _on_renovation_changed() -> void:
	if visible and _screen == Screen.BUILDERS:
		_refresh()


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
	_length = clampf(_length, _len_min(), Upgrades.max_roll_length())
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


## The rows live in a scroll area: the panel grows with its content until it would run
## off the bottom of the screen, then the list scrolls and follows the selection.
func _wrap_rows() -> void:
	var box := _rows.get_parent()
	var at := _rows.get_index()
	box.remove_child(_rows)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_list_scroll)
	box.move_child(_list_scroll, at)
	_list_pad = MarginContainer.new()
	_list_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top"]:
		_list_pad.add_theme_constant_override("margin_" + side, LIST_PAD)
	_list_pad.add_theme_constant_override("margin_bottom", LIST_PAD + 4)  # + the drop shadow
	_list_scroll.add_child(_list_pad)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_pad.add_child(_rows)


## Short screens hug their content. The long upgrades list gets a FIXED panel as tall as
## the screen allows, with the list filling it and scrolling inside — so the panel never
## changes size as the selection moves. Either way the selected row is kept in view.
func _fit_list() -> void:
	if _list_scroll == null or not visible:
		return
	var tallest := minf(get_viewport_rect().size.y - _panel.offset_top - LIST_MARGIN, PANEL_MAX_H)
	if _screen == Screen.UPGRADES or _screen == Screen.BUILDERS:
		_list_scroll.custom_minimum_size.y = 0.0
		_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_panel.offset_bottom = _panel.offset_top + tallest
	else:
		_list_scroll.size_flags_vertical = Control.SIZE_FILL
		_panel.offset_bottom = _panel.offset_top
		var want := _list_pad.get_combined_minimum_size().y
		var others := _panel.get_combined_minimum_size().y - _list_scroll.custom_minimum_size.y
		_list_scroll.custom_minimum_size.y = clampf(want, 0.0, maxf(tallest - others, 120.0))
	# Two frames: one for the new rows to lay out, one for the resized scroll area.
	await get_tree().process_frame
	await get_tree().process_frame
	if _selected_row == null or not is_instance_valid(_selected_row):
		return
	var mid := LIST_PAD + _selected_row.position.y + _selected_row.size.y * 0.5
	_list_scroll.scroll_vertical = int(mid - _list_scroll.size.y * 0.5)


func _build_preview() -> void:
	_contacts = VBoxContainer.new()
	_contacts.custom_minimum_size = Vector2(230, 0)
	_contacts.add_theme_constant_override("separation", Style.S1)
	_preview.add_child(_contacts)

	_swatch = MaterialSwatch.new()
	_swatch.swatch_size = 96
	_preview.add_child(_swatch)
	_big_icon = UpgradeIcon.make("", 84.0)
	_big_icon.visible = false
	_preview.add_child(_big_icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", Style.S1)
	_preview.add_child(info)

	_name_label = Label.new()
	_name_label.add_theme_font_override("font", Style.font_medium())
	_name_label.add_theme_font_size_override("font_size", Style.T_NAME)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_name_label)
	_summary_label = Label.new()
	_summary_label.add_theme_font_override("font", Style.font_body())
	_summary_label.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_summary_label)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", Style.T_VALUE)
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
		# The stock-room ledger sits opposite, top-left, while cloth is being ordered.
		_ledger = ClothLedger.new()
		add_child(_ledger)
		_ledger.position = Vector2(28, 72)
	_panel.offset_left = -(PANEL_W + 28)
	_panel.offset_right = -28
	_panel.offset_top = 72
	_panel.offset_bottom = 72


func _style() -> void:
	_dim.color = Style.tint(Style.SCRIM, 0.22)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	Style.apply_skin(_panel, Style.MenuSkin.ORDER)
	_preview.add_theme_constant_override("separation", Style.S3)
	_head = TitleBlock.adopt(_title, KICKER, Style.ACC_ORDER)
	_money.reparent(_head.meta)
	_money.add_theme_font_override("font", Style.font_bold())
	_money.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_name_label.add_theme_color_override("font_color", Style.INK)
	_summary_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_rows.add_theme_constant_override("separation", Style.S1)
	_hint.visible = false
	if _total_slot == null:
		# Pinned above the hint bar, same slot the order total lives in (see suit_builder).
		_total_slot = VBoxContainer.new()
		_hint.get_parent().add_child(_total_slot)


func _set_hint(pairs: Array) -> void:
	if _hint_bar != null:
		_hint_bar.get_parent().remove_child(_hint_bar)  # gone now, not at frame end
		_hint_bar.queue_free()
	_hint_bar = Style.hint_bar(pairs)
	_hint.get_parent().add_child(_hint_bar)


# --- Rendering -------------------------------------------------------------


func _refresh() -> void:
	_money.text = "Budget  $%d" % GameState.money
	_money.add_theme_color_override("font_color", Style.INK)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_selected_row = null
	_big_icon.visible = _screen == Screen.UPGRADES
	if _ledger != null:
		_ledger.visible = _screen == Screen.SUPPLIERS or _screen == Screen.ORDER
		if _ledger.visible:
			_ledger.refresh(_phone)
	_clear_total()
	match _screen:
		Screen.HUB:
			_refresh_hub()
		Screen.SUPPLIERS:
			_refresh_suppliers()
		Screen.ORDER:
			_refresh_order()
		Screen.UPGRADES:
			_refresh_upgrades()
		Screen.BUILDERS:
			_refresh_builders()
	_fit_list.call_deferred()


func _refresh_hub() -> void:
	_head.set_kicker(KICKER)
	_title.text = "Phone"
	_preview.visible = false
	var opts := _hub_options()
	_row = clampi(_row, 0, opts.size() - 1)
	_hub_sel = _row
	for i in opts.size():
		var text := _hub_card_text(i)
		_rows.add_child(_make_hub_card(text[0], text[1], i == _row))
	_set_hint([["W/S", "Select"], ["E", "Open"], ["Esc", "Hang up"]])


## The hub cards for the current location: the base three, plus Builders at grandpa's
## shop (where rooms actually need booking). A function of location, not a mutated
## const, so HUB_SIGN and the tutorial's Hemming's-shop indices never move.
func _hub_options() -> Array:
	if Locations.current == Locations.GRANDPA:
		return HUB_OPTIONS + [BUILDERS_CARD]
	return HUB_OPTIONS


## The supplier phonebook: browse every mill (locked ones too) and read what they stock.
func _refresh_suppliers() -> void:
	_head.set_kicker(KICKER)
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
	_head.set_kicker("Ordering from")
	_title.text = str(Upgrades.VENDORS[_vendor]["name"])
	var rows := _order_rows()
	_row = clampi(_row, 0, rows.size() - 1)
	var mat := MaterialFactory.make(_fabric, _pattern, _color, _length, _pattern_dye)
	var cost := _order_cost(mat)
	var afford := GameState.can_afford(cost)
	if mat != null:
		_swatch.setup(mat, mat.roll_length_m)
		_name_label.text = mat.display_name
		_summary_label.text = mat.summary()
	var note := _status if _status != "" else _on_the_way()
	if not afford and not _free_order() and GameState.can_use_account(cost):
		note += "\nE: put it on account (repaid from your next sale)"
	_price_label.text = note.strip_edges()
	_price_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_show_order_total(cost, afford)
	for i in rows.size():
		_rows.add_child(_make_cfg_row(rows[i], _row == i))
	_set_hint([["W/S", "Select"], ["A/D", "Change"], ["E", "Order"], ["Esc", "Back"]])


func _clear_total() -> void:
	for child in _total_slot.get_children():
		_total_slot.remove_child(child)  # gone now, so it can't count toward this frame's layout
		child.queue_free()


## The live order cost as the panel's footer: length + any deals on the left, the
## price large and bold on the right — pinned above the hint bar.
func _show_order_total(cost: int, afford: bool) -> void:
	_clear_total()
	if _free_order():
		_total_slot.add_child(
			Style.total_bar(_deals_text(), "Order", 0, Style.FOREST, "On the house!")
		)
		return
	var col := Style.INK
	var note := ""
	if not afford:
		if GameState.can_use_account(cost):
			col = Style.AMBER
			note = "On account"
		else:
			col = Style.CLAY
			note = "Can't afford"
	_total_slot.add_child(Style.total_bar(_deals_text(), "Order", cost, col, note))


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
	_head.set_kicker(KICKER)
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
		var card := _make_upgrade_row(id, _row == i)
		if _row == i:
			_selected_row = card
		_rows.add_child(card)
	_set_hint([["W/S", "Select"], ["E", "Buy"], ["Esc", "Back"]])


## BUILD renovation projects only (cleanup is done by hand in the shop), grouped under a
## header per room in ROOMS order — locked ones are listed too, so the player can see
## what's coming, the same way locked suppliers are shown.
func _refresh_builders() -> void:
	_preview.visible = true
	_contacts.visible = false
	_swatch.visible = false
	_head.set_kicker(KICKER)
	_title.text = "Builders"
	_row = clampi(_row, 0, maxi(_build_ids.size() - 1, 0))
	if not _build_ids.is_empty():
		_show_builder_preview(_build_ids[_row])
	var last_room := ""
	for i in _build_ids.size():
		var id: String = _build_ids[i]
		var room := str(Renovation.data(id).get("room", ""))
		if room != last_room:
			last_room = room
			_rows.add_child(Style.header(_room_name(room), Style.ACC_ORDER))
		var card := _make_builder_row(id, _row == i)
		if _row == i:
			_selected_row = card
		_rows.add_child(card)
	_set_hint([["W/S", "Select"], ["E", "Order"], ["Esc", "Back"]])


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
		var mult := Pricing.vendor_mult(i)
		var note := "  ·  +%d%% per metre" % roundi((mult - 1.0) * 100.0) if mult > 1.0 else ""
		if Pricing.is_market_day():
			note += "  ·  MARKET DAY −%d%%" % roundi(Pricing.market_discount() * 100.0)
		_price_label.text = "E — call this supplier%s" % note
		_price_label.add_theme_color_override("font_color", Style.FOREST)


func _fabrics_text(v: Dictionary) -> String:
	var names: Array = []
	for f in v["fabrics"]:
		names.append(Enums.fabric_name(int(f)))
	return "Stocks: %s" % ", ".join(names)


func _show_upgrade_preview(id: String) -> void:
	var d := Upgrades.data(id)
	_big_icon.id = id
	_big_icon.state = UpgradeIcon.state_of(id, _needs(id) != "")
	_name_label.text = str(d.get("name", "?"))
	_summary_label.text = str(d.get("desc", ""))
	if Upgrades.has(id):
		_price_label.text = "Owned ✓%s" % _status
		_price_label.add_theme_color_override("font_color", Style.FOREST)
	elif not Upgrades.tier_met(id):
		_price_label.text = "Locked — %s%s" % [_tier_name(int(d.get("tier", 0))), _status]
		_price_label.add_theme_color_override("font_color", Style.CLAY)
	elif _needs(id) != "":
		_price_label.text = "Needs the %s first%s" % [_needs(id), _status]
		_price_label.add_theme_color_override("font_color", Style.CLAY)
	else:
		var cost := int(d.get("cost", 0))
		_price_label.text = "Buy:  $ %d%s" % [cost, _status]
		var ok := GameState.can_afford(cost)
		_price_label.add_theme_color_override("font_color", Style.FOREST if ok else Style.CLAY)


## Right-hand detail for the highlighted renovation project: its blurb, room, and either
## its progress, its lock reason, or its price and how long the builders will need.
func _show_builder_preview(id: String) -> void:
	var d := Renovation.data(id)
	_name_label.text = str(d.get("name", "?"))
	_summary_label.text = str(d.get("desc", ""))
	var room_name := _room_name(str(d.get("room", "")))
	var line := ""
	var col := Style.INK
	if Renovation.is_done(id):
		line = "Done"
		col = Style.FOREST
	elif Renovation.nights_left(id) > 0:
		line = "Builders in — %s left" % _nights_text(Renovation.nights_left(id))
		col = Style.AMBER
	elif not Renovation.tier_met(id):
		line = "Needs %s" % _tier_name(Renovation.tier_needed(id))
		col = Style.CLAY
	elif _builder_blocker(id) != "":
		line = _blocker_text(_builder_blocker(id))
		col = Style.CLAY
	else:
		var cost := int(d.get("cost", 0))
		line = "$%d  ·  The builders need %s" % [cost, _nights_text(int(d.get("nights", 1)))]
		col = Style.FOREST if GameState.can_afford(cost) else Style.CLAY
	_price_label.text = "%s\n%s%s" % [room_name, line, _status]
	_price_label.add_theme_color_override("font_color", col)


func _tier_name(t: int) -> String:
	return str(Reputation.TIERS[clampi(t, 0, Reputation.TIERS.size() - 1)]["name"])


# --- Cards -----------------------------------------------------------------


func _card_panel(selected: bool) -> PanelContainer:
	return CraftPanel.option(selected, Style.ACC_ORDER)


func _make_hub_card(title: String, desc: String, selected: bool) -> Control:
	var card := _card_panel(selected)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var head := Label.new()
	head.text = ("▸  %s" % title) if selected else title
	head.add_theme_font_override("font", Style.font_bold() if selected else Style.font_medium())
	head.add_theme_font_size_override("font_size", Style.T_NAME)
	head.add_theme_color_override("font_color", Style.INK)
	box.add_child(head)
	var sub := Label.new()
	sub.text = desc
	sub.add_theme_font_size_override("font_size", Style.T_CAPTION)
	sub.add_theme_color_override("font_color", Style.INK_SOFT)
	box.add_child(sub)
	return card


func _make_cfg_row(row: int, selected: bool) -> Control:
	var card := _card_panel(selected)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	Style.field_row(hbox, OROW_NAME[row], _cfg_value(row), selected)
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
	sub.add_theme_font_size_override("font_size", Style.T_MICRO)
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
	head.add_theme_font_size_override("font_size", Style.T_CAPTION)
	head.add_theme_color_override("font_color", Style.INK_SOFT if locked else Style.INK)
	return head


func _make_upgrade_row(id: String, selected: bool) -> Control:
	var d := Upgrades.data(id)
	var card := _card_panel(selected)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	hbox.add_child(UpgradeIcon.make(id, 36.0, UpgradeIcon.state_of(id, _needs(id) != "")))
	var name_label := Label.new()
	name_label.text = str(d.get("name", "?"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_override("font", Style.font_medium())
	name_label.add_theme_color_override("font_color", Style.INK)
	name_label.add_theme_font_size_override("font_size", Style.T_BODY)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)
	var status := _upgrade_status(id, d)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(status)
	return card


## Right-hand status of an upgrade row: owned / locked, or its price (always bold).
func _upgrade_status(id: String, d: Dictionary) -> Label:
	if Upgrades.has(id):
		var owned := _status_label("Owned ✓", Style.FOREST)
		return owned
	if not Upgrades.tier_met(id) or _needs(id) != "":
		var locked := _status_label("Locked", Style.CLAY)
		return locked
	var price := Style.money(int(d.get("cost", 0)), Style.T_BODY, Style.INK_SOFT)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return price


func _status_label(text: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", Style.T_BODY)
	lbl.add_theme_color_override("font_color", col)
	return lbl


func _make_builder_row(id: String, selected: bool) -> Control:
	var d := Renovation.data(id)
	var card := _card_panel(selected)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var name_label := Label.new()
	name_label.text = str(d.get("name", "?"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_override("font", Style.font_medium())
	name_label.add_theme_color_override("font_color", Style.INK)
	name_label.add_theme_font_size_override("font_size", Style.T_BODY)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)
	var status := _builder_status(id, d)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(status)
	return card


## Right-hand status of a builders row: done / under way / locked, or its price (in the
## unaffordable colour when the player can't yet cover it).
func _builder_status(id: String, d: Dictionary) -> Label:
	if Renovation.is_done(id):
		return _status_label("Done", Style.FOREST)
	var nights := Renovation.nights_left(id)
	if nights > 0:
		return _status_label("Builders in — %s left" % _nights_text(nights), Style.AMBER)
	if not Renovation.tier_met(id):
		return _status_label("Needs %s" % _tier_name(Renovation.tier_needed(id)), Style.CLAY)
	var blocker := _builder_blocker(id)
	if blocker != "":
		var name: String = str(Renovation.data(blocker).get("name", blocker))
		return _status_label("After: %s" % name, Style.CLAY)
	var cost := int(d.get("cost", 0))
	var afford := GameState.can_afford(cost)
	var price := Style.money(cost, Style.T_BODY, Style.INK_SOFT if afford else Style.CLAY)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return price


## The id of the first not-yet-done project this one's `needs` waits on ("" if none).
func _builder_blocker(id: String) -> String:
	for other: String in Renovation.data(id).get("needs", []):
		if not Renovation.is_done(other):
			return other
	return ""


## The preview's reason text for a `needs` lock: cleanup work is done by hand in the
## shop (not ordered), so it gets its own phrasing rather than "After: <name>".
func _blocker_text(blocker_id: String) -> String:
	var bd := Renovation.data(blocker_id)
	var name := str(bd.get("name", blocker_id))
	if int(bd.get("kind", Renovation.Kind.BUILD)) == Renovation.Kind.CLEANUP:
		return "First, in the shop: %s" % name
	return "After: %s" % name


func _room_name(room: String) -> String:
	return str(Renovation.ROOMS.get(room, {}).get("name", room))


func _nights_text(n: int) -> String:
	return "%d night%s" % [n, "" if n == 1 else "s"]


## BUILD project ids only, grouped by room in ROOMS order (cleanup is done by hand, not
## ordered from the phone).
func _builder_ids() -> Array:
	var ids: Array = []
	for room: String in Renovation.ROOMS:
		for id: String in Renovation.all_ids():
			var d := Renovation.data(id)
			if str(d.get("room", "")) == room and int(d.get("kind", -1)) == Renovation.Kind.BUILD:
				ids.append(id)
	return ids


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
			return _hub_options().size()
		Screen.SUPPLIERS:
			return Upgrades.VENDORS.size()
		Screen.ORDER:
			return _order_rows().size()
		Screen.BUILDERS:
			return _build_ids.size()
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
			_length = clampf(_length + dir * _len_step(), _len_min(), Upgrades.max_roll_length())
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
		Screen.BUILDERS:
			_order_builder()


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


## Title + description for a hub card (the sign card shows its live state).
func _hub_card_text(i: int) -> Array:
	var opt: Dictionary = _hub_options()[i]
	if i != HUB_SIGN:
		return [opt["title"], opt["desc"]]
	if FrontDesk.booked:
		return ["Sign: FULLY BOOKED", "No new walk-ins. Appointments still come. E to open up."]
	return ["Sign: OPEN", "Walk-ins welcome. E to flip it to Fully Booked."]


func _open_hub_choice() -> void:
	if _hub_sel == HUB_SIGN:
		FrontDesk.booked = not FrontDesk.booked
		Sfx.play("drawer")
		_refresh()
		return
	if _hub_sel == HUB_OPTIONS.size():  # the Builders card, only ever present at grandpa's
		_screen = Screen.BUILDERS
		_row = 0
		_status = ""
		_refresh()
		return
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
	var lesson: Dictionary = Tutorial.order_cloth() if Tutorial != null else {}
	if not lesson.is_empty() and not tutorial_cloth_ok(lesson):
		# The lesson's bolt only: the recipe's jacket cloth, nothing else on the house.
		_status = "     Mr. Hemming wants the jacket's cloth first"
		Sfx.play("error")
		_refresh()
		return
	var mat := MaterialFactory.make(_fabric, _pattern, _color, _length, _pattern_dye)
	if mat == null:
		return
	var cost := _order_cost(mat)
	if GameState.can_afford(cost):
		GameState.spend(cost)
		_status = "     Ordered!  (-$%d)" % cost
	elif GameState.buy_on_account(cost):
		_status = "     On account — $%d owed" % cost
	else:
		_status = "     Not enough money!"
		Sfx.play("error")
		_refresh()
		return
	var when: String = _phone.order_roll(mat, _length)
	if when != "now":
		_status += "  ·  arrives %s" % when
	EventBus.order_placed.emit(mat, _length, cost)
	_refresh()


## "  ·  2 on the way, next at 10:30" while bolts are still coming ("" when none).
func _on_the_way() -> String:
	if _phone == null or _phone.pending_count() == 0:
		return ""
	return "     %d on the way, next %s" % [_phone.pending_count(), _phone.next_arrival_text()]


## What this bolt costs from the current supplier today (free for the tutorial's first).
func _order_cost(mat: MaterialType) -> int:
	if mat == null or _free_order():
		return 0
	return Pricing.roll_price(mat, _length, _vendor)


func _free_order() -> bool:
	return Tutorial != null and Tutorial.is_active() and Tutorial.first_bolt_free()


## "10 m · −10% bulk · market day −25%" — the length plus any deals on this bolt, the
## working text for the order total's footer.
func _deals_text() -> String:
	var parts := PackedStringArray(["%.0f m" % _length])
	var bulk := Pricing.bulk_discount(_length)
	if bulk > 0.0:
		parts.append("−%d%% bulk" % roundi(bulk * 100.0))
	if Pricing.is_market_day():
		parts.append("market day −%d%%" % roundi(Pricing.market_discount() * 100.0))
	var mult := Pricing.vendor_mult(_vendor)
	if mult > 1.0:
		parts.append("premium +%d%%" % roundi((mult - 1.0) * 100.0))
	return " · ".join(parts)


func _len_min() -> float:
	return Config.data.roll_min_m if Config.data != null else LENGTH_MIN


func _len_step() -> float:
	return Config.data.roll_step_m if Config.data != null else LENGTH_STEP


func _buy_upgrade() -> void:
	var id: String = _upg_ids[_row]
	if Upgrades.has(id):
		_status = "  (already owned)"
	elif not Upgrades.tier_met(id):
		_status = "  (need more reputation)"
	elif _needs(id) != "":
		_status = "  (buy the %s first)" % _needs(id)
	elif not GameState.can_afford(int(Upgrades.data(id).get("cost", 0))):
		_status = "  (not enough money)"
	elif Upgrades.buy(id):
		Sfx.play("coins")
		_status = "  — purchased!"
	_refresh()


## The name of the upgrade this one builds on, while that one is still unbought ("" if none).
func _needs(id: String) -> String:
	var base := str(Upgrades.data(id).get("needs", ""))
	if base == "" or Upgrades.has(base):
		return ""
	return str(Upgrades.data(base).get("name", base))


## Book a BUILD project's renovation work: the same refusal feedback as _buy_upgrade
## (a status line, nothing spent) when it can't be ordered, else pay, start the nights,
## and toast it like a purchase.
func _order_builder() -> void:
	if _build_ids.is_empty():
		return
	var id: String = _build_ids[_row]
	if Renovation.is_done(id):
		_status = "  (already done)"
	elif Renovation.nights_left(id) > 0:
		_status = "  (the builders are already on it)"
	elif not Renovation.tier_met(id):
		_status = "  (need more reputation)"
	elif _builder_blocker(id) != "":
		var name: String = str(Renovation.data(_builder_blocker(id)).get("name", ""))
		_status = "  (finish %s first)" % name
	elif not GameState.can_afford(int(Renovation.data(id).get("cost", 0))):
		_status = "  (not enough money)"
	elif Renovation.order(id):
		Sfx.play("coins")
		var nights := int(Renovation.data(id).get("nights", 1))
		UI.toast("Builders booked — done in %s" % _nights_text(nights))
		_status = "  — booked!"
	_refresh()


# --- Tutorial hooks ----------------------------------------------------------


## The tutorial's coach mark on this screen (see Tutorial._update_pointers). While it asks
## for the jacket's cloth: the card, row or key that leads there, with the value to pick;
## once the bolt is ordered, the way back out of the phone. {} = nothing to point at.
func tutorial_coach(goal: Dictionary) -> Dictionary:
	match str(goal.get("step", "")):
		"order":
			return _coach_order(goal.get("cloth", {}))
		"store":
			return {"key": "Esc", "text": "Hang up" if _screen == Screen.HUB else "Done — back out"}
	return {}


## Whether the order form is set to `cloth` ({fabric, color, pattern}).
func tutorial_cloth_ok(cloth: Dictionary) -> bool:
	return (
		not cloth.is_empty()
		and _fabric == int(cloth.get("fabric", -1))
		and _color == int(cloth.get("color", -1))
		and _pattern == int(cloth.get("pattern", -1))
	)


func _coach_order(cloth: Dictionary) -> Dictionary:
	var vendor := _supplier_of(int(cloth.get("fabric", -1)))
	match _screen:
		Screen.HUB:
			return _coach_pick(_rows, 0, 0, str(HUB_OPTIONS[0]["title"]), "Open")
		Screen.SUPPLIERS:
			var who := str(Upgrades.VENDORS[vendor]["name"])
			return _coach_pick(_contacts, vendor, 1, who, "Call")  # [0] is the header
		Screen.ORDER:
			if _vendor != vendor:
				return {"key": "Esc", "text": "Wrong supplier — back"}
			return _coach_form(cloth)
	return {"key": "Esc", "text": "Back"}


## Point at card `index` of `list` (after `skip` leading children): W/S to reach it, then
## E to `verb` it.
func _coach_pick(list: Node, index: int, skip: int, what: String, verb: String) -> Dictionary:
	var card := _live_child(list, index + skip)
	if card == null:
		return {}
	var text := ("E: %s" % verb) if _row == index else ("W/S: go to %s" % what)
	return {"rect": card.get_global_rect(), "text": text, "beside": true}


## On the order form: the first row not yet set to the jacket's cloth, else the order key.
func _coach_form(cloth: Dictionary) -> Dictionary:
	var fabric := int(cloth.get("fabric", _fabric))
	var color := int(cloth.get("color", _color))
	var pattern := int(cloth.get("pattern", _pattern))
	var fields := [
		[ORow.FABRIC, _fabric == fabric, Enums.fabric_name(fabric)],
		[ORow.COLOR, _color == color, MaterialFactory.color_name(color)],
		[ORow.PATTERN, _pattern == pattern, Enums.pattern_name(pattern)],
	]
	for f: Array in fields:
		if f[1]:
			continue
		var i := _order_rows().find(f[0])
		var card := _live_child(_rows, i)
		if card == null:
			return {}
		var text := ("A/D: pick %s" % f[2]) if _row == i else ("W/S: go to %s" % OROW_NAME[f[0]])
		return {"rect": card.get_global_rect(), "text": text, "beside": true}
	return {"key": "E", "text": "Order it"}


## The first open supplier that stocks `fabric` (the tutorial's recipe is built from them).
func _supplier_of(fabric: int) -> int:
	for i in Upgrades.VENDORS.size():
		if not _vendor_locked(i) and fabric in Upgrades.VENDORS[i]["fabrics"]:
			return i
	return 0


## The `index`th child of `list` that isn't on its way out (rebuilt lists free the old
## cards at the end of the frame).
func _live_child(list: Node, index: int) -> Control:
	var n := 0
	for child in list.get_children():
		if child.is_queued_for_deletion():
			continue
		if n == index:
			return child as Control
		n += 1
	return null

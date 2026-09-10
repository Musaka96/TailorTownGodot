extends Control

## Phone screen. Three modes (cycle the top "Mode" row):
##  - Premade: pick a catalogue roll.
##  - Custom Maker: choose supplier + fabric + colour + pattern yourself. The supplier
##    (unlocked by reputation) decides which fabrics you can buy — premium mills carry
##    the finer cloth.
##  - Upgrades: buy reputation-gated shop upgrades (faster machines, more hooks, bigger
##    bolts). E orders / buys the selected row, Esc closes.

enum Row { MODE, VENDOR, MATERIAL, FABRIC, COLOR, PATTERN, LENGTH }

const LENGTH_MIN := 4.0
const LENGTH_STEP := 2.0
const ROW_NAME := {
	Row.MODE: "Mode",
	Row.VENDOR: "Supplier",
	Row.MATERIAL: "Roll",
	Row.FABRIC: "Fabric",
	Row.COLOR: "Colour",
	Row.PATTERN: "Pattern",
	Row.LENGTH: "Length",
}
const MODE_NAMES := ["Premade Rolls", "Custom Maker", "Shop Upgrades"]

var _phone = null
var _actor = null
var _mode := 0  # 0 premade, 1 custom, 2 upgrades
var _premade := 0
var _vendor := 0
var _fabric := 0
var _color := 0
var _pattern := 0
var _length := 10.0
var _row := 0
var _status := ""
var _upg_ids: Array = []
var _swatch: MaterialSwatch
var _name_label: Label
var _summary_label: Label
var _price_label: Label
var _decor_built := false

@onready var _panel: PanelContainer = $Center/Panel
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
	_row = 0
	_status = ""
	_vendor = clampi(_vendor, 0, Upgrades.unlocked_vendors().size() - 1)
	_length = clampf(_length, LENGTH_MIN, Upgrades.max_roll_length())
	GameState.input_locked = true
	visible = true
	_style()
	_refresh()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_phone = null


func _build_preview() -> void:
	_swatch = MaterialSwatch.new()
	_swatch.swatch_size = 112
	_preview.add_child(_swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", Style.S1)
	_preview.add_child(info)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	info.add_child(_name_label)
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 15)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_summary_label)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 19)
	info.add_child(_price_label)


func _style() -> void:
	_panel.custom_minimum_size = Vector2(640, 0)
	Style.apply_skin(_panel, Style.MenuSkin.ORDER)
	_preview.add_theme_constant_override("separation", Style.S3)
	_title.add_theme_font_override("font", Style.bold_font())
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Style.ACC_ORDER.darkened(0.2))
	_money.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Style.INK)
	_summary_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_rows.add_theme_constant_override("separation", Style.S1)
	_rows.custom_minimum_size = Vector2(0, 250)
	_build_decor_once()


func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	_hint.visible = false
	var bar := Style.hint_bar(
		[["W/S", "Select"], ["A/D", "Change"], ["E", "Order / Buy"], ["Esc", "Close"]]
	)
	_hint.get_parent().add_child(bar)


# --- State helpers ---------------------------------------------------------


func _active_rows() -> Array:
	if _mode == 0:
		return [Row.MODE, Row.MATERIAL, Row.LENGTH]
	if _mode == 1:
		return [Row.MODE, Row.VENDOR, Row.FABRIC, Row.COLOR, Row.PATTERN, Row.LENGTH]
	return []  # upgrades mode renders its own list


func _row_count() -> int:
	if _mode == 2:
		return 1 + _upg_ids.size()  # Mode row + one per upgrade
	return _active_rows().size()


func _vendor_fabrics() -> Array:
	var vendors := Upgrades.unlocked_vendors()
	return vendors[clampi(_vendor, 0, vendors.size() - 1)]["fabrics"]


func _current_material() -> MaterialType:
	if _mode == 0:
		var all := Catalog.all_materials()
		if all.is_empty():
			return null
		return all[_premade % all.size()]
	return MaterialFactory.make(_fabric, _pattern, _color, _length)


func _price() -> int:
	var mat := _current_material()
	return Pricing.roll_price(mat, _length) if mat != null else 0


func _value_text(row: int) -> String:
	match row:
		Row.MODE:
			return MODE_NAMES[_mode]
		Row.FABRIC:
			return Enums.fabric_name(_fabric)
		Row.COLOR:
			return MaterialFactory.color_name(_color)
		Row.PATTERN:
			return Enums.pattern_name(_pattern)
		Row.LENGTH:
			return "%.0f m" % _length
	return _value_text_other(row)


func _value_text_other(row: int) -> String:
	if row == Row.VENDOR:
		var v := Upgrades.unlocked_vendors()
		return str(v[clampi(_vendor, 0, v.size() - 1)]["name"])
	var mat := _current_material()
	return mat.display_name if mat != null else "—"


# --- Rendering -------------------------------------------------------------


func _refresh() -> void:
	_title.text = "Phone  ·  %s" % ("Shop Upgrades" if _mode == 2 else "Order Materials")
	_money.text = "Budget:  $ %d" % GameState.money
	if _mode == 2:
		_refresh_upgrades()
	else:
		_refresh_order()


func _refresh_order() -> void:
	_swatch.visible = true
	var mat := _current_material()
	var cost := _price()
	var afford := GameState.can_afford(cost)
	_money.add_theme_color_override("font_color", Style.INK if afford else Style.CLAY)
	if mat != null:
		_swatch.setup(mat, mat.roll_length_m)
		_name_label.text = mat.display_name
		_summary_label.text = mat.summary()
	_price_label.text = "Order:  $ %d   for %.0f m%s" % [cost, _length, _status]
	_price_label.add_theme_color_override("font_color", Style.FOREST if afford else Style.CLAY)

	var rows := _active_rows()
	_row = clampi(_row, 0, rows.size() - 1)
	for child in _rows.get_children():
		child.queue_free()
	for i in rows.size():
		_rows.add_child(_make_row(rows[i], i == _row))


func _refresh_upgrades() -> void:
	_swatch.visible = false
	_money.add_theme_color_override("font_color", Style.INK)
	_row = clampi(_row, 0, _row_count() - 1)
	# Preview shows the selected upgrade (or the Mode row).
	if _row == 0:
		_name_label.text = "Shop Upgrades"
		_summary_label.text = "Spend your standing on the Row to improve the shop."
		_price_label.text = _status
		_price_label.add_theme_color_override("font_color", Style.INK_SOFT)
	else:
		_show_upgrade_preview(_upg_ids[_row - 1])

	for child in _rows.get_children():
		child.queue_free()
	_rows.add_child(_make_row(Row.MODE, _row == 0))
	for i in _upg_ids.size():
		_rows.add_child(_make_upgrade_row(_upg_ids[i], _row == i + 1))


func _show_upgrade_preview(id: String) -> void:
	var d := Upgrades.data(id)
	_name_label.text = "%s  ·  %s" % [d.get("name", "?"), d.get("category", "")]
	_summary_label.text = str(d.get("desc", ""))
	if Upgrades.has(id):
		_price_label.text = "Owned%s" % _status
		_price_label.add_theme_color_override("font_color", Style.FOREST)
	elif not Upgrades.tier_met(id):
		_price_label.text = "Locked — needs %s%s" % [_tier_name(id), _status]
		_price_label.add_theme_color_override("font_color", Style.CLAY)
	else:
		var cost := int(d.get("cost", 0))
		_price_label.text = "Buy:  $ %d%s" % [cost, _status]
		_price_label.add_theme_color_override(
			"font_color", Style.FOREST if GameState.can_afford(cost) else Style.CLAY
		)


func _tier_name(id: String) -> String:
	var t := int(Upgrades.data(id).get("tier", 0))
	return str(Reputation.TIERS[clampi(t, 0, Reputation.TIERS.size() - 1)]["name"])


func _make_row(row: int, selected: bool) -> Control:
	var card := PanelContainer.new()
	var skin := (
		Style.card(Style.CARD_SELECTED, 12, 3, Style.ACC_ORDER) if selected else Style.card()
	)
	card.add_theme_stylebox_override("panel", skin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var name_label := Label.new()
	name_label.text = ROW_NAME[row]
	name_label.custom_minimum_size = Vector2(120, 0)
	name_label.add_theme_color_override("font_color", Style.INK_SOFT)
	name_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(name_label)
	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text = ("‹  %s  ›" % _value_text(row)) if selected else _value_text(row)
	value.add_theme_color_override("font_color", Style.INK)
	value.add_theme_font_size_override("font_size", 19)
	hbox.add_child(value)
	return card


func _make_upgrade_row(id: String, selected: bool) -> Control:
	var d := Upgrades.data(id)
	var card := PanelContainer.new()
	var skin := (
		Style.card(Style.CARD_SELECTED, 12, 3, Style.ACC_ORDER) if selected else Style.card()
	)
	card.add_theme_stylebox_override("panel", skin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var name_label := Label.new()
	name_label.text = str(d.get("name", "?"))
	name_label.custom_minimum_size = Vector2(220, 0)
	name_label.add_theme_color_override("font_color", Style.INK)
	name_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(name_label)
	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 18)
	if Upgrades.has(id):
		status.text = "Owned ✓"
		status.add_theme_color_override("font_color", Style.FOREST)
	elif not Upgrades.tier_met(id):
		status.text = "🔒"
		status.add_theme_color_override("font_color", Style.CLAY)
	else:
		status.text = "$ %d" % int(d.get("cost", 0))
		status.add_theme_color_override("font_color", Style.INK_SOFT)
	hbox.add_child(status)
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
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _move_row(delta: int) -> void:
	_status = ""
	var n := _row_count()
	_row = (_row + delta + n) % n
	_refresh()


func _adjust(dir: int) -> void:
	_status = ""
	# Row 0 in every mode is the Mode selector.
	if _row == 0:
		_mode = (_mode + dir + MODE_NAMES.size()) % MODE_NAMES.size()
		_row = 0
		_refresh()
		return
	if _mode == 2:
		_refresh()  # upgrades don't cycle values; E buys
		return
	match int(_active_rows()[_row]):
		Row.VENDOR:
			var n := Upgrades.unlocked_vendors().size()
			_vendor = (_vendor + dir + n) % n
			_snap_fabric_to_vendor()
		Row.MATERIAL:
			var n := Catalog.all_materials().size()
			if n > 0:
				_premade = (_premade + dir + n) % n
		Row.FABRIC:
			_cycle_fabric(dir)
		Row.COLOR:
			var c := MaterialFactory.color_count()
			_color = (_color + dir + c) % c
		Row.PATTERN:
			_pattern = (_pattern + dir + Enums.Pattern.size()) % Enums.Pattern.size()
		Row.LENGTH:
			_length = clampf(_length + dir * LENGTH_STEP, LENGTH_MIN, Upgrades.max_roll_length())
	_refresh()


## Step the fabric within the current supplier's offered list (wrapping).
func _cycle_fabric(dir: int) -> void:
	var fabrics := _vendor_fabrics()
	if fabrics.is_empty():
		return
	var idx := fabrics.find(_fabric)
	if idx < 0:
		idx = 0
	_fabric = int(fabrics[(idx + dir + fabrics.size()) % fabrics.size()])


## When the supplier changes, keep the fabric valid for what they carry.
func _snap_fabric_to_vendor() -> void:
	var fabrics := _vendor_fabrics()
	if not fabrics.has(_fabric) and not fabrics.is_empty():
		_fabric = int(fabrics[0])


func _confirm() -> void:
	if _mode == 2:
		_buy_upgrade()
		return
	var mat := _current_material()
	if mat == null:
		return
	var cost := _price()
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
	if _row == 0:
		return
	var id: String = _upg_ids[_row - 1]
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

extends Control

## Phone ordering screen. Two modes:
##  - Premade: pick one of the catalogue rolls.
##  - Custom Maker: choose fabric + colour + pattern yourself.
## Both let you set a length; a live swatch + price update as you change fields.
## W/S select a field, A/D change it, E order (delivered by the phone), Esc close.

enum Row { MODE, MATERIAL, FABRIC, COLOR, PATTERN, LENGTH }

const LENGTH_MIN := 4.0
const LENGTH_MAX := 24.0
const LENGTH_STEP := 2.0
const ROW_NAME := {
	Row.MODE: "Mode",
	Row.MATERIAL: "Roll",
	Row.FABRIC: "Fabric",
	Row.COLOR: "Colour",
	Row.PATTERN: "Pattern",
	Row.LENGTH: "Length",
}

var _phone = null
var _actor = null
var _mode := 0  # 0 = premade, 1 = custom
var _premade := 0
var _fabric := 0
var _color := 0
var _pattern := 0
var _length := 10.0
var _row := 0
var _status := ""
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


func open(phone, actor) -> void:
	_phone = phone
	_actor = actor
	_row = 0
	_status = ""
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
	info.add_child(_summary_label)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 19)
	info.add_child(_price_label)


func _style() -> void:
	# Fixed frame (§3): the order pad keeps its size whether Premade (3 rows) or
	# Custom (5 rows) is showing — the rows region reserves the taller height.
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


## The key-cap hint bar is one-time structure (the raw scene Hint label is retired
## for it); the skin/frame itself is (re)applied by Style.apply_skin() in _style().
func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	_hint.visible = false
	var bar := Style.hint_bar(
		[["W/S", "Select"], ["A/D", "Change"], ["E", "Order"], ["Esc", "Close"]]
	)
	_hint.get_parent().add_child(bar)


# --- State helpers ---------------------------------------------------------


func _active_rows() -> Array:
	if _mode == 0:
		return [Row.MODE, Row.MATERIAL, Row.LENGTH]
	return [Row.MODE, Row.FABRIC, Row.COLOR, Row.PATTERN, Row.LENGTH]


func _current_material() -> MaterialType:
	if _mode == 0:
		var all := Catalog.all_materials()
		if all.is_empty():
			return null
		return all[_premade % all.size()]
	return MaterialFactory.make(_fabric, _pattern, _color, _length)


func _price() -> int:
	var mat := _current_material()
	if mat == null:
		return 0
	return Pricing.roll_price(mat, _length)


func _value_text(row: int) -> String:
	if row == Row.MODE:
		return "Premade" if _mode == 0 else "Custom Maker"
	if row == Row.FABRIC:
		return Enums.fabric_name(_fabric)
	if row == Row.COLOR:
		return MaterialFactory.color_name(_color)
	if row == Row.PATTERN:
		return Enums.pattern_name(_pattern)
	if row == Row.LENGTH:
		return "%.0f m" % _length
	# Row.MATERIAL
	var mat := _current_material()
	return mat.display_name if mat else "—"


# --- Rendering -------------------------------------------------------------


func _refresh() -> void:
	var mat := _current_material()
	var cost := _price()
	var afford := GameState.can_afford(cost)

	_title.text = "Phone  ·  Order Materials"
	_money.text = "Budget:  $ %d" % GameState.money
	_money.add_theme_color_override("font_color", Style.INK if afford else Style.CLAY)

	if mat != null:
		_swatch.setup(mat, mat.roll_length_m)
		_name_label.text = mat.display_name
		_summary_label.text = mat.summary()
	_price_label.text = "Order:  $ %d   for %.0f m%s" % [cost, _length, _status]
	var price_col := Style.FOREST if afford else Style.CLAY
	_price_label.add_theme_color_override("font_color", price_col)

	var rows := _active_rows()
	_row = clampi(_row, 0, rows.size() - 1)
	for child in _rows.get_children():
		child.queue_free()
	for i in rows.size():
		_rows.add_child(_make_row(rows[i], i == _row))


func _make_row(row: int, selected: bool) -> Control:
	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override(
			"panel", Style.card(Style.CARD_SELECTED, 12, 3, Style.ACC_ORDER)
		)
	else:
		card.add_theme_stylebox_override("panel", Style.card())

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
		_order()
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
	var row: int = _active_rows()[_row]
	match row:
		Row.MODE:
			_mode = 1 - _mode
		Row.MATERIAL:
			var n := Catalog.all_materials().size()
			if n > 0:
				_premade = (_premade + dir + n) % n
		Row.FABRIC:
			_fabric = (_fabric + dir + Enums.Fabric.size()) % Enums.Fabric.size()
		Row.COLOR:
			var c := MaterialFactory.color_count()
			_color = (_color + dir + c) % c
		Row.PATTERN:
			_pattern = (_pattern + dir + Enums.Pattern.size()) % Enums.Pattern.size()
		Row.LENGTH:
			_length = clampf(_length + dir * LENGTH_STEP, LENGTH_MIN, LENGTH_MAX)
	_refresh()


func _order() -> void:
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

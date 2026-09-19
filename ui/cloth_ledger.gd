class_name ClothLedger
extends PanelContainer

## The stock-room ledger that sits beside the phone while you order cloth: what the open
## orders still need (and whether the shop has it, or it's already on the way), then
## everything else on the shelves. Read-only — it answers "what do I actually need to
## buy?" without walking to the shelf. Only the panel is a fixed size; the list scrolls.
##   ledger.refresh(phone)

const PANEL := Vector2(340, 470)
const SWATCH := 30

var _head: TitleBlock
var _list: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PANEL
	size = PANEL
	Style.apply_skin(self, Style.MenuSkin.ORDER)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	add_child(box)
	_head = TitleBlock.make("Cloth Ledger", "Stock room", Style.ACC_ORDER)
	box.add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Style.S1)
	scroll.add_child(_list)


func refresh(phone: Node) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries: Array = ClothStock.ledger(get_tree().current_scene, phone).values()
	var needed := entries.filter(func(e: Dictionary) -> bool: return float(e["need"]) > 0.0)
	var spare := entries.filter(
		func(e: Dictionary) -> bool: return float(e["need"]) <= 0.0 and _total(e) > 0.0
	)
	needed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _short(a) > _short(b))
	spare.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _total(a) > _total(b))
	_list.add_child(Style.header("Needed for orders", Style.ACC_ORDER))
	if needed.is_empty():
		_list.add_child(_note("No open order is waiting on cloth."))
	for e: Dictionary in needed:
		_list.add_child(_needed_row(e))
	_list.add_child(Style.header("Also in stock", Style.ACC_ORDER))
	if spare.is_empty():
		_list.add_child(_note("Nothing else on the shelves."))
	for e: Dictionary in spare:
		_list.add_child(_stock_row(e))


## Metres still missing once what's here and what's coming are counted.
func _short(e: Dictionary) -> float:
	return maxf(0.0, float(e["need"]) - _total(e))


func _total(e: Dictionary) -> float:
	return float(e["have"]) + float(e["coming"])


func _needed_row(e: Dictionary) -> Control:
	var need := float(e["need"])
	var have := float(e["have"])
	var word := "In stock"
	var tint := Style.FOREST
	if have + 0.001 < need:
		if _total(e) + 0.001 >= need:
			word = "On the way"
			tint = Style.BRASS
		else:
			word = "Order %.1f m" % _short(e)
			tint = Style.AMBER
	var who := "for " + ", ".join(PackedStringArray(e["orders"] as Array))
	var sub := "Need %.1f m · have %.1f m" % [need, have]
	return _row(e, sub, word, tint, who)


func _stock_row(e: Dictionary) -> Control:
	var sub := "%.1f m" % float(e["have"])
	if float(e["coming"]) > 0.0:
		sub += " · %.1f m on the way" % float(e["coming"])
	return _row(e, sub, "", Style.FOREST, "")


## One cloth: swatch, its name, then the metres line with the status word at its right
## end, and (for needed cloth) who it is for.
func _row(e: Dictionary, sub: String, chip: String, tint: Color, who: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card(Style.CARD, 10))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var mat := e["material"] as MaterialType
	var swatch := MaterialSwatch.new()
	swatch.swatch_size = SWATCH
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(swatch)
	swatch.setup(mat, mat.roll_length_m)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	hbox.add_child(col)
	var nm := Label.new()
	nm.text = mat.display_name
	nm.clip_text = true
	nm.add_theme_font_override("font", Style.font_medium())
	nm.add_theme_font_size_override("font_size", Style.T_CAPTION)
	nm.add_theme_color_override("font_color", Style.INK)
	col.add_child(nm)
	var line := HBoxContainer.new()
	col.add_child(line)
	var metres := _note(sub)
	metres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(metres)
	if chip != "":
		var tag := Label.new()
		tag.text = chip
		tag.add_theme_font_override("font", Style.font_bold())
		tag.add_theme_font_size_override("font_size", Style.T_MICRO)
		tag.add_theme_color_override("font_color", Style.text_accent(tint))
		line.add_child(tag)
	if who != "":
		var names := _note(who)
		names.clip_text = true
		col.add_child(names)
	return card


func _note(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", Style.T_MICRO)
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	return lbl

extends Control

## Browse menu for the clothing rack — the shelf menu's cousin, in the fitting-room
## (MIRROR) theme. Each hung item is a card: garment parts show type/size/quality,
## finished suits show their overall quality, both with a cloth swatch. Press E to
## take the selected one to your hands (which closes the menu). Built in code by
## ui.gd, so no scene file is needed.

var _rack = null
var _actor = null
var _index := 0
var _cards: Array = []

var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func open(rack, actor) -> void:
	_rack = rack
	_actor = actor
	_index = 0
	GameState.input_locked = true
	visible = true
	_rebuild_list()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_rack = null


# --- Structure -------------------------------------------------------------


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Style.FRAME_TALL
	center.add_child(_panel)
	Style.apply_skin(_panel, Style.MenuSkin.MIRROR)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	_panel.add_child(box)

	_title = Style.title_label("Wardrobe", Style.ACC_MIRROR)
	box.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 400)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Style.S2)
	_scroll.add_child(_list)

	box.add_child(Style.hint_bar([["W/S", "Select"], ["E", "Take"], ["Esc", "Close"]]))


# --- List (built once per open; navigation only re-highlights) --------------


func _rebuild_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	_cards.clear()
	var items: Array = _rack.stored
	for i in items.size():
		var card := _make_card(items[i], i == _index)
		_list.add_child(card)
		_cards.append(card)
	_title.text = "Wardrobe  ·  %d hung" % items.size()


func _highlight(old: int) -> void:
	if old >= 0 and old < _cards.size():
		_cards[old].add_theme_stylebox_override("panel", Style.card())
	if _index < 0 or _index >= _cards.size():
		return
	var card: Control = _cards[_index]
	card.add_theme_stylebox_override("panel", Style.card(Style.CARD_SELECTED, 14, 3, Style.ACC_MIRROR))
	if _scroll != null:
		_scroll.ensure_control_visible(card)


func _make_card(item, selected: bool) -> Control:
	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override(
			"panel", Style.card(Style.CARD_SELECTED, 14, 3, Style.ACC_MIRROR)
		)
	else:
		card.add_theme_stylebox_override("panel", Style.card())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S3)
	card.add_child(row)
	row.add_child(_make_swatch(item))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", Style.S1)
	row.add_child(col)

	var title := Label.new()
	title.text = _name_of(item)
	title.add_theme_color_override("font_color", Style.INK)
	title.add_theme_font_size_override("font_size", 21)
	col.add_child(title)

	var sub := Label.new()
	sub.text = _detail_of(item)
	sub.add_theme_color_override("font_color", Style.INK_SOFT)
	sub.add_theme_font_size_override("font_size", 15)
	col.add_child(sub)

	var quality: float = clampf(item.quality if "quality" in item else 1.0, 0.0, 1.0)
	var qlabel := Label.new()
	qlabel.text = "Quality  %d%%" % roundi(quality * 100.0)
	qlabel.add_theme_color_override("font_color", Style.fill_color(quality).darkened(0.25))
	qlabel.add_theme_font_size_override("font_size", 15)
	col.add_child(qlabel)

	return card


func _make_swatch(item) -> Control:
	if item is Suit:
		return _suit_preview(item)
	var mat: MaterialType = _material_of(item)
	if mat != null:
		var swatch := MaterialSwatch.new()
		swatch.setup(mat, mat.roll_length_m)
		return swatch
	return _color_chip(Style.CARD, 84)


## A suit previews every part it was built from — a labelled mini swatch per piece.
func _suit_preview(item) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var any := false
	for t in [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS]:
		if item.parts.has(t):
			box.add_child(_part_swatch(t, item.parts[t]))
			any = true
	if not any:
		var color: Color = item.primary_color if "primary_color" in item else Style.CARD
		return _color_chip(color, 84)
	return box


func _part_swatch(garment_type: int, spec: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", Style.S1)
	var mat: MaterialType = spec.get("material")
	if mat != null:
		var s := MaterialSwatch.new()
		s.swatch_size = 52
		s.setup(mat, mat.roll_length_m)
		col.add_child(s)
	else:
		col.add_child(_color_chip(Style.CARD, 52))
	var lbl := Label.new()
	lbl.text = Enums.garment_type_name(garment_type)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(lbl)
	return col


func _color_chip(color: Color, chip_size: int) -> Control:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(chip_size, chip_size)
	chip.add_theme_stylebox_override("panel", Style.bar(color, 12))
	return chip


func _name_of(item) -> String:
	if item is Suit:
		return "Finished Suit"
	if item is GarmentPiece:
		return Enums.garment_type_name(item.garment_type)
	return "Item"


func _detail_of(item) -> String:
	if item is Suit:
		var n: int = item.parts.size()
		return "Complete  ·  %d piece%s" % [n, "" if n == 1 else "s"]
	if item is GarmentPiece:
		var stage := "Sewn" if item.stage == Enums.Stage.SEWN else "Cut"
		var mat: MaterialType = item.material
		var cloth := mat.summary() if mat != null else "cloth"
		return "Size %s  ·  %s  ·  %s" % [Enums.size_name(item.size), stage, cloth]
	return ""


func _material_of(item) -> MaterialType:
	return item.material if item is GarmentPiece else null


# --- Input -----------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	Sfx.ui(event)
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_move(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_move(-1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_take()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(delta: int) -> void:
	var n: int = _rack.stored.size()
	if n == 0:
		return
	var old := _index
	_index = (_index + delta + n) % n
	_highlight(old)


func _take() -> void:
	if _rack.stored.size() == 0:
		close()
		return
	# Taking fills your hands, so close on success.
	if _rack.take(_index, _actor):
		close()

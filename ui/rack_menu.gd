extends Control

## Browse menu for the clothing rack — the shelf menu's cousin, in the fitting-room
## (MIRROR) theme. Each hung item is a card: garment parts show type/size/quality,
## finished suits show their overall quality, both with a cloth swatch, and a set of
## parts gathered for one order shows whose it is and what's still to come. Press E to
## take the selected item to your hands (which closes the menu), or on a set to take it
## apart onto separate hooks (the menu stays open). Built in code by ui.gd, so no scene
## file is needed.

const KICKER := "Fitting room"

var _rack = null
var _actor = null
var _index := 0
var _cards: Array = []

var _panel: PanelContainer
var _head: TitleBlock
var _hung_meta: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _hints: Control


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
	dim.color = Style.SCRIM
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

	_head = TitleBlock.make("Wardrobe", KICKER, Style.ACC_MIRROR)
	box.add_child(_head)
	_hung_meta = TitleBlock.meta_label("", true)
	_head.meta.add_child(_hung_meta)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 400)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Style.S2)
	_scroll.add_child(_list)

	_hints = Style.hint_bar(_hint_pairs())
	MousePick.wire_hint(_hints, -1, _click_close)
	box.add_child(_hints)


## E takes the selected item — or, on a set, takes it apart.
func _hint_pairs() -> Array:
	var verb := "Take apart" if _selected() is GarmentSet else "Take"
	return [["W/S", "Select"], ["E", verb], ["Esc", "Close"]]


func _refresh_hints() -> void:
	if _hints == null:
		return
	var fresh := Style.hint_bar(_hint_pairs())
	MousePick.wire_hint(fresh, -1, _click_close)
	_hints.add_sibling(fresh)
	_hints.queue_free()
	_hints = fresh
	MousePick.release(self)  # a right click anywhere reaches _unhandled_input as Esc


func _selected() -> Node:
	if _rack == null or _index < 0 or _index >= _rack.stored.size():
		return null
	return _rack.stored[_index]


# --- List (built once per open; navigation only re-highlights) --------------


func _rebuild_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	_cards.clear()
	var items: Array = _rack.stored
	if items.is_empty():
		_list.add_child(
			EmptyNote.make(
				"Nothing hanging yet.\nSewn parts and finished suits hang here for pickup."
			)
		)
	for i in items.size():
		var card := _make_card(items[i], i)
		MousePick.wire(card, _pick.bind(i), _click.bind(i))
		_list.add_child(card)
		_cards.append(card)
	_hung_meta.text = "%d hung" % items.size()
	_refresh_hints()


func _highlight(old: int) -> void:
	if old >= 0 and old < _cards.size():
		_tag_look(_cards[old], false)
	if _index < 0 or _index >= _cards.size():
		return
	var card: CraftPanel = _cards[_index]
	_tag_look(card, true)
	if old != _index:
		Craft.flourish(card)
	if _scroll != null:
		_scroll.ensure_control_visible(card)
	_refresh_hints()


## Hung items read as price tags on the rail; the selected one is brass-edged.
func _tag_look(card: CraftPanel, selected: bool) -> void:
	card.fill = Style.CARD_SELECTED if selected else Style.CARD
	card.line = Style.ACC_MIRROR if selected else Style.CREAM_DARK
	card.line_width = 3.0 if selected else 1.5
	card.stitch_color = Style.CREAM_DARK
	card.queue_redraw()


func _make_card(item, index: int) -> Control:
	var card := CraftPanel.new()
	card.eyelet = true
	card.setup(CraftPanel.Shape.PRICE_TAG, Style.CARD)
	_tag_look(card, index == _index)

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
	title.add_theme_font_override("font", Style.font_medium())
	title.add_theme_color_override("font_color", Style.INK)
	title.add_theme_font_size_override("font_size", Style.T_NAME)
	col.add_child(title)

	var sub := Label.new()
	sub.text = _detail_of(item)
	if _rack.is_loose(index):
		sub.text += "  ·  taken apart"
	sub.add_theme_color_override("font_color", Style.INK_SOFT)
	sub.add_theme_font_size_override("font_size", Style.T_CAPTION)
	col.add_child(sub)

	var quality: float = clampf(_quality_of(item), 0.0, 1.0)
	var qlabel := Label.new()
	qlabel.text = "Quality  %d%%" % roundi(quality * 100.0)
	qlabel.add_theme_color_override("font_color", Style.fill_color(quality).darkened(0.25))
	qlabel.add_theme_font_size_override("font_size", Style.T_CAPTION)
	col.add_child(qlabel)

	return card


func _quality_of(item) -> float:
	if item is GarmentSet:
		return item.average_quality()
	return item.quality if "quality" in item else 1.0


func _make_swatch(item) -> Control:
	if item is Suit:
		return _suit_preview(item)
	if item is GarmentSet:
		return _set_preview(item)
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


## A set previews the parts on its hanger, like a suit does.
func _set_preview(item) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for piece: Node in item.pieces:
		box.add_child(_part_swatch(int(piece.garment_type), {"material": piece.material}))
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
	lbl.add_theme_font_size_override("font_size", Style.T_MICRO)
	col.add_child(lbl)
	return col


func _color_chip(color: Color, chip_size: int) -> Control:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(chip_size, chip_size)
	chip.add_theme_stylebox_override("panel", Style.bar(color, 12))
	return chip


func _name_of(item) -> String:
	if item is GarmentSet and item.order_id <= 0:
		return "Spare parts"
	if item is GarmentSet:
		var who: String = item.customer_name()
		return "Order #%d" % item.order_id + ("  ·  %s" % who if who != "" else "")
	if item is Suit and item.order_id <= 0:
		return "Finished Suit"
	if item is Suit:
		var who: String = item.customer_name()
		return "Suit for order #%d" % item.order_id + ("  ·  %s" % who if who != "" else "")
	if item is GarmentPiece:
		return "%s  ·  %s" % [Enums.garment_type_name(item.garment_type), _piece_state(item)]
	return "Item"


## Why a part hangs alone: not sewn yet, made for an order, or a spare that fits none.
func _piece_state(item) -> String:
	if item.stage != Enums.Stage.SEWN:
		return "not sewn yet"
	if int(item.order_id) > 0:
		return "order #%d" % int(item.order_id)
	return "spare"


func _detail_of(item) -> String:
	if item is GarmentSet:
		return _set_detail(item)
	if item is Suit:
		var n: int = item.parts.size()
		return "Complete  ·  %d piece%s" % [n, "" if n == 1 else "s"]
	if item is GarmentPiece:
		var stage := "Sewn" if item.stage == Enums.Stage.SEWN else "Cut"
		var mat: MaterialType = item.material
		var cloth := mat.summary() if mat != null else "cloth"
		return "Size %s  ·  %s  ·  %s" % [Enums.size_name(item.size), stage, cloth]
	return ""


## "Jacket + Shirt  ·  Trousers still to come".
func _set_detail(item) -> String:
	var have: Array[String] = []
	for piece: Node in item.pieces:
		have.append(Enums.garment_type_name(int(piece.garment_type)))
	var left: Array[String] = []
	for t in item.missing():
		left.append(Enums.garment_type_name(t))
	var still := "order no longer open" if item.customer_name() == "" else "all here"
	if not left.is_empty():
		still = "%s still to come" % ", ".join(left)
	return "%s  ·  %s" % [" + ".join(have), still]


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
	elif (
		event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
		or MousePick.is_back(event)
	):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## The Esc pill clicked: close, as Esc does.
func _click_close() -> void:
	if visible:
		Sfx.ui_cancel()
		close()


## An item pointed at: the same step as W/S landing on it.
func _pick(index: int) -> void:
	if not visible or _rack == null or index == _index or index >= _rack.stored.size():
		return
	Sfx.ui_move()
	_move(index - _index)


## An item clicked: select it and take it (or take the set apart), like E.
func _click(index: int) -> void:
	if not visible or _rack == null or index >= _rack.stored.size():
		return
	_pick(index)
	Sfx.ui_confirm()
	_take()


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
	if _selected() is GarmentSet:
		_take_apart()
		return
	# Taking fills your hands, so close on success.
	if _rack.take(_index, _actor):
		close()


## Spread the selected set over free hooks and stay open, so a part can be taken next.
func _take_apart() -> void:
	if not _rack.take_apart(_index):
		Sfx.play("error")
		UI.toast("No free hooks to take it apart onto")
		return
	Sfx.play("cloth_rustle", -3.0)
	_rebuild_list()

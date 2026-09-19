extends Control

## Talking to Percy, the apprentice: what he's up to, how good he's getting, and a card
## for every part of every open order — pick one (E) and he goes off to make it from the
## matching bolt on the shelf. Parts with no matching cloth are shown but greyed, with
## the reason, so the list doubles as a "what cloth do I need" reminder. WORK skin, like
## the benches. Built in code by ui.gd.

const KICKER := "Apprentice"

var _bench = null
var _index := 0
var _cards: Array = []
var _jobs: Array = []

var _panel: PanelContainer
var _head: TitleBlock
var _skill: Label
var _now: Label
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func open(bench, _actor) -> void:
	_bench = bench
	_index = 0
	GameState.input_locked = true
	visible = true
	_rebuild()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_bench = null


# --- Structure -------------------------------------------------------------


func _build() -> void:
	add_child(Style.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Style.FRAME_TALL
	center.add_child(_panel)
	Style.apply_skin(_panel, Style.MenuSkin.WORK)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	_panel.add_child(box)

	_head = TitleBlock.make("Percy", KICKER, Style.ACC_WORK)
	box.add_child(_head)
	_skill = _line(box, Style.T_CAPTION, Style.INK_SOFT)
	_now = _line(box, Style.T_BODY, Style.INK)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 330)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Style.S2)
	_scroll.add_child(_list)

	box.add_child(
		Style.hint_bar([["W/S", "Select"], ["E", "Give him this part"], ["Esc", "Close"]])
	)


func _line(parent: Control, size_px: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	_cards.clear()
	_skill.text = (
		"Cutting %d%%   ·   Sewing %d%%   ·   %d pieces made"
		% [
			roundi(_bench.skill("cut") * 100.0),
			roundi(_bench.skill("sew") * 100.0),
			_bench.sew_jobs,
		]
	)
	if _bench.is_busy():
		_now.text = "On it now: %s  —  %s" % [_bench.current_job_text(), _bench.status_text()]
	elif _bench.has_finished_piece():
		_now.text = "A finished piece is waiting on his tray — take it first."
	else:
		_now.text = "Free — pick a part for him to make."
	_jobs = _bench.available_jobs()
	if _jobs.is_empty():
		_list.add_child(EmptyNote.make("No open orders need a part right now."))
	for i in _jobs.size():
		var card := _make_card(_jobs[i], i == _index)
		_list.add_child(card)
		_cards.append(card)


func _make_card(job: Dictionary, selected: bool) -> Control:
	var card := CraftPanel.new()
	card.setup(CraftPanel.Shape.TICKET, Style.CARD)
	_card_look(card, selected, job["cloth"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S3)
	card.add_child(row)
	var order: SuitOrder = job["order"]
	var mat := order.part_material(job["type"])
	if mat != null:
		var swatch := MaterialSwatch.new()
		swatch.swatch_size = 56
		swatch.setup(mat, mat.roll_length_m)
		row.add_child(swatch)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var head := _line(col, 19, Style.INK)
	head.text = (
		"#%d  %s — %s" % [order.id, order.customer_name, Enums.garment_type_name(job["type"])]
	)
	var sub := _line(col, 14, Style.INK_SOFT if job["cloth"] else Style.CLAY)
	var cloth := mat.display_name if mat != null else "cloth"
	sub.text = (
		"%s  ·  on the shelf ✓" % cloth
		if job["cloth"]
		else "%s  ·  no matching bolt on the shelf" % cloth
	)
	return card


func _card_look(card: CraftPanel, selected: bool, ok: bool) -> void:
	card.fill = Style.CARD_SELECTED if selected else Style.CARD
	card.line = Style.ACC_WORK if selected else Style.CREAM_DARK
	card.line_width = 3.0 if selected else 1.5
	card.modulate.a = 1.0 if ok else 0.7
	card.queue_redraw()


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
		_give()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(delta: int) -> void:
	if _jobs.is_empty():
		return
	var old := _index
	_index = (_index + delta + _jobs.size()) % _jobs.size()
	_card_look(_cards[old], false, _jobs[old]["cloth"])
	_card_look(_cards[_index], true, _jobs[_index]["cloth"])
	Craft.wiggle(_cards[_index], 2.0)
	_scroll.ensure_control_visible(_cards[_index])


func _give() -> void:
	if _jobs.is_empty():
		close()
		return
	var job: Dictionary = _jobs[_index]
	var why: String = _bench.assign(job["order"], job["type"])
	if why == "":
		close()
		return
	Sfx.play("error")
	Craft.wiggle(_cards[_index], 4.0)
	_now.text = why

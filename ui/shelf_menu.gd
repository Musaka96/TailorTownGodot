extends Control

## Animal-Crossing-styled browse menu for a shelf. Each stored roll is a card
## with a layered swatch, name, fabric/pattern and %-left. You can take a whole
## bolt (E) or measure and cut a piece (A/D to measure in 0.1 m steps — hold to run —
## F to cut) to carry to the worktable. Each part needs its own length, shown under the
## title. Taking or cutting fills your hands, so the menu closes after.

const CUT_STEP := 0.1
const CUT_START := 2.0
const KICKER := "Bolt shelf"

var _shelf = null
var _actor = null
var _index := 0
var _cut_length := 1.0
var _decor_built := false
var _scroll: ScrollContainer
var _cards: Array = []  # one card per stored roll, built once per open
var _tape: TapeMeasure
var _fits_label: Label
var _head: TitleBlock
var _rolls_meta: Label
var _cut_meta: Label

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint
@onready var _list: VBoxContainer = $Center/Panel/Margin/Box/List


func open(shelf, actor) -> void:
	_shelf = shelf
	_actor = actor
	_index = 0
	_cut_length = CUT_START
	GameState.input_locked = true
	visible = true
	_style()
	_clamp_cut()
	_rebuild_list()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_shelf = null


func _style() -> void:
	_panel.custom_minimum_size = Style.FRAME_TALL
	Style.apply_skin(_panel, Style.MenuSkin.SHELF)
	if _head == null:
		_head = TitleBlock.adopt(_title, KICKER, Style.ACC_SHELF)
	_list.add_theme_constant_override("separation", Style.S2)
	_build_decor_once()


## One-time structure: scroll wrapper around the roll list (so a full shelf can't
## grow the panel) and the key-cap hint bar. Skin/frame is applied in _style().
func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	var box := _list.get_parent()
	var pos := _list.get_index()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.remove_child(_list)
	scroll.add_child(_list)
	box.add_child(scroll)
	box.move_child(scroll, pos)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = scroll
	_hint.visible = false
	var pairs := [
		["W/S", "Select"],
		["A/D", "Measure"],
		["F", "Cut"],
		["E", "Take roll"],
		["Esc", "Close"],
	]
	box.add_child(Style.hint_bar(pairs))
	# Roll count + current cut length: the one sanctioned home is the title's meta row.
	_rolls_meta = TitleBlock.meta_label("", true)
	_head.meta.add_child(_rolls_meta)
	_cut_meta = TitleBlock.meta_label("", true)
	_head.meta.add_child(_cut_meta)
	# Measuring guide under the title: what each part takes, and what this cut covers.
	var head_pos := _head.get_index()
	_tape = TapeMeasure.new()
	box.add_child(_tape)
	box.move_child(_tape, head_pos + 1)
	_fits_label = Label.new()
	_fits_label.add_theme_font_override("font", Style.font_bold())
	_fits_label.add_theme_font_size_override("font_size", Style.T_BODY)
	box.add_child(_fits_label)
	box.move_child(_fits_label, head_pos + 2)


## Build the whole card list once (on open). The roll set doesn't change while
## browsing — cutting or taking closes the menu — so navigation never rebuilds;
## it just re-highlights and scrolls persistent, already-laid-out cards, which
## makes ensure_control_visible reliable in both directions.
func _rebuild_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	_cards.clear()
	var rolls: Array = _shelf.stored
	if rolls.is_empty():
		_list.add_child(
			EmptyNote.make(
				"This shelf is empty.\nOrder a bolt on the phone, then store it here (E).",
				EmptyNote.Icon.BOLT
			)
		)
	for i in rolls.size():
		var card := _make_card(rolls[i], i == _index)
		_list.add_child(card)
		_cards.append(card)
	_update_title()


func _update_title() -> void:
	_title.text = "Shelf"
	_rolls_meta.text = (
		"%d roll%s" % [_shelf.stored.size(), "" if _shelf.stored.size() == 1 else "s"]
	)
	_cut_meta.text = "cutting %.1f m" % _cut_length
	_update_measure()


## "Size M takes: jacket 2.0 m · trousers 1.4 m · shirt 1.6 m", then which parts the
## current cut covers (or that it covers none).
func _update_measure() -> void:
	if _tape == null:
		return
	var parts := [Enums.GarmentType.PANTS, Enums.GarmentType.SHIRT, Enums.GarmentType.JACKET]
	var marks := {}
	var fits := PackedStringArray()
	for t in parts:
		var need := Pricing.part_meters(t, Enums.Size.M)
		var nm := Enums.garment_type_name(t).to_lower()
		marks[need] = nm
		if _cut_length + 0.001 >= need:
			fits.append(nm)
	_tape.marks = marks
	_tape.set_value(_cut_length)
	if fits.is_empty():
		_fits_label.text = "%.1f m is too short for any part" % _cut_length
		_fits_label.add_theme_color_override("font_color", Style.CLAY)
	else:
		_fits_label.text = "%.1f m is enough for: %s" % [_cut_length, ", ".join(fits)]
		_fits_label.add_theme_color_override("font_color", Style.FOREST)


## Move the highlight from `old` to the current `_index` and scroll it into view.
## Cards are already laid out, so no wait is needed and it follows both ways.
func _highlight(old: int) -> void:
	if old >= 0 and old < _cards.size():
		_card_look(_cards[old], false)
	if _index < 0 or _index >= _cards.size():
		return
	var card: CraftPanel = _cards[_index]
	_card_look(card, true)
	if old != _index:
		Craft.flourish(card)
	if _scroll != null:
		_scroll.ensure_control_visible(card)


## Selected sample: brighter paper, a forest outline and a burgundy pin.
func _card_look(card: CraftPanel, selected: bool) -> void:
	card.fill = Style.CARD_SELECTED if selected else Style.CARD
	card.line = Style.ACC_SHELF if selected else Style.CREAM_DARK
	card.line_width = 3.0 if selected else 1.5
	card.stitch_color = Style.ACC_SHELF if selected else Style.CREAM_DARK
	card.pin_color = Style.BURGUNDY if selected else Style.NONE
	card.queue_redraw()


func _make_card(roll, selected: bool) -> Control:
	var mat = roll.material

	# A cloth sample card cut with pinking shears.
	var card := CraftPanel.new()
	card.pad = Vector2(Style.S3, Style.S2)
	card.setup(CraftPanel.Shape.PINKED, Style.CARD)
	_card_look(card, selected)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S3)
	card.add_child(row)

	var swatch := MaterialSwatch.new()
	swatch.setup(mat, roll.remaining_length_m)
	row.add_child(swatch)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", Style.S1)
	row.add_child(col)

	var name_label := Label.new()
	name_label.text = mat.display_name
	name_label.add_theme_color_override("font_color", Style.INK)
	name_label.add_theme_font_size_override("font_size", 21)
	col.add_child(name_label)

	var sub := Label.new()
	sub.text = mat.summary()
	sub.add_theme_color_override("font_color", Style.INK_SOFT)
	sub.add_theme_font_size_override("font_size", 15)
	col.add_child(sub)

	var frac: float = roll.remaining_length_m / maxf(mat.roll_length_m, 0.001)
	var left := Label.new()
	left.text = (
		"%.1f / %.1f m left  (%d%%)"
		% [roll.remaining_length_m, mat.roll_length_m, roundi(frac * 100.0)]
	)
	left.add_theme_color_override("font_color", Style.fill_color(frac).darkened(0.25))
	left.add_theme_font_size_override("font_size", 15)
	col.add_child(left)

	return card


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	Sfx.ui(event)
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_move(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_move(-1)
	elif event.is_action_pressed("move_right", true):
		_adjust_cut(CUT_STEP)
	elif event.is_action_pressed("move_left", true):
		_adjust_cut(-CUT_STEP)
	elif event.is_action_pressed("cut"):
		_do_cut()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_take()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(delta: int) -> void:
	var n: int = _shelf.stored.size()
	if n == 0:
		return
	var old := _index
	_index = (_index + delta + n) % n
	_clamp_cut()
	_highlight(old)
	_update_title()


func _adjust_cut(delta: float) -> void:
	_cut_length += delta
	_clamp_cut()
	_update_title()


## The shortest cut allowed: enough for the smallest part (pants, size S) — or size M
## during the tutorial, so a first-timer can't make a piece that fits nothing.
func _cut_min() -> float:
	var size := Enums.Size.M if Tutorial != null and Tutorial.is_active() else Enums.Size.S
	return Pricing.part_meters(Enums.GarmentType.PANTS, size)


## Keep the requested cut length within [the shortest useful cut, the roll's remaining].
func _clamp_cut() -> void:
	var rolls: Array = _shelf.stored
	if _index < 0 or _index >= rolls.size():
		return
	var remaining: float = rolls[_index].remaining_length_m
	var low := _cut_min()
	_cut_length = snappedf(clampf(_cut_length, low, maxf(low, remaining)), CUT_STEP)


func _take() -> void:
	if _shelf.stored.size() == 0:
		close()
		return
	# Taking a bolt fills your hands, so close on success.
	if _shelf.take(_index, _actor):
		close()


func _do_cut() -> void:
	if _shelf.stored.size() == 0:
		close()
		return
	# Refuse a cut the bolt can't cover (too little left for even the smallest part).
	var remaining: float = _shelf.stored[_index].remaining_length_m
	if remaining + 0.001 < _cut_length:
		Sfx.play("error")
		UI.toast("Only %.1f m left on this bolt — take the roll instead" % remaining)
		return
	# Cutting fills your hands with the piece, so close on success.
	if _shelf.cut_piece(_index, _cut_length, _actor):
		close()

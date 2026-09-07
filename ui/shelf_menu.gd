extends Control

## Animal-Crossing-styled browse menu for a shelf. Each stored roll is a card
## with a layered swatch, name, fabric/pattern and %-left. You can take a whole
## bolt (E) or cut a piece of a chosen length (A/D to set, F to cut) to carry to
## the worktable. Taking or cutting fills your hands, so the menu closes after.

const CUT_STEP := 0.5
const CUT_MIN := 0.5

var _shelf = null
var _actor = null
var _index := 0
var _cut_length := 1.0

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint
@onready var _list: VBoxContainer = $Center/Panel/Margin/Box/List


func open(shelf, actor) -> void:
	_shelf = shelf
	_actor = actor
	_index = 0
	_cut_length = 1.0
	GameState.input_locked = true
	visible = true
	_style()
	_clamp_cut()
	_rebuild()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_shelf = null


func _style() -> void:
	_panel.add_theme_stylebox_override("panel", Style.panel())
	_title.add_theme_color_override("font_color", Style.INK)
	_title.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", Style.INK_SOFT)
	_hint.add_theme_font_size_override("font_size", 15)
	_list.add_theme_constant_override("separation", Style.S2)


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()

	var rolls: Array = _shelf.stored
	_title.text = "Shelf  ·  %d rolls" % rolls.size()
	_hint.text = ("W/S select    A/D cut length ‹%.1f m›    F cut    E take roll    Esc close"
		% _cut_length)

	for i in rolls.size():
		_list.add_child(_make_card(rolls[i], i == _index))


func _make_card(roll, selected: bool) -> Control:
	var mat = roll.material

	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override("panel", Style.card(Style.CARD_SELECTED, 14, 3, Style.LEAF))
	else:
		card.add_theme_stylebox_override("panel", Style.card())

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
	left.text = "%.1f / %.1f m left  (%d%%)" % [
		roll.remaining_length_m, mat.roll_length_m, roundi(frac * 100.0)]
	left.add_theme_color_override("font_color", Style.fill_color(frac).darkened(0.25))
	left.add_theme_font_size_override("font_size", 15)
	col.add_child(left)

	return card


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_move(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_move(-1)
	elif event.is_action_pressed("move_right"):
		_adjust_cut(CUT_STEP)
	elif event.is_action_pressed("move_left"):
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
	_index = (_index + delta + n) % n
	_clamp_cut()
	_rebuild()


func _adjust_cut(delta: float) -> void:
	_cut_length += delta
	_clamp_cut()
	_rebuild()


## Keep the requested cut length within [0.5 m, the selected roll's remaining].
func _clamp_cut() -> void:
	var rolls: Array = _shelf.stored
	if _index < 0 or _index >= rolls.size():
		return
	var remaining: float = rolls[_index].remaining_length_m
	_cut_length = clampf(_cut_length, CUT_MIN, maxf(CUT_MIN, remaining))


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
	# Cutting fills your hands with the piece, so close on success.
	if _shelf.cut_piece(_index, _cut_length, _actor):
		close()

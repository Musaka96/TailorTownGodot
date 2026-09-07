extends Control

## Two-phase worktable screen: configure the garment (type / size / style), then
## run the cutting minigame. Applies the result back to the worktable.

enum Row { TYPE, SIZE, STYLE }
const ROW_NAME := {Row.TYPE: "Type", Row.SIZE: "Size", Row.STYLE: "Style"}

var _worktable = null
var _actor = null
var _piece = null
var _type := 0
var _size := 1   # M
var _style_idx := 0
var _row := 0
var _swatch: MaterialSwatch
var _name_label: Label
var _sub_label: Label
var _minigame: CuttingMinigame

@onready var _config: Control = $Config
@onready var _panel: PanelContainer = $Config/Center/Panel
@onready var _title: Label = $Config/Center/Panel/Margin/Box/Title
@onready var _preview: HBoxContainer = $Config/Center/Panel/Margin/Box/Preview
@onready var _rows: VBoxContainer = $Config/Center/Panel/Margin/Box/Rows
@onready var _hint: Label = $Config/Center/Panel/Margin/Box/Hint


func _ready() -> void:
	_build_preview()


func open(worktable, actor, piece) -> void:
	_worktable = worktable
	_actor = actor
	_piece = piece
	_row = 0
	GameState.input_locked = true
	visible = true
	_config.visible = true
	if _minigame:
		_minigame.visible = false
		_minigame.set_process(false)
	_style()
	_refresh()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_worktable = null
	_piece = null


func _build_preview() -> void:
	_swatch = MaterialSwatch.new()
	_swatch.swatch_size = 96
	_preview.add_child(_swatch)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview.add_child(info)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	info.add_child(_name_label)
	_sub_label = Label.new()
	_sub_label.add_theme_font_size_override("font_size", 15)
	info.add_child(_sub_label)


func _style() -> void:
	_panel.add_theme_stylebox_override("panel", Style.panel())
	_preview.add_theme_constant_override("separation", Style.S3)
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Style.INK)
	_name_label.add_theme_color_override("font_color", Style.INK)
	_sub_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Style.INK_SOFT)
	_rows.add_theme_constant_override("separation", Style.S1)


func _styles() -> PackedStringArray:
	return Enums.styles_for(_type)


func _value_text(row: int) -> String:
	if row == Row.TYPE:
		return Enums.garment_type_name(_type)
	if row == Row.SIZE:
		return Enums.size_name(_size)
	return _styles()[_style_idx]


func _refresh() -> void:
	_title.text = "Worktable  ·  Make a Part"
	if _piece != null and _piece.material != null:
		_swatch.setup(_piece.material, _piece.material.roll_length_m)
		_name_label.text = _piece.material.display_name
	_sub_label.text = "%s  ·  Size %s  ·  %s" % [
		Enums.garment_type_name(_type), Enums.size_name(_size), _styles()[_style_idx]]
	_hint.text = "W/S select    A/D change    E start cutting    Esc cancel"

	for child in _rows.get_children():
		child.queue_free()
	for i in 3:
		_rows.add_child(_make_row(i, i == _row))


func _make_row(row: int, selected: bool) -> Control:
	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override("panel", Style.card(Style.CARD_SELECTED, 12, 3, Style.LEAF))
	else:
		card.add_theme_stylebox_override("panel", Style.card())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	var name_label := Label.new()
	name_label.text = ROW_NAME[row]
	name_label.custom_minimum_size = Vector2(110, 0)
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _config.visible:
		return  # minigame handles its own input while it's up
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_row = (_row + 1) % 3
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_row = (_row + 2) % 3
	elif event.is_action_pressed("move_right"):
		_adjust(1)
	elif event.is_action_pressed("move_left"):
		_adjust(-1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_start_cutting()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh()


func _adjust(dir: int) -> void:
	match _row:
		Row.TYPE:
			_type = (_type + dir + 3) % 3
			_style_idx = 0  # styles differ per type
		Row.SIZE:
			_size = (_size + dir + 4) % 4
		Row.STYLE:
			var n := _styles().size()
			_style_idx = (_style_idx + dir + n) % n


func _start_cutting() -> void:
	_config.visible = false
	if _minigame == null:
		_minigame = CuttingMinigame.new()
		add_child(_minigame)
		_minigame.finished.connect(_on_cut_finished)
	_minigame.visible = true
	_minigame.start(_type, "%s · %s" % [Enums.garment_type_name(_type), Enums.size_name(_size)])


func _on_cut_finished(success: bool, quality: float) -> void:
	if _minigame:
		_minigame.visible = false
	var style: String = _styles()[_style_idx]
	if _worktable:
		_worktable.finish_cut(success, _type, _size, style, quality)
	close()

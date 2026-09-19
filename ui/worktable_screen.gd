extends Control

## Two-phase worktable screen: configure the garment (type / size / style), then
## run the cutting minigame. Applies the result back to the worktable.

enum Row { TYPE, SIZE, STYLE }
const ROW_NAME := {Row.TYPE: "Type", Row.SIZE: "Size", Row.STYLE: "Style"}
const KICKER := "The bench"

var _worktable = null
var _actor = null
var _piece = null
var _type := 0
var _size := 1  # M
var _style_idx := 0
var _row := 0
var _swatch: MaterialSwatch
var _name_label: Label
var _sub_label: Label
var _cloth_label: Label
var _minigame: MinigameScreen
var _minigame_variant := -1
var _decor_built := false
var _head: TitleBlock

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
	_size = int(Enums.Size.M)
	_type = _best_fit_type()
	_style_idx = 0
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
	_name_label.add_theme_font_override("font", Style.font_medium())
	_name_label.add_theme_font_size_override("font_size", Style.T_NAME)
	info.add_child(_name_label)
	_sub_label = Label.new()
	_sub_label.add_theme_font_override("font", Style.font_body())
	_sub_label.add_theme_font_size_override("font_size", Style.T_CAPTION)
	info.add_child(_sub_label)
	_cloth_label = Label.new()
	_cloth_label.add_theme_font_size_override("font_size", Style.T_CAPTION)
	info.add_child(_cloth_label)


func _style() -> void:
	_panel.custom_minimum_size = Vector2(700, 0)
	Style.apply_skin(_panel, Style.MenuSkin.WORK)
	_preview.add_theme_constant_override("separation", Style.S3)
	if _head == null:
		_head = TitleBlock.adopt(_title, KICKER, Style.ACC_WORK)
	_name_label.add_theme_color_override("font_color", Style.INK)
	_sub_label.add_theme_color_override("font_color", Style.INK_SOFT)
	_rows.add_theme_constant_override("separation", Style.S1)
	_build_decor_once()


func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	_hint.visible = false
	(
		_hint
		. get_parent()
		. add_child(
			(
				Style
				. hint_bar(
					[
						["W/S", "Select"],
						["A/D", "Change"],
						["E", "Start cutting"],
						["F", "Take back"],
						["Esc", "Cancel"],
					]
				)
			)
		)
	)


func _styles() -> PackedStringArray:
	return Enums.styles_for(_type)


func _value_text(row: int) -> String:
	if row == Row.TYPE:
		return Enums.garment_type_name(_type)
	if row == Row.SIZE:
		return Enums.size_name(_size)
	return _styles()[_style_idx]


func _refresh() -> void:
	_title.text = "Make a part"
	if _piece != null and _piece.material != null:
		_swatch.setup(_piece.material, _piece.material.roll_length_m)
		_name_label.text = _piece.material.display_name
	_sub_label.text = (
		"%s  ·  Size %s  ·  %s"
		% [Enums.garment_type_name(_type), Enums.size_name(_size), _styles()[_style_idx]]
	)

	_refresh_cloth()

	for child in _rows.get_children():
		child.queue_free()
	for i in 3:
		_rows.add_child(_make_row(i, i == _row))


func _make_row(row: int, selected: bool) -> Control:
	var card := CraftPanel.option(selected, Style.ACC_WORK)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", Style.S2)
	card.add_child(hbox)
	Style.field_row(hbox, ROW_NAME[row], _value_text(row), selected)
	return card


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _config.visible:
		return  # minigame handles its own input while it's up
	Sfx.ui(event)
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
	elif event.is_action_pressed("cut"):
		# Changed your mind: pick the cloth back up off the table.
		if _worktable != null and _worktable.take_back(_actor):
			Sfx.play("pickup")
			close()
			return
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


## "Needs 1.6 m · piece 2.0 m · 0.4 m offcut" — green when it fits snugly, amber when
## cloth will be wasted, red when the piece is too short to cut this part.
func _refresh_cloth() -> void:
	var need := Pricing.part_meters(_type, _size)
	var have: float = _piece.length_m if _piece != null else 0.0
	var spare := have - need
	if spare < -0.001:
		_cloth_label.text = "Too short: needs %.1f m, piece is %.1f m" % [need, have]
		_cloth_label.add_theme_color_override("font_color", Style.CLAY)
	elif spare < 0.05:
		_cloth_label.text = "Needs %.1f m  ·  piece %.1f m  ·  a perfect fit" % [need, have]
		_cloth_label.add_theme_color_override("font_color", Style.FOREST)
	else:
		_cloth_label.text = (
			"Needs %.1f m  ·  piece %.1f m  ·  %.1f m offcut wasted" % [need, have, spare]
		)
		_cloth_label.add_theme_color_override("font_color", Style.AMBER)


## The part this piece suits best: the one it covers with the least cloth left over
## (size M), falling back to the smallest part if it covers none.
func _best_fit_type() -> int:
	var have: float = _piece.length_m if _piece != null else 0.0
	var best := int(Enums.GarmentType.PANTS)
	var best_spare := INF
	for t in 3:
		var spare := have - Pricing.part_meters(t, int(Enums.Size.M))
		if spare >= -0.001 and spare < best_spare:
			best_spare = spare
			best = t
	return best


func _start_cutting() -> void:
	if _worktable != null and not _worktable.has_cloth_for(_type, _size):
		Sfx.play("error")
		var tw := create_tween()
		for dx in [6.0, -6.0, 4.0, 0.0]:
			tw.tween_property(_cloth_label, "position:x", dx, 0.04).as_relative()
		return
	_config.visible = false
	var variant := CutVariants.current()
	if _minigame == null or _minigame_variant != variant:
		if _minigame != null:
			_minigame.queue_free()
		_minigame = CutVariants.create(variant)
		_minigame_variant = variant
		add_child(_minigame)
		_minigame.connect("finished", _on_cut_finished)
	_minigame.visible = true
	var title := "%s · %s" % [Enums.garment_type_name(_type), Enums.size_name(_size)]
	var cloth: MaterialType = _piece.material if _piece != null else null
	_minigame.call("start", _type, title, cloth)


func _on_cut_finished(success: bool, quality: float) -> void:
	if _minigame:
		_minigame.visible = false
	var style: String = _styles()[_style_idx]
	if _worktable:
		_worktable.finish_cut(success, _type, _size, style, quality)
	close()

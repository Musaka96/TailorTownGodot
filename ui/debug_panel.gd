class_name DebugPanel
extends Control

## The look of the F3 debug panel (debug builds only). The Debug autoload
## (globals/debug_menu.gd) owns every action and fills this through the builders below:
## section() for a headed group, row() for one labelled line (the name in a shared column
## on the left, its control on the right), then button() / slider() / option() / ... into
## that row. This file owns the surface: the WORK skin on a fixed frame docked top-left
## under the HUD's clock, one scrolling column of sections, a note line and the key pills.
## The checklists (upgrades, renovation projects) open as fixed side panels to its right.
## Everything is sized by the player's Menus interface size (UiScale).

signal close_requested

const TITLE := "Debug"
const KICKER := "Test bench  ·  F3"
## The main column and the side lists. Only these frames are fixed; their content scrolls.
## The height gives way on a short window (or a big HUD) so the frame always fits.
const FRAME := Vector2(480, 720)
const SIDE_FRAME := Vector2(340, 720)
## The shared name column every row lines up on.
const LABEL_W := 118
## The least height of any control (reference px, before the interface size).
const CONTROL_H := 32
## How tall the HUD's clock + reputation block is at HUD size 1.0: the panel starts under
## it, so the clock stays readable and the player (mid-screen) stays in view.
const HUD_CLOCK_H := 212.0

var _columns: HBoxContainer
var _panel: PanelContainer
var _content: VBoxContainer
var _note: Label
var _sides: Array[SidePanel] = []


## One side list: a skinned frame with a title, a row of tools and a scrolling list.
class SidePanel:
	extends PanelContainer
	var tools: HFlowContainer
	var list: VBoxContainer


func _init() -> void:
	name = "DebugPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns = HBoxContainer.new()
	_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns.add_theme_constant_override("separation", Style.S2)
	_columns.theme = _make_theme()
	add_child(_columns)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = FRAME
	_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	Style.apply_skin(_panel, Style.MenuSkin.WORK)
	_columns.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	_panel.add_child(box)

	var head := TitleBlock.make(TITLE, KICKER, Style.ACC_WORK)
	button(head.right, "Close", close_requested.emit)
	box.add_child(head)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", Style.S4)
	box.add_child(_scroll(_content))

	_note = _label("", Style.INK_SOFT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note)
	var bar := Style.hint_bar([["F3", "Close"], ["Esc", "Close"]])
	MousePick.wire_hint(bar, -1, close_requested.emit)
	box.add_child(bar)

	UiScale.attach(_columns, UiScale.MENUS, Vector2.ZERO)  # toward its top-left corner


func _ready() -> void:
	get_viewport().size_changed.connect(fit_to_screen)
	var settings := _settings()
	if settings != null:
		settings.connect("ui_scale_changed", func(_c: String, _v: float) -> void: fit_to_screen())


## Size the frames to the window and dock them top-left, under the HUD clock, down to
## the bottom margin. Call on open (the Debug autoload does), never per frame.
func fit_to_screen() -> void:
	var view := get_viewport_rect().size
	var s := maxf(UiScale.target_scale(_columns).y, 0.01)
	var settings := _settings()
	var hud := float(settings.call("ui_scale_of", UiScale.HUD)) if settings != null else 1.0
	var top := Style.S3 + HUD_CLOCK_H * hud
	var h := minf(FRAME.y, (view.y - top - Style.S3) / s)
	_panel.custom_minimum_size = Vector2(FRAME.x, h)
	for side in _sides:
		side.custom_minimum_size = Vector2(SIDE_FRAME.x, h)
	_columns.reset_size()
	_columns.position = Vector2(Style.S3, top)
	UiScale.apply(_columns)


## The status line under the list: what the last action did.
func note(text: String) -> void:
	_note.text = text


func note_text() -> String:
	return _note.text


# --- Builders -------------------------------------------------------------------


## A headed group of rows in the main column.
func section(title: String) -> VBoxContainer:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", Style.S2)
	sec.add_child(Style.header(title, Style.ACC_WORK))
	_content.add_child(sec)
	return sec


## One labelled line: `label` in the shared name column, then the returned slot for its
## control(s), which wrap onto a second line rather than widen the frame.
func row(parent: Control, label: String) -> HFlowContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Style.S2)
	var name_lbl := _label(label, Style.INK)
	name_lbl.custom_minimum_size = Vector2(LABEL_W, CONTROL_H)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # beside the first line of a wrap
	line.add_child(name_lbl)
	var slot := HFlowContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("h_separation", Style.S2)
	slot.add_theme_constant_override("v_separation", Style.S2)
	line.add_child(slot)
	parent.add_child(line)
	return slot


func button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, CONTROL_H)
	b.focus_mode = Control.FOCUS_CLICK
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## A tick in a side list: a toggle button that reads pressed (brass) when on.
func toggle(parent: Control, text: String, cb: Callable) -> Button:
	var b := button(parent, text, func() -> void: pass)
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggled.connect(cb)
	return b


## The value a row reports (money, points, a readout), in bold ink.
func value(parent: Control, text: String) -> Label:
	var lbl := _label(text, Style.INK)
	lbl.add_theme_font_override("font", Style.font_bold())
	lbl.custom_minimum_size = Vector2(0, CONTROL_H)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	return lbl


## Body text spanning the row (e.g. a status summary), wrapped to the column.
func text(parent: Control, body: String) -> Label:
	var lbl := _label(body, Style.INK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)
	return lbl


func line_edit(parent: Control, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(LABEL_W, CONTROL_H)
	parent.add_child(edit)
	return edit


func option(parent: Control, items: Array, selected: int, cb: Callable) -> OptionButton:
	var pick := OptionButton.new()
	for item: Variant in items:
		pick.add_item(str(item))
	pick.custom_minimum_size = Vector2(0, CONTROL_H)
	pick.focus_mode = Control.FOCUS_CLICK
	if selected >= 0 and selected < items.size():
		pick.selected = selected
	pick.item_selected.connect(cb)
	parent.add_child(pick)
	return pick


## A slider that fills its row, live as it drags.
func slider(parent: Control, lo: float, hi: float, step: float, at: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = at
	s.custom_minimum_size = Vector2(LABEL_W * 2, CONTROL_H)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_CLICK
	s.value_changed.connect(cb)
	parent.add_child(s)
	return s


## A fixed side panel to the right of the main column (hidden until set_side()).
func side(title: String) -> SidePanel:
	var panel := SidePanel.new()
	panel.custom_minimum_size = SIDE_FRAME
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.visible = false
	Style.apply_skin(panel, Style.MenuSkin.WORK)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	panel.add_child(box)
	box.add_child(TitleBlock.make(title, "Debug", Style.ACC_WORK))
	panel.tools = HFlowContainer.new()
	panel.tools.add_theme_constant_override("h_separation", Style.S2)
	panel.tools.add_theme_constant_override("v_separation", Style.S2)
	box.add_child(panel.tools)
	panel.list = VBoxContainer.new()
	panel.list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.list.add_theme_constant_override("separation", Style.S1)
	box.add_child(_scroll(panel.list))
	_columns.add_child(panel)
	_sides.append(panel)
	return panel


## A group heading inside a side list.
func list_heading(parent: Control, title: String) -> void:
	var head := Style.header(title, Style.ACC_WORK)
	head.custom_minimum_size = Vector2(0, CONTROL_H)
	head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	parent.add_child(head)


func set_side(panel: SidePanel, on: bool) -> void:
	panel.visible = on
	fit_to_screen()


# --- Internals --------------------------------------------------------------------


## The Settings autoload by path: headless tool scripts compile this file (through the
## Debug autoload's type hints) before autoload names exist.
func _settings() -> Node:
	return get_node_or_null("/root/Settings")


func _scroll(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


func _label(body: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = body
	lbl.add_theme_font_size_override("font_size", Style.T_BODY)
	lbl.add_theme_color_override("font_color", col)
	return lbl


## The atelier form controls, set in the body face at body size (buttons in medium), plus
## paper-coloured text fields and a lit state for toggles that are on.
func _make_theme() -> Theme:
	var t := Style.form_theme()
	t.default_font = Style.font_body()
	t.default_font_size = Style.T_BODY
	for cls in ["Button", "OptionButton"]:
		t.set_font("font", cls, Style.font_medium())
		t.set_stylebox("hover_pressed", cls, t.get_stylebox("pressed", cls))
		t.set_color("font_hover_pressed_color", cls, Style.INK)
	var field := StyleBoxFlat.new()
	field.bg_color = Style.CARD
	field.set_corner_radius_all(8)
	field.set_border_width_all(2)
	field.border_color = Style.CREAM_DARK
	field.content_margin_left = Style.S2
	field.content_margin_right = Style.S2
	var lit := field.duplicate() as StyleBoxFlat
	lit.border_color = Style.BRASS
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", lit)
	t.set_color("font_color", "LineEdit", Style.INK)
	t.set_color("font_placeholder_color", "LineEdit", Style.INK_SOFT)
	t.set_color("caret_color", "LineEdit", Style.INK)
	return t

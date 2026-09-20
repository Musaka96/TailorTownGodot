extends Control

## A sheet of paper held up to read: one of grandpa's letters, or everything on the memory
## shelf. Deliberately not the morning paper — that is printed and public, this is his hand.
## Opened by `open(title, body)`; Esc or E folds it away. Built in code like the other menus.

const PAPER_W := 560.0
const N_TITLE := 22
const N_BODY := 15
const OPEN_GUARD := 0.35  # so the press that opened it can't close it again

var _title: Label
var _body: RichTextLabel
var _hint: Label
var _panel: PanelContainer
var _opened_at := 0.0
var _on_closed := Callable()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


## Show `body` under `title`. `on_closed` runs once it is folded away.
func open(title: String, body: String, on_closed := Callable()) -> void:
	_title.text = title
	_body.text = body
	_on_closed = on_closed
	_opened_at = Time.get_ticks_msec() / 1000.0
	GameState.input_locked = true  # not is_paused: that is the pause menu's own flag
	visible = true
	Sfx.play("page_turn")


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.input_locked = false
	Sfx.play("page_turn")
	var done := _on_closed
	_on_closed = Callable()
	if done.is_valid():
		done.call()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if Time.get_ticks_msec() / 1000.0 - _opened_at < OPEN_GUARD:
		return
	if event.is_action("ui_cancel") or event.is_action("interact") or event.is_action("pause"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Sheet"
	_panel.custom_minimum_size = Vector2(PAPER_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.PAPER
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	sb.border_color = Style.WALNUT
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 8)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", Style.S4)
	margin.add_theme_constant_override("margin_right", Style.S4)
	margin.add_theme_constant_override("margin_top", Style.S3)
	margin.add_theme_constant_override("margin_bottom", Style.S3)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	margin.add_child(box)

	_title = Label.new()
	_title.add_theme_font_override("font", Style.font_display())
	_title.add_theme_font_size_override("font_size", N_TITLE)
	_title.add_theme_color_override("font_color", Style.INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	var rule := ColorRect.new()
	rule.color = Style.INK
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(PAPER_W - Style.S4 * 2, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_override("normal_font", Style.font_body())
	_body.add_theme_font_size_override("normal_font_size", N_BODY)
	_body.add_theme_color_override("default_color", Style.INK)
	scroll.add_child(_body)

	_hint = Label.new()
	_hint.text = "Esc — fold it away"
	_hint.add_theme_font_override("font", Style.font_medium())
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Style.tint(Style.INK, 0.55))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)

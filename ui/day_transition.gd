extends Control

## Full-screen day-change animation played by UI between shifts: fade to a night
## card ("Day N complete" + today's earnings), switch the text to the new day and
## fire the switch callback (which resets the world/clock), then fade back in and
## fire the done callback. Purely visual; ShiftManager supplies the callbacks.

const BG := Color(0.05, 0.06, 0.12, 1.0)

var _title: Label
var _subtitle: Label  # the plain half of the line ("Earnings today: " / "The shop…")
var _subtitle_money: Label  # the bold, forest figure — shown only alongside earnings
var _on_switch := Callable()
var _on_done := Callable()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# The day's summary hangs like the shop's sign on the night street.
	var sign := PanelContainer.new()
	sign.custom_minimum_size = Vector2(460, 0)
	center.add_child(sign)
	UiScale.attach(sign, UiScale.MENUS)
	SignBoard.dress(sign)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	sign.add_child(box)

	_title = _make_label(Style.T_HERO, Style.WALNUT, Style.font_display())
	box.add_child(_title)

	var subtitle_row := HBoxContainer.new()
	subtitle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	subtitle_row.add_theme_constant_override("separation", Style.S1)
	box.add_child(subtitle_row)
	_subtitle = _make_label(Style.T_NAME, Style.FOREST, Style.font_medium())
	subtitle_row.add_child(_subtitle)
	# Money is always bold, even here on the night sign.
	_subtitle_money = _make_label(Style.T_NAME, Style.FOREST, Style.font_bold())
	subtitle_row.add_child(_subtitle_money)


func play(old_day: int, new_day: int, earned: int, on_switch: Callable, on_done: Callable) -> void:
	_on_switch = on_switch
	_on_done = on_done
	_title.text = "Day %d complete" % old_day
	_subtitle.text = "Earnings today:  "
	_subtitle_money.text = "$%d" % earned
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.2)
	tw.tween_callback(_switch.bind(new_day))
	tw.tween_interval(1.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_finish)


func _switch(new_day: int) -> void:
	_title.text = "Day %d" % new_day
	_subtitle.text = "The shop opens at midday"
	_subtitle_money.text = ""
	if _on_switch.is_valid():
		_on_switch.call()


func _finish() -> void:
	visible = false
	if _on_done.is_valid():
		_on_done.call()


func _make_label(font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

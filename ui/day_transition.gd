extends Control

## Full-screen day-change animation played by UI between shifts: fade to a night
## card ("Day N complete" + today's earnings), switch the text to the new day and
## fire the switch callback (which resets the world/clock), then fade back in and
## fire the done callback. Purely visual; ShiftManager supplies the callbacks.

const BG := Color(0.05, 0.06, 0.12, 1.0)
const TITLE_COL := Color(0.97, 0.93, 0.85)
const SUB_COL := Color(0.75, 0.80, 0.95)

var _title: Label
var _subtitle: Label
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

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	_title = _make_label(52, TITLE_COL)
	box.add_child(_title)
	_subtitle = _make_label(22, SUB_COL)
	box.add_child(_subtitle)


func play(
	old_day: int, new_day: int, earned: int, on_switch: Callable, on_done: Callable
) -> void:
	_on_switch = on_switch
	_on_done = on_done
	_title.text = "Day %d complete" % old_day
	_subtitle.text = "Earnings today:  $%d" % earned
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
	if _on_switch.is_valid():
		_on_switch.call()


func _finish() -> void:
	visible = false
	if _on_done.is_valid():
		_on_done.call()


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

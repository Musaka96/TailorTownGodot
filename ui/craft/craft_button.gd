class_name CraftButton
extends Button

## A button that looks like a sewn-on fabric label: cream cloth with a running stitch;
## on hover/focus it turns brass, grows a touch and gives a little wiggle. The label is
## drawn by a backdrop child behind the button (so the text stays on top).

const GROW := 1.04

var _back: Control
var _lit := false


func _init() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = Style.S3
		sb.content_margin_right = Style.S3
		sb.content_margin_top = Style.S2
		sb.content_margin_bottom = Style.S2
		add_theme_stylebox_override(state, sb)
	_back = _Backdrop.new()
	add_child(_back)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	mouse_entered.connect(_refresh)
	mouse_exited.connect(_refresh)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _process(_delta: float) -> void:
	_back.queue_redraw()


func is_lit() -> bool:
	return not disabled and (has_focus() or is_hovered())


func _refresh() -> void:
	var lit := is_lit()
	if lit == _lit:
		return
	_lit = lit
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE * (GROW if lit else 1.0), 0.15)
	if lit:
		Craft.wiggle(self, 1.5)
		pivot_offset = size * 0.5


class _Backdrop:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var b := get_parent() as CraftButton
		if b == null:
			return
		var lit := b.is_lit()
		var fill := Style.BRASS if lit else Style.CARD
		var line := Style.WALNUT if lit else Style.CREAM_DARK
		if b.disabled:
			fill = Style.PAPER
		elif b.button_pressed or (lit and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			fill = fill.darkened(0.1)
		var poly := Craft.rounded(Rect2(Vector2.ZERO, size), 10.0)
		Craft.card(self, poly, fill, line, 2.0)
		Craft.stitch(self, poly, Style.WALNUT if lit else Style.CREAM_DARK, 5.0, 1.2)

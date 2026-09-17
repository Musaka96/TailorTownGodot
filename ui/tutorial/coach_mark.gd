class_name CoachMark
extends Control

## A tiny callout for the tutorial: a short brass pill ("Press F to cut") with a
## bobbing arrow pointing at one control inside an open menu (usually a key-cap in the
## menu's hint bar). Full-screen and mouse-transparent; call point_at() every frame
## with the target's global rect, or clear() to hide it.

const GAP := 34.0  # distance between the pill and the target
const BOB := 4.0

var _pill: PanelContainer
var _label: Label
var _target := Rect2()
var _above := true
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.BRASS
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Style.WALNUT
	sb.content_margin_left = Style.S3
	sb.content_margin_right = Style.S3
	sb.content_margin_top = Style.S1
	sb.content_margin_bottom = Style.S1
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	_pill.add_theme_stylebox_override("panel", sb)
	add_child(_pill)
	_label = Label.new()
	_label.add_theme_font_override("font", Style.bold_font())
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Style.WALNUT)
	_pill.add_child(_label)
	visible = false


## Aim at `target` (global rect) with `text` in the pill.
func point_at(target: Rect2, text: String) -> void:
	if _label.text != text:
		_label.text = text
		_pill.reset_size()
	_target = target
	# Prefer hanging below the target (key hints sit at the bottom of a menu, so the space
	# under them is free); go above when there's no room left at the screen bottom.
	var room_below := get_viewport_rect().size.y - (target.end.y + GAP + _pill.size.y)
	_above = room_below < 8.0
	visible = true
	queue_redraw()


func clear() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var bob := sin(_time * 6.0) * BOB
	var cx := _target.get_center().x - _pill.size.x * 0.5
	cx = clampf(cx, 8.0, get_viewport_rect().size.x - _pill.size.x - 8.0)
	var y := _target.position.y - GAP - _pill.size.y + bob if _above else _target.end.y + GAP + bob
	_pill.position = Vector2(cx, y)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var tip := Vector2(
		_target.get_center().x, _target.position.y - 3.0 if _above else _target.end.y + 3.0
	)
	var start := Vector2(tip.x, _pill.position.y + (_pill.size.y if _above else 0.0))
	var dir := 1.0 if _above else -1.0
	draw_line(start, tip - Vector2(0, 7.0 * dir), Style.WALNUT, 3.0, true)
	var head := PackedVector2Array(
		[tip, tip + Vector2(-7.0, -9.0 * dir), tip + Vector2(7.0, -9.0 * dir)]
	)
	draw_colored_polygon(head, Style.BRASS)
	head.append(tip)
	draw_polyline(head, Style.WALNUT, 2.0, true)

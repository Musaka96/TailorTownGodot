class_name GoalTag
extends PanelContainer

## The tutorial's current-goal card, drawn as a kraft swing ticket (notched top
## corners, punched hole, a loop of string) so it reads as its own thing next to the
## paper menus. One short goal plus a 2–3 item checklist that ticks itself off live.
## The Tutorial positions it (clear of whatever menu is open) via move_to().

const WIDTH := 236.0
const NOTCH := 16.0
const HOLE_Y := 15.0
const TILT_DEG := -1.5
const GLIDE := 10.0  # how fast it slides to a new spot

var _step_label: Label
var _goal: Label
var _list: VBoxContainer
var _checks: Array[TagCheck] = []
var _target := Vector2.ZERO
var _placed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = Style.S3
	sb.content_margin_right = Style.S3
	sb.content_margin_top = HOLE_Y + Style.S3 + 2
	sb.content_margin_bottom = Style.S3
	add_theme_stylebox_override("panel", sb)
	rotation_degrees = TILT_DEG
	resized.connect(_on_resized)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S1 + 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", Style.T_MICRO)
	_step_label.add_theme_color_override("font_color", Style.BURGUNDY)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_step_label)
	_goal = Label.new()
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.add_theme_font_override("font", Style.bold_font())
	_goal.add_theme_font_size_override("font_size", Style.T_BODY)
	_goal.add_theme_color_override("font_color", Style.WALNUT)
	box.add_child(_goal)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", Style.S1)
	box.add_child(_list)
	visible = false


## Show a goal. `items` are the checklist lines (plain text).
func set_goal(step_text: String, goal: String, items: PackedStringArray) -> void:
	_step_label.text = step_text.to_upper()
	_goal.text = goal
	for c in _list.get_children():
		c.queue_free()
	_checks.clear()
	for line in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Style.S2)
		var check := TagCheck.new()
		row.add_child(check)
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", Style.T_CAPTION)
		lbl.add_theme_color_override("font_color", Style.INK)
		row.add_child(lbl)
		_list.add_child(row)
		_checks.append(check)
	reset_size()
	visible = true
	_pop()


## Tick (or un-tick) checklist line `index`. Ticking plays a small pop.
func set_done(index: int, done: bool) -> void:
	if index < 0 or index >= _checks.size():
		return
	var check := _checks[index]
	if check.done == done:
		return
	check.set_done(done)
	var lbl := check.get_parent().get_child(1) as Label
	lbl.add_theme_color_override("font_color", Style.INK_SOFT if done else Style.INK)
	if done:
		Sfx.play("pin_in", -6.0, 1.05, 1.15)


## Slide toward a screen position (top-left of the tag). Snaps on first placement.
func move_to(pos: Vector2) -> void:
	_target = pos
	if not _placed:
		position = pos
		_placed = true


func _process(delta: float) -> void:
	if not visible:
		return
	# Wrapped labels report a tall minimum before their width is known, and a Control
	# never shrinks on its own — so keep the card hugging its content.
	var want := get_combined_minimum_size()
	if not size.is_equal_approx(want):
		size = want
	position = position.lerp(_target, clampf(GLIDE * delta, 0.0, 1.0))


func _pop() -> void:
	var rest := UiScale.target_scale(self)
	scale = rest * 0.85
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", rest, 0.28)


func _on_resized() -> void:
	pivot_offset = Vector2(size.x * 0.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var poly := Craft.ticket(Rect2(Vector2.ZERO, size), NOTCH)
	Craft.card(self, poly, Style.CORK, Style.WALNUT)
	Craft.stitch(self, poly, Style.PAPER)
	Craft.eyelet(self, Vector2(size.x * 0.5, HOLE_Y))


## A little hand-drawn checkbox that ticks with a pop.
class TagCheck:
	extends Control

	var done := false

	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = Vector2(9, 9)

	func set_done(on: bool) -> void:
		done = on
		queue_redraw()
		if on:
			scale = Vector2(1.5, 1.5)
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), Vector2(16, 16))
		draw_rect(r, Style.CREAM if not done else Style.FOREST, true)
		draw_rect(r, Style.WALNUT, false, 1.5)
		if done:
			var pts := PackedVector2Array([Vector2(4, 9), Vector2(8, 13), Vector2(14, 4)])
			draw_polyline(pts, Style.CHALK, 2.5, true)

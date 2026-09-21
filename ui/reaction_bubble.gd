class_name ReactionBubble
extends PanelContainer

## What the customer at the fitting mirror says about the design, in a speech bubble at
## his shoulder: a thumbs up (forest) or down (clay) badge, the verdict, and — for a no —
## each thing that's wrong with what would do instead. The tail points at his head and
## follows it as the camera moves. Only the bubble is a fixed width; the text wraps.
##   ReactionBubble.show_for(host, customer, head_height, happy, lines)

const WIDTH := 280.0
const BADGE := 46.0
const GAP := 70.0  # px from the head to the bubble's near edge
const CLEAR := 36.0  # the bubble's near edge never comes closer to the head's centre
const EDGE := 16.0  # keep this far inside the screen / the panel

var target: Node3D
var head_height := 1.8
## The area the bubble must stay inside (screen px) — left of the builder's panel.
var bounds := Rect2()
var _happy := true
var _tail: Control


static func show_for(
	host: Control, who: Node3D, at_height: float, happy: bool, lines: PackedStringArray
) -> ReactionBubble:
	var bubble := ReactionBubble.new()
	bubble.target = who
	bubble.head_height = at_height
	bubble._happy = happy
	bubble._build(lines)
	host.add_child(bubble)
	bubble._follow()
	Craft.pop_in(bubble, 0.7, 0.22)
	return bubble


## Fade out and go.
func dismiss() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _build(lines: PackedStringArray) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.CREAM
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Style.BROWN
	sb.set_content_margin_all(Style.S3)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", sb)
	_tail = Control.new()
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.show_behind_parent = true
	_tail.draw.connect(_draw_tail)
	add_child(_tail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S3)
	add_child(row)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(BADGE, BADGE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.draw.connect(_draw_badge.bind(badge))
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wrapping labels need a real width, or they measure themselves one letter wide.
	var text_w := WIDTH - BADGE - Style.S3 * 3.0
	col.add_theme_constant_override("separation", Style.S1)
	row.add_child(col)
	for i in lines.size():
		var lbl := Label.new()
		lbl.text = lines[i]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(text_w, 0)
		var head := i == 0
		lbl.add_theme_font_override("font", Style.font_bold() if head else Style.font_body())
		lbl.add_theme_font_size_override("font_size", Style.T_BODY if head else Style.T_CAPTION)
		lbl.add_theme_color_override("font_color", Style.INK if head else Style.INK_SOFT)
		col.add_child(lbl)


func _process(_delta: float) -> void:
	_follow()


## Sit beside the head (towards the free side of the screen), inside `bounds`.
func _follow() -> void:
	if target == null or not is_instance_valid(target):
		dismiss()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := cam.unproject_position(target.global_position + Vector3.UP * head_height)
	var box := get_combined_minimum_size()
	if size.y > box.y + 1.0:
		size = box  # never taller than the words
	var area := bounds if bounds.has_area() else get_viewport_rect()
	# Beside the head on the free side, slid in to fit; the other side if that would cover
	# the face; above the head if neither side has the room.
	var at := Vector2(minf(head.x + GAP, area.end.x - box.x - EDGE), head.y - box.y * 0.35)
	if at.x < head.x + CLEAR:
		at.x = head.x - GAP - box.x
		if at.x < area.position.x + EDGE:
			at = Vector2(head.x - box.x * 0.5, head.y - box.y - GAP)
	at.x = clampf(at.x, area.position.x + EDGE, maxf(area.position.x, area.end.x - box.x - EDGE))
	at.y = clampf(at.y, area.position.y + EDGE, maxf(area.position.y, area.end.y - box.y - EDGE))
	global_position = at
	_tail.set_meta("head", head)
	_tail.size = size
	_tail.queue_redraw()


## A wedge from the bubble's near side to just short of the head.
func _draw_tail() -> void:
	if not _tail.has_meta("head"):
		return
	var head: Vector2 = _tail.get_meta("head") - global_position
	var pts := PackedVector2Array()
	if head.y > size.y and head.x > 0.0 and head.x < size.x:
		# Sitting above the head: the wedge hangs from the bottom edge.
		var root := Vector2(clampf(head.x, 24.0, size.x - 24.0), size.y)
		pts = PackedVector2Array(
			[root + Vector2(-12, 0), root.lerp(head, 0.5), root + Vector2(12, 0)]
		)
	else:
		var x := 0.0 if head.x < size.x * 0.5 else size.x
		var root := Vector2(x, clampf(head.y, 24.0, size.y - 24.0))
		pts = PackedVector2Array(
			[root + Vector2(0, -12), root.lerp(head, 0.55), root + Vector2(0, 12)]
		)
	_tail.draw_colored_polygon(pts, Style.CREAM)
	_tail.draw_polyline(pts, Style.BROWN, 2.0, true)


## A round badge with a drawn thumb: up on forest for a yes, down on clay for a no.
func _draw_badge(badge: Control) -> void:
	var c := badge.size * 0.5
	var r := minf(c.x, c.y)
	badge.draw_circle(c + Vector2(0, 2), r, Style.SHADOW)
	badge.draw_circle(c, r, Style.FOREST if _happy else Style.CLAY)
	badge.draw_circle(c, r - 3.0, Style.tint(Style.CHALK, 0.18), false, 1.5, true)
	var flip := 1.0 if _happy else -1.0
	var u := r / 20.0  # the thumb is drawn in a 40-unit box
	var ink := Style.CHALK
	# The fist: a rounded block, knuckles to the right.
	var fist := Rect2(c + Vector2(-9, -2 * flip - (0 if _happy else 12)) * u, Vector2(18, 14) * u)
	badge.draw_colored_polygon(Craft.rounded(fist, 3.5 * u), ink)
	# The cuff, to the left of the fist.
	var cuff := Rect2(fist.position + Vector2(-6, 1) * u, Vector2(5, 12) * u)
	badge.draw_colored_polygon(Craft.rounded(cuff, 1.5 * u), ink)
	# The thumb, rising (or hanging) from the top of the fist.
	var base := Vector2(fist.position.x + 5.5 * u, fist.position.y if _happy else fist.end.y)
	var thumb := PackedVector2Array(
		[
			base + Vector2(-3.5, 0) * u,
			base + Vector2(-2.0, -11 * flip) * u,
			base + Vector2(2.5, -12 * flip) * u,
			base + Vector2(4.0, 0) * u,
		]
	)
	badge.draw_colored_polygon(thumb, ink)
	# Finger creases on the fist.
	var crease := Style.FOREST if _happy else Style.CLAY
	for i in 3:
		var y := fist.position.y + (4.5 + 3.5 * i) * u
		badge.draw_line(
			Vector2(fist.end.x - 7 * u, y), Vector2(fist.end.x - 1.5 * u, y), crease, 1.2 * u
		)

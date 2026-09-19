class_name WorldBubble
extends PanelContainer

## A short line of speech floating over someone in the world — the player's pitch on the
## street, a passer-by's reply. The same cream bubble and tail as the greeting bubble, in
## miniature; it pops in over `who`, follows them, and clears itself after `seconds`.
##   WorldBubble.say(passer_by, "Do I look like I wear suits?", 2.4)

const MAX_W := 300.0
const HEIGHT := 2.75  # metres over the feet


static func say(who: Node3D, text: String, seconds := 2.4) -> WorldBubble:
	var bubble := WorldBubble.new()
	bubble._build(text)
	WorldAnchor.pin(who, bubble, HEIGHT)
	Craft.pop_in(bubble, 0.7, 0.18)
	bubble._expire_after(seconds)
	return bubble


func _build(text: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.CREAM
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Style.BROWN
	sb.content_margin_left = Style.S3
	sb.content_margin_right = Style.S3
	sb.content_margin_top = Style.S2
	sb.content_margin_bottom = Style.S2
	add_theme_stylebox_override("panel", sb)
	var tail := SpeechTail.new()
	add_child(tail)
	tail.setup(Style.CREAM, Style.BROWN)
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", Style.font_medium())
	lbl.add_theme_font_size_override("font_size", Style.T_CAPTION)
	lbl.add_theme_color_override("font_color", Style.INK)
	var font := Style.font_medium()
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_CAPTION).x
	if wide > MAX_W:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(MAX_W, 0)
	add_child(lbl)
	# Leave room under the panel for the tail, so it points at the speaker's head.
	custom_minimum_size = Vector2(0, 0)


func _expire_after(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_clear)


func _clear() -> void:
	var holder := get_parent()
	if holder is WorldAnchor:
		holder.queue_free()
	else:
		queue_free()

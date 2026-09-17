class_name EmptyNote
extends VBoxContainer

## A friendly empty-state for a list: a little drawn icon (a coat hanger or a bolt of
## cloth) above a short, helpful line of text.

enum Icon { HANGER, BOLT }


static func make(text: String, icon: int = Icon.HANGER) -> EmptyNote:
	var note := EmptyNote.new()
	note.alignment = BoxContainer.ALIGNMENT_CENTER
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.add_theme_constant_override("separation", Style.S3)
	var pic := _Pic.new()
	pic.icon = icon
	note.add_child(pic)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	note.add_child(lbl)
	return note


class _Pic:
	extends Control

	var icon := 0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 50)
		draw_set_transform(c, sin(_t * 1.6) * 0.06, Vector2.ONE)
		if icon == Icon.HANGER:
			_hanger()
		else:
			_bolt()
		draw_set_transform(Vector2.ZERO)

	func _hanger() -> void:
		var hook := PackedVector2Array()
		for i in 10:
			var a := PI * 1.1 + i * 0.16
			hook.append(Vector2(cos(a), sin(a)) * 9.0 + Vector2(0, -28))
		hook.append(Vector2(0, -12))
		draw_polyline(hook, Style.BRASS, 4.0, true)
		var body := PackedVector2Array(
			[Vector2(0, -12), Vector2(-46, 18), Vector2(46, 18), Vector2(0, -12)]
		)
		draw_polyline(body, Style.BROWN, 5.0, true)

	func _bolt() -> void:
		var r := Rect2(Vector2(-44, -22), Vector2(88, 44))
		Craft.card(self, Craft.rounded(r, 10.0), Style.PATCH, Style.WALNUT)
		for i in 5:
			var x := r.position.x + 14.0 + i * 15.0
			draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4), Style.CREAM_DARK, 1.0)
		draw_circle(Vector2(r.end.x, 0), 22.0, Style.PATCH)
		draw_arc(Vector2(r.end.x, 0), 22.0, 0, TAU, 24, Style.WALNUT, 2.0, true)
		draw_arc(Vector2(r.end.x, 0), 12.0, 0, TAU, 20, Style.CREAM_DARK, 1.5, true)
		draw_circle(Vector2(r.end.x, 0), 4.0, Style.WALNUT)

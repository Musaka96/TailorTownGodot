class_name MenuKit

## Small shared builders for the front-of-house menus (main menu + pause menu) so
## they share one atelier button/slot look. Colours and spacing come from Style.

const BTN_WIDE := Vector2(340, 46)
const SLOT_WIDE := Vector2(440, 52)


## A styled atelier button. `cb` is connected to `pressed` when valid.
static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN_WIDE
	b.add_theme_font_override("font", Style.bold_font())
	b.add_theme_font_size_override("font_size", 18)
	for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(role, Style.INK)
	b.add_theme_color_override("font_disabled_color", Style.INK_SOFT)
	b.add_theme_stylebox_override("normal", _box(Style.CARD, Style.CREAM_DARK))
	b.add_theme_stylebox_override("hover", _box(Style.CARD_SELECTED, Style.BRASS))
	b.add_theme_stylebox_override("pressed", _box(Style.PAPER, Style.BRASS))
	b.add_theme_stylebox_override("focus", _box(Style.CARD_SELECTED, Style.BRASS))
	b.add_theme_stylebox_override("disabled", _box(Style.PAPER, Style.CREAM_DARK))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## A save-slot button labelled with the slot's day/money/time, or "empty".
static func slot_row(info: Dictionary, cb: Callable) -> Button:
	var b := button(_slot_text(info), cb)
	b.custom_minimum_size = SLOT_WIDE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not bool(info.get("exists", false)):
		b.add_theme_color_override("font_color", Style.INK_SOFT)
	return b


static func _slot_text(info: Dictionary) -> String:
	var label := "Slot %s" % str(info.get("slot", "?"))
	if not bool(info.get("exists", false)):
		return "%s  —  empty" % label
	return (
		"%s  ·  Day %d  ·  $%d  ·  %d rep  ·  %s"
		% [
			label,
			int(info.get("day", 1)),
			int(info.get("money", 0)),
			int(info.get("reputation", 0)),
			_short_time(str(info.get("saved_at", ""))),
		]
	)


## "2026-09-09T21:14:03" -> "09-09 21:14" (best-effort; returns the input on miss).
static func _short_time(stamp: String) -> String:
	if stamp.length() < 16 or not stamp.contains("T"):
		return stamp
	return "%s %s" % [stamp.substr(5, 5), stamp.substr(11, 5)]


# --- Navigation ------------------------------------------------------------


## Extra keyboard/controller nav for a column of buttons, on top of Godot's
## built-in arrow/D-pad/stick focus. Adds the game's own W/S (move_forward/back)
## and E (interact) so the menus navigate the same way as the rest of the shop.
## Returns true if it acted (caller should mark the input handled).
static func handle_nav(event: InputEvent, box: Node) -> bool:
	var buttons := focusables(box)
	if buttons.is_empty():
		return false
	var cur := -1
	for i in buttons.size():
		if buttons[i].has_focus():
			cur = i
			break
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_focus_at(buttons, cur + 1)
		return true
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_focus_at(buttons, cur - 1)
		return true
	if event.is_action_pressed("interact") and cur >= 0:
		buttons[cur].emit_signal("pressed")
		return true
	return false


## Visible, enabled buttons in `box`, in order — the current focus ring.
static func focusables(box: Node) -> Array:
	var out: Array = []
	for child in box.get_children():
		if child is Button and child.visible and not child.disabled:
			out.append(child)
	return out


static func _focus_at(buttons: Array, index: int) -> void:
	var n := buttons.size()
	buttons[((index % n) + n) % n].grab_focus()


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = Style.S3
	sb.content_margin_right = Style.S3
	sb.content_margin_top = Style.S2
	sb.content_margin_bottom = Style.S2
	return sb

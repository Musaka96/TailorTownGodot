class_name MousePick
extends RefCounted

## Mouse support for the "cursor index" menus — the ones whose rows are drawn cards and
## whose selection moves with W/S and confirms with E. The mouse walks the same paths:
##   MousePick.wire(card, hover, click)  — pointing at a card selects it, a left click on
##                                        it confirms it (or just selects, with no click)
##   MousePick.wire_stepper(label, step) — a click on the left/right half of a "‹ value ›"
##                                        steps it, like A/D
##   MousePick.is_back(event)            — a right click backs out, like Esc
##   MousePick.wire_hint(bar, i, click)  — key pill i of a Style.hint_bar works as a button
##   MousePick.release(menu)             — lets clicks and the wheel through the menu's
##                                        plain containers (see there)
## Cards PASS (never STOP) so the wheel still reaches the ScrollContainer they sit in.
## The callbacks run deferred: a menu that rebuilds on a pick frees the very card that
## is still emitting the event.

## Slack (px) either side of a stepper's text, so a short value is still easy to hit.
const STEP_PAD := 12.0


## Make `ctrl` pickable: `on_hover` when the pointer moves onto it, `on_click` (or
## `on_hover` when none is given) on a left click. The right button and the wheel pass
## on up to the menu. A tab passes no `on_hover` (Callable()): pointing at a tab never
## turns to it, only a click does.
static func wire(ctrl: Control, on_hover: Callable, on_click: Callable = Callable()) -> void:
	ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	ctrl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quiet(ctrl)
	var pick := on_click if on_click.is_valid() else on_hover
	# Hover follows real pointer motion only, not mouse_entered: a list that scrolls or
	# rebuilds under a resting pointer would otherwise snatch the keyboard's selection.
	# (Every menu's hover no-ops on the row that's already selected.)
	ctrl.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseMotion and on_hover.is_valid():
				on_hover.call_deferred()
			elif is_left_press(event):
				ctrl.accept_event()
				pick.call_deferred()
	)


## Make a value label step on a click: `on_step(-1)` on the left half of its text,
## `on_step(1)` on the right. A click beside the text (the rest of the row) is left to
## the row's own card.
static func wire_stepper(label: Label, on_step: Callable) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.gui_input.connect(
		func(event: InputEvent) -> void:
			if not is_left_press(event):
				return
			var x: float = (event as InputEventMouseButton).position.x
			var span := _text_span(label)
			if x < span.x - STEP_PAD or x > span.y + STEP_PAD:
				return
			label.accept_event()
			on_step.call_deferred(-1 if x < (span.x + span.y) * 0.5 else 1)
	)


## Make pill `index` of a Style.hint_bar (in its `pairs` order) clickable — for the
## one-shot keys (E, F, Esc) that act on the whole screen rather than on a row.
static func wire_hint(bar: Control, index: int, on_click: Callable) -> void:
	var pills := bar.get_child(0).get_children()  # hint_bar: wrap > flow row > pills
	if index < 0:
		index += pills.size()
	if index >= 0 and index < pills.size():
		wire(pills[index], Callable(), on_click)


## A right click: every menu treats it as its Esc (back / close).
static func is_back(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT


static func is_left_press(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT


## A plain Control (the menu root, its dim, a drawn picture) STOPs the mouse by default,
## which swallows a right click before the menu's _unhandled_input can read it as Esc.
## Turn every such non-widget under `menu` (and `menu` itself) to PASS; real widgets —
## buttons, sliders, text fields, scroll bars — keep theirs.
static func release(menu: Control) -> void:
	if menu.mouse_filter == Control.MOUSE_FILTER_STOP and not _is_widget(menu):
		menu.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in menu.get_children():
		if child is Control:
			release(child)


## Nothing inside a wired card may STOP, or it would take the click (and the hover) for
## itself; the card is the target.
static func _quiet(ctrl: Control) -> void:
	for child in ctrl.get_children():
		var c := child as Control
		if c == null:
			continue
		if c.mouse_filter == Control.MOUSE_FILTER_STOP and not _is_widget(c):
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quiet(c)


static func _is_widget(c: Control) -> bool:
	return (
		c is BaseButton
		or c is Range
		or c is LineEdit
		or c is TextEdit
		or c is ItemList
		or c is Tree
		or c is TabBar
	)


## Where a label's text sits across its width (x from, x to), by its alignment.
static func _text_span(label: Label) -> Vector2:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var w := minf(text_w, label.size.x)
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return Vector2((label.size.x - w) * 0.5, (label.size.x + w) * 0.5)
		HORIZONTAL_ALIGNMENT_RIGHT:
			return Vector2(label.size.x - w, label.size.x)
	return Vector2(0.0, w)

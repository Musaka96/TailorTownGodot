class_name FittingNotepad
extends Control

## The fitting notepad: a small spiral pad in the bottom-left corner while a customer is
## at the mirror. It keeps the brief in the tailor's hand and, after each ask, what is
## still wrong with the suit, the shirt and the price, plus the customer's last words.
## Only the width is fixed; the height follows the notes (VBox stacking).
##   pad.show_for(pref, female)   # a fresh page for this customer
##   pad.note(reaction)           # CustomerPreference.evaluate(), after an ask
##   pad.hide_pad()

enum Mark { NONE, WRONG, FINE }

const WIDTH := 300.0
const EDGE := 16.0  # from the screen's bottom edge, and left of the goal tag's column
const TOP := 26.0  # clears the spiral binding's holes
const SIDE := 14.0  # paper margin left / right / bottom
const RADIUS := 6.0
const LABEL_W := 58.0
const MARK_W := 22.0
const WIPE_TIME := 0.18
const WRITE_TIME := 0.25
## The rule sits this fraction of a line up from the line's bottom (Caveat's descenders).
const RULE_LIFT := 0.2
## The three things the tailor keeps notes on, top to bottom: [part key, label].
const SLOTS := [["suit", "Suit"], ["shirt", "Shirt"], ["price", "Price"]]
const HAPPY_FALLBACK := "Perfect. I'll take it."

var _margin: MarginContainer
var _box: VBoxContainer
var _brief: Label
var _budget: Label
var _said: Label
var _notes := {}  # part key -> Label
var _marks := {}  # part key -> Label
var _mark_state := {}  # part key -> Mark
var _ruled: Array[Control] = []  # rows the paper is ruled under
var _tweens := {}  # Label instance id -> the Tween rewriting it
var _pronoun := "He"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	UiScale.attach(self, UiScale.DIALOGUE)  # toward the bottom-left corner
	_build()


func _process(_delta: float) -> void:
	if visible:
		_fit()


# --- API ---------------------------------------------------------------------


## A fresh page for `pref`: the brief written out, the three slots blank, no quote yet.
func show_for(pref: CustomerPreference, female := false) -> void:
	_pronoun = "She" if female else "He"
	_brief.text = "%s — %s" % [pref.display_name, pref.describe().replace(" · ", ", ")]
	var line := "Budget $%d" % pref.budget
	var taste: String = pref.taste_short()
	if taste != "":
		line += " · " + taste
	_budget.text = line
	for slot: Array in SLOTS:
		_reset(_notes[slot[0]])
		_set_mark(slot[0], Mark.NONE)
	_reset(_said)
	_said.visible = false
	visible = true
	_fit()
	Craft.pop_in(self)


## After an ask: each slot takes the first note about it (a cross), or is found fine (a
## tick, the old note wiped); the customer's words go on the last line.
func note(reaction: Dictionary) -> void:
	var notes := notes_of(reaction)
	for slot: Array in SLOTS:
		var key: String = slot[0]
		var text := ""
		for n: Dictionary in notes:
			if str(n.get("part", "")) == key:
				text = str(n.get("note", ""))
				break
		_write(_notes[key], text)
		_set_mark(key, Mark.WRONG if text != "" else Mark.FINE)
	var said := said_of(reaction)
	_said.visible = true
	_write(_said, "%s said: “%s”" % [_pronoun, said] if said != "" else "")


func hide_pad() -> void:
	visible = false


## The verdict's notes, or — from an evaluate() that doesn't write them yet — one per
## reason, the part guessed from its words.
static func notes_of(reaction: Dictionary) -> Array:
	var notes: Array = reaction.get("notes", [])
	var reasons: Array = reaction.get("reasons", [])
	if notes.is_empty() and not reasons.is_empty():
		return fallback_notes(reasons)
	return notes


## One note per reason line: "shirt" → the shirt, "budget" → the price, else the suit.
static func fallback_notes(reasons: Array) -> Array:
	var out: Array = []
	for r in reasons:
		var text := str(r)
		var low := text.to_lower()
		var part := "suit"
		if low.contains("shirt"):
			part = "shirt"
		elif low.contains("budget"):
			part = "price"
		var said := text.substr(0, 1).to_upper() + text.substr(1)
		out.append({"part": part, "note": text, "said": said})
	return out


## What the customer says out loud: their happy line, or their biggest complaint.
static func said_of(reaction: Dictionary) -> String:
	if bool(reaction.get("suitable", false)):
		var happy := str(reaction.get("said_happy", ""))
		return happy if happy != "" else HAPPY_FALLBACK
	var notes := notes_of(reaction)
	return str((notes[0] as Dictionary).get("said", "")) if not notes.is_empty() else ""


# --- Building ----------------------------------------------------------------


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_theme_constant_override("margin_left", int(SIDE))
	_margin.add_theme_constant_override("margin_right", int(SIDE))
	_margin.add_theme_constant_override("margin_top", int(TOP))
	_margin.add_theme_constant_override("margin_bottom", int(SIDE))
	add_child(_margin)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 0)
	_margin.add_child(_box)
	var kicker := _label(Style.font_caps(), Style.T_MICRO, Style.BRASS)
	kicker.text = "FITTING NOTES"
	_box.add_child(kicker)
	_brief = _hand(Style.T_HAND, Style.INK)
	_budget = _hand(Style.T_HAND, Style.INK)
	for lbl: Label in [_brief, _budget]:
		_box.add_child(lbl)
		_ruled.append(lbl)
	for slot: Array in SLOTS:
		_box.add_child(_slot_row(slot[0], slot[1]))
	_said = _hand(Style.T_HAND_SMALL, Style.INK)
	_box.add_child(_said)
	_ruled.append(_said)


## One slot: its name, the note in pencil (wraps), and the mark at the right end.
func _slot_row(key: String, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Style.S1)
	var name_lbl := _hand(Style.T_HAND, Style.INK)
	name_lbl.text = title
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.custom_minimum_size.x = LABEL_W
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(name_lbl)
	var note_lbl := _hand(Style.T_HAND_SMALL, Style.PENCIL)
	note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(note_lbl)
	var mark := _label(Style.font_bold(), Style.T_VALUE, Style.INK)
	mark.custom_minimum_size.x = MARK_W
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)
	_notes[key] = note_lbl
	_marks[key] = mark
	_ruled.append(row)
	return row


func _hand(font_size: int, col: Color) -> Label:
	var lbl := _label(Style.font_hand(), font_size, col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _label(font: Font, font_size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	return lbl


# --- Writing -----------------------------------------------------------------


func _reset(lbl: Label) -> void:
	_kill_tween(lbl)
	lbl.text = ""
	lbl.visible_ratio = 1.0
	lbl.modulate.a = 1.0


## Rewrite `lbl`: the old words fade off the paper, then the new ones are written in.
func _write(lbl: Label, text: String) -> void:
	if lbl.text == text:
		return
	_kill_tween(lbl)
	var tw := lbl.create_tween()
	_tweens[lbl.get_instance_id()] = tw
	if lbl.text != "":
		tw.tween_property(lbl, "modulate:a", 0.0, WIPE_TIME)
	tw.tween_callback(_start_writing.bind(lbl, text))
	if text != "":
		tw.tween_property(lbl, "visible_ratio", 1.0, WRITE_TIME)


func _start_writing(lbl: Label, text: String) -> void:
	lbl.text = text
	lbl.visible_ratio = 0.0 if text != "" else 1.0
	lbl.modulate.a = 1.0
	if text != "" and lbl == _said:
		Sfx.play("chalk", -14.0)


func _kill_tween(lbl: Label) -> void:
	var tw: Tween = _tweens.get(lbl.get_instance_id(), null)
	if tw != null and tw.is_valid():
		tw.kill()
	_tweens.erase(lbl.get_instance_id())


func _set_mark(key: String, mark: Mark) -> void:
	if int(_mark_state.get(key, -1)) == mark:
		return
	_mark_state[key] = mark
	var lbl: Label = _marks[key]
	match mark:
		Mark.WRONG:
			lbl.text = "✕"
			lbl.add_theme_color_override("font_color", Style.CLAY)
		Mark.FINE:
			lbl.text = "✓"
			lbl.add_theme_color_override("font_color", Style.FOREST)
		_:
			lbl.text = ""
	if mark != Mark.NONE and lbl.is_inside_tree():
		Craft.bump(lbl, 1.3)


# --- Layout & paper ------------------------------------------------------------


## Bottom-left, right of the tutorial's goal tag; as tall as the notes need.
func _fit() -> void:
	var h := _margin.get_combined_minimum_size().y
	var left := EDGE + (Tutorial.side_reserve() if Tutorial != null else 0.0)
	offset_left = left
	offset_right = left + WIDTH
	offset_bottom = -EDGE
	offset_top = -EDGE - h
	_margin.position = Vector2.ZERO
	_margin.size = Vector2(WIDTH, h)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	Craft.card(self, Craft.rounded(r, RADIUS), Style.CREAM, Style.WALNUT, 1.5)
	var rule := Style.tint(Style.BRASS, 0.35)
	for row: Control in _ruled:
		if not row.visible:
			continue
		for y: float in _rule_ys(row):
			draw_line(Vector2(SIDE * 0.5, y), Vector2(size.x - SIDE * 0.5, y), rule, 1.0)
	Craft.spiral(self, r)


## The y (in the pad's own space) of a rule under every text line of `row`: the lines of
## whichever of its labels runs deepest.
func _rule_ys(row: Control) -> Array[float]:
	var labels: Array[Label] = []
	if row is Label:
		labels.append(row as Label)
	else:
		for child in row.get_children():
			if child is Label:
				labels.append(child as Label)
	var best: Label = null
	var depth := 0.0
	for lbl in labels:
		var d := float(maxi(lbl.get_line_count(), 1)) * lbl.get_line_height()
		if d > depth:
			depth = d
			best = lbl
	var out: Array[float] = []
	if best == null:
		return out
	var top := _local_y(best)
	var lh := best.get_line_height()
	for k in maxi(best.get_line_count(), 1):
		out.append(top + lh * (float(k) + 1.0 - RULE_LIFT))
	return out


## `c`'s top in the pad's unscaled space (summing positions, so the pop-in scale and
## the pad's own spot on screen don't matter).
func _local_y(c: Control) -> float:
	var y := 0.0
	var node: Node = c
	while node != null and node != self:
		if node is Control:
			y += (node as Control).position.y
		node = node.get_parent()
	return y

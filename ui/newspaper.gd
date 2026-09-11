extends Control

## The morning paper — THE TAILOR'S GAZETTE. A modal, single-page broadsheet that
## slides up at the start of each day (EventBus.newspaper_ready) and can be reread
## with the "newspaper" key. The sheet carries only real articles (a flanked
## masthead, a rule-lined folio line, a full-width lead story, then the rest as
## rule-separated stories) so it reads authentically. All game-facing guidance — the
## running fashion trend, the social calendar, and the control hints — lives on a
## strip beside the paper, never printed on it. Read-only; content comes from News.
##
## Built entirely in code from a bare Control (ui.gd._build_newspaper), so no scene
## has to be regenerated to add it.

const FONT := preload("res://assets/fonts/Fredoka.ttf")
const GRAIN_SHADER := preload("res://assets/shaders/paper_grain.gdshader")
const PAPER_W := 600.0
const SIDE_W := 216.0
const HINT_BG := Color(0.18, 0.13, 0.09, 0.82)

var _dateline: Label
var _folio: Label
var _lead: VBoxContainer
var _stories: VBoxContainer
var _fashion_body: Label
var _events_body: Label
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	EventBus.newspaper_ready.connect(_on_newspaper_ready)


func open() -> void:
	if News == null or News.current_edition.is_empty():
		return
	GameState.input_locked = true
	_fill()
	visible = true
	Sfx.play("page_turn")


func close() -> void:
	visible = false
	GameState.input_locked = false
	Sfx.play("page_turn")


func _on_newspaper_ready(_day: int) -> void:
	# Don't slide the paper up over the first-run tutorial.
	if Tutorial != null and Tutorial.is_active():
		return
	open()


# --- Fonts -----------------------------------------------------------------


func _font(embolden: float, glyph: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = FONT
	fv.variation_embolden = embolden
	fv.spacing_glyph = glyph
	return fv


# --- Layout ----------------------------------------------------------------


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Paper + a side strip, so nothing game-facing is printed on the sheet.
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", Style.S4)
	center.add_child(spread)
	spread.add_child(_build_paper())
	spread.add_child(_build_side())


func _build_paper() -> PanelContainer:
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(PAPER_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.PAPER
	sb.set_corner_radius_all(2)
	sb.set_border_width_all(2)
	sb.border_color = Style.WALNUT
	sb.set_content_margin_all(3)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	paper.add_theme_stylebox_override("panel", sb)

	# Aged-newsprint overlay behind the text (fills the whole sheet, ignores input).
	var grain := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = GRAIN_SHADER
	grain.material = mat
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(grain)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", Style.S4)
	margin.add_theme_constant_override("margin_right", Style.S4)
	margin.add_theme_constant_override("margin_top", Style.S3)
	margin.add_theme_constant_override("margin_bottom", Style.S3)
	paper.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", Style.S1)
	margin.add_child(body)

	_build_masthead(body)
	body.add_child(_rule(3, Style.INK))
	body.add_child(_gap(2))
	_folio = _folio_label()
	body.add_child(_folio)
	body.add_child(_gap(2))
	body.add_child(_rule(2, Style.INK))
	body.add_child(_gap(Style.S2))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 230)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	var page := VBoxContainer.new()
	page.custom_minimum_size = Vector2(PAPER_W - Style.S4 * 2, 0)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", Style.S2)
	_scroll.add_child(page)

	_lead = VBoxContainer.new()
	_lead.add_theme_constant_override("separation", Style.S1)
	page.add_child(_lead)
	_stories = VBoxContainer.new()
	_stories.add_theme_constant_override("separation", Style.S3)
	page.add_child(_stories)
	return paper


func _build_masthead(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	body.add_child(row)
	row.add_child(_flavor("BESPOKE\nSINCE TODAY", HORIZONTAL_ALIGNMENT_LEFT))

	var title := Label.new()
	title.text = "THE TAILOR'S GAZETTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", _font(0.4, 1))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Style.INK)
	row.add_child(title)

	_dateline = _flavor("", HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(_dateline)


## The side strip: fashion trend, social calendar and control hints — all game UI,
## kept off the sheet so the paper stays authentic.
func _build_side() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(SIDE_W, 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", Style.S3)
	_fashion_body = _side_panel(col, "IN FASHION", Style.BRASS)
	_events_body = _side_panel(col, "COMING UP", Style.AMBER)
	col.add_child(_hint_panel())
	return col


func _side_panel(parent: VBoxContainer, title: String, accent: Color) -> Label:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(SIDE_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = HINT_BG
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(Style.S3)
	box.add_theme_stylebox_override("panel", sb)
	parent.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Style.S1)
	box.add_child(col)
	var head := Label.new()
	head.text = title
	head.add_theme_font_override("font", _font(0.4, 2))
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", accent)
	col.add_child(head)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Style.CHALK)
	col.add_child(body)
	return body


func _hint_panel() -> PanelContainer:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = HINT_BG
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(Style.S3)
	wrap.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Style.S2)
	wrap.add_child(col)
	col.add_child(_hint_row("Esc", "Fold away"))
	col.add_child(_hint_row("W / S", "Read on"))
	return wrap


func _hint_row(key: String, verb: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	row.add_child(Style.keycap(key))
	var lbl := Label.new()
	lbl.text = verb
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Style.CHALK)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return row


# --- Small builders --------------------------------------------------------


func _flavor(text: String, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(84, 0)
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font(0.0, 2))
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	return lbl


func _folio_label() -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font(0.0, 3))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	return lbl


func _rule(thickness: int, col: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = col
	line.custom_minimum_size = Vector2(0, thickness)
	return line


func _gap(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


# --- Fill from the edition -------------------------------------------------


func _fill() -> void:
	var day := _day()
	_dateline.text = "MORNING ED.\nDAY %d" % day
	_folio.text = "VOL. I  ·  NO. %d          THE ROW, THE CITY          PRICE: ONE FARTHING" % day

	var edition := News.edition()
	for child in _lead.get_children():
		child.queue_free()
	for child in _stories.get_children():
		child.queue_free()
	if not edition.is_empty():
		_fill_story(_lead, edition[0], true)
	for i in range(1, edition.size()):
		_stories.add_child(_rule(1, Style.CREAM_DARK))
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", Style.S1)
		_stories.add_child(block)
		_fill_story(block, edition[i], false)

	_fashion_body.text = _fashion_text()
	_events_body.text = _events_text(day)
	_scroll.scroll_vertical = 0


## Compose one article (optional kicker, headline, body) into `parent`.
func _fill_story(parent: VBoxContainer, ev: NewsEvent, lead: bool) -> void:
	var kicker := _kicker(ev)
	if kicker != "":
		var k := Label.new()
		k.text = kicker
		k.add_theme_font_override("font", _font(0.3, 2))
		k.add_theme_font_size_override("font_size", 11)
		k.add_theme_color_override("font_color", _kicker_color(ev))
		parent.add_child(k)
	var head := Label.new()
	head.text = ev.headline
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_override("font", _font(0.4, 0))
	head.add_theme_font_size_override("font_size", 26 if lead else 18)
	head.add_theme_color_override("font_color", Style.INK)
	parent.add_child(head)
	var body_text := _body_text(ev)
	if body_text != "":
		var text := Label.new()
		text.text = body_text
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 15 if lead else 14)
		text.add_theme_color_override("font_color", Style.INK_SOFT)
		parent.add_child(text)


## An event's write-up gains a line that escalates as its day nears; other stories
## read as authored.
func _body_text(ev: NewsEvent) -> String:
	if ev.kind != NewsEvent.Kind.EVENT:
		return ev.body
	var urgency := _event_urgency(ev.event_day - _day())
	if ev.body == "":
		return urgency
	return "%s %s" % [ev.body, urgency]


func _event_urgency(days: int) -> String:
	if days <= 0:
		return "It is tonight — the city turns out in its finest."
	if days == 1:
		return "It is tomorrow night; last stitches, please."
	if days <= 3:
		return "Only %d days to go, and the smart set is already fussing." % days
	return "A little way off yet, but the diaries are filling."


func _kicker(ev: NewsEvent) -> String:
	match ev.kind:
		NewsEvent.Kind.FASHION:
			return "IN FASHION"
		NewsEvent.Kind.EVENT:
			return "CITY EVENT · %s" % _countdown(ev.event_day - _day())
	return ""


func _countdown(days: int) -> String:
	if days <= 0:
		return "TODAY"
	if days == 1:
		return "TOMORROW"
	return "IN %d DAYS" % days


func _kicker_color(ev: NewsEvent) -> Color:
	return Style.BURGUNDY if ev.kind == NewsEvent.Kind.EVENT else Style.BRASS


func _fashion_text() -> String:
	var trend: NewsEvent = News.current_fashion
	if trend == null:
		return "No firm trend just yet — dress them as you see fit."
	var wants: Array[String] = []
	if trend.fashion_pattern >= 0:
		wants.append(Enums.pattern_name(trend.fashion_pattern))
	if trend.fashion_fabric >= 0:
		wants.append(Enums.fabric_name(trend.fashion_fabric))
	if wants.is_empty():
		return trend.headline
	var joined := ", ".join(wants)
	return "%s in favour — match it for +%d standing." % [joined, trend.fashion_bonus]


func _events_text(day: int) -> String:
	var events := News.upcoming_events(day)
	if events.is_empty():
		return "The calendar's clear for now."
	var lines: Array[String] = []
	for ev in events:
		var away := ev.event_day - day
		var when := "today" if away <= 0 else ("tomorrow" if away == 1 else "in %d days" % away)
		lines.append(
			"Day %d · %s (%s)" % [ev.event_day, Enums.occasion_name(ev.event_occasion), when]
		)
	return "\n".join(lines)


# --- Access + input --------------------------------------------------------


func _day() -> int:
	return Shift.day if Shift != null else 1


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("newspaper") and not GameState.input_locked:
			open()
			get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("newspaper")
		or event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
		or event.is_action_pressed("interact")
	):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical -= 60
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += 60
		get_viewport().set_input_as_handled()

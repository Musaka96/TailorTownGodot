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

const GRAIN_SHADER := preload("res://assets/shaders/paper_grain.gdshader")
const PAPER_W := 600.0
const SIDE_W := 216.0

# The paper's own private type sub-scale — smaller and denser than the rest of the
# game's UI, as befits a broadsheet, but every size still lives here named rather than
# bare at a call site (style guide §2).
const N_MASTHEAD := 30  # THE TAILOR'S GAZETTE lockup
const N_FLAVOR := 10  # the flanking "BESPOKE / SINCE TODAY" flavour text
const N_FOLIO := 11  # the rule-lined folio line
const N_KICKER := 11  # a story's kicker ("CITY EVENT · IN 3 DAYS")
const N_HEAD_LEAD := 26  # the lead story's headline
const N_HEAD_STORY := 18  # every other story's headline
const N_BODY_LEAD := 15  # the lead story's body copy
const N_BODY_STORY := 14  # every other story's body copy
const N_SIDE_HEAD := 12  # side-strip panel title ("IN FASHION", "COMING UP")
const N_SIDE_BODY := 14  # side-strip panel body
## Presses this soon after the paper lands can't fold it away — the E that locked the
## door (or a tap during the day card) would otherwise close a paper nobody saw.
const OPEN_GUARD := 0.5
## The paper is not on the mat at dawn: the boy comes round once the shop has been open
## a while, so the quiet morning (and anything the story wants to say first) gets it to
## itself. In in-game hours after the sign is flipped.
const ARRIVES_AFTER := 0.75
const ROUND_POLL := 0.5  # seconds between looks while he is still on his way

var _dateline: Label
var _folio: Label
var _lead: VBoxContainer
var _stories: VBoxContainer
var _fashion_body: Label
var _events_body: Label
var _scroll: ScrollContainer
var _opened_at := 0.0
var _due_day := 0  # the day whose paper is still to be delivered (0 = none)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	EventBus.newspaper_ready.connect(_on_newspaper_ready)


func open() -> void:
	if News == null:
		return
	News.ensure_edition()
	if News.current_edition.is_empty():
		return
	_opened_at = Time.get_ticks_msec() / 1000.0
	GameState.input_locked = true
	_fill()
	visible = true
	Sfx.play("page_turn")


func close() -> void:
	visible = false
	GameState.input_locked = false
	Sfx.play("page_turn")


func _on_newspaper_ready(day: int) -> void:
	# Don't slide the paper up over the first-run tutorial.
	if Tutorial != null and Tutorial.is_active():
		return
	if _due_day == day:
		return  # already on its way — the round is not run twice
	_due_day = day
	_deliver()


## Hold today's edition until the boy's round reaches the shop, and then until the player
## is not in the middle of something — a menu, a minigame, or one of grandpa's letters.
## The letter goes first that way, and the paper follows it rather than sliding up
## underneath it. Drops the round the moment a new day prints over it.
func _deliver() -> void:
	var day := _due_day
	while is_inside_tree() and _due_day == day:
		if _round_has_come() and UI != null and not UI.busy():
			_due_day = 0
			open()
			return
		await get_tree().create_timer(ROUND_POLL).timeout


## The shop has been open long enough for the paper to have arrived.
func _round_has_come() -> bool:
	if Shift == null or not Shift.is_open():
		return false
	if DayNight == null:
		return true
	return DayNight.hour >= DayNight.start_hour() + ARRIVES_AFTER


# --- Fonts -----------------------------------------------------------------


## Every non-masthead face on the sheet: the real bold cut in place of the old fake
## embolden, or plain body when none was asked for. A FontVariation's own weight axis
## doesn't carry through a second FontVariation wrapped around it as `base_font` (it
## renders at the base instance instead), so each caller gets its own duplicate of
## the real Style face with just the glyph spacing changed, rather than a wrapper.
func _font(embolden: float, glyph: int) -> FontVariation:
	var base := Style.font_bold() if embolden > 0.0 else Style.font_body()
	var fv: FontVariation = base.duplicate()
	fv.spacing_glyph = glyph
	return fv


## THE TAILOR'S GAZETTE lockup — the one place on the sheet that gets the display face.
func _masthead_font(glyph: int) -> FontVariation:
	var fv: FontVariation = Style.font_display().duplicate()
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
	title.add_theme_font_override("font", _masthead_font(1))
	title.add_theme_font_size_override("font_size", N_MASTHEAD)
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
	# A kraft note pinned beside the paper, each at its own slight angle.
	var box := CraftPanel.new()
	box.pad = Vector2(Style.S3, Style.S3)
	box.setup(CraftPanel.Shape.TICKET, Style.CORK)
	box.stitch_color = Style.PAPER
	box.pin_color = Style.BURGUNDY if parent.get_child_count() % 2 == 0 else Style.FOREST
	box.custom_minimum_size = Vector2(SIDE_W, 0)
	box.rotation_degrees = 1.5 if parent.get_child_count() % 2 == 0 else -1.5
	parent.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Style.S1)
	box.add_child(col)
	var head := Label.new()
	head.text = title
	head.add_theme_font_override("font", _font(0.4, 2))
	head.add_theme_font_size_override("font_size", N_SIDE_HEAD)
	head.add_theme_color_override("font_color", accent.darkened(0.35))
	col.add_child(head)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", N_SIDE_BODY)
	body.add_theme_color_override("font_color", Style.WALNUT)
	col.add_child(body)
	return body


func _hint_panel() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Style.S2)
	for pair in [["Esc", "Fold away"], ["W / S", "Read on"]]:
		var pill := Style.key_pill(pair[0], pair[1])
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(pill)
	return col


# --- Small builders --------------------------------------------------------


func _flavor(text: String, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(84, 0)
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font(0.0, 2))
	lbl.add_theme_font_size_override("font_size", N_FLAVOR)
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	return lbl


func _folio_label() -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font(0.0, 3))
	lbl.add_theme_font_size_override("font_size", N_FOLIO)
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
		k.add_theme_font_size_override("font_size", N_KICKER)
		k.add_theme_color_override("font_color", _kicker_color(ev))
		parent.add_child(k)
	var head := Label.new()
	head.text = ev.headline
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_override("font", _font(0.4, 0))
	head.add_theme_font_size_override("font_size", N_HEAD_LEAD if lead else N_HEAD_STORY)
	head.add_theme_color_override("font_color", Style.INK)
	parent.add_child(head)
	var body_text := _body_text(ev)
	if body_text != "":
		var text := Label.new()
		text.text = body_text
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", N_BODY_LEAD if lead else N_BODY_STORY)
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
	if ev.kicker != "":
		return ev.kicker
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
	lines.append("Best dressed makes the paper: fine work, on trend.")
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
	if Time.get_ticks_msec() / 1000.0 - _opened_at < OPEN_GUARD:
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

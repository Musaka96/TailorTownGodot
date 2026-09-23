extends Control

## The Tailor's Handbook — a book-style reference opened at the bookshelf. Chapter
## tabs across the top, a topic index on the left page, the article on the right.
## Content comes from Handbook (real tailoring info + live dress-code rules).
## Reading freezes the game: the scene tree is paused while the book is open (the
## book itself keeps processing) so the clock, customers and orders all wait.
##
## Navigation: W/S move through the topics and A/D through the chapters, at once —
## the index is a table of contents, not a reading order. A long article turns in
## pages with E (a "Page 1 of 2" marker under it says where you are, and after the
## last page E goes back to the top); the mouse wheel and the right stick scroll it
## freely as well.

## The book was shut (the pause menu uses this to come back when it opened the book).
signal closed

## The book's fixed size — the ONLY fixed element. Everything inside stacks and
## scrolls within it (index on the left, preview + article on the right).
const BOOK_SIZE := Vector2(780, 600)
const KICKER := "Handbook"
## A page turn moves the article one page height less this overlap, so the line that
## was cut off at the bottom of one page is the first whole line of the next.
const PAGE_OVERLAP := 28.0
const STICK_SPEED := 900.0  # px/s the right stick scrolls the article at full tilt
const STICK_DEAD := 0.25

var _actor = null
var _chapters: Array = []
var _chapter := 0
var _topic := 0
var _decor_built := false
var _index_scroll: ScrollContainer
var _art_scroll: ScrollContainer
var _pager: Label
var _page_pill: Control
var _read_tween: Tween
var _was_paused := false
## The handbook can be opened over another screen (the fitting mirror does it), so it puts
## the input lock back the way it found it rather than clearing it outright — otherwise
## closing the book would hand the player back their legs with the mirror still up.
var _was_locked := false
var _head: TitleBlock

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _tabs: HBoxContainer = $Center/Panel/Margin/Box/Tabs
@onready var _index: VBoxContainer = $Center/Panel/Margin/Box/Pages/Index
@onready var _preview: HBoxContainer = $Center/Panel/Margin/Box/Pages/Right/Preview
@onready var _body: RichTextLabel = $Center/Panel/Margin/Box/Pages/Right/Body
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func _ready() -> void:
	# Above every menu it can open over: their swatches lift themselves with z_index 1.
	z_index = 4
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(actor) -> void:
	_actor = actor
	_was_paused = get_tree().paused
	_was_locked = GameState.input_locked
	get_tree().paused = true
	_chapters = Handbook.chapters()
	_chapter = 0
	_topic = 0
	GameState.input_locked = true
	visible = true
	_style()
	_refresh()


func close() -> void:
	visible = false
	GameState.input_locked = _was_locked
	get_tree().paused = _was_paused
	_actor = null
	closed.emit()


func _style() -> void:
	# The book is a fixed size; everything inside fills it and scrolls when long, so
	# no tab can resize it and empty space is never reserved.
	_panel.custom_minimum_size = BOOK_SIZE
	Style.apply_skin(_panel, Style.MenuSkin.BOOK)
	if _head == null:
		_head = TitleBlock.adopt(_title, KICKER, Style.ACC_BOOK)
	_tabs.add_theme_constant_override("separation", Style.S1)
	_index.add_theme_constant_override("separation", Style.S1)
	# The body grows with its text (fit_content) and wraps to the page width; the
	# article ScrollContainer handles overflow, so the label sets no fixed size.
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.fit_content = true
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2.ZERO
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", Style.INK)
	_body.add_theme_font_override("bold_font", Style.bold_font())
	_body.add_theme_font_size_override("normal_font_size", Style.T_BODY)
	_body.add_theme_font_size_override("bold_font_size", Style.T_BODY)
	_build_decor_once()


## One-time structure: wrap the index and the article each in a ScrollContainer
## that fills the fixed panel and scrolls when its content is too tall, put the page
## marker under the article, and add the key-cap hint bar. Nothing here sets a fixed
## size — only the panel is fixed.
func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	var pages := _index.get_parent()  # the Pages HBox
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Left page: the topic index, scrolling within the fixed panel.
	var ipos := _index.get_index()
	var idx_scroll := ScrollContainer.new()
	idx_scroll.custom_minimum_size = Vector2(220, 0)
	idx_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	idx_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.remove_child(_index)
	idx_scroll.add_child(_index)
	pages.add_child(idx_scroll)
	pages.move_child(idx_scroll, ipos)
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index_scroll = idx_scroll

	# Right page: the preview + article stacked in one column that scrolls when long,
	# with the page marker sitting under it (outside the scroll, so it never moves).
	var right := _preview.get_parent()  # the Right VBox (Preview then Body)
	var rpos := right.get_index()
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", Style.S1)
	var art_scroll := ScrollContainer.new()
	art_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	art_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.remove_child(right)
	art_scroll.add_child(right)
	right_col.add_child(art_scroll)
	pages.add_child(right_col)
	pages.move_child(right_col, rpos)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", Style.S3)
	_art_scroll = art_scroll
	_body.mouse_filter = Control.MOUSE_FILTER_PASS  # let the wheel reach the scroll

	# "Page 1 of 2" under the article — only there when the article has more than one
	# page, so a short one reserves no room for it. A click on it turns the page too.
	_pager = Label.new()
	_pager.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pager.add_theme_font_size_override("font_size", Style.T_CAPTION)
	_pager.add_theme_color_override("font_color", Style.INK_SOFT)
	_pager.visible = false
	right_col.add_child(_pager)
	MousePick.wire(_pager, Callable(), _click_page)
	var bar := art_scroll.get_v_scroll_bar()
	bar.value_changed.connect(func(_value: float) -> void: _update_pager())
	bar.changed.connect(_update_pager)

	# The preview takes no space when a topic has none, and never stretches its art.
	_preview.custom_minimum_size = Vector2.ZERO
	_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_hint.visible = false
	var hints := Style.hint_bar(
		[["A/D", "Chapter"], ["W/S", "Topic"], ["E", "Next page"], ["Esc", "Close"]]
	)
	_hint.get_parent().add_child(hints)
	_page_pill = hints.get_child(0).get_child(2)  # hint_bar: wrap > flow row > pills
	MousePick.wire_hint(hints, 2, _click_page)
	MousePick.wire_hint(hints, -1, _click_close)


func _refresh() -> void:
	_title.text = _chapters[_chapter]["name"]
	for child in _tabs.get_children():
		child.queue_free()
	for i in _chapters.size():
		var tab := _make_tab(_chapters[i]["name"], i == _chapter)
		MousePick.wire(tab, Callable(), _pick_chapter.bind(i))
		_tabs.add_child(tab)

	var entries: Array = _chapters[_chapter]["entries"]
	_topic = clampi(_topic, 0, entries.size() - 1)
	# free() (not queue_free): the old rows must be gone this frame, or the scroll
	# content is briefly double-height and ensure_control_visible reads stale sizes.
	for child in _index.get_children():
		_index.remove_child(child)
		child.free()
	var selected_card: Control = null
	for i in entries.size():
		var card := _make_card(entries[i]["title"], i == _topic, Style.T_BODY)
		MousePick.wire(card, _pick_topic.bind(i))  # choosing a topic is all there is to do
		_index.add_child(card)
		if i == _topic:
			selected_card = card
	# Keep the highlighted topic in view, both directions, as you page a long chapter.
	if _index_scroll != null and selected_card != null:
		_scroll_into_view(_index_scroll, selected_card)

	var entry: Dictionary = entries[_topic]
	for child in _preview.get_children():
		child.queue_free()
	var preview: Dictionary = entry.get("preview", {})
	if not preview.is_empty():
		_preview.add_child(_make_preview(preview))
	_body.text = "[b]%s[/b]\n\n%s" % [entry["title"], entry["body"]]
	if _art_scroll != null:
		if _read_tween != null:
			_read_tween.kill()
		_art_scroll.scroll_vertical = 0  # a new topic starts at its top
	MousePick.release(self)  # a right click anywhere reaches _unhandled_input as Esc


# --- Article pages -------------------------------------------------------------------


## How far one page turn moves the article.
func _page_step() -> float:
	return maxf(40.0, _art_scroll.get_v_scroll_bar().page - PAGE_OVERLAP)


## The last scroll position: the article's length past the visible page (0 if it fits).
func _page_bottom() -> float:
	var bar := _art_scroll.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _page_count() -> int:
	var bottom := _page_bottom()
	if bottom < 2.0:
		return 1
	return 1 + ceili(bottom / _page_step())


## Which page (0-based) a scroll position is on: the page whose turn reached it.
func _page_at(scroll: float) -> int:
	return clampi(ceili((scroll - 1.0) / _page_step()), 0, _page_count() - 1)


## E: turn to the next page of the article, eased; after the last, back to the top.
func _turn_page() -> void:
	if _art_scroll == null or _page_count() < 2:
		return
	var from := float(_art_scroll.scroll_vertical)
	var to := 0.0
	if from < _page_bottom() - 1.0:
		to = minf((_page_at(from) + 1) * _page_step(), _page_bottom())
	if _read_tween != null:
		_read_tween.kill()
	_read_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_read_tween.tween_property(_art_scroll, "scroll_vertical", int(to), 0.18)
	Sfx.play_single("page_turn", -8.0)


## The page marker and the E pill follow the article: shown only when it has more
## than one page, the marker names the page the scroll is on, and on the last page
## the pill says where E goes next.
func _update_pager() -> void:
	if _art_scroll == null or _pager == null:
		return
	var count := _page_count()
	_pager.visible = count > 1
	if _page_pill != null:
		_page_pill.visible = count > 1
	if count > 1:
		var page := _page_at(float(_art_scroll.scroll_vertical)) + 1
		_pager.text = "Page %d of %d" % [page, count]
		if _page_pill != null:  # key_pill: pill > row > [keycap, verb]
			var verb := _page_pill.get_child(0).get_child(1) as Label
			if verb != null:
				verb.text = "Back to top" if page == count else "Next page"


func _process(delta: float) -> void:
	if not visible or _art_scroll == null:
		return
	var tilt := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(tilt) > STICK_DEAD:
		_art_scroll.scroll_vertical += int(tilt * STICK_SPEED * delta)


## Scroll `card` into view after a frame, so the freshly rebuilt list has been laid
## out first — otherwise ensure_control_visible reads stale positions and only ever
## follows one direction.
func _scroll_into_view(scroll: ScrollContainer, card: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(card):
		scroll.ensure_control_visible(card)


func _make_preview(preview: Dictionary) -> Control:
	# A reference photo (styles): scales to the page width keeping its aspect (height
	# follows, and the article scroll handles it) — no fixed size, never stretched.
	if preview.has("image"):
		var rect := TextureRect.new()
		rect.texture = load(preview["image"]) as Texture2D
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return rect
	# … or a cloth swatch (fabrics/patterns) at its own natural size, not stretched.
	var mat: MaterialType
	if preview.has("fabric"):
		mat = MaterialFactory.make(preview["fabric"], Enums.Pattern.SOLID, 1, 1.0)
	else:
		mat = MaterialFactory.make(Enums.Fabric.WORSTED_WOOL, preview["pattern"], 0, 1.0)
	var swatch := MaterialSwatch.new()
	swatch.swatch_size = 112
	swatch.setup(mat, mat.roll_length_m)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return swatch


func _make_card(text: String, selected: bool, font_size: int) -> Control:
	var card := CraftPanel.option(selected, Style.ACC_BOOK)
	var label := Label.new()
	label.text = text
	if selected:
		label.add_theme_font_override("font", Style.bold_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Style.INK if selected else Style.INK_SOFT)
	card.add_child(label)
	return card


## A chapter tab: the open chapter is a burgundy ribbon bookmark with chalk lettering.
func _make_tab(text: String, selected: bool) -> Control:
	if not selected:
		return _make_card(text, false, Style.T_VALUE)
	var tab := CraftPanel.new()
	tab.pad = Vector2(Style.S3, Style.S1 + 2)
	tab.setup(CraftPanel.Shape.TICKET, Style.ACC_BOOK, Style.WALNUT)
	tab.stitch_color = Style.PAPER
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Style.bold_font())
	label.add_theme_font_size_override("font_size", Style.T_VALUE)
	label.add_theme_color_override("font_color", Style.CHALK)
	tab.add_child(label)
	return tab


func _can_hotkey() -> bool:
	return UI.visible and not (GameState.input_locked or get_tree().paused or UI.any_menu_open())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		# The book's own key opens it from anywhere in the shop (not over another menu).
		if event.is_action_pressed("handbook") and _can_hotkey():
			UI.open_handbook(get_tree().get_first_node_in_group("player"))
			get_viewport().set_input_as_handled()
		return
	# (D-pad Up is also "previous topic" in here, so only a non-navigation press shuts it.)
	if event.is_action_pressed("handbook") and not event.is_action_pressed("ui_up"):
		close()
		get_viewport().set_input_as_handled()
		return
	# Held keys don't repeat (is_action_pressed drops echoes): a topic is a deliberate
	# press, never a flick through the whole chapter.
	var count: int = _chapters[_chapter]["entries"].size()
	if event.is_action_pressed("move_right"):
		_turn_chapter(wrapi(_chapter + 1, 0, _chapters.size()))
	elif event.is_action_pressed("move_left"):
		_turn_chapter(wrapi(_chapter - 1, 0, _chapters.size()))
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_turn_topic(wrapi(_topic + 1, 0, count))
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_turn_topic(wrapi(_topic - 1, 0, count))
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_turn_page()
		get_viewport().set_input_as_handled()
		return
	elif (
		event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
		or MousePick.is_back(event)
	):
		close()
		get_viewport().set_input_as_handled()
		return
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()


func _turn_chapter(chapter: int) -> void:
	_chapter = chapter
	_topic = 0
	Sfx.play_single("page_turn")


func _turn_topic(topic: int) -> void:
	_topic = topic
	Sfx.play_single("page_turn", -8.0)


## The Esc pill clicked: close, as Esc does.
func _click_close() -> void:
	if visible:
		Sfx.ui_cancel()
		close()


## The E pill or the page marker clicked: the next page, as E does.
func _click_page() -> void:
	if visible:
		_turn_page()


## A chapter tab clicked (pointing at one doesn't turn to it).
func _pick_chapter(chapter: int) -> void:
	if visible and chapter != _chapter:
		_turn_chapter(chapter)
		_refresh()


## A topic pointed at or clicked: the same page turn as W/S landing on it.
func _pick_topic(topic: int) -> void:
	if visible and topic != _topic:
		_turn_topic(topic)
		_refresh()

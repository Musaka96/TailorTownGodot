extends Control

## The Tailor's Handbook — a book-style reference opened at the bookshelf. Chapter
## tabs across the top, a topic index on the left page, the article on the right.
## Content comes from Handbook (real tailoring info + live dress-code rules).

var _actor = null
var _chapters: Array = []
var _chapter := 0
var _topic := 0
var _decor_built := false
var _index_scroll: ScrollContainer

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _tabs: HBoxContainer = $Center/Panel/Margin/Box/Tabs
@onready var _index: VBoxContainer = $Center/Panel/Margin/Box/Pages/Index
@onready var _preview: HBoxContainer = $Center/Panel/Margin/Box/Pages/Right/Preview
@onready var _body: RichTextLabel = $Center/Panel/Margin/Box/Pages/Right/Body
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func open(actor) -> void:
	_actor = actor
	_chapters = Handbook.chapters()
	_chapter = 0
	_topic = 0
	GameState.input_locked = true
	visible = true
	_style()
	_refresh()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_actor = null


func _style() -> void:
	# Fixed book (§3): a paper leather-bound volume; the topic index scrolls and
	# the article scrolls, so neither a long chapter nor a long article resizes it.
	_panel.custom_minimum_size = Style.FRAME_WIDE
	Style.apply_skin(_panel, Style.MenuSkin.BOOK)
	_title.add_theme_font_override("font", Style.bold_font())
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Style.ACC_BOOK)
	_tabs.add_theme_constant_override("separation", Style.S1)
	_index.add_theme_constant_override("separation", Style.S1)
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.fit_content = false
	# A stable article width and a reserved-height preview keep the book the same
	# size on every tab — short chapters/articles no longer shrink or grow it.
	_body.custom_minimum_size = Vector2(360, 380)
	_body.add_theme_color_override("default_color", Style.INK)
	_body.add_theme_font_override("bold_font", Style.bold_font())
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("bold_font_size", 17)
	_build_decor_once()


## One-time structure: key-cap hint bar and the scrolling wrapper around the topic
## index so long chapters don't grow the book (the skin/frame is applied in _style).
func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	var pages := _index.get_parent()
	var pos := _index.get_index()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.remove_child(_index)
	scroll.add_child(_index)
	pages.add_child(scroll)
	pages.move_child(scroll, pos)
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index_scroll = scroll

	# Reserve a fixed slot for the preview so a tab with a big photo and one with a
	# small swatch (or none) don't change the book's height.
	_preview.custom_minimum_size = Vector2(230, 300)
	_preview.alignment = BoxContainer.ALIGNMENT_CENTER

	_hint.visible = false
	var bar := Style.hint_bar([["A/D", "Chapter"], ["W/S", "Topic"], ["Esc", "Close"]])
	_hint.get_parent().add_child(bar)


func _refresh() -> void:
	_title.text = "Tailor's Handbook"
	for child in _tabs.get_children():
		child.queue_free()
	for i in _chapters.size():
		_tabs.add_child(_make_card(_chapters[i]["name"], i == _chapter, 18))

	var entries: Array = _chapters[_chapter]["entries"]
	_topic = clampi(_topic, 0, entries.size() - 1)
	for child in _index.get_children():
		child.queue_free()
	var selected_card: Control = null
	for i in entries.size():
		var card := _make_card(entries[i]["title"], i == _topic, 16)
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


## Scroll `card` into view after a frame, so the freshly rebuilt list has been laid
## out first — otherwise ensure_control_visible reads stale positions and only ever
## follows one direction.
func _scroll_into_view(scroll: ScrollContainer, card: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(card):
		scroll.ensure_control_visible(card)


func _make_preview(preview: Dictionary) -> Control:
	# A reference photo (styles) …
	if preview.has("image"):
		var rect := TextureRect.new()
		rect.texture = load(preview["image"]) as Texture2D
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(210, 285)
		rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return rect
	# … or a cloth swatch (fabrics/patterns).
	var mat: MaterialType
	if preview.has("fabric"):
		mat = MaterialFactory.make(preview["fabric"], Enums.Pattern.SOLID, 1, 1.0)
	else:
		mat = MaterialFactory.make(Enums.Fabric.WORSTED_WOOL, preview["pattern"], 0, 1.0)
	var swatch := MaterialSwatch.new()
	swatch.swatch_size = 112
	swatch.setup(mat, mat.roll_length_m)
	return swatch


func _make_card(text: String, selected: bool, font_size: int) -> Control:
	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override(
			"panel", Style.card(Style.CARD_SELECTED, 10, 3, Style.ACC_BOOK)
		)
	else:
		card.add_theme_stylebox_override("panel", Style.card())
	var label := Label.new()
	label.text = text
	if selected:
		label.add_theme_font_override("font", Style.bold_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Style.INK if selected else Style.INK_SOFT)
	card.add_child(label)
	return card


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var count: int = _chapters[_chapter]["entries"].size()
	if event.is_action_pressed("move_right"):
		_chapter = wrapi(_chapter + 1, 0, _chapters.size())
		_topic = 0
		Sfx.play_single("page_turn")
	elif event.is_action_pressed("move_left"):
		_chapter = wrapi(_chapter - 1, 0, _chapters.size())
		_topic = 0
		Sfx.play_single("page_turn")
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_topic = wrapi(_topic + 1, 0, count)
		Sfx.play_single("page_turn", -8.0)
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_topic = wrapi(_topic - 1, 0, count)
		Sfx.play_single("page_turn", -8.0)
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()

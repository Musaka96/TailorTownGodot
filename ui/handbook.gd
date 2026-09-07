extends Control

## The Tailor's Handbook — a book-style reference opened at the bookshelf. Chapter
## tabs across the top, a topic index on the left page, the article on the right.
## Content comes from Handbook (real tailoring info + live dress-code rules).

var _actor = null
var _chapters: Array = []
var _chapter := 0
var _topic := 0

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _tabs: HBoxContainer = $Center/Panel/Margin/Box/Tabs
@onready var _index: VBoxContainer = $Center/Panel/Margin/Box/Pages/Index
@onready var _body: RichTextLabel = $Center/Panel/Margin/Box/Pages/Body
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
	_panel.add_theme_stylebox_override("panel", Style.panel())
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Style.INK)
	_tabs.add_theme_constant_override("separation", Style.S1)
	_index.add_theme_constant_override("separation", Style.S1)
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.add_theme_color_override("default_color", Style.INK)
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("bold_font_size", 17)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Style.INK_SOFT)


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
	for i in entries.size():
		_index.add_child(_make_card(entries[i]["title"], i == _topic, 16))

	var entry: Dictionary = entries[_topic]
	_body.text = "[b]%s[/b]\n\n%s" % [entry["title"], entry["body"]]
	_hint.text = "A/D chapter    W/S topic    Esc close"


func _make_card(text: String, selected: bool, font_size: int) -> Control:
	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override("panel", Style.card(Style.CARD_SELECTED, 10, 3, Style.LEAF))
	else:
		card.add_theme_stylebox_override("panel", Style.card())
	var label := Label.new()
	label.text = text
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
	elif event.is_action_pressed("move_left"):
		_chapter = wrapi(_chapter - 1, 0, _chapters.size())
		_topic = 0
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_topic = wrapi(_topic + 1, 0, count)
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_topic = wrapi(_topic - 1, 0, count)
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()

extends Control

## Shown when the player greets a waiting customer. Presents their brief (what
## suit they want + budget) and lets you send them to the fitting mirror.

var _customer = null
var _actor = null

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _brief: Label = $Center/Panel/Margin/Box/Brief
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func open(customer, actor) -> void:
	_customer = customer
	_actor = actor
	GameState.input_locked = true
	_style()
	_fill()
	visible = true


func close() -> void:
	visible = false
	GameState.input_locked = false
	_customer = null


func _style() -> void:
	_panel.add_theme_stylebox_override("panel", Style.panel())
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Style.INK)
	_brief.add_theme_font_size_override("font_size", 18)
	_brief.add_theme_color_override("font_color", Style.INK)
	_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Style.INK_SOFT)


func _fill() -> void:
	var pref = _customer.get("preference") if _customer != null else null
	if pref == null:
		_title.text = "A customer"
		_brief.text = "They're just browsing."
	else:
		_title.text = pref.display_name
		_brief.text = '"I\'m after a %s suit."\n\nBudget: $%d' % [pref.describe(), pref.budget]
	_hint.text = "E: send to the fitting mirror      Esc: later"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_accept()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _accept() -> void:
	var cust = _customer
	close()
	if cust != null and cust.has_method("begin_fitting"):
		cust.begin_fitting()

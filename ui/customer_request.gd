extends Control

## Shown when the player greets a waiting customer. Presents their brief (what
## suit they want + budget) and lets you send them to the fitting mirror.

const PORTRAIT_SIZE := Vector2(160, 184)
## Fraction of the TV that sits inside the bubble; the rest overhangs the top-right.
const PORTRAIT_INSET := 0.5
const PORTRAIT_RISE := 0.3  # how far the TV lifts above the panel's top edge

var _customer = null
var _actor = null
var _decor_built := false
var _portrait: CustomerPortrait

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
	if _portrait != null and _customer != null:
		_portrait.configure(_customer)
		_portrait.set_live(true)
	if _customer != null and _customer.has_method("set_talking"):
		_customer.set_talking(true)


func close() -> void:
	visible = false
	GameState.input_locked = false
	if _portrait != null:
		_portrait.set_live(false)  # stop rendering the mini-scene while hidden
	if _customer != null and _customer.has_method("set_talking"):
		_customer.set_talking(false)
	_customer = null


func _style() -> void:
	# Small, simple speech bubble — what the customer is "saying" as you greet them.
	_panel.custom_minimum_size = Vector2(360, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.CREAM
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Style.BROWN
	sb.set_content_margin_all(Style.S3)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", sb)
	_title.add_theme_font_override("font", Style.bold_font())
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Style.INK)
	_brief.add_theme_font_size_override("font_size", 15)
	_brief.add_theme_color_override("font_color", Style.INK_SOFT)
	_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_decor_once()


func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	var tail := SpeechTail.new()
	tail.name = "Tail"
	_panel.add_child(tail)
	tail.setup(Style.CREAM, Style.BROWN)
	# A little TV portrait of the customer, floating off the bubble's right edge.
	_portrait = CustomerPortrait.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.size = PORTRAIT_SIZE
	add_child(_portrait)  # overlay on the root, so it can overhang the panel
	_reposition_portrait()
	# Light prompts (no dark bar) to keep the bubble airy and simple.
	_hint.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S3)
	row.add_child(_prompt("E", "Send to mirror"))
	row.add_child(_prompt("Esc", "Later"))
	_hint.get_parent().add_child(row)


func _process(_delta: float) -> void:
	if visible:
		_reposition_portrait()


## Perch the TV on the panel's top-right corner, overhanging up and to the right.
func _reposition_portrait() -> void:
	if _portrait == null or _panel == null:
		return
	var pr := _panel.get_global_rect()
	var x := pr.end.x - _portrait.size.x * PORTRAIT_INSET
	var y := pr.position.y - _portrait.size.y * PORTRAIT_RISE
	_portrait.global_position = Vector2(x, y)


func _prompt(key: String, verb: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S1 + 2)
	box.add_child(Style.keycap(key))
	var lbl := Label.new()
	lbl.text = verb
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	box.add_child(lbl)
	return box


func _fill() -> void:
	var pref = _customer.get("preference") if _customer != null else null
	if pref == null:
		_title.text = "A customer"
		_brief.text = "They're just browsing."
	else:
		_title.text = pref.display_name
		_brief.text = "%s\n\nBudget: $%d" % [pref.describe(), pref.budget]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	Sfx.ui(event)
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

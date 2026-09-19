extends Control

## Shown when the player greets a waiting customer. Presents their brief (what suit they
## want + budget + notes: regular, rush, picky, booked, referred) and lets you choose:
## take the fitting, book them for a later day, send them to the rival tailor, or decline
## (an honest "I can't make that yet" when the brief is out of reach). See
## docs/CUSTOMERS.md and FrontDesk.

const PORTRAIT_SIZE := Vector2(160, 184)
## Fraction of the TV that sits inside the bubble; the rest overhangs the top-right.
const PORTRAIT_INSET := 0.5
const PORTRAIT_RISE := 0.3  # how far the TV lifts above the panel's top edge

var _customer = null
var _actor = null
var _decor_built := false
var _portrait: CustomerPortrait
var _choices: VBoxContainer
var _badges: ClientBadges
var _options: Array[String] = []  # "take" / "book" / "refer" / "decline"
var _cards: Array[CraftPanel] = []
var _sel := 0

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
	_title.add_theme_font_size_override("font_size", Style.T_NAME)
	_title.add_theme_color_override("font_color", Style.INK)
	_brief.add_theme_font_size_override("font_size", Style.T_CAPTION)
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
	# What kind of client this is, right under their name.
	_badges = ClientBadges.make(null)
	_title.get_parent().add_child(_badges)
	_title.get_parent().move_child(_badges, _title.get_index() + 1)
	# What to do with them, then light key prompts (no dark bar) to keep it airy.
	_hint.visible = false
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", Style.S1)
	_hint.get_parent().add_child(_choices)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", Style.S2)
	row.add_child(_prompt("W/S", "Choose"))
	row.add_child(_prompt("E", "Confirm"))
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
	return Style.key_pill(key, verb)


func _fill() -> void:
	var pref = _customer.get("preference") if _customer != null else null
	if pref == null:
		_title.text = "A customer"
		_brief.text = "They're just browsing."
	else:
		_title.text = pref.display_name
		var lines := PackedStringArray([pref.describe(), "Budget: $%d" % pref.budget])
		lines.append_array(pref.tags())
		var reason: String = FrontDesk.infeasible_reason(pref)
		if reason != "":
			lines.append("Hmm — this %s." % reason)
		_brief.text = "\n".join(lines)
	_badges.show_for(pref)
	_build_options(pref)


## The choices for this customer (only "take" during the tutorial or for a browser).
func _build_options(pref) -> void:
	_options.clear()
	_options.append("take")
	var tutorial: bool = Tutorial != null and Tutorial.is_active()
	if pref != null and not tutorial:
		_options.append_array(["book", "refer", "decline"])
	_sel = 0
	_draw_options(pref)


## Build the cards once for this customer. Moving the selection only restyles them
## (see _highlight) — rebuilding would resize the bubble and jolt the TV perched on it.
func _draw_options(pref) -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	_cards.clear()
	for i in _options.size():
		var card := CraftPanel.option(i == _sel, Style.BRASS)
		var lbl := Label.new()
		lbl.text = _option_text(_options[i], pref)
		lbl.add_theme_font_size_override("font_size", Style.T_CAPTION)
		lbl.add_theme_color_override("font_color", Style.INK)
		card.add_child(lbl)
		_choices.add_child(card)
		_cards.append(card)


func _highlight() -> void:
	for i in _cards.size():
		_cards[i].set_option_selected(i == _sel, Style.BRASS, i == _sel)


func _option_text(opt: String, pref) -> String:
	match opt:
		"book":
			return "Book them for day %d" % FrontDesk.next_free_day()
		"refer":
			return "Send them to %s" % FrontDesk.RIVAL_NAME
		"decline":
			if pref != null and not FrontDesk.brief_feasible(pref):
				return "Be honest: I can't make that yet"
			return "Politely decline"
	return "Take the fitting (send to the mirror)"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	Sfx.ui(event)
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_sel = wrapi(_sel + 1, 0, _options.size())
		_highlight()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_sel = wrapi(_sel - 1, 0, _options.size())
		_highlight()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_choose(_options[_sel] if _sel < _options.size() else "take")
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _choose(opt: String) -> void:
	var cust = _customer
	if opt == "take" or cust == null:
		_accept()
		return
	var who: String = cust.preference.display_name
	close()
	match opt:
		"book":
			var day := FrontDesk.book_appointment(cust)
			UI.toast('%s: "Day %d it is — see you then!"' % [who, day])
			cust.finish_and_leave("wave")
		"refer":
			FrontDesk.refer_to_rival(cust)
			UI.toast("%s heads off to %s. (+1 reputation)" % [who, FrontDesk.RIVAL_NAME])
			cust.finish_and_leave("wave")
		"decline":
			var rep := FrontDesk.decline(cust)
			if rep > 0:
				UI.toast('%s: "Thank you for being honest." (+%d reputation)' % [who, rep])
				cust.finish_and_leave("wave")
			else:
				UI.toast('%s: "Oh… another time, then."' % who)
				cust.finish_and_leave("sad")


func _accept() -> void:
	var cust = _customer
	close()
	if cust != null and cust.has_method("begin_fitting"):
		cust.begin_fitting()

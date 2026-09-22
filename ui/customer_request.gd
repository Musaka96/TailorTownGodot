extends Control

## Shown when the player greets a waiting customer. Presents their brief (what suit they
## want + budget + notes: regular, rush, picky, booked, referred) and lets you choose:
## take the fitting, book them for a later day, send them to the rival tailor, or decline
## (an honest "I can't make that yet" when the brief is out of reach). See
## docs/CUSTOMERS.md and FrontDesk.
##
## The same bubble speaks for a customer kept waiting for a suit that isn't ready
## (open() with their CustomerWait): apologise, or buy time. And once the coffee machine
## is in, either kind of customer can be offered a cup first — you make it on the spot.

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
var _wait: CustomerWait = null  # set when speaking to a waiting collector
var _options: Array[String] = []  # "take" / "book" / "refer" / "decline" / "coffee" / "sorry"
var _cards: Array[CraftPanel] = []
var _sel := 0

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _brief: Label = $Center/Panel/Margin/Box/Brief
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func open(customer, actor, wait: CustomerWait = null) -> void:
	_customer = customer
	_actor = actor
	_wait = wait
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
	_wait = null


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
	var later := _prompt("Esc", "Later")
	MousePick.wire(later, Callable(), _click_close)
	row.add_child(later)
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
	if _wait != null:
		_fill_wait()
		return
	if pref == null:
		_title.text = "A customer"
		_brief.text = "They're just browsing."
	else:
		_title.text = pref.display_name
		var lines := PackedStringArray([pref.describe(), "Budget: $%d" % pref.budget])
		var taste: String = pref.taste_line()
		if taste != "":
			lines.append('"%s"' % taste)
		lines.append_array(pref.tags())
		var reason: String = FrontDesk.infeasible_reason(pref)
		if reason != "":
			lines.append("Hmm — this %s." % reason)
		_brief.text = "\n".join(lines)
	_badges.show_for(pref)
	_build_options(pref)


## A collector whose suit isn't ready: what they say, and the two things you can do.
func _fill_wait() -> void:
	var order := _wait.order
	_title.text = order.customer_name
	var lines := PackedStringArray(['"I\'m here for order #%d. Is it ready?"' % order.id])
	if not CustomerWait.can_reschedule(order):
		var why := "already waited a day" if order.late else "needs it for the event"
		lines.append("(They %s — tomorrow won't do.)" % why)
	elif Clientele != null and Clientele.loyalty(order.customer_name) > 0:
		lines.append("(A regular — they'll understand.)")
	_brief.text = "\n".join(lines)
	_badges.show_for(null)
	_options.clear()
	if _can_offer_coffee():
		_options.append("coffee")
	_options.append("sorry")
	_sel = 0
	_draw_options(null)


## The shop's coffee machine, if a cup can be made for this customer right now.
func _coffee_machine() -> CoffeeMachine:
	var scene := get_tree().current_scene
	if scene == null or (Tutorial != null and Tutorial.is_active()):
		return null
	for node in scene.find_children("*", "CoffeeMachine", true, false):
		var machine := node as CoffeeMachine
		if machine != null and machine.can_serve_guest():
			return machine
	return null


func _can_offer_coffee() -> bool:
	if _customer == null or _coffee_machine() == null:
		return false
	if _wait != null:
		return _wait.goodwill <= 0.0  # one cup per wait
	return float(_customer.get("coffee")) <= 0.0


## Make them a cup (the coffee game), then hand it over: a waiting collector calms down,
## a new customer remembers the welcome on the bill. They stay where they are — greet or
## speak to them again afterwards.
func _offer_coffee() -> void:
	var cust = _customer
	var wait := _wait
	var machine := _coffee_machine()
	var who := "The customer"
	if wait != null:
		who = wait.order.customer_name
	elif cust != null and cust.preference != null:
		who = cust.preference.display_name
	close()
	if machine == null or cust == null:
		return
	machine.serve_guest(
		func(quality: float) -> void:
			if not is_instance_valid(cust):
				return
			if quality <= 0.0:
				UI.toast("Spilled — %s pretends not to notice." % who)
				return
			if wait != null and is_instance_valid(wait):
				wait.soothe(quality)
				UI.toast('%s: "Oh — thank you. I can wait a little."' % who)
			else:
				cust.coffee = quality
				if Reputation != null and Config.data != null:
					Reputation.points += Config.data.coffee_rep
				UI.toast('%s: "How civilised! Thank you."' % who)
			if cust.has_method("react"):
				cust.react(Customer.REACT_LIKE)
	)


## The choices for this customer (only "take" during the tutorial or for a browser).
func _build_options(pref) -> void:
	_options.clear()
	_options.append("take")
	var tutorial: bool = Tutorial != null and Tutorial.is_active()
	if pref != null and not tutorial:
		if _can_offer_coffee():
			_options.append("coffee")
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
		MousePick.wire(card, _pick.bind(i), _click.bind(i))
		_choices.add_child(card)
		_cards.append(card)
	MousePick.release(self)  # a right click anywhere reaches _unhandled_input as Esc


func _highlight() -> void:
	for i in _cards.size():
		_cards[i].set_option_selected(i == _sel, Style.BRASS, i == _sel)


func _option_text(opt: String, pref) -> String:
	var text := "Take the fitting (send to the mirror)"
	match opt:
		"coffee":
			text = "Offer them a coffee first"
		"sorry":
			text = "Apologise: it isn't ready yet"
		"book":
			text = "Book them for day %d" % FrontDesk.next_free_day()
		"refer":
			text = "Send them to %s" % FrontDesk.RIVAL_NAME
		"decline":
			text = "Politely decline"
			if pref != null and not FrontDesk.brief_feasible(pref):
				text = "Be honest: I can't make that yet"
	return text


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
	elif (
		event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
		or MousePick.is_back(event)
	):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## The Esc pill clicked: "later", as Esc does.
func _click_close() -> void:
	if visible:
		Sfx.ui_cancel()
		close()


## A choice pointed at: the same step as W/S landing on it.
func _pick(index: int) -> void:
	if not visible or index == _sel or index >= _options.size():
		return
	Sfx.ui_move()
	_sel = index
	_highlight()


## A choice clicked: select it and answer with it, like E.
func _click(index: int) -> void:
	if not visible or index >= _options.size():
		return
	_pick(index)
	Sfx.ui_confirm()
	_choose(_options[_sel])


func _choose(opt: String) -> void:
	var cust = _customer
	if opt == "coffee":
		_offer_coffee()
		return
	if opt == "sorry":
		var wait := _wait
		close()
		if wait != null and is_instance_valid(wait):
			wait.say_sorry()
		return
	if cust != null:
		EventBus.customer_answered.emit(opt, cust)
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

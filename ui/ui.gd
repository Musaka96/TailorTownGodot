extends CanvasLayer

## Root of all in-game UI — autoloaded as "UI" so any station can reach it.
## Holds the always-on HUD and the (hidden) shelf browse menu.

const POP_HEIGHT := 2.6  # metres above the player's feet a pop-up appears at
const OUTLINE := 8  # px of walnut outline on text drawn straight over the world
const QUIET_POLL := 0.4  # seconds between looks, while something waits its turn

## Built in code (see _build_orders_menu / _build_clock) so the scene files never
## have to be regenerated to add them.
var orders_menu: Control
var clock: Control
var reputation: Control
var newspaper: Control
## Grandpa's letters and the memory shelf, on a sheet of his notepaper.
var story_note: Control
var day_transition: Control
var pause_menu: Control
var rack_menu: Control
var apprentice_menu: Control
var bench_game: Control
## True while a screen owns the HUD's bottom-left corner (the fitting notepad sits
## there): the key pills stay hidden. A flag, not a method: this class is at gdlint's
## public-method cap.
var key_pills_hidden := false

var _toast: Label
var _toast_bar: PanelContainer
var _toast_tween: Tween

@onready var hud: Control = $HUD
@onready var shelf_menu: Control = $ShelfMenu
@onready var phone_order: Control = $PhoneOrder
@onready var worktable_screen: Control = $WorktableScreen
@onready var sewing_screen: Control = $SewingScreen
@onready var suit_builder: Control = $SuitBuilder
@onready var customer_request: Control = $CustomerRequest
@onready var handbook: Control = $Handbook


func _ready() -> void:
	orders_menu = get_node_or_null("OrdersMenu")
	if orders_menu == null:
		orders_menu = _build_orders_menu()
	shelf_menu.visible = false
	phone_order.visible = false
	worktable_screen.visible = false
	sewing_screen.visible = false
	suit_builder.visible = false
	customer_request.visible = false
	handbook.visible = false
	orders_menu.visible = false
	# One base theme (Style's body face) on the root window, so every Control in the
	# game inherits it — including scenes this layer doesn't build, like the title screen.
	var theme := Style.base_theme()
	get_tree().root.theme = theme
	hud.theme = theme
	shelf_menu.theme = theme
	phone_order.theme = theme
	worktable_screen.theme = theme
	sewing_screen.theme = theme
	suit_builder.theme = theme
	customer_request.theme = theme
	handbook.theme = theme
	orders_menu.theme = theme
	clock = _build_clock()
	reputation = _build_reputation()
	_build_focus()
	_build_handbook_pill()
	newspaper = _build_newspaper()
	day_transition = _build_day_transition()
	pause_menu = _build_pause_menu()
	rack_menu = _build_rack_menu()
	apprentice_menu = _build_code_menu("ApprenticeMenu", "res://ui/apprentice_menu.gd")
	bench_game = _build_code_menu("BenchGameScreen", "res://ui/bench_game_screen.gd")
	story_note = _build_code_menu("StoryNote", "res://ui/story_note.gd")
	_wire_pop_ins()
	_attach_sizes()


## Close every station menu (e.g. when leaving the game scene).
func close_all_menus() -> void:
	for menu: Control in [
		shelf_menu,
		phone_order,
		worktable_screen,
		sewing_screen,
		suit_builder,
		customer_request,
		handbook,
		orders_menu,
		rack_menu,
		apprentice_menu,
		bench_game,
		newspaper,
		story_note,
	]:
		if menu != null and menu.visible:
			if menu.has_method("close"):
				menu.close()
			menu.visible = false


## True while any full-screen station menu (or the morning paper) is up — HUD bits
## that would sit on top of it (order tickets, the E prompt) tuck themselves away.
func any_menu_open() -> bool:
	for menu: Control in [
		shelf_menu,
		phone_order,
		worktable_screen,
		sewing_screen,
		suit_builder,
		customer_request,
		handbook,
		orders_menu,
		rack_menu,
		apprentice_menu,
		bench_game,
		newspaper,
		story_note,
	]:
		if menu != null and menu.visible:
			return true
	return false


## True while anything at all is on screen: a menu, a minigame, the pause, the mentor,
## or a cutscene holding input. The things that let themselves in — grandpa's letters,
## the morning paper — wait on this, which is what keeps them off each other's backs.
func busy() -> bool:
	if GameState.is_paused or GameState.input_locked:
		return true
	if any_menu_open():
		return true
	if Tutorial != null and Tutorial.is_active():
		return true
	return false


## Wait until nothing else is on screen. Whoever awaits this must open straight after
## it returns, with nothing in between that could yield — otherwise two waiters can
## both come through on the same frame and land on top of one another.
func quiet_moment() -> void:
	while is_inside_tree() and busy():
		await get_tree().create_timer(QUIET_POLL).timeout


## Every station menu springs open (its panel pops in) the moment it becomes visible.
func _wire_pop_ins() -> void:
	EventBus.session_ended.connect(close_all_menus)
	for menu: Control in [
		shelf_menu,
		phone_order,
		worktable_screen,
		sewing_screen,
		suit_builder,
		customer_request,
		handbook,
		orders_menu,
		rack_menu,
		apprentice_menu,
		bench_game,
	]:
		if menu == null:
			continue
		menu.visibility_changed.connect(_pop_menu.bind(menu))


## Each menu's panel takes the Menus interface size (Settings > Interface); its dimmer
## stays full-screen. The order tickets along the top take the HUD size.
func _attach_sizes() -> void:
	for menu: Control in [
		shelf_menu,
		phone_order,
		worktable_screen,
		suit_builder,
		customer_request,
		handbook,
		orders_menu,
		rack_menu,
		apprentice_menu,
		story_note,
		pause_menu,
	]:
		var panel: Variant = menu.get("_panel") if menu != null else null
		if panel is Control:
			UiScale.attach(panel, UiScale.MENUS)
	var tickets := hud.get_node_or_null("OrdersPanel") as Control
	if tickets != null:
		UiScale.attach(tickets, UiScale.HUD, Vector2(0.5, 0.0))


func _pop_menu(menu: Control) -> void:
	if not menu.visible:
		return
	var panel: Variant = menu.get("_panel")
	if panel is Control:
		# Wait a frame so the panel has its real size (the pop pivots on its centre).
		await get_tree().process_frame
		Craft.pop_in(panel)


func open_shelf_menu(shelf, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("drawer")
	shelf_menu.open(shelf, actor)


func open_apprentice_menu(bench, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("menu_open")
	apprentice_menu.open(bench, actor)


func open_rack_menu(rack, actor) -> void:
	Sfx.play("cloth_rustle")
	rack_menu.open(rack, actor)


func open_phone(phone, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("menu_open")
	phone_order.open(phone, actor)


func open_worktable(worktable, actor, piece) -> void:
	if _shop_closed():
		return
	Sfx.play("chalk")
	worktable_screen.open(worktable, actor, piece)


func open_sewing(machine, actor, piece) -> void:
	if _shop_closed():
		return
	Sfx.play("sew_machine", -3.0)
	sewing_screen.open(machine, actor, piece)


## Pressing at the ironing board. Like the coffee below it is a comfort, not shop work, so
## it is not shut with the shop.
func open_pressing(board, piece) -> void:
	Sfx.play("cloth_rustle")
	var game := PressMinigame.new()
	var title := (
		"%s · %s" % [Enums.garment_type_name(piece.garment_type), Enums.size_name(piece.size)]
	)
	bench_game.open(
		game,
		game.start_piece.bind(int(piece.garment_type), title, piece.material),
		board.finish_press
	)


## A cup at the coffee machine: instant coffee, or the three-beat espresso once owned.
func open_coffee(machine) -> void:
	Sfx.play("menu_open")
	var espresso: bool = Upgrades.has("shop_espresso")
	var game: CoffeeBench = EspressoMinigame.new() if espresso else CoffeePourMinigame.new()
	var title := "An espresso" if espresso else "A cup of coffee"
	bench_game.open(game, game.start_cup.bind(title), machine.finish_coffee)


## Speak to a customer kept waiting for a suit that isn't ready (see CustomerWait).
func open_customer_wait(customer, actor, wait: Node) -> void:
	Sfx.play("menu_open")
	customer_request.open(customer, actor, wait)


func open_suit_builder(mirror, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("tape")
	suit_builder.open(mirror, actor)


func open_customer_request(customer, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("menu_open")
	customer_request.open(customer, actor)


func open_handbook(actor) -> void:
	Sfx.play("menu_open")
	handbook.open(actor)


func open_orders_menu(actor) -> void:
	Sfx.play("menu_open")
	orders_menu.open(actor)


func play_day_transition(old_day, new_day, earned, on_switch, on_done) -> void:
	day_transition.play(old_day, new_day, earned, on_switch, on_done)


## Brief centred message near the top of the screen, on a walnut bar so it reads over
## any part of the shop (fades out on its own).
func toast(text: String, hold := 1.6) -> void:
	if _toast == null:
		_toast_bar = PanelContainer.new()
		var sb := Style.bar(Style.tint(Style.WALNUT, 0.88), Style.S3)
		sb.content_margin_left = Style.S3
		sb.content_margin_right = Style.S3
		sb.content_margin_top = Style.S1
		sb.content_margin_bottom = Style.S1
		_toast_bar.add_theme_stylebox_override("panel", sb)
		_toast_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast = _outlined(Style.font_medium(), Style.T_VALUE, Style.CHALK)
		_toast_bar.add_child(_toast)
		var holder := CenterContainer.new()
		holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		holder.position.y = 120
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_toast_bar)
		hud.add_child(holder)
		UiScale.attach(_toast_bar, UiScale.HUD, Vector2(0.5, 0.0))
	_toast.text = text
	_toast_bar.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(_toast_bar, "modulate:a", 0.0, 0.6)


## A gain popping up over the player's head ("+16 reputation"), with an optional smaller
## note under it. Outlined so it reads over floor, wall or grass. Falls back to a toast
## when there is no player on screen.
func pop_above_player(text: String, note := "", col: Color = Style.BRASS_LIGHT) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if player == null or cam == null:
		toast(text if note == "" else "%s — %s" % [text, note])
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := _outlined(Style.font_bold(), Style.T_TITLE, col)
	head.text = text
	box.add_child(head)
	if note != "":
		var sub := _outlined(Style.font_medium(), Style.T_BODY, Style.CHALK)
		sub.text = note
		box.add_child(sub)
	hud.add_child(box)
	var at := cam.unproject_position(player.global_position + Vector3.UP * POP_HEIGHT)
	var size := box.get_combined_minimum_size()
	box.size = size
	box.position = at - Vector2(size.x * 0.5, size.y)
	UiScale.attach(box, UiScale.DIALOGUE, Vector2(0.5, 1.0))  # grows up from the head
	Craft.pop_in(box, 0.6, 0.3)
	var tw := create_tween()
	tw.tween_property(box, "position:y", box.position.y - 46.0, 1.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.6).set_delay(1.3)
	tw.tween_callback(box.queue_free)


## A centred label with a walnut outline — legible on any background.
func _outlined(font: Font, size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Style.WALNUT)
	lbl.add_theme_constant_override("outline_size", OUTLINE)
	return lbl


## True while the shop is shut for the night — work stations refuse and show a hint.
func _shop_closed() -> bool:
	# Tutorial exception: the day hasn't started yet, but stations must work during it.
	if Tutorial != null and Tutorial.is_active():
		return false
	# Only after the closing bell: the morning before the sign is flipped is prep time.
	if Shift != null and Shift.is_after_hours():
		Sfx.play("error")
		toast("The shop's closed — flip the sign by the door to finish the day")
		return true
	return false


## Assemble the Orders board node tree in code (Dim + centered Panel with a Title,
## a two-column Pages row of List + Detail, and a Hint) and attach it last so its
## @onready paths resolve. Matches what orders_menu.gd expects. Kept out of the
## .tscn on purpose, so adding this feature never means rebuilding the scenes.
func _build_orders_menu() -> Control:
	var menu := Control.new()
	menu.name = "OrdersMenu"
	menu.set_script(load("res://ui/orders_menu.gd"))
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Style.S2)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", Style.S2)
	margin.add_child(box)

	var title := Label.new()
	title.name = "Title"
	box.add_child(title)

	var pages := HBoxContainer.new()
	pages.name = "Pages"
	pages.add_theme_constant_override("separation", Style.S3)
	box.add_child(pages)

	var list := VBoxContainer.new()
	list.name = "List"
	list.custom_minimum_size = Vector2(300, 420)
	pages.add_child(list)

	var detail := VBoxContainer.new()
	detail.name = "Detail"
	detail.custom_minimum_size = Vector2(440, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(detail)

	var hint := Label.new()
	hint.name = "Hint"
	box.add_child(hint)

	add_child(menu)  # attach last so the script's @onready node paths resolve
	return menu


## Analog shift clock, mounted top-left of the HUD. Built in code so the scenes
## never need regenerating to add it.
func _build_clock() -> Control:
	var widget := Control.new()
	widget.name = "Clock"
	widget.set_script(load("res://ui/clock_widget.gd"))
	widget.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	widget.position = Vector2(16, 12)
	hud.corner(Vector2.ZERO).add_child(widget)
	return widget


## Reputation badge, mounted just under the clock on the HUD. Built in code so the
## scenes never need regenerating to add it.
func _build_reputation() -> Control:
	var widget := Control.new()
	widget.name = "Reputation"
	widget.set_script(load("res://ui/reputation_widget.gd"))
	widget.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	widget.position = Vector2(20, 126)
	hud.corner(Vector2.ZERO).add_child(widget)
	return widget


## Coffee focus badge, beside the reputation patch (hidden while there's no focus).
func _build_focus() -> void:
	var widget := Control.new()
	widget.name = "Focus"
	widget.set_script(load("res://ui/focus_widget.gd"))
	widget.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	widget.position = Vector2(152, 126)
	hud.corner(Vector2.ZERO).add_child(widget)


## The Newspaper / Orders / Handbook key pills, bottom-left of the HUD — click one (or
## press its key) to open it.
func _build_handbook_pill() -> void:
	var widget := Control.new()
	widget.name = "HandbookPill"
	widget.set_script(load("res://ui/handbook_pill.gd"))
	hud.add_child(widget)
	UiScale.attach(widget, UiScale.PROMPTS)  # anchored bottom-left once it fits


## The morning paper — a modal broadsheet attached to the root UI (above the HUD) so
## it covers everything. Auto-opens on EventBus.newspaper_ready. Built in code.
## No .theme assignment needed: it inherits the root window's base theme, the same
## way _build_day_transition() always has.
func _build_newspaper() -> Control:
	var paper := Control.new()
	paper.name = "Newspaper"
	paper.set_script(load("res://ui/newspaper.gd"))
	add_child(paper)
	return paper


## The pause overlay (Resume / Save / Load / Main Menu / Quit), attached above the
## HUD. Processes while the tree is paused so its buttons stay live. Built in code.
func _build_pause_menu() -> Control:
	var menu := Control.new()
	menu.name = "PauseMenu"
	menu.set_script(load("res://ui/pause_menu.gd"))
	add_child(menu)
	return menu


## A station menu built entirely in code from `script`, attached to the root UI.
func _build_code_menu(menu_name: String, script: String) -> Control:
	var menu := Control.new()
	menu.name = menu_name
	menu.set_script(load(script))
	add_child(menu)
	return menu


## The clothing-rack browse menu (like the shelf's, fitting-room theme). Built in
## code and attached to the root UI so no scene file is needed.
func _build_rack_menu() -> Control:
	var menu := Control.new()
	menu.name = "RackMenu"
	menu.set_script(load("res://ui/rack_menu.gd"))
	add_child(menu)
	return menu


## Full-screen day-change animation, attached to the root UI (above the HUD) so it
## covers everything. Built in code — no scene regen needed.
func _build_day_transition() -> Control:
	var overlay := Control.new()
	overlay.name = "DayTransition"
	overlay.set_script(load("res://ui/day_transition.gd"))
	add_child(overlay)
	return overlay

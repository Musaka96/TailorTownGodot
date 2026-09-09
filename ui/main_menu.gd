extends Control

## The game's front door — the boot scene (project.godot run/main_scene). Offers
## New Game, Continue (most recent save), Load Game and Quit. It pauses the tree so
## the autoloaded sim (clock, orders) is frozen behind it, and processes anyway
## (PROCESS_MODE_ALWAYS). Selecting New/Load hands off to SaveManager, which swaps
## in main.tscn and starts (or restores) the day.

const FONT := preload("res://assets/fonts/Fredoka.ttf")

var _box: VBoxContainer
var _title: Label
var _sub := false  # true while the Load slot list is showing (Esc goes back)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# The in-game HUD/newspaper autoload draws above the scene — hide it behind the
	# menu (SaveManager shows it again once a game is running).
	if UI != null:
		UI.visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	self.theme = theme
	_build()
	_show_main()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Style.WALNUT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	Style.apply_skin(panel, Style.MenuSkin.ORDER)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Style.S4)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", Style.S3)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(outer)

	_title = Style.title_label("TailorTown", Style.BRASS)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	outer.add_child(_title)

	var sub := Label.new()
	sub.text = "Bespoke tailoring on the Row"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Style.INK_SOFT)
	sub.add_theme_font_size_override("font_size", 16)
	outer.add_child(sub)

	outer.add_child(HSeparator.new())

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", Style.S2)
	outer.add_child(_box)


func _unhandled_input(event: InputEvent) -> void:
	# Esc backs out of the load list; on the main page it's swallowed so it can't
	# reach GameState and unpause the frozen sim behind the menu.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _sub:
			_show_main()
		get_viewport().set_input_as_handled()
		return
	if MenuKit.handle_nav(event, _box):
		get_viewport().set_input_as_handled()


func _show_main() -> void:
	_sub = false
	_clear()
	_title.text = "TailorTown"
	_box.add_child(MenuKit.button("New Game", _new_game))
	if SaveManager.has_any_save():
		_box.add_child(MenuKit.button("Continue", _continue))
	_box.add_child(MenuKit.button("Load Game", _show_load))
	_box.add_child(MenuKit.button("Quit", func() -> void: get_tree().quit()))
	_focus_first()


func _show_load() -> void:
	_sub = true
	_clear()
	_title.text = "Load a save"
	for info: Dictionary in SaveManager.slot_infos():
		var slot: Variant = info["slot"]
		if bool(info.get("exists", false)):
			_box.add_child(MenuKit.slot_row(info, func() -> void: _load(slot)))
		else:
			var empty := MenuKit.slot_row(info, Callable())
			empty.disabled = true
			_box.add_child(empty)
	_box.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


func _new_game() -> void:
	SaveManager.new_game()


func _continue() -> void:
	var slot: Variant = SaveManager.latest_slot()
	if slot != null:
		SaveManager.load_from(slot)


func _load(slot: Variant) -> void:
	SaveManager.load_from(slot)


func _clear() -> void:
	# queue_free (not free): _clear runs from a button's own pressed handler, and a
	# node can't be freed while it's mid-emit. Hide now so the container drops it
	# from layout this frame and the new buttons don't briefly overlap the old.
	for child in _box.get_children():
		child.hide()
		child.queue_free()


func _focus_first() -> void:
	await get_tree().process_frame
	for child in _box.get_children():
		if child is Button and child.visible and not child.disabled:
			child.grab_focus()
			return

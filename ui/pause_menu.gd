extends Control

## In-game pause overlay — built in code by ui.gd and parented to the UI layer.
## Shows on GameState.pause_toggled(true). This is the home for Save / Load: it
## lists SaveManager's slots and writes or reads the chosen one. Processes while
## the tree is paused (PROCESS_MODE_ALWAYS) so its buttons stay live.

var _box: VBoxContainer
var _head: TitleBlock
var _panel: PanelContainer
var _sub := false  # true while a Save/Load slot list is showing (Esc goes back)
var _controls: ControlsScreen = null  # the controls sheet, while it is up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	GameState.pause_toggled.connect(_on_pause)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Style.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	SignBoard.dress(panel)
	_panel = panel

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Style.S3)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", Style.S3)
	margin.add_child(outer)

	_head = TitleBlock.make("Paused", "TailorTown", Style.BRASS)
	outer.add_child(_head)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", Style.S2)
	outer.add_child(_box)
	outer.add_child(Style.hint_bar([["W/S", "Select"], ["E", "Choose"], ["Esc", "Back"]]))


func _on_pause(paused: bool) -> void:
	visible = paused
	if paused:
		set_process_unhandled_input(true)  # re-arm (a prior Load/Menu disabled it)
		_show_main()
		Craft.pop_in.call_deferred(_panel, 0.9, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	var vp := get_viewport()
	if not visible or vp == null or _controls != null:
		return
	# Esc / B backs out of a sub-page to the main pause page (instead of unpausing).
	if _sub and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		Sfx.play("ui_cancel", -4.0)
		_show_main()
		vp.set_input_as_handled()
		return
	if MenuKit.handle_nav(event, _box):
		vp.set_input_as_handled()


func _show_main() -> void:
	_sub = false
	_clear()
	_head.title.text = "Paused"
	_refresh_meta()
	_box.add_child(MenuKit.button("Resume", _resume))
	# Mr. Hemming's shop isn't the player's to save; the game saves from grandpa's on.
	if SaveManager.can_save():
		_box.add_child(MenuKit.button("Save Game", func() -> void: _show_slots(true)))
	_box.add_child(MenuKit.button("Load Game", func() -> void: _show_slots(false)))
	_box.add_child(MenuKit.button("Handbook", _open_handbook))
	_box.add_child(MenuKit.button("Controls", _show_controls))
	_box.add_child(MenuKit.button("Settings", _show_settings))
	_box.add_child(MenuKit.button("Main Menu", _to_menu))
	_box.add_child(MenuKit.button("Quit to Desktop", _quit))
	_focus_first()


## Read the Tailor's Handbook from here: the pause menu steps aside for the book (which
## freezes the game itself) and comes back when the book is shut.
func _open_handbook() -> void:
	GameState.is_paused = false
	UI.handbook.closed.connect(func() -> void: GameState.is_paused = true, CONNECT_ONE_SHOT)
	UI.open_handbook(get_tree().get_first_node_in_group("player"))


func _show_controls() -> void:
	_panel.visible = false
	_controls = ControlsScreen.open(self)
	_controls.closed.connect(_on_controls_closed)


func _on_controls_closed() -> void:
	_controls = null
	_panel.visible = true
	_focus_first()


func _show_settings() -> void:
	_sub = true
	_clear()
	_clear_meta()
	_head.title.text = "Settings"
	SettingsUI.build(_box)
	_box.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


func _show_slots(saving: bool) -> void:
	_sub = true
	_clear()
	_clear_meta()
	_head.title.text = "Save to a slot" if saving else "Load a save"
	var infos: Array = SaveManager.slot_infos() if saving else SaveManager.load_infos()
	for info: Dictionary in infos:
		var slot: Variant = info["slot"]
		if saving:
			_box.add_child(MenuKit.slot_row(info, func() -> void: _save(slot)))
		elif bool(info.get("exists", false)):
			_box.add_child(MenuKit.slot_row(info, func() -> void: _load(slot)))
		else:
			var empty := MenuKit.slot_row(info, Callable())
			empty.disabled = true
			_box.add_child(empty)
	_box.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


func _save(slot: Variant) -> void:
	var day := Shift.day if Shift != null else 1
	if SaveManager.save_to(slot, "Day %d" % day):
		UI.toast("Saved to slot %s" % str(slot))
	else:
		UI.toast("Save failed")
	_show_main()


func _load(slot: Variant) -> void:
	set_process_unhandled_input(false)  # stop reacting while the scene swaps
	GameState.is_paused = false
	SaveManager.load_from(slot)


## Keep the day as it stood (Continue comes back to it), then leave.
func _quit() -> void:
	SaveManager.autosave()
	get_tree().quit()


func _to_menu() -> void:
	set_process_unhandled_input(false)  # stop reacting while the scene swaps
	GameState.is_paused = false
	SaveManager.to_menu()


func _resume() -> void:
	GameState.is_paused = false


## Day / money strip under the title — only on the main pause page.
func _refresh_meta() -> void:
	_clear_meta()
	_head.meta.add_child(TitleBlock.meta_label("Day %d" % Shift.day))
	_head.meta.add_child(TitleBlock.meta_label("$%d" % GameState.money, true))
	_head.meta.visible = true


func _clear_meta() -> void:
	for child in _head.meta.get_children():
		_head.meta.remove_child(child)
		child.queue_free()
	_head.meta.visible = false


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
			if child is CraftButton:
				child.focus_quietly()
			else:
				child.grab_focus()
			return

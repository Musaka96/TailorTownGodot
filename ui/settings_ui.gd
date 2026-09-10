class_name SettingsUI

## Shared builder for the options controls (audio / display / controls), wired to the
## Settings autoload. Both the main menu and the pause menu call `SettingsUI.build(box)` —
## it drops a scroll area (the list can be tall with all the key bindings) filled with the
## rows. Each control applies live and persists via Settings; no Apply button needed.

const SCROLL_HEIGHT := 452


static func build(box: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", Style.S1)
	scroll.add_child(col)

	col.add_child(Style.header("Audio"))
	col.add_child(_slider("Master", Settings.master, Settings.set_master))
	col.add_child(_slider("Music", Settings.music, Settings.set_music))
	col.add_child(_slider("Sound", Settings.sfx, Settings.set_sfx))

	col.add_child(Style.header("Display"))
	col.add_child(_mode_row())
	col.add_child(_resolution_row())
	col.add_child(_check("VSync", Settings.vsync, Settings.set_vsync))

	col.add_child(Style.header("Controls"))
	for r: Array in Settings.REBINDS:
		col.add_child(_rebind_row(r[0], r[1]))
	col.add_child(_reset_controls_button(col))


# --- Rows ------------------------------------------------------------------


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_color_override("font_color", Style.INK)
	l.add_theme_font_size_override("font_size", 16)
	return l


static func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	return row


static func _slider(label: String, value: float, setter: Callable) -> HBoxContainer:
	var row := _row()
	row.add_child(_label(label))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(0, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d%%" % roundi(value * 100.0)
	val.custom_minimum_size = Vector2(46, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_color_override("font_color", Style.INK_SOFT)
	row.add_child(val)
	s.value_changed.connect(
		func(v: float) -> void:
			val.text = "%d%%" % roundi(v * 100.0)
			setter.call(v)
	)
	return row


static func _check(label: String, on: bool, setter: Callable) -> HBoxContainer:
	var row := _row()
	var l := _label(label)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var cb := CheckButton.new()
	cb.button_pressed = on
	cb.toggled.connect(func(pressed: bool) -> void: setter.call(pressed))
	row.add_child(cb)
	return row


static func _mode_row() -> HBoxContainer:
	var row := _row()
	row.add_child(_label("Window"))
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m: String in Settings.MODES:
		opt.add_item(m)
	opt.selected = Settings.mode
	opt.item_selected.connect(func(i: int) -> void: Settings.set_mode(i))
	row.add_child(opt)
	return row


static func _resolution_row() -> HBoxContainer:
	var row := _row()
	row.add_child(_label("Resolution"))
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for res: Vector2i in Settings.RESOLUTIONS:
		opt.add_item("%d × %d" % [res.x, res.y])
	opt.selected = Settings.resolution_index()
	opt.item_selected.connect(
		func(i: int) -> void: Settings.set_resolution(Settings.RESOLUTIONS[i])
	)
	row.add_child(opt)
	return row


static func _rebind_row(action: String, label: String) -> HBoxContainer:
	var row := _row()
	var l := _label(label)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := RebindButton.new()
	row.add_child(b)
	b.setup(action)
	return row


static func _reset_controls_button(col: VBoxContainer) -> Button:
	var b := MenuKit.button("Reset controls", func() -> void: _reset(col))
	b.custom_minimum_size = Vector2(0, 40)
	return b


## Reset key bindings, then refresh every RebindButton's label in place.
static func _reset(col: VBoxContainer) -> void:
	Settings.reset_controls()
	for row in col.get_children():
		for child in row.get_children():
			if child is RebindButton:
				(child as RebindButton)._refresh()

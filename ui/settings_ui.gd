class_name SettingsUI

## Shared builder for the options controls (audio / display / filter), wired to the
## Settings autoload. Both the main menu and the pause menu call `SettingsUI.build(box)`
## to fill a VBox with the rows, so the screen looks and behaves the same in each. Each
## control applies live and persists via Settings — no Apply button needed.


static func build(box: VBoxContainer) -> void:
	box.add_child(Style.header("Audio"))
	box.add_child(_slider("Master", Settings.master, Settings.set_master))
	box.add_child(_slider("Music", Settings.music, Settings.set_music))
	box.add_child(_slider("Sound", Settings.sfx, Settings.set_sfx))
	box.add_child(Style.header("Display"))
	box.add_child(_check("Fullscreen", Settings.fullscreen, Settings.set_fullscreen))
	box.add_child(_check("VSync", Settings.vsync, Settings.set_vsync))
	box.add_child(Style.header("Picture"))
	box.add_child(_filter_row())


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(104, 0)
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


static func _filter_row() -> HBoxContainer:
	var row := _row()
	var l := _label("Filter")
	row.add_child(l)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for f: Array in Settings.FILTERS:
		opt.add_item(str(f[0]))
	opt.selected = Settings.filter_index()
	opt.item_selected.connect(
		func(i: int) -> void: Settings.set_filter(str(Settings.FILTERS[i][1]))
	)
	row.add_child(opt)
	return row

class_name SettingsUI

## Shared builder for the options controls (audio / display / interface / controls), wired
## to the Settings autoload. Both the main menu and the pause menu call
## `SettingsUI.build(box)` — it drops a scroll area (the list can be tall with all the key
## bindings) filled with the rows. Each control applies live and persists via Settings; no
## Apply button needed.

const SCROLL_HEIGHT := 360
## The interface size rows: [UiScale category, label].
const SIZES := [
	[UiScale.MENUS, "Menus"],
	[UiScale.HUD, "HUD"],
	[UiScale.PROMPTS, "Prompts and keys"],
	[UiScale.DIALOGUE, "Dialogue"],
]
const SIZE_STEP := 0.05


static func build(box: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.theme = Style.form_theme()
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
	col.add_child(_vsync_row())
	col.add_child(_antialiasing_row())

	_add_sizes(col)

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
	l.add_theme_font_size_override("font_size", Style.T_BODY)
	return l


static func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	return row


static func _slider(
	label: String, value: float, setter: Callable, lo := 0.0, hi := 1.0, step := 0.01
) -> HBoxContainer:
	var row := _row()
	row.add_child(_label(label))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d%%" % roundi(value * 100.0)
	val.custom_minimum_size = Vector2(46, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", Style.T_BODY)
	val.add_theme_color_override("font_color", Style.INK_SOFT)
	row.add_child(val)
	s.value_changed.connect(
		func(v: float) -> void:
			val.text = "%d%%" % roundi(v * 100.0)
			setter.call(v)
	)
	return row


## Interface: one size slider per UiScale category, live as it drags, and a reset.
static func _add_sizes(col: VBoxContainer) -> void:
	col.add_child(Style.header("Interface"))
	var sliders: Array[HSlider] = []
	for spec: Array in SIZES:
		var cat: String = spec[0]
		var row := _slider(
			spec[1],
			Settings.ui_scale_of(cat),
			func(v: float) -> void: Settings.set_ui_scale(cat, v),
			Settings.UI_SCALE_MIN,
			Settings.UI_SCALE_MAX,
			SIZE_STEP
		)
		col.add_child(row)
		sliders.append(row.get_child(1) as HSlider)
	var reset := MenuKit.button("Reset to default", func() -> void: _reset_sizes(sliders))
	reset.custom_minimum_size = Vector2(0, 40)
	col.add_child(reset)


## Each slider back to the default; moving it applies the size and updates its percentage.
static func _reset_sizes(sliders: Array[HSlider]) -> void:
	for s in sliders:
		s.value = Settings.UI_SCALE_DEFAULT


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


## VSync with a live frame-rate readout beside it, so the switch visibly does something.
static func _vsync_row() -> HBoxContainer:
	var row := _check("VSync", Settings.vsync, Settings.set_vsync)
	var fps := Label.new()
	fps.add_theme_font_size_override("font_size", Style.T_CAPTION)
	fps.add_theme_color_override("font_color", Style.INK_SOFT)
	row.add_child(fps)
	row.move_child(fps, 1)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(
		func() -> void: fps.text = "%d fps" % roundi(Engine.get_frames_per_second())
	)
	fps.add_child(timer)
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


static func _antialiasing_row() -> HBoxContainer:
	var row := _row()
	row.add_child(_label("Smooth edges"))
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for level: Array in Settings.ANTIALIASING:
		opt.add_item(level[0])
	opt.selected = Settings.antialiasing
	opt.item_selected.connect(func(i: int) -> void: Settings.set_antialiasing(i))
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

extends Control

## Dev harness for the character body-part + face system. Open this scene and press F6.
## Character renders on the right; controls (dropdowns + sliders) on the left. Drag a
## slider to tune, or scroll it — hold SHIFT while scrolling for 10x-finer steps. Face
## depth (face_z) and the whole face layout save to data/face_layout.tres with Save.
## Any GLB added to assets/characters/parts/ (then build_wardrobe) shows up here.

const RIG_SCENE := preload("res://entities/character/character_rig.tscn")
const SUIT_MAT := preload("res://data/materials/navy_worsted_pinstripe.tres")
const GENDERS := [Enums.Gender.ANY, Enums.Gender.MALE, Enums.Gender.FEMALE]
const GLASSES := ["", "sun", "round"]
const EXPRS := ["neutral", "happy", "sad"]
const SKINS := [
	Color(0.9, 0.76, 0.66), Color(0.8, 0.62, 0.48), Color(0.66, 0.48, 0.35), Color(0.55, 0.38, 0.27)
]
const HAIR_COLORS := [
	Color(0.12, 0.09, 0.07),
	Color(0.35, 0.22, 0.12),
	Color(0.72, 0.55, 0.30),
	Color(0.55, 0.20, 0.10),
	Color(0.6, 0.6, 0.62),
]
# [property, min, max, step, per_head]
const FIELDS := [
	["face_z", 0.2, 0.7, 0.002, true],
	["face_curve", 0.0, 8.0, 0.05, false],
	["head_y", 1.0, 2.2, 0.005, false],
	["eye_y", -0.3, 0.4, 0.002, false],
	["eye_x", -0.3, 0.3, 0.002, false],
	["eye_gap", 0.0, 0.6, 0.002, false],
	["eye_px", 0.0002, 0.01, 0.00005, false],
	["eye_z", -0.15, 0.2, 0.002, false],
	["eye_curve", -8.0, 8.0, 0.05, false],
	["brow_y", -0.2, 0.5, 0.002, false],
	["brow_x", -0.3, 0.3, 0.002, false],
	["brow_gap", 0.0, 0.6, 0.002, false],
	["brow_px", 0.0002, 0.01, 0.00005, false],
	["brow_z", -0.15, 0.2, 0.002, false],
	["brow_curve", -8.0, 8.0, 0.05, false],
	["nose_y", -0.3, 0.3, 0.002, false],
	["nose_x", -0.3, 0.3, 0.002, false],
	["nose_px", 0.0005, 0.01, 0.0001, false],
	["nose_z", -0.15, 0.25, 0.002, false],
	["nose_curve", -8.0, 8.0, 0.05, false],
	["mouth_y", -0.4, 0.2, 0.002, false],
	["mouth_x", -0.3, 0.3, 0.002, false],
	["mouth_px", 0.0005, 0.01, 0.0001, false],
	["mouth_z", -0.15, 0.2, 0.002, false],
	["mouth_curve", -8.0, 8.0, 0.05, false],
	["glasses_y", -0.3, 0.4, 0.002, false],
	["glasses_x", -0.3, 0.3, 0.002, false],
	["glasses_px", 0.0005, 0.01, 0.0001, false],
	["glasses_z", -0.05, 0.25, 0.002, false],
	["glasses_curve", -8.0, 8.0, 0.05, false],
]

var _view: SubViewport
var _rig: Node3D
var _cam: Camera3D
var _layout: FaceLayout
var _rng := RandomNumberGenerator.new()
var _head := 0
var _hair := 0
var _top := 0
var _bottom := 0
var _gender_i := 0
var _eye_i := 0
var _glasses_i := 0
var _expr_i := 0
var _skin_i := 0
var _hairc_i := 0
var _dist := 2.4
var _yaw := 0.0
var _sliders := {}
var _val_labels := {}
var _status: Label


func _ready() -> void:
	_rng.randomize()
	_layout = FaceLayout.load_or_default()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_apply()
	_apply_view()


func _build() -> void:
	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	add_child(split)

	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	scroll.add_child(col)
	left.add_child(scroll)
	split.add_child(left)

	var right := SubViewportContainer.new()
	right.stretch = true
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = false
	_view.msaa_3d = Viewport.MSAA_2X
	right.add_child(_view)
	split.add_child(right)
	_build_view()
	_build_controls(col)


func _build_view() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.shadow_enabled = true
	_view.add_child(sun)
	_rig = RIG_SCENE.instantiate()
	_view.add_child(_rig)
	var ap := _rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.play("idle")
	_cam = Camera3D.new()
	_cam.fov = 35
	_view.add_child(_cam)
	_cam.current = true


func _build_controls(col: VBoxContainer) -> void:
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	col.add_child(_heading("Body"))
	col.add_child(_dropdown("Head", _head_names(), _head, _on_head))
	col.add_child(_dropdown("Hair", _hair_names(), _hair, _on_hair))
	var tops := _range_names(Wardrobe.library().tops.size(), "Top")
	var bottoms := _range_names(Wardrobe.library().bottoms.size(), "Bottom")
	col.add_child(_dropdown("Top", tops, _top, _on_top))
	col.add_child(_dropdown("Bottom", bottoms, _bottom, _on_bottom))
	col.add_child(_dropdown("Gender (random)", ["Any", "Male", "Female"], _gender_i, _on_gender))
	col.add_child(_heading("Face"))
	col.add_child(_dropdown("Eyes", CharacterRig.EYE_COLORS, _eye_i, _on_eye))
	col.add_child(_dropdown("Glasses", ["none", "sun", "round"], _glasses_i, _on_glasses))
	col.add_child(_dropdown("Expression", EXPRS, _expr_i, _on_expr))
	col.add_child(_heading("View"))
	col.add_child(_slider("Zoom", 0.8, 4.5, 0.05, _dist, _on_zoom))
	col.add_child(_slider("Turn", -180, 180, 1, 0, _on_turn))
	col.add_child(_heading("Layout  (scroll a slider; Shift = fine)"))
	for f: Array in FIELDS:
		col.add_child(_field_slider(f))
	var buttons := HBoxContainer.new()
	buttons.add_child(_button("Random", _random))
	buttons.add_child(_button("Save", _save))
	buttons.add_child(_button("Reset", _reset))
	col.add_child(buttons)
	col.add_child(_status)


# --- Control builders ------------------------------------------------------


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	return l


func _dropdown(label: String, items: Array, current: int, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		opt.add_item(str(items[i]), i)
	opt.selected = clampi(current, 0, maxi(0, items.size() - 1))
	opt.item_selected.connect(cb)
	row.add_child(opt)
	return row


func _slider(
	label: String, lo: float, hi: float, step: float, value: float, cb: Callable
) -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var val := Label.new()
	val.text = _fmt(value, step)
	head.add_child(val)
	box.add_child(head)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.scrollable = false
	s.value_changed.connect(func(v: float) -> void: val.text = _fmt(v, step))
	s.value_changed.connect(cb)
	s.gui_input.connect(_slider_wheel.bind(s, step))
	box.add_child(s)
	return box


## A slider bound to a FaceLayout field (updates the layout live).
func _field_slider(f: Array) -> VBoxContainer:
	var prop: String = f[0]
	var step: float = f[3]
	var value := _field_value(prop)
	var box := _slider(prop, f[1], f[2], step, value, _on_field.bind(prop))
	_sliders[prop] = box.get_child(1)
	_val_labels[prop] = box.get_child(0).get_child(1)
	return box


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


# --- Handlers --------------------------------------------------------------


func _slider_wheel(event: InputEvent, s: HSlider, step: float) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	var dir := 0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		dir = 1
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		dir = -1
	if dir == 0:
		return
	var mult := 0.1 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	s.value = snappedf(s.value + dir * step * mult, step * mult)
	accept_event()


func _on_head(i: int) -> void:
	_head = i
	_apply()
	_sync_face_z()


func _on_hair(i: int) -> void:
	_hair = i
	_apply()


func _on_top(i: int) -> void:
	_top = i
	_apply()


func _on_bottom(i: int) -> void:
	_bottom = i
	_apply()


func _on_gender(i: int) -> void:
	_gender_i = i


func _on_eye(i: int) -> void:
	_eye_i = i
	_apply()


func _on_glasses(i: int) -> void:
	_glasses_i = i
	_apply()


func _on_expr(i: int) -> void:
	_expr_i = i
	_apply()


func _on_zoom(v: float) -> void:
	_dist = v
	_apply_view()


func _on_turn(v: float) -> void:
	_yaw = deg_to_rad(v)
	if _rig != null:
		_rig.rotation.y = _yaw


func _on_field(v: float, prop: String) -> void:
	if prop == "face_z":
		_layout.set_face_z_for(_head, v)
	else:
		_layout.set(prop, v)
	if _rig != null:
		_rig.apply_layout(_layout)


func _random() -> void:
	var g: int = GENDERS[_gender_i]
	_head = maxi(0, Wardrobe.random_head_index(g, _rng))
	_hair = _head
	_skin_i = _rng.randi() % SKINS.size()
	_hairc_i = _rng.randi() % HAIR_COLORS.size()
	_eye_i = _rng.randi() % CharacterRig.EYE_COLORS.size()
	_apply()


func _save() -> void:
	var err := ResourceSaver.save(_layout, FaceLayout.PATH)
	_status.text = "Saved to face_layout.tres" if err == OK else "Save failed"


func _reset() -> void:
	_layout = FaceLayout.new()
	if _rig != null:
		_rig.apply_layout(_layout)
	for prop: String in _sliders:
		(_sliders[prop] as HSlider).set_value_no_signal(_field_value(prop))
		_update_val_label(prop)
	_status.text = "Reset (not saved)"


# --- Applying --------------------------------------------------------------


func _apply() -> void:
	if _rig == null:
		return
	_rig.set_head(_head)
	_rig.set_hair(_hair)
	_rig.set_palette(SKINS[_skin_i])
	_rig.set_hair_color(HAIR_COLORS[_hairc_i])
	_rig.set_outfit(SUIT_MAT, null, SUIT_MAT, _top, _bottom)
	_rig.set_face_look(CharacterRig.EYE_COLORS[_eye_i], GLASSES[_glasses_i])
	match _expr_i:
		1:
			_rig.set_expression(true)
		2:
			_rig.set_expression(false)
		_:
			_rig.reset_expression()


func _apply_view() -> void:
	if _cam == null:
		return
	_cam.position = Vector3(0, 1.15, _dist)
	_cam.look_at_from_position(_cam.position, Vector3(0, 1.02, 0), Vector3.UP)


func _sync_face_z() -> void:
	if _sliders.has("face_z"):
		(_sliders["face_z"] as HSlider).set_value_no_signal(_layout.face_z_for(_head))
		_update_val_label("face_z")


func _update_val_label(prop: String) -> void:
	if _val_labels.has(prop):
		var step := _field_step(prop)
		(_val_labels[prop] as Label).text = _fmt(_field_value(prop), step)


# --- Data helpers ----------------------------------------------------------


func _field_value(prop: String) -> float:
	if prop == "face_z":
		return _layout.face_z_for(_head)
	return float(_layout.get(prop))


func _field_step(prop: String) -> float:
	for f: Array in FIELDS:
		if f[0] == prop:
			return f[3]
	return 0.001


func _head_names() -> Array:
	var out: Array = []
	for i in Wardrobe.head_count():
		out.append(_part_name(Wardrobe.head(i), "Head %d" % i))
	return out


func _hair_names() -> Array:
	var out: Array = []
	for i in Wardrobe.hair_count():
		out.append(_part_name(Wardrobe.hair(i), "Hair %d" % i))
	return out


func _part_name(part, fallback: String) -> String:
	if part != null and not part.display_name.is_empty():
		return part.display_name
	return fallback


func _range_names(n: int, prefix: String) -> Array:
	var out: Array = []
	for i in maxi(1, n):
		out.append("%s %d" % [prefix, i])
	return out


func _fmt(v: float, step: float) -> String:
	if step < 0.001:
		return "%.5f" % v
	if step < 0.01:
		return "%.4f" % v
	if step < 0.1:
		return "%.3f" % v
	return "%.2f" % v

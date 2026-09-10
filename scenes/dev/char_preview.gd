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
	["eye_rot", -45.0, 45.0, 1.0, false],
	["brow_y", -0.2, 0.5, 0.002, false],
	["brow_x", -0.3, 0.3, 0.002, false],
	["brow_gap", 0.0, 0.6, 0.002, false],
	["brow_px", 0.0002, 0.01, 0.00005, false],
	["brow_z", -0.15, 0.2, 0.002, false],
	["brow_curve", -8.0, 8.0, 0.05, false],
	["brow_rot", -45.0, 45.0, 1.0, false],
	["nose_y", -0.3, 0.3, 0.002, false],
	["nose_x", -0.3, 0.3, 0.002, false],
	["nose_px", 0.0005, 0.01, 0.0001, false],
	["nose_z", -0.15, 0.25, 0.002, false],
	["nose_curve", -8.0, 8.0, 0.05, false],
	["nose_rot", -45.0, 45.0, 1.0, false],
	["mouth_y", -0.4, 0.2, 0.002, false],
	["mouth_x", -0.3, 0.3, 0.002, false],
	["mouth_px", 0.0005, 0.01, 0.0001, false],
	["mouth_z", -0.15, 0.2, 0.002, false],
	["mouth_curve", -8.0, 8.0, 0.05, false],
	["mouth_rot", -45.0, 45.0, 1.0, false],
	["glasses_y", -0.3, 0.4, 0.002, false],
	["glasses_x", -0.3, 0.3, 0.002, false],
	["glasses_px", 0.0005, 0.01, 0.0001, false],
	["glasses_z", -0.05, 0.25, 0.002, false],
	["glasses_curve", -8.0, 8.0, 0.05, false],
	["glasses_rot", -45.0, 45.0, 1.0, false],
]

# Elements the gizmo can grab: [label, rig node name, x-field, y-field, rot-field, px-field].
const ELEMENTS := [
	["Eyes", "eye_l", "eye_x", "eye_y", "eye_rot", "eye_px"],
	["Brows", "brow_l", "brow_x", "brow_y", "brow_rot", "brow_px"],
	["Nose", "nose", "nose_x", "nose_y", "nose_rot", "nose_px"],
	["Mouth", "mouth", "mouth_x", "mouth_y", "mouth_rot", "mouth_px"],
	["Glasses", "glasses", "glasses_x", "glasses_y", "glasses_rot", "glasses_px"],
]

var _view: SubViewport
var _rig: Node3D
var _cam: Camera3D
var _active := 0  # which ELEMENTS entry the gizmo edits
var _giz: Control
var _layout: FaceLayout
var _rng := RandomNumberGenerator.new()
var _head := 0
var _hair := 0
var _top := 0
var _bottom := 0
var _gender_i := 0
var _eye_i := 0
var _glasses_i := 0
var _nose_i := 0
var _mouth_i := 0
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
	_giz = GizmoLayer.new()
	_giz.host = self
	_giz.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.add_child(_giz)
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
	var noses := _range_names(CharacterRig.variant_count("nose"), "Nose")
	var mouths := _range_names(CharacterRig.variant_count("mouth"), "Mouth")
	col.add_child(_dropdown("Nose", noses, _nose_i, _on_nose))
	col.add_child(_dropdown("Mouth", mouths, _mouth_i, _on_mouth))
	col.add_child(_dropdown("Expression", EXPRS, _expr_i, _on_expr))
	col.add_child(_heading("Gizmo  (drag = move, ring = rotate, box = scale)"))
	var elem_names: Array = []
	for e: Array in ELEMENTS:
		elem_names.append(e[0])
	col.add_child(_dropdown("Active", elem_names, _active, _on_active))
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


func _on_nose(i: int) -> void:
	_nose_i = i
	_apply()


func _on_mouth(i: int) -> void:
	_mouth_i = i
	_apply()


func _on_expr(i: int) -> void:
	_expr_i = i
	_apply()


func _on_active(i: int) -> void:
	_active = i
	if _giz != null:
		_giz.queue_redraw()


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
	_nose_i = _rng.randi() % maxi(1, CharacterRig.variant_count("nose"))
	_mouth_i = _rng.randi() % maxi(1, CharacterRig.variant_count("mouth"))
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
	_rig.set_face_look(CharacterRig.EYE_COLORS[_eye_i], GLASSES[_glasses_i], _nose_i, _mouth_i)
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


# --- Gizmo support (called by GizmoLayer) ----------------------------------


## The active element row: [label, rig node name, x-field, y-field, rot-field, px-field].
func _giz_elem() -> Array:
	return ELEMENTS[_active]


func _giz_node() -> Node3D:
	if _rig == null:
		return null
	return _rig.find_child(ELEMENTS[_active][1], true, false) as Node3D


## Where the active element projects on the viewport (Vector2(-1,-1) if unavailable).
func _giz_screen_pos() -> Vector2:
	var n := _giz_node()
	if n == null or _cam == null or not n.visible:
		return Vector2(-1, -1)
	return _cam.unproject_position(n.global_position)


func _giz_field(prop: String) -> float:
	return float(_layout.get(prop))


## Set a layout field from the gizmo, clamped to its slider range, syncing the slider.
func _giz_set(prop: String, value: float) -> void:
	var v := value
	if _sliders.has(prop):
		var s: HSlider = _sliders[prop]
		v = clampf(v, s.min_value, s.max_value)
		s.set_value_no_signal(v)
	_layout.set(prop, v)
	if _rig != null:
		_rig.apply_layout(_layout)
	_update_val_label(prop)


## Calibrate screen-pixels per unit for the active element's x/y fields (by nudging each
## and measuring the projected move), so a drag maps back to layout units at any turn.
func _giz_calibrate() -> Dictionary:
	var n := _giz_node()
	if n == null or _cam == null:
		return {"ok": false}
	var e: Array = ELEMENTS[_active]
	var s0 := _cam.unproject_position(n.global_position)
	var sx := _giz_probe(e[2], n, s0)
	var sy := _giz_probe(e[3], n, s0)
	var det := sx.x * sy.y - sx.y * sy.x
	if absf(det) < 0.0001:
		return {"ok": false}
	return {"ok": true, "sx": sx, "sy": sy, "det": det}


func _giz_probe(prop: String, n: Node3D, s0: Vector2) -> Vector2:
	var eps := 0.02
	var base := float(_layout.get(prop))
	_layout.set(prop, base + eps)
	_rig.apply_layout(_layout)
	var s := _cam.unproject_position(n.global_position)
	_layout.set(prop, base)
	_rig.apply_layout(_layout)
	return (s - s0) / eps


## Convert a screen drag (px) into (x-field, y-field) deltas using a calibration.
func _giz_screen_to_field(d: Vector2, calib: Dictionary) -> Vector2:
	var sx: Vector2 = calib["sx"]
	var sy: Vector2 = calib["sy"]
	var det: float = calib["det"]
	return Vector2((sy.y * d.x - sy.x * d.y) / det, (-sx.y * d.x + sx.x * d.y) / det)


## On-viewport transform gizmo for the active face element: a center handle + X/Y axes
## (drag to move), a ring (drag to rotate), and a corner box (drag to scale). It edits the
## same FaceLayout fields the sliders do, so both stay in sync.
class GizmoLayer:
	extends Control

	const R := 46.0  # rotate-ring radius / axis reach
	const HIT := 12.0

	var host  # CharPreview
	var _mode := ""
	var _press := Vector2.ZERO
	var _center := Vector2.ZERO
	var _calib := {}
	var _start := {}
	var _start_angle := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = host._giz_screen_pos()
		if c.x < 0:
			return
		draw_arc(c, R, 0.0, TAU, 48, Color(0.92, 0.82, 0.35, 0.85), 2.0)
		draw_line(c, c + Vector2(R, 0), Color(0.90, 0.35, 0.35), 3.0)  # X (red)
		draw_line(c, c - Vector2(0, R), Color(0.40, 0.85, 0.45), 3.0)  # Y (green, up)
		draw_rect(Rect2(c + Vector2(R, -R) - Vector2(6, 6), Vector2(12, 12)), Color(0.4, 0.7, 0.95))
		draw_circle(c, 7.0, Color(0.96, 0.9, 0.5, 0.95))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_begin(ev.position)
			else:
				_mode = ""
		elif ev is InputEventMouseMotion and _mode != "":
			_drag(ev.position)

	func _begin(pos: Vector2) -> void:
		_center = host._giz_screen_pos()
		if _center.x < 0:
			return
		_press = pos
		var d := pos - _center
		var scale_h := _center + Vector2(R, -R)
		if d.length() <= HIT:
			_mode = "move"
		elif pos.distance_to(scale_h) <= HIT:
			_mode = "scale"
		elif absf(d.length() - R) <= 9.0:
			_mode = "rotate"
		elif absf(d.y) < 12.0 and d.x > HIT:
			_mode = "movex"
		elif absf(d.x) < 12.0 and d.y < -HIT:
			_mode = "movey"
		elif d.length() < R * 1.5:
			_mode = "move"
		else:
			_mode = ""  # clicked away from the gizmo — ignore
			return
		var e: Array = host._giz_elem()
		_start = {
			e[2]: host._giz_field(e[2]),
			e[3]: host._giz_field(e[3]),
			e[4]: host._giz_field(e[4]),
			e[5]: host._giz_field(e[5]),
		}
		_calib = host._giz_calibrate()
		_start_angle = (pos - _center).angle()

	func _drag(pos: Vector2) -> void:
		var e: Array = host._giz_elem()
		if _mode == "rotate":
			host._giz_set(e[4], _start[e[4]] + rad_to_deg((pos - _center).angle() - _start_angle))
		elif _mode == "scale":
			host._giz_set(e[5], _start[e[5]] * maxf(0.05, 1.0 + (_press.y - pos.y) * 0.01))
		elif _calib.get("ok", false):
			var fd: Vector2 = host._giz_screen_to_field(pos - _press, _calib)
			if _mode != "movey":
				host._giz_set(e[2], _start[e[2]] + fd.x)
			if _mode != "movex":
				host._giz_set(e[3], _start[e[3]] + fd.y)

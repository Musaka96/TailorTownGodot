@tool
extends VBoxContainer

## Face Editor dock: a live 2D preview of the character's face over the fields that
## place it. Every element's position, the gap between the paired eyes/brows, and
## each element's size are editable; the preview blinks (and talks, if toggled) so
## you can see the result. Save writes data/face_layout.tres, which the rig reads at
## runtime (CharacterRig.apply_layout). Editor-only; no 3D or autoloads needed here.

const FACE_DIR := "res://assets/textures/faces/"
const SKIN := Color(0.86, 0.72, 0.6)
const SCALE := 640.0  # preview pixels per metre

# prop, label, min, max, step
const FIELDS := [
	["eye_y", "Eye height", -0.3, 0.4, 0.005],
	["eye_gap", "Eye spacing", 0.0, 0.5, 0.005],
	["eye_px", "Eye size", 0.001, 0.02, 0.0005],
	["brow_y", "Brow height", -0.2, 0.5, 0.005],
	["brow_gap", "Brow spacing", 0.0, 0.5, 0.005],
	["brow_px", "Brow size", 0.001, 0.02, 0.0005],
	["nose_y", "Nose height", -0.3, 0.3, 0.005],
	["nose_px", "Nose size", 0.001, 0.02, 0.0005],
	["mouth_y", "Mouth height", -0.4, 0.2, 0.005],
	["mouth_px", "Mouth size", 0.001, 0.02, 0.0005],
	["face_z", "Face depth", 0.2, 0.7, 0.005],
	["head_y", "Head height", 1.0, 2.2, 0.01],
]
const TALK_SEQ := ["mouth_closed", "mouth_mid", "mouth_open", "mouth_mid"]

var _layout: FaceLayout
var _tex: Dictionary = {}
var _spins: Dictionary = {}
var _preview: Control
var _status: Label
var _syncing := false

var _talking := false
var _blink_left := 3.0
var _eye_closed := false
var _mouth_i := 0
var _mouth_left := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	add_theme_constant_override("separation", 6)
	_layout = FaceLayout.load_or_default()
	for n in ["eye", "eye_closed", "brow", "nose", "mouth_closed", "mouth_mid", "mouth_open"]:
		if ResourceLoader.exists(FACE_DIR + n + ".png"):
			_tex[n] = load(FACE_DIR + n + ".png")
	_build_ui()
	set_process(true)


func _process(delta: float) -> void:
	_blink_left -= delta
	if _eye_closed and _blink_left <= 0.0:
		_eye_closed = false
		_blink_left = randf_range(2.0, 5.0)
		_preview.queue_redraw()
	elif not _eye_closed and _blink_left <= 0.0:
		_eye_closed = true
		_blink_left = 0.11
		_preview.queue_redraw()
	if _talking:
		_mouth_left -= delta
		if _mouth_left <= 0.0:
			_mouth_i = (_mouth_i + 1) % TALK_SEQ.size()
			_mouth_left = 1.0 / 9.0
			_preview.queue_redraw()


# --- UI --------------------------------------------------------------------


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Character Face"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(300, 300)
	_preview.draw.connect(_draw_preview)
	add_child(_preview)

	var buttons := HBoxContainer.new()
	add_child(buttons)
	buttons.add_child(_button("Save", _on_save))
	buttons.add_child(_button("Reset", _on_reset))
	var talk := CheckButton.new()
	talk.text = "Talk"
	talk.toggled.connect(func(on: bool) -> void: _talking = on)
	buttons.add_child(talk)

	add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	for f: Array in FIELDS:
		_field(form, f[0], f[1], f[2], f[3], f[4])

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(_status)


func _field(
	parent: VBoxContainer, prop: String, label: String, lo: float, hi: float, step: float
) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = _layout.get(prop)
	sb.custom_minimum_size = Vector2(96, 0)
	sb.value_changed.connect(func(v: float) -> void: _on_field(prop, v))
	row.add_child(sb)
	_spins[prop] = sb
	parent.add_child(row)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _on_field(prop: String, v: float) -> void:
	if _syncing:
		return
	_layout.set(prop, v)
	_preview.queue_redraw()


func _on_reset() -> void:
	_layout = FaceLayout.new()
	_syncing = true
	for prop: String in _spins:
		_spins[prop].value = _layout.get(prop)
	_syncing = false
	_preview.queue_redraw()
	_status.text = "Reset to defaults (Save to keep)."


func _on_save() -> void:
	if ResourceSaver.save(_layout, FaceLayout.PATH) != OK:
		_status.text = "Save failed."
		return
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	_status.text = "Saved. Runs next play."


# --- Preview ---------------------------------------------------------------


func _draw_preview() -> void:
	var c := Vector2(_preview.size.x * 0.5, _preview.size.y * 0.55)
	_preview.draw_circle(c, SCALE * 0.34, SKIN)
	_blit(c, -_layout.brow_gap * 0.5, _layout.brow_y, _layout.brow_px, "brow", false)
	_blit(c, _layout.brow_gap * 0.5, _layout.brow_y, _layout.brow_px, "brow", true)
	var eye := "eye_closed" if _eye_closed and _tex.has("eye_closed") else "eye"
	_blit(c, -_layout.eye_gap * 0.5, _layout.eye_y, _layout.eye_px, eye, false)
	_blit(c, _layout.eye_gap * 0.5, _layout.eye_y, _layout.eye_px, eye, true)
	_blit(c, 0.0, _layout.nose_y, _layout.nose_px, "nose", false)
	var mouth: String = TALK_SEQ[_mouth_i] if _talking else "mouth_closed"
	_blit(c, 0.0, _layout.mouth_y, _layout.mouth_px, mouth, false)


func _blit(
	c: Vector2, x_off: float, y_off: float, px: float, tex_name: String, mirror: bool
) -> void:
	var tex: Texture2D = _tex.get(tex_name)
	if tex == null:
		return
	var pos := c + Vector2(x_off * SCALE, -y_off * SCALE)
	var sz := Vector2(tex.get_width(), tex.get_height()) * px * SCALE
	var flip := Vector2(-1.0, 1.0) if mirror else Vector2.ONE
	_preview.draw_set_transform(pos, 0.0, flip)
	_preview.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
	_preview.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

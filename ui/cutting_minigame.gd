class_name CuttingMinigame
extends Control

## Orient-the-scissors cutting minigame, dressed as a tailor's cutting mat inside an
## atelier panel. A chalked garment silhouette is drawn on the mat; you steer the
## scissors (WASD / left stick) to keep them aligned with the outline as a cut cursor
## travels around it. Staying misaligned racks up slips — 3 slips ruins the piece.
## Emits finished(success, quality).

signal finished(success: bool, quality: float)

enum State { RUNNING, SUCCESS, RUINED }

const GOOD_TOL := deg_to_rad(26.0)  # within this of the outline = clean cut
const TARGET_SECONDS := 15.0  # time to cut the whole shape when aligned
const MISTAKE_COST := 0.85  # accumulated error that equals one mistake
const MAX_MISTAKES := 3
const ROT_SPEED := 14.0
const SPRINT_MULT := 1.8  # hold Shift: cut faster, but misalignment bites faster too

# Normalized garment silhouettes (roughly [-1, 1]); jittered at generation.
const SHAPES := {
	Enums.GarmentType.SHIRT:
	[
		Vector2(-0.6, -0.72),
		Vector2(0.6, -0.72),
		Vector2(0.86, -0.34),
		Vector2(0.5, -0.14),
		Vector2(0.55, 0.8),
		Vector2(-0.55, 0.8),
		Vector2(-0.5, -0.14),
		Vector2(-0.86, -0.34),
	],
	Enums.GarmentType.PANTS:
	[
		Vector2(-0.5, -0.8),
		Vector2(0.5, -0.8),
		Vector2(0.45, 0.8),
		Vector2(0.12, 0.8),
		Vector2(0.0, 0.05),
		Vector2(-0.12, 0.8),
		Vector2(-0.45, 0.8),
	],
	Enums.GarmentType.JACKET:
	[
		Vector2(-0.7, -0.68),
		Vector2(0.7, -0.68),
		Vector2(0.88, -0.2),
		Vector2(0.55, 0.8),
		Vector2(0.12, 0.8),
		Vector2(0.0, -0.22),
		Vector2(-0.12, 0.8),
		Vector2(-0.55, 0.8),
		Vector2(-0.88, -0.2),
	],
}

# Play-field look.
const MAT_INSET := 10.0
const GRID_STEP := 30.0
const CANVAS_MIN := Vector2(600, 384)

var _good_tol := GOOD_TOL
var _seconds := TARGET_SECONDS
var _max_mistakes := MAX_MISTAKES
var _lead := 0.0
var _state := State.RUNNING
var _pts: PackedVector2Array = []
var _cum: PackedFloat32Array = []
var _total := 0.0
var _cursor := 0.0
var _angle := 0.0
var _mistakes := 0
var _error := 0.0
var _cooldown := 0.0
var _aligned := false
var _snip_accum := 0.0
var _nicks: PackedVector2Array = []
var _title := ""

var _snip: AudioStream
var _slip: AudioStream
var _complete: AudioStream
var _ruined: AudioStream
var _player: AudioStreamPlayer

var _panel: PanelContainer
var _canvas: MinigameCanvas
var _sub_lbl: Label
var _status_lbl: Label
var _pips_box: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_snip = _load("snip")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_build_chrome()


func start(garment_type: int, title: String) -> void:
	_title = title
	var c := Config.data
	_lead = 1.6
	if c != null:
		_good_tol = deg_to_rad(c.cut_tolerance_deg)
		_seconds = c.cut_seconds
		_max_mistakes = c.cut_max_mistakes
		_lead = c.cut_lead_seconds
	_generate(garment_type)
	_state = State.RUNNING
	_cursor = 0.0
	_mistakes = 0
	_error = 0.0
	_cooldown = 0.0
	_nicks = []
	_angle = _tangent_at(0.0)
	_sub_lbl.text = title
	_refresh_pips()
	_update_status()
	set_process(true)
	_repaint()


func _generate(garment_type: int) -> void:
	var base: Array = SHAPES.get(garment_type, SHAPES[Enums.GarmentType.SHIRT])
	_pts = PackedVector2Array()
	for p in base:
		_pts.append(p + Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)))
	# Cumulative perimeter lengths (closed loop).
	_cum = PackedFloat32Array()
	_cum.append(0.0)
	for i in _pts.size():
		var a: Vector2 = _pts[i]
		var b: Vector2 = _pts[(i + 1) % _pts.size()]
		_cum.append(_cum[i] + a.distance_to(b))
	_total = _cum[_cum.size() - 1]


func _process(delta: float) -> void:
	if _state != State.RUNNING:
		return
	_cooldown = maxf(0.0, _cooldown - delta)

	# Steer the scissors toward the stick/WASD direction.
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if v.length() > 0.35:
		_angle = _rotate_toward(_angle, v.angle(), ROT_SPEED * delta)

	# Lead-in: let the player line up before the cut starts.
	if _lead > 0.0:
		_lead -= delta
		_update_status()
		_repaint()
		return

	# Sharp Scissors upgrade: hold Shift to race the cut (faster, but slips rack up
	# faster). Master Shears add an always-on speed bump.
	var boost := Upgrades.cutting_speed()
	if Upgrades.cutting_sprint() and Input.is_action_pressed("sprint"):
		boost *= SPRINT_MULT

	# The scissors must point the way the cut is travelling — facing backwards (180° off)
	# does NOT count, so the player actually steers along the line.
	var tangent := _tangent_at(_cursor)
	var err := absf(angle_difference(_angle, tangent))
	_aligned = err <= _good_tol

	if _aligned:
		_cursor += (_total / _seconds) * boost * delta
		_error = maxf(0.0, _error - delta * 0.7)
		_snip_accum += delta
		if _snip_accum >= 0.13 / boost:
			_snip_accum = 0.0
			_play(_snip, 0.35)
		if _cursor >= _total:
			_succeed()
	elif _cooldown <= 0.0:
		_error += (err - _good_tol) * boost * delta
		if _error >= MISTAKE_COST:
			_register_mistake()

	_update_status()
	_repaint()


## Debug (F2, debug builds only): skip the cut and finish it perfectly.
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.RUNNING or not OS.is_debug_build():
		return
	if event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		finished.emit(true, 1.0)


func _register_mistake() -> void:
	_mistakes += 1
	_error = 0.0
	_cooldown = 0.5
	_nicks.append(_point_at(_cursor))
	_play(_slip, 0.8)
	_refresh_pips()
	if _mistakes >= _max_mistakes:
		_fail()


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	_play(_complete, 0.7)
	_set_status("Cut complete — a clean piece!", Style.FOREST)
	_repaint()
	var quality := clampf(1.0 - 0.22 * _mistakes, 0.15, 1.0)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, quality)


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	_play(_ruined, 0.8)
	_set_status("Oh no — the piece is spoiled.", Style.CLAY)
	_repaint()
	await get_tree().create_timer(1.0).timeout
	finished.emit(false, 0.0)


# --- Chrome ----------------------------------------------------------------


func _build_chrome() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(_panel)
	Style.apply_skin(_panel, Style.MenuSkin.WORK)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	_panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Style.S2)
	box.add_child(head)
	head.add_child(Style.title_label("Cutting Table", Style.ACC_WORK))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_pips_box = HBoxContainer.new()
	_pips_box.add_theme_constant_override("separation", Style.S1 + 2)
	_pips_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_pips_box)

	_sub_lbl = Label.new()
	_sub_lbl.add_theme_color_override("font_color", Style.INK_SOFT)
	_sub_lbl.add_theme_font_size_override("font_size", 16)
	box.add_child(_sub_lbl)

	_canvas = MinigameCanvas.new()
	_canvas.custom_minimum_size = CANVAS_MIN
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.painter = _paint
	box.add_child(_canvas)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_override("font", Style.bold_font())
	_status_lbl.add_theme_font_size_override("font_size", 16)
	box.add_child(_status_lbl)

	box.add_child(
		Style.hint_bar([["WASD", "Aim the scissors"], ["Shift", "Cut faster (riskier)"]])
	)


func _refresh_pips() -> void:
	if _pips_box == null:
		return
	for child in _pips_box.get_children():
		child.queue_free()
	for i in _max_mistakes:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(15, 15)
		var col: Color = Style.CLAY if i < _mistakes else Style.CREAM_DARK
		pip.add_theme_stylebox_override("panel", Style.bar(col, 8))
		_pips_box.add_child(pip)


func _update_status() -> void:
	if _state != State.RUNNING:
		return
	if _lead > 0.0:
		_set_status("Line up the scissors…  %d" % ceili(_lead), Style.AMBER)
		return
	var pct := int(_cursor / _total * 100.0)
	var tip := "Keep the scissors along the chalk line   ·   %d%%" % pct
	if OS.is_debug_build():
		tip += "   ·   F2 skip"
	_set_status(tip, Style.INK_SOFT)


func _set_status(text: String, col: Color) -> void:
	if _status_lbl == null:
		return
	_status_lbl.text = text
	_status_lbl.add_theme_color_override("font_color", col)


func _repaint() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


# --- Geometry --------------------------------------------------------------


func _point_at(s: float) -> Vector2:
	s = fmod(s, _total)
	for i in _pts.size():
		if s <= _cum[i + 1]:
			var seg: float = _cum[i + 1] - _cum[i]
			var t: float = 0.0 if seg <= 0.0 else (s - _cum[i]) / seg
			return _pts[i].lerp(_pts[(i + 1) % _pts.size()], t)
	return _pts[0]


func _tangent_at(s: float) -> float:
	s = fmod(s, _total)
	for i in _pts.size():
		if s <= _cum[i + 1]:
			return (_pts[(i + 1) % _pts.size()] - _pts[i]).angle()
	return 0.0


func _rotate_toward(from: float, to: float, amount: float) -> float:
	var diff := angle_difference(from, to)
	return from + clampf(diff, -amount, amount)


func _origin() -> Vector2:
	return _canvas.size * 0.5


func _scale() -> float:
	return minf(_canvas.size.x, _canvas.size.y) * 0.40


func _world(p: Vector2) -> Vector2:
	return _origin() + p * _scale()


# --- Painting (called from the MinigameCanvas) -----------------------------


func _paint(c: Control) -> void:
	var rect := Rect2(
		Vector2(MAT_INSET, MAT_INSET), c.size - Vector2(MAT_INSET * 2.0, MAT_INSET * 2.0)
	)
	var mat := StyleBoxFlat.new()
	mat.bg_color = Style.MAT.darkened(0.05)
	mat.set_corner_radius_all(14)
	mat.set_border_width_all(3)
	mat.border_color = Style.WALNUT
	c.draw_style_box(mat, rect)
	_paint_grid(c, rect)
	if _pts.is_empty():
		return

	# Chalked garment outline.
	var chalk := Color(Style.CHALK, 0.6)
	for i in _pts.size():
		_dashed(c, _world(_pts[i]), _world(_pts[(i + 1) % _pts.size()]), chalk)
	_paint_progress(c)
	for n in _nicks:
		_paint_x(c, _world(n), Style.CLAY, 7.0)
	var cur := _world(_point_at(_cursor))
	_paint_scissors(c, cur, _angle, Style.FOREST if _aligned else Style.CLAY)


func _paint_grid(c: Control, rect: Rect2) -> void:
	var col := Color(Style.WALNUT, 0.09)
	var x := rect.position.x + GRID_STEP
	while x < rect.end.x:
		c.draw_line(Vector2(x, rect.position.y + 5), Vector2(x, rect.end.y - 5), col, 1.0)
		x += GRID_STEP
	var y := rect.position.y + GRID_STEP
	while y < rect.end.y:
		c.draw_line(Vector2(rect.position.x + 5, y), Vector2(rect.end.x - 5, y), col, 1.0)
		y += GRID_STEP


func _paint_progress(c: Control) -> void:
	var start_pt := _world(_point_at(0.0))
	if _cursor > 0.0:
		var pl: PackedVector2Array = []
		pl.append(start_pt)
		for i in _pts.size():
			if _cum[i + 1] <= _cursor:
				pl.append(_world(_pts[(i + 1) % _pts.size()]))
		pl.append(_world(_point_at(_cursor)))
		if pl.size() >= 2:
			c.draw_polyline(pl, Style.FOREST, 5.0)
	c.draw_circle(start_pt, 6.0, Style.BRASS)


## A pair of blades with brass finger-rings and a pivot rivet — cuter than a cross.
func _paint_scissors(c: Control, pos: Vector2, angle: float, col: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var perp := dir.orthogonal()
	c.draw_line(pos - dir * 10.0 + perp * 4.0, pos + dir * 27.0 + perp * 2.0, col, 3.5)
	c.draw_line(pos - dir * 10.0 - perp * 4.0, pos + dir * 27.0 - perp * 2.0, col, 3.5)
	c.draw_arc(pos - dir * 16.0 + perp * 7.0, 6.5, 0, TAU, 18, Style.BRASS, 2.5)
	c.draw_arc(pos - dir * 16.0 - perp * 7.0, 6.5, 0, TAU, 18, Style.BRASS, 2.5)
	c.draw_circle(pos + dir * 2.0, 3.0, Style.BRASS)


func _paint_x(c: Control, pos: Vector2, col: Color, r: float) -> void:
	c.draw_line(pos - Vector2(r, r), pos + Vector2(r, r), col, 3.0)
	c.draw_line(pos - Vector2(r, -r), pos + Vector2(r, -r), col, 3.0)


## A dashed line from a to b (chalk marks read as short strokes, not a solid line).
func _dashed(c: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var d := a.distance_to(b)
	if d <= 0.001:
		return
	var dir := (b - a) / d
	var t := 0.0
	while t < d:
		c.draw_line(a + dir * t, a + dir * minf(t + 8.0, d), col, 2.5)
		t += 14.0


func _play(stream: AudioStream, volume_scale: float) -> void:
	if stream == null or _player == null:
		return
	_player.stream = stream
	_player.volume_db = linear_to_db(clampf(volume_scale, 0.01, 1.0))
	_player.play()


func _load(name: String) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % name
	return load(path) if ResourceLoader.exists(path) else null

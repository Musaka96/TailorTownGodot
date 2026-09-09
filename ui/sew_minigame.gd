class_name SewMinigame
extends Control

## Rhythm sewing minigame, dressed as a strip of cloth on the machine bed inside an
## atelier panel. A needle travels along the seam; tap the stitch button (E / Space /
## F / A) as it reaches each stitch point. Good timing = clean stitches; early taps
## and missed points are slips — 3 ruins the piece. Emits finished(success, quality).

signal finished(success: bool, quality: float)

enum State { RUNNING, SUCCESS, RUINED }
enum Stitch { PENDING, PERFECT, GOOD, MISS }

const STITCHES := 9
const CROSS_SECONDS := 7.5
const GOOD_WINDOW := 0.05  # in seam fraction (0..1)
const PERFECT_WINDOW := 0.025
const MAX_MISTAKES := 3
const SPRINT_MULT := 1.7  # hold Shift: the needle races, so the timing is tighter

const CANVAS_MIN := Vector2(600, 300)
const CLOTH_DEFAULT := Color("c9b48c")  # linen fallback when no fabric colour known

var _stitches := STITCHES
var _cross_seconds := CROSS_SECONDS
var _good_window := GOOD_WINDOW
var _perfect_window := PERFECT_WINDOW
var _max_mistakes := MAX_MISTAKES
var _lead := 0.0
var _state := State.RUNNING
var _needle := 0.0
var _pts: PackedFloat32Array = []
var _judge: PackedInt32Array = []
var _mistakes := 0
var _title := ""
var _bob := 0.0
var _cloth := CLOTH_DEFAULT

var _stitch_snd: AudioStream
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
	_stitch_snd = _load("stitch")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_build_chrome()


func start(title: String, cloth := CLOTH_DEFAULT) -> void:
	_title = title
	_cloth = cloth
	var c := Config.data
	_lead = 1.6
	if c != null:
		_stitches = maxi(2, c.sew_stitches)
		_cross_seconds = c.sew_cross_seconds
		_good_window = c.sew_good_window
		_perfect_window = c.sew_perfect_window
		_max_mistakes = c.sew_max_mistakes
		_lead = c.sew_lead_seconds
	_state = State.RUNNING
	_needle = 0.0
	_mistakes = 0
	_pts = _random_points()
	_judge = PackedInt32Array()
	for i in _pts.size():
		_judge.append(Stitch.PENDING)
	_sub_lbl.text = title
	_refresh_pips()
	_update_status()
	set_process(true)
	Sfx.start_loop("sew_machine_loop", -6.0)
	_repaint()


func _process(delta: float) -> void:
	if _state != State.RUNNING:
		return
	_bob += delta * 12.0

	# Lead-in: hold at the start so the player can find the rhythm.
	if _lead > 0.0:
		_lead -= delta
		_update_status()
		_repaint()
		return

	# Hold Shift to run the needle faster — quicker seam, tighter timing.
	var boost := SPRINT_MULT if Input.is_action_pressed("sprint") else 1.0
	_needle += (delta / _cross_seconds) * boost

	# Points the needle has passed without a stitch are misses.
	for i in _pts.size():
		if _judge[i] == Stitch.PENDING and _needle > _pts[i] + _good_window:
			_judge[i] = Stitch.MISS
			_register_mistake()

	if _needle >= 1.0:
		_succeed()
	_update_status()
	_repaint()


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.RUNNING:
		return
	# Debug (F2, debug builds only): skip the seam and finish it perfectly.
	if OS.is_debug_build() and event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		finished.emit(true, 1.0)
		return
	if not (
		event.is_action_pressed("interact")
		or event.is_action_pressed("jump")
		or event.is_action_pressed("cut")
		or event.is_action_pressed("ui_accept")
	):
		return
	get_viewport().set_input_as_handled()
	_try_stitch()


func _try_stitch() -> void:
	if _lead > 0.0:
		return  # ignore taps during the lead-in
	var idx := _next_pending()
	if idx == -1:
		return
	var d: float = absf(_needle - _pts[idx])
	if d <= _good_window:
		_judge[idx] = Stitch.PERFECT if d <= _perfect_window else Stitch.GOOD
		_play(_stitch_snd, 0.6)
	else:
		# Tapped too early (no point in range yet) — a wasted stitch.
		_register_mistake()
	_repaint()


func _next_pending() -> int:
	for i in _pts.size():
		if _judge[i] == Stitch.PENDING:
			return i
	return -1


## Stitch points at uneven, random spacing along the seam (scaled to fit 0.08..0.92),
## so the rhythm isn't a metronome — the player has to watch the needle, not the beat.
func _random_points() -> PackedFloat32Array:
	var gaps: Array[float] = []
	var total := 0.0
	for i in _stitches - 1:
		var g := randf_range(0.55, 1.55)
		gaps.append(g)
		total += g
	var pts := PackedFloat32Array()
	pts.append(_map01(0.0, total))
	var acc := 0.0
	for i in _stitches - 1:
		acc += gaps[i]
		pts.append(_map01(acc, total))
	return pts


func _map01(v: float, total: float) -> float:
	return lerpf(0.08, 0.92, v / total if total > 0.0 else 0.0)


func _register_mistake() -> void:
	_mistakes += 1
	_play(_slip, 0.7)
	_refresh_pips()
	if _mistakes >= _max_mistakes:
		_fail()


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	Sfx.stop_loop("sew_machine_loop")
	_play(_complete, 0.7)
	_set_status("Seam finished — looking sharp!", Style.FOREST)
	_repaint()
	var score := 0.0
	for j in _judge:
		score += 1.0 if j == Stitch.PERFECT else (0.7 if j == Stitch.GOOD else 0.0)
	var quality := clampf(score / _pts.size(), 0.15, 1.0)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, quality)


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	Sfx.stop_loop("sew_machine_loop")
	_play(_ruined, 0.8)
	_set_status("Ruined — the seam is a mess.", Style.CLAY)
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
	head.add_child(Style.title_label("Sewing Machine", Style.ACC_WORK))
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
		Style.hint_bar([["E / Space", "Stitch"], ["Shift", "Speed up (riskier)"]])
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
		_set_status("Find the rhythm…  %d" % ceili(_lead), Style.AMBER)
		return
	var tip := "Tap as the needle meets each stitch"
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


# --- Painting (called from the MinigameCanvas) -----------------------------


func _seam_y() -> float:
	return _canvas.size.y * 0.5


func _seam_x(frac: float) -> float:
	var pad := _canvas.size.x * 0.1
	return pad + frac * (_canvas.size.x - pad * 2.0)


func _paint(c: Control) -> void:
	var band_h: float = minf(c.size.y * 0.6, 150.0)
	var band := Rect2(8.0, _seam_y() - band_h * 0.5, c.size.x - 16.0, band_h)
	var cloth := StyleBoxFlat.new()
	cloth.bg_color = _cloth
	cloth.set_corner_radius_all(10)
	cloth.set_border_width_all(2)
	cloth.border_color = _cloth.darkened(0.25)
	c.draw_style_box(cloth, band)

	var y := _seam_y()
	# Timing band around the next pending point.
	var nxt := _next_pending()
	if nxt != -1 and _state == State.RUNNING and _lead <= 0.0:
		var gx0 := _seam_x(_pts[nxt] - _good_window)
		var gx1 := _seam_x(_pts[nxt] + _good_window)
		c.draw_rect(Rect2(gx0, y - 26.0, gx1 - gx0, 52.0), Color(Style.FOREST, 0.20))

	# Seam guide (a dashed chalk line the needle follows).
	_dashed(c, Vector2(_seam_x(0.0), y), Vector2(_seam_x(1.0), y), Color(Style.WALNUT, 0.4))

	# Stitch points.
	for i in _pts.size():
		var p := Vector2(_seam_x(_pts[i]), y)
		match _judge[i]:
			Stitch.PERFECT:
				c.draw_circle(p, 8.0, Style.FOREST)
			Stitch.GOOD:
				c.draw_circle(p, 8.0, Style.AMBER)
			Stitch.MISS:
				_paint_x(c, p, Style.CLAY, 7.0)
			_:
				c.draw_arc(p, 8.0, 0, TAU, 18, Style.BRASS, 2.5)

	if _state == State.RUNNING:
		_paint_needle(c, _seam_x(_needle), y)


## A slim needle with a brass eye and a thread tail, bobbing as it runs the seam.
func _paint_needle(c: Control, nx: float, y: float) -> void:
	var dip: float = absf(sin(_bob)) * 10.0
	var tip := Vector2(nx, y + 4.0)
	var top := Vector2(nx, y - 44.0 + dip)
	c.draw_line(top, tip, Style.WALNUT, 3.0)
	c.draw_circle(top, 4.0, Style.BRASS)
	c.draw_line(top + Vector2(0, 1.0), top + Vector2(10.0, -8.0), Color(Style.CHALK, 0.8), 1.5)


func _paint_x(c: Control, pos: Vector2, col: Color, r: float) -> void:
	c.draw_line(pos - Vector2(r, r), pos + Vector2(r, r), col, 3.0)
	c.draw_line(pos - Vector2(r, -r), pos + Vector2(r, -r), col, 3.0)


func _dashed(c: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var d := a.distance_to(b)
	if d <= 0.001:
		return
	var dir := (b - a) / d
	var t := 0.0
	while t < d:
		c.draw_line(a + dir * t, a + dir * minf(t + 8.0, d), col, 2.0)
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

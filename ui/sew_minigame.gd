class_name SewMinigame
extends Control

## Rhythm sewing minigame. A needle travels along a seam; tap the stitch button
## (E / Space / F / A) as it reaches each stitch point. Good timing = clean
## stitches; early taps and missed points are mistakes — 3 ruins the piece.
## Emits finished(success, quality).

signal finished(success: bool, quality: float)

enum State { RUNNING, SUCCESS, RUINED }
enum Stitch { PENDING, PERFECT, GOOD, MISS }

const STITCHES := 9
const CROSS_SECONDS := 7.5
const GOOD_WINDOW := 0.05     # in seam fraction (0..1)
const PERFECT_WINDOW := 0.025
const MAX_MISTAKES := 3

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

var _stitch_snd: AudioStream
var _slip: AudioStream
var _complete: AudioStream
var _ruined: AudioStream
var _player: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stitch_snd = _load("stitch")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_player = AudioStreamPlayer.new()
	add_child(_player)


func start(title: String) -> void:
	_title = title
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
	_pts = PackedFloat32Array()
	_judge = PackedInt32Array()
	for i in _stitches:
		_pts.append(lerpf(0.08, 0.92, float(i) / (_stitches - 1)))
		_judge.append(Stitch.PENDING)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _state != State.RUNNING:
		return
	_bob += delta * 12.0

	# Lead-in: hold at the start so the player can find the rhythm.
	if _lead > 0.0:
		_lead -= delta
		queue_redraw()
		return

	_needle += delta / _cross_seconds

	# Points the needle has passed without a stitch are misses.
	for i in _pts.size():
		if _judge[i] == Stitch.PENDING and _needle > _pts[i] + _good_window:
			_judge[i] = Stitch.MISS
			_register_mistake()

	if _needle >= 1.0:
		_succeed()
	queue_redraw()


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
	if not (event.is_action_pressed("interact") or event.is_action_pressed("jump")
			or event.is_action_pressed("cut") or event.is_action_pressed("ui_accept")):
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
	queue_redraw()


func _next_pending() -> int:
	for i in _pts.size():
		if _judge[i] == Stitch.PENDING:
			return i
	return -1


func _register_mistake() -> void:
	_mistakes += 1
	_play(_slip, 0.7)
	if _mistakes >= _max_mistakes:
		_fail()


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	_play(_complete, 0.7)
	queue_redraw()
	var score := 0.0
	for j in _judge:
		score += 1.0 if j == Stitch.PERFECT else (0.7 if j == Stitch.GOOD else 0.0)
	var quality := clampf(score / _pts.size(), 0.15, 1.0)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, quality)


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	_play(_ruined, 0.8)
	queue_redraw()
	await get_tree().create_timer(1.0).timeout
	finished.emit(false, 0.0)


# --- Drawing ---------------------------------------------------------------

func _mat_half() -> float:
	return minf(size.x, size.y) * 0.32


func _origin() -> Vector2:
	return size * 0.5 + Vector2(0, 8)


func _seam_x(frac: float) -> float:
	var half_w := _mat_half() * 0.86
	return _origin().x - half_w + frac * half_w * 2.0


func _draw() -> void:
	var mat_size := _mat_half() * 2.0
	var mat_rect := Rect2(_origin() - Vector2(mat_size, mat_size) * 0.5, Vector2(mat_size, mat_size))
	var mat_box := StyleBoxFlat.new()
	mat_box.bg_color = Color("2e3a30")
	mat_box.set_corner_radius_all(18)
	mat_box.set_border_width_all(4)
	mat_box.border_color = Color("46543f")
	draw_style_box(mat_box, mat_rect)

	var y := _origin().y
	draw_line(Vector2(_seam_x(0.0), y), Vector2(_seam_x(1.0), y), Color(1, 1, 1, 0.25), 3.0)

	# Timing band around the next pending point.
	var nxt := _next_pending()
	if nxt != -1 and _state == State.RUNNING:
		var gx0 := _seam_x(_pts[nxt] - _good_window)
		var gx1 := _seam_x(_pts[nxt] + _good_window)
		draw_rect(Rect2(gx0, y - 24, gx1 - gx0, 48), Color(0.56, 0.78, 0.45, 0.18))

	# Stitch points.
	for i in _pts.size():
		var p := Vector2(_seam_x(_pts[i]), y)
		match _judge[i]:
			Stitch.PERFECT:
				draw_circle(p, 8.0, Color("8fe07a"))
			Stitch.GOOD:
				draw_circle(p, 8.0, Color("e6c84c"))
			Stitch.MISS:
				_draw_x(p, Color("e05a4a"), 7.0)
			_:
				draw_arc(p, 8.0, 0, TAU, 16, Color(1, 1, 1, 0.5), 2.0)

	# Needle.
	if _state == State.RUNNING:
		var nx := _seam_x(_needle)
		var dip: float = absf(sin(_bob)) * 10.0
		draw_line(Vector2(nx, y - 40 + dip), Vector2(nx, y + 6), Color("dfe6d8"), 3.0)
		draw_circle(Vector2(nx, y - 40 + dip), 4.0, Color("dfe6d8"))

	_draw_hud()


func _draw_x(pos: Vector2, col: Color, r: float) -> void:
	draw_line(pos - Vector2(r, r), pos + Vector2(r, r), col, 3.0)
	draw_line(pos - Vector2(r, -r), pos + Vector2(r, -r), col, 3.0)


func _draw_hud() -> void:
	var font := get_theme_default_font()
	var top := _origin() - Vector2(0, _mat_half() + 30)
	draw_string(font, top + Vector2(-_mat_half(), 0), "Sewing  ·  %s" % _title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f4ead2"))
	for i in _max_mistakes:
		var c := Color("e05a4a") if i < _mistakes else Color(1, 1, 1, 0.3)
		draw_circle(_origin() + Vector2(_mat_half() - 60 + i * 26, -_mat_half() - 22), 8.0, c)

	var bottom := _origin() + Vector2(-_mat_half(), _mat_half() + 34)
	if _state == State.RUNNING and _lead > 0.0:
		draw_string(font, bottom, "Get ready…  %d" % ceili(_lead),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e6c84c"))
	elif _state == State.RUNNING:
		var tip := "Tap E / Space as the needle hits each stitch"
		if OS.is_debug_build():
			tip += "   ·   F2 skip"
		draw_string(font, bottom, tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d8cdb2"))
	elif _state == State.SUCCESS:
		draw_string(font, bottom, "Seam finished!  Looking sharp.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8fe07a"))
	else:
		draw_string(font, bottom, "Ruined!  The seam is a mess.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e05a4a"))


func _play(stream: AudioStream, volume_scale: float) -> void:
	if stream == null or _player == null:
		return
	_player.stream = stream
	_player.volume_db = linear_to_db(clampf(volume_scale, 0.01, 1.0))
	_player.play()


func _load(name: String) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % name
	return load(path) if ResourceLoader.exists(path) else null

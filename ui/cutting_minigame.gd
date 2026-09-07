class_name CuttingMinigame
extends Control

## Orient-the-scissors cutting minigame. A random garment shape is drawn on a
## cutting mat; you steer the scissors (WASD / left stick) to keep them aligned
## with the outline as a cut cursor travels around it. Staying misaligned racks
## up mistakes — 3 mistakes ruins the piece. Emits finished(success, quality).

signal finished(success: bool, quality: float)

enum State { RUNNING, SUCCESS, RUINED }

const GOOD_TOL := deg_to_rad(26.0)     # within this of the outline = clean cut
const TARGET_SECONDS := 9.0            # time to cut the whole shape when aligned
const MISTAKE_COST := 0.85             # accumulated error that equals one mistake
const MAX_MISTAKES := 3
const ROT_SPEED := 14.0

# Normalized garment silhouettes (roughly [-1, 1]); jittered at generation.
const SHAPES := {
	Enums.GarmentType.SHIRT: [
		Vector2(-0.6, -0.72), Vector2(0.6, -0.72), Vector2(0.86, -0.34),
		Vector2(0.5, -0.14), Vector2(0.55, 0.8), Vector2(-0.55, 0.8),
		Vector2(-0.5, -0.14), Vector2(-0.86, -0.34),
	],
	Enums.GarmentType.PANTS: [
		Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(0.45, 0.8),
		Vector2(0.12, 0.8), Vector2(0.0, 0.05), Vector2(-0.12, 0.8), Vector2(-0.45, 0.8),
	],
	Enums.GarmentType.JACKET: [
		Vector2(-0.7, -0.68), Vector2(0.7, -0.68), Vector2(0.88, -0.2),
		Vector2(0.55, 0.8), Vector2(0.12, 0.8), Vector2(0.0, -0.22),
		Vector2(-0.12, 0.8), Vector2(-0.55, 0.8), Vector2(-0.88, -0.2),
	],
}

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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_snip = _load("snip")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_player = AudioStreamPlayer.new()
	add_child(_player)


func start(garment_type: int, title: String) -> void:
	_title = title
	_generate(garment_type)
	_state = State.RUNNING
	_cursor = 0.0
	_mistakes = 0
	_error = 0.0
	_cooldown = 0.0
	_nicks = []
	_angle = _tangent_at(0.0)
	set_process(true)
	queue_redraw()


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

	# Alignment is line-orientation (either blade direction is fine).
	var tangent := _tangent_at(_cursor)
	var err: float = minf(
		absf(angle_difference(_angle, tangent)),
		absf(angle_difference(_angle, tangent + PI)))
	_aligned = err <= GOOD_TOL

	if _aligned:
		_cursor += (_total / TARGET_SECONDS) * delta
		_error = maxf(0.0, _error - delta * 0.7)
		_snip_accum += delta
		if _snip_accum >= 0.13:
			_snip_accum = 0.0
			_play(_snip, 0.35)
		if _cursor >= _total:
			_succeed()
	elif _cooldown <= 0.0:
		_error += (err - GOOD_TOL) * delta
		if _error >= MISTAKE_COST:
			_register_mistake()

	queue_redraw()


func _register_mistake() -> void:
	_mistakes += 1
	_error = 0.0
	_cooldown = 0.5
	_nicks.append(_point_at(_cursor))
	_play(_slip, 0.8)
	if _mistakes >= MAX_MISTAKES:
		_fail()


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	_play(_complete, 0.7)
	queue_redraw()
	var quality := clampf(1.0 - 0.22 * _mistakes, 0.15, 1.0)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, quality)


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	_play(_ruined, 0.8)
	queue_redraw()
	await get_tree().create_timer(1.0).timeout
	finished.emit(false, 0.0)


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


# --- Drawing ---------------------------------------------------------------

func _mat_half() -> float:
	# Half the cutting mat's size; kept below full height so the HUD text fits.
	return minf(size.x, size.y) * 0.32


func _scale() -> float:
	return _mat_half() * 0.8


func _origin() -> Vector2:
	return size * 0.5 + Vector2(0, 8)


func _world(p: Vector2) -> Vector2:
	return _origin() + p * _scale()


func _draw() -> void:
	# Cutting mat.
	var mat_size := _mat_half() * 2.0
	var mat_rect := Rect2(_origin() - Vector2(mat_size, mat_size) * 0.5, Vector2(mat_size, mat_size))
	var mat_box := StyleBoxFlat.new()
	mat_box.bg_color = Color("2e3a30")
	mat_box.set_corner_radius_all(18)
	mat_box.set_border_width_all(4)
	mat_box.border_color = Color("46543f")
	draw_style_box(mat_box, mat_rect)

	# Full outline (guide) + cut progress.
	var outline: PackedVector2Array = []
	for p in _pts:
		outline.append(_world(p))
	outline.append(_world(_pts[0]))
	draw_polyline(outline, Color(1, 1, 1, 0.28), 3.0)

	_draw_progress()

	# Nicks.
	for n in _nicks:
		_draw_x(_world(n), Color("e05a4a"), 7.0)

	# Scissors at the cursor.
	var cur := _world(_point_at(_cursor))
	var col := Color("8fe07a") if _aligned else Color("e58b5a")
	_draw_scissors(cur, _angle, col)

	_draw_hud()


func _draw_progress() -> void:
	if _cursor <= 0.0:
		return
	var pl: PackedVector2Array = []
	pl.append(_world(_point_at(0.0)))
	for i in _pts.size():
		if _cum[i + 1] <= _cursor:
			pl.append(_world(_pts[(i + 1) % _pts.size()]))
	pl.append(_world(_point_at(_cursor)))
	if pl.size() >= 2:
		draw_polyline(pl, Color("8fe07a"), 6.0)
	draw_circle(_world(_point_at(0.0)), 6.0, Color("f4ead2"))


func _draw_scissors(pos: Vector2, angle: float, col: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var perp := dir.orthogonal()
	draw_line(pos - dir * 12 + perp * 5, pos + dir * 30 + perp * 3, col, 3.0)
	draw_line(pos - dir * 12 - perp * 5, pos + dir * 30 - perp * 3, col, 3.0)
	draw_arc(pos - dir * 18 + perp * 7, 6.0, 0, TAU, 14, col, 2.0)
	draw_arc(pos - dir * 18 - perp * 7, 6.0, 0, TAU, 14, col, 2.0)


func _draw_x(pos: Vector2, col: Color, r: float) -> void:
	draw_line(pos - Vector2(r, r), pos + Vector2(r, r), col, 3.0)
	draw_line(pos - Vector2(r, -r), pos + Vector2(r, -r), col, 3.0)


func _draw_hud() -> void:
	var font := get_theme_default_font()
	var top := _origin() - Vector2(0, _mat_half() + 30)
	draw_string(font, top + Vector2(-_mat_half(), 0), "Cutting  ·  %s" % _title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f4ead2"))

	# Mistakes as pips (top-right of the mat).
	for i in MAX_MISTAKES:
		var c := Color("e05a4a") if i < _mistakes else Color(1, 1, 1, 0.3)
		draw_circle(_origin() + Vector2(_mat_half() - 60 + i * 26, -_mat_half() - 22), 8.0, c)

	var bottom := _origin() + Vector2(-_mat_half(), _mat_half() + 34)
	if _state == State.RUNNING:
		var pct := int(_cursor / _total * 100.0)
		draw_string(font, bottom, "Point the scissors along the line   ·   %d%%" % pct,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d8cdb2"))
	elif _state == State.SUCCESS:
		draw_string(font, bottom, "Cut complete!  Nice work.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8fe07a"))
	else:
		draw_string(font, bottom, "Ruined!  The piece is wasted.",
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

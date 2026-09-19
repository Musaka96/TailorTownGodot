class_name CoffeeBench
extends MinigameScreen

## The coffee counter both coffee games share. A cup is made in one or more one-button
## beats, laid out left to right on the counter with the one in hand lit:
##
##   GRIND  a needle sweeps the grinder's dial — tap to stop it in the band
##   TAMP   hold to press the tamper down, let go at the mark
##   POUR   hold to pour, let go at the line; over the rim is a spill, and the cup is lost
##
## TAMP and POUR are the same hold-and-release gauge: it climbs faster the further it gets,
## so the last stretch takes a little nerve. A subclass only names its beats (_beats) and
## its title. Emits finished(success, quality): quality is the mean of the beats' grades;
## success is false only for a spilt cup. No slips, so the header's pins stay empty.

signal finished(success: bool, quality: float)

enum Beat { GRIND, TAMP, POUR }
enum Grade { PERFECT, GOOD, WEAK }
enum State { RUNNING, SUCCESS, SPILLED }

const GRADE_SCORE := [1.0, 0.7, 0.3]
const GRADE_WORD := ["Perfect", "Good", "Off"]
const BEAT_NAME := ["Grind", "Tamp", "Pour"]
const BEAT_HINT := [
	"Stop the grinder in the band",
	"Hold to tamp, let go at the mark",
	"Hold to pour, let go at the line",
]
const PERFECT_BAND := 0.035
const GOOD_BAND := 0.085
const DIAL_PERFECT := 0.045
const DIAL_GOOD := 0.11
const FILL_BASE := 0.26  # gauge units a second at the bottom…
const FILL_ACCEL := 0.6  # …plus this much per unit already filled
const SWEEP_SPEED := 0.95  # dial sweeps a second
const BEAT_PAUSE := 0.55  # a breath between beats, with the grade showing
const PERFECT_CUP := 0.9
const GOOD_CUP := 0.6

const GRIND_LOOP := "grinder"
const POUR_LOOP := "pour"
const LOOP_DB := -5.0
const COUNTER_INSET := 10.0

var _state := State.RUNNING
var _armed := false  # the press that opened the counter must be let go first
var _beat_list: Array = []
var _grades: Array = []
var _beat := 0
var _level := 0.0  # the gauge (tamp, pour) or the needle (grind)
var _mark := 0.5
var _dir := 1.0
var _holding := false
var _pause := 0.0

var _complete: AudioStream
var _ruined: AudioStream


## Which beats this cup takes, in order. Overridden by each game.
func _beats() -> Array:
	return [Beat.POUR]


func _title() -> String:
	return "Coffee"


func _ready() -> void:
	_ensure_chrome(_title(), _paint)


func _load_assets() -> void:
	_complete = _load("complete")
	_ruined = _load("ruined")


func coach_flags() -> Dictionary:
	return {"started": _state == State.RUNNING, "beats": _grades.size()}


## The contract the coffee machine uses for both games.
func start_cup(title: String) -> void:
	_ensure_chrome(_title(), _paint)
	_state = State.RUNNING
	_armed = false
	_beat_list = _beats()
	_grades = []
	_beat = -1
	_pause = 0.0
	_max_mistakes = 0
	_set_job(title)
	_show_panel()
	set_process(true)
	_next_beat()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_stop_sounds()


func _exit_tree() -> void:
	_stop_sounds()


func _stop_sounds() -> void:
	Sfx.stop_loop(GRIND_LOOP)
	Sfx.stop_loop(POUR_LOOP)


func _process(delta: float) -> void:
	if _state != State.RUNNING:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_next_beat()
		_repaint()
		return
	var held := _button_held()
	if not _armed and not held:
		_armed = true
	if _kind() == Beat.GRIND:
		_sweep(delta, _armed and held)
	else:
		_fill(delta, _armed and held)
	_repaint()


## Debug (F2, debug builds only): skip to a perfect cup.
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.RUNNING or not OS.is_debug_build():
		return
	if event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		_stop_sounds()
		finished.emit(true, 1.0)


## Any of the "do it" buttons (F / Space / E / pad A, X, Y).
func _button_held() -> bool:
	for action in ["cut", "jump", "interact", "ui_accept"]:
		if Input.is_action_pressed(action):
			return true
	return false


func _kind() -> int:
	return _beat_list[_beat] if _beat >= 0 and _beat < _beat_list.size() else Beat.POUR


func _next_beat() -> void:
	_beat += 1
	if _beat >= _beat_list.size():
		_succeed()
		return
	_level = 0.0
	_dir = 1.0
	_holding = false
	_armed = false  # each beat wants a fresh press
	match _kind():
		Beat.GRIND:
			_mark = randf_range(0.3, 0.7)
			Sfx.start_loop(GRIND_LOOP, LOOP_DB)
		Beat.TAMP:
			_mark = randf_range(0.6, 0.8)
		_:
			_mark = randf_range(0.76, 0.86)
	_set_hints([["E / Space", BEAT_HINT[_kind()]]])
	_update_status()


## The grinder's needle swings back and forth; the press stops it where it is.
func _sweep(delta: float, held: bool) -> void:
	if held:
		_grade(_judge(DIAL_PERFECT, DIAL_GOOD))
		return
	_level += _dir * SWEEP_SPEED * delta
	if _level >= 1.0 or _level <= 0.0:
		_level = clampf(_level, 0.0, 1.0)
		_dir = -_dir
	Sfx.set_loop_pitch(GRIND_LOOP, 0.9 + 0.2 * _level)


## Hold to fill, let go to be judged. Topping out ends it for you: a tamp pressed too hard
## is only "off", but a cup poured over the rim is a spill.
func _fill(delta: float, held: bool) -> void:
	if held:
		if not _holding and _kind() == Beat.POUR:
			Sfx.start_loop(POUR_LOOP, LOOP_DB)
		_holding = true
		_level = minf(1.0, _level + (FILL_BASE + FILL_ACCEL * _level) * delta)
		if _level >= 1.0:
			if _kind() == Beat.POUR:
				_spill()
			else:
				_grade(Grade.WEAK)
		return
	if not _holding:
		return
	_grade(_judge(PERFECT_BAND, GOOD_BAND))


## How close the gauge (or needle) stopped to its mark.
func _judge(fine: float, good: float) -> int:
	var d := absf(_level - _mark)
	if d <= fine:
		return Grade.PERFECT
	return Grade.GOOD if d <= good else Grade.WEAK


func _grade(grade: int) -> void:
	_stop_sounds()
	_holding = false
	_grades.append(grade)
	if _kind() == Beat.TAMP:
		Sfx.play("tamp")
	elif _kind() == Beat.POUR:
		Sfx.play("putdown")
	var col: Color = [Style.FOREST, Style.FOREST, Style.AMBER][grade]
	_set_status("%s — %s" % [BEAT_NAME[_kind()], GRADE_WORD[grade].to_lower()], col)
	_pause = BEAT_PAUSE


func _score() -> float:
	if _grades.is_empty():
		return 0.0
	var total := 0.0
	for g: int in _grades:
		total += GRADE_SCORE[g]
	return total / _grades.size()


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	_stop_sounds()
	_play(_complete, 0.7)
	var score := _score()
	var word := "Weak cup"
	if score >= PERFECT_CUP:
		word = "Perfect cup"
	elif score >= GOOD_CUP:
		word = "Good cup"
	_set_status(word, Style.FOREST if score >= GOOD_CUP else Style.AMBER)
	_repaint()
	await get_tree().create_timer(0.8).timeout
	finished.emit(true, score)


func _spill() -> void:
	_state = State.SPILLED
	set_process(false)
	_stop_sounds()
	_play(_ruined, 0.8)
	Craft.wiggle(_panel, SLIP_ROCK)
	_set_status("Spilled — that cup's gone", Style.CLAY)
	_repaint()
	await get_tree().create_timer(1.0).timeout
	finished.emit(false, 0.0)


func _update_status() -> void:
	var tip: String = BEAT_NAME[_kind()]
	if _beat_list.size() > 1:
		tip += "   ·   step %d of %d" % [_beat + 1, _beat_list.size()]
	if OS.is_debug_build():
		tip += "   ·   F2 skip"
	_set_status(tip, Style.INK_SOFT)


# --- Painting (called from the MinigameCanvas) -----------------------------


func _paint(c: Control) -> void:
	var rect := Rect2(
		Vector2(COUNTER_INSET, COUNTER_INSET),
		c.size - Vector2(COUNTER_INSET * 2.0, COUNTER_INSET * 2.0)
	)
	var top := StyleBoxFlat.new()
	top.bg_color = Style.WALNUT.lightened(0.1)
	top.set_corner_radius_all(14)
	top.set_border_width_all(3)
	top.border_color = Style.WALNUT
	c.draw_style_box(top, rect)
	var n := maxi(1, _beat_list.size())
	var w := rect.size.x / n
	for i in n:
		var slot := Rect2(rect.position.x + i * w, rect.position.y, w, rect.size.y).grow(-12.0)
		_paint_slot(c, slot, i)


## One beat's place on the counter: a card, its name, its grade once made, and the thing
## itself. The beat in hand is bright; the others wait dimmed.
func _paint_slot(c: Control, slot: Rect2, index: int) -> void:
	var active := index == _beat and _state == State.RUNNING
	var card := StyleBoxFlat.new()
	card.bg_color = Style.CARD if active else Style.tint(Style.CARD, 0.55)
	card.set_corner_radius_all(10)
	card.set_border_width_all(3 if active else 1)
	card.border_color = Style.BRASS if active else Style.RIM_DARK
	c.draw_style_box(card, slot)
	var kind: int = _beat_list[index] if index < _beat_list.size() else Beat.POUR
	var font := Style.bold_font()
	var label: String = BEAT_NAME[kind]
	if index < _grades.size():
		label += " · " + GRADE_WORD[_grades[index]]
	c.draw_string(font, slot.position + Vector2(12.0, 24.0), label, 0, -1, 16, Style.INK)
	var level := _level if index == _beat else (-1.0 if index > _beat else -2.0)
	var body := Rect2(slot.position + Vector2(0.0, 32.0), slot.size - Vector2(0.0, 40.0))
	match kind:
		Beat.GRIND:
			_paint_dial(c, body, level)
		Beat.TAMP:
			_paint_tamp(c, body, level)
		_:
			_paint_cup(c, body, level)


## `level` < 0 means the beat is not live: -1 still to come, -2 already made.
func _paint_dial(c: Control, body: Rect2, level: float) -> void:
	var r := minf(body.size.x * 0.42, body.size.y - 30.0)
	var at := Vector2(body.get_center().x, body.get_center().y + r * 0.5)
	c.draw_arc(at, r, PI, TAU, 32, Style.WALNUT, 4.0, true)
	c.draw_circle(at, 7.0, Style.BRASS)
	if level < 0.0:
		return
	var a0 := PI + (_mark - DIAL_GOOD) * PI
	var a1 := PI + (_mark + DIAL_GOOD) * PI
	c.draw_arc(at, r - 9.0, a0, a1, 12, Style.tint(Style.FOREST, 0.5), 12.0)
	var p0 := PI + (_mark - DIAL_PERFECT) * PI
	var p1 := PI + (_mark + DIAL_PERFECT) * PI
	c.draw_arc(at, r - 9.0, p0, p1, 8, Style.FOREST, 12.0)
	var ang := PI + level * PI
	c.draw_line(at, at + Vector2(cos(ang), sin(ang)) * (r - 2.0), Style.CLAY, 4.0, true)


func _paint_tamp(c: Control, body: Rect2, level: float) -> void:
	var tube := Rect2(body.get_center().x - 26.0, body.position.y + 6.0, 52.0, body.size.y - 22.0)
	c.draw_rect(tube, Style.tint(Style.WALNUT, 0.15))
	c.draw_rect(tube, Style.WALNUT, false, 3.0)
	if level < 0.0:
		return
	_paint_band(c, tube, true)
	# The tamper comes down from the top as the gauge climbs.
	var y := lerpf(tube.position.y, tube.end.y, level)
	c.draw_line(
		Vector2(tube.get_center().x, tube.position.y - 4.0),
		Vector2(tube.get_center().x, y),
		Style.WALNUT,
		8.0
	)
	c.draw_rect(Rect2(tube.position.x + 3.0, y - 6.0, tube.size.x - 6.0, 12.0), Style.STEEL)


func _paint_cup(c: Control, body: Rect2, level: float) -> void:
	var w := minf(body.size.x * 0.5, 130.0)
	var cup := Rect2(body.get_center().x - w * 0.5, body.position.y + 26.0, w, body.size.y - 44.0)
	c.draw_rect(cup, Style.tint(Style.CHALK, 0.6))
	if level >= 0.0 or level == -2.0:
		var shown := level if level >= 0.0 else _mark
		var h := cup.size.y * clampf(shown, 0.0, 1.0)
		var coffee := Rect2(cup.position.x, cup.end.y - h, cup.size.x, h)
		c.draw_rect(coffee, Style.WALNUT.darkened(0.25))
		c.draw_rect(Rect2(coffee.position, Vector2(cup.size.x, minf(h, 5.0))), Style.LINEN)
	c.draw_rect(cup, Style.INK, false, 3.0)
	c.draw_arc(
		Vector2(cup.end.x, cup.get_center().y),
		cup.size.y * 0.22,
		-PI / 2.0,
		PI / 2.0,
		12,
		Style.INK,
		4.0
	)
	if level < 0.0:
		return
	_paint_band(c, cup, false)
	if _holding:
		var x := cup.get_center().x
		var to := cup.end.y - cup.size.y * level
		c.draw_line(Vector2(x, body.position.y), Vector2(x, to), Style.WALNUT.darkened(0.25), 6.0)
	if _state == State.SPILLED:
		c.draw_line(
			cup.position,
			Vector2(cup.position.x - 14.0, cup.end.y),
			Style.WALNUT.darkened(0.25),
			5.0
		)
		c.draw_line(
			Vector2(cup.end.x, cup.position.y),
			cup.end + Vector2(14.0, 0.0),
			Style.WALNUT.darkened(0.25),
			5.0
		)


## The mark on a gauge: the good band, the perfect band inside it, and a brass line with a
## notch either side so it reads without the green. `down` gauges fill from the top.
func _paint_band(c: Control, gauge: Rect2, down: bool) -> void:
	var at := gauge.position.y + gauge.size.y * _mark
	if not down:
		at = gauge.end.y - gauge.size.y * _mark
	var good := gauge.size.y * GOOD_BAND
	var fine := gauge.size.y * PERFECT_BAND
	var x := gauge.position.x
	var w := gauge.size.x
	c.draw_rect(Rect2(x, at - good, w, good * 2.0), Style.tint(Style.FOREST, 0.22))
	c.draw_rect(Rect2(x, at - fine, w, fine * 2.0), Style.tint(Style.FOREST, 0.45))
	c.draw_line(Vector2(x - 8.0, at), Vector2(x + w + 8.0, at), Style.BRASS, 3.0)

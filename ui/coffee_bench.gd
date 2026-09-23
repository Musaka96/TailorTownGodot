class_name CoffeeBench
extends MinigameScreen

## The coffee counter both coffee games share. A cup is made in one or more one-button
## beats, laid out left to right on the counter with the one in hand lit:
##
##   GRIND  hold to run the grinder, let go when the dial's needle is in the band
##   TAMP   hold to press the tamper down, let go at the mark
##   POUR   hold to pour, let go at the line; over the rim is a spill, and the cup is lost
##
## Nothing moves until the button is held. All three are the same hold-and-release gauge:
## it climbs faster the further it gets, so the last stretch takes a little nerve. A
## subclass only names its beats (_beats) and its title. Emits finished(success, quality):
## quality is the mean of the beats' grades; success is false only for a spilt cup. No
## slips, so the header's pins stay empty.

signal finished(success: bool, quality: float)

enum Beat { GRIND, TAMP, POUR }
enum Grade { PERFECT, GOOD, WEAK }
enum State { RUNNING, SUCCESS, SPILLED }

const GRADE_SCORE := [1.0, 0.7, 0.3]
const GRADE_WORD := ["Perfect", "Good", "Off"]
const BEAT_NAME := ["Grind", "Tamp", "Pour"]
const BEAT_HINT := [
	"Hold to grind, let go in the band",
	"Hold to tamp, let go at the mark",
	"Hold to pour, let go at the line",
]
const PERFECT_BAND := 0.035
const GOOD_BAND := 0.085
const DIAL_PERFECT := 0.045
const DIAL_GOOD := 0.11
const FILL_BASE := 0.26  # gauge units a second at the bottom…
const FILL_ACCEL := 0.6  # …plus this much per unit already filled
const BEAT_PAUSE := 0.85  # between beats: the grade shows, the portafilter is carried on
const PERFECT_CUP := 0.9
const GOOD_CUP := 0.6

const GRIND_LOOP := "grinder"
const POUR_LOOP := "pour"
const LOOP_DB := -5.0
const COUNTER_INSET := 10.0
const COUNTER_H := 62.0  # the counter's front, below the things standing on it
const SCENE_H := 300.0  # the tallest thing on the counter, in CoffeeArt's own units
const TAMP_TOP := -150.0  # the tamper's face above the mat at rest…
const TAMP_BOTTOM := -24.0  # …and rammed right down into the basket
const TAMP_TOUCH := 0.3  # the gauge level at which the tamper meets the coffee
const HEAP_FOOT := -31.0  # the basket's rim over the mat, where the mound starts…
const HEAP_RISE := 16.0  # …and how high loose coffee heaps above it

var _state := State.RUNNING
var _armed := false  # the press that opened the counter must be let go first
var _beat_list: Array = []
var _grades: Array = []
var _beat := 0
var _level := 0.0  # the gauge (tamp, pour) or the needle (grind)
var _mark := 0.5
var _holding := false
var _pause := 0.0
var _anim := 0.0  # free-running, for steam, beans and falling grounds
var _beat_time := 0.0
var _tilt := 0.0  # how far the carafe is tipped, easing after the button
var _tamped := 0.0  # where the tamp and the pour stopped, to go on showing them
var _poured := 0.0

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
	_tilt = 0.0
	_tamped = 0.0
	_poured = 0.0
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
	_anim += delta
	_beat_time += delta
	var tipping := _holding and _kind() == Beat.POUR and _state == State.RUNNING
	_tilt = lerpf(_tilt, 1.0 if tipping else 0.0, clampf(delta * 9.0, 0.0, 1.0))
	if _state != State.RUNNING:
		_repaint()
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
	_beat_time = 0.0
	_holding = false
	_armed = false  # each beat wants a fresh press
	match _kind():
		Beat.GRIND:
			_mark = randf_range(0.74, 0.87)  # towards the end of the dial
		Beat.TAMP:
			_mark = randf_range(0.6, 0.8)
		_:
			_mark = randf_range(0.76, 0.86)
	_set_hints([["E / Space", BEAT_HINT[_kind()]]])
	_update_status()


## Hold to fill, let go to be judged. Topping out ends it for you: beans ground too long
## or a tamp pressed too hard are only "off", but a cup poured over the rim is a spill.
func _fill(delta: float, held: bool) -> void:
	if held:
		if not _holding and _kind() == Beat.POUR:
			Sfx.start_loop(POUR_LOOP, LOOP_DB)
		elif not _holding and _kind() == Beat.GRIND:
			Sfx.start_loop(GRIND_LOOP, LOOP_DB)
		_holding = true
		if _kind() == Beat.GRIND:
			Sfx.set_loop_pitch(GRIND_LOOP, 0.9 + 0.25 * _level)
		_level = minf(1.0, _level + (FILL_BASE + FILL_ACCEL * _level) * delta)
		if _level >= 1.0:
			if _kind() == Beat.POUR:
				_spill()
			else:
				_grade(Grade.WEAK)
		return
	if not _holding:
		return
	if _kind() == Beat.GRIND:
		_grade(_judge(DIAL_PERFECT, DIAL_GOOD))
	else:
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
	if _kind() == Beat.TAMP:
		_tamped = _level
	elif _kind() == Beat.POUR:
		_poured = _level
	_grades.append(grade)
	if _kind() == Beat.TAMP:
		Sfx.play("tamp")
	elif _kind() == Beat.POUR:
		Sfx.play("putdown")
	if grade == Grade.PERFECT:
		_perfect_beat(_canvas.size * Vector2(0.5, 0.45), Style.BRASS_LIGHT)
	elif grade == Grade.WEAK:
		_break_streak()
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
	_stamp_verdict(score, word)
	await get_tree().create_timer(_stamp_hold(score)).timeout
	finished.emit(true, score)


func _spill() -> void:
	_state = State.SPILLED
	_holding = false
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
	_set_status(tip, Style.INK_SOFT)


# --- Painting (called from the MinigameCanvas) -----------------------------
# The things themselves are CoffeeArt's; this lays out the counter, moves them with the
# game, and draws the game's marks (band, needle, fill line) on top of them.


func _paint(c: Control) -> void:
	var rect := Rect2(
		Vector2(COUNTER_INSET, COUNTER_INSET),
		c.size - Vector2(COUNTER_INSET * 2.0, COUNTER_INSET * 2.0)
	)
	var wall := StyleBoxFlat.new()
	wall.bg_color = Style.CARD
	wall.set_corner_radius_all(14)
	wall.set_border_width_all(3)
	wall.border_color = Style.WALNUT
	c.draw_style_box(wall, rect)
	var top := rect.end.y - COUNTER_H
	var slab := Rect2(rect.position.x + 3.0, top, rect.size.x - 6.0, COUNTER_H - 3.0)
	c.draw_rect(slab, Style.WALNUT.lightened(0.08))
	c.draw_rect(Rect2(slab.position, Vector2(slab.size.x, 7.0)), Style.WALNUT.lightened(0.22))
	c.draw_line(slab.position, Vector2(slab.end.x, top), Style.WALNUT, 2.0)
	var s := clampf((rect.size.y - COUNTER_H - 8.0) / SCENE_H, 0.5, 1.5)
	if _beat_list.size() > 1:
		_paint_espresso_bar(c, rect, top, s)
	else:
		_paint_coffee_corner(c, rect, top, s)
	c.draw_set_transform(Vector2.ZERO)
	_paint_labels(c, rect, top)


func _place(c: Control, at: Vector2, s: float, turn := 0.0) -> void:
	c.draw_set_transform(at, turn, Vector2(s, s))


## Instant coffee: the filter machine, a glass mug on its saucer, and the carafe tipping
## over it while the button is held.
func _paint_coffee_corner(c: Control, rect: Rect2, top: float, s: float) -> void:
	_place(c, Vector2(rect.position.x + rect.size.x * 0.2, top), s)
	CoffeeArt.filter_machine(c)
	var cup := Vector2(rect.position.x + rect.size.x * 0.6, top)
	_place(c, cup, s)
	CoffeeArt.saucer(c, CoffeeArt.MUG.x + 56.0)
	_place(c, cup + Vector2(0.0, -9.0) * s, s)
	_paint_vessel(c, CoffeeArt.MUG, true)
	var spout := cup + Vector2(-8.0, -9.0 - CoffeeArt.MUG.z - 58.0) * s
	if _holding and _state == State.RUNNING:
		var surface := CoffeeArt.level_y(CoffeeArt.MUG, _level) - 9.0
		c.draw_set_transform(Vector2.ZERO)
		var fall := Vector2(spout.x + 3.0 * s, cup.y + surface * s)
		c.draw_line(spout, fall, CoffeeArt.coffee(), 7.0 * s, true)
		c.draw_circle(spout, 3.5 * s, CoffeeArt.coffee())
	var turn := lerpf(-0.12, 0.62, _tilt)
	_place(c, spout, s, turn)
	CoffeeArt.carafe(c, turn)


## Espresso: grinder, tamping mat and machine in a row, and the one portafilter carried
## from each to the next as its beat is made.
func _paint_espresso_bar(c: Control, rect: Rect2, top: float, s: float) -> void:
	var grinder := Vector2(rect.position.x + rect.size.x * 0.14, top)
	var mat := Vector2(rect.position.x + rect.size.x * 0.43, top)
	var machine := Vector2(rect.position.x + rect.size.x * 0.77, top)
	var kind := _kind()
	var grinding := kind == Beat.GRIND and _holding and _state == State.RUNNING
	_place(c, grinder, s)
	CoffeeArt.grinder(c, _anim if grinding else 0.0)
	_paint_dial(c)
	_place(c, mat, s)
	CoffeeArt.tamp_mat(c)
	_place(c, machine, s)
	var pulling := kind == Beat.POUR and _holding
	CoffeeArt.machine(c, (0.75 + 0.05 * sin(_anim * 9.0)) if pulling else 0.0)
	_place(c, machine + CoffeeArt.TRAY_AT * s, s)
	_paint_vessel(c, CoffeeArt.SHOT_GLASS, false)
	if pulling and _state == State.RUNNING:
		_paint_shot(c)
	# The portafilter, wherever it has got to.
	var docks := [
		grinder + CoffeeArt.FORK_AT * s,
		mat + CoffeeArt.MAT_AT * s,
		machine + CoffeeArt.GROUP_AT * s,
	]
	var made := _grades.size()
	var heap := 1.0 if made > 0 else clampf(_level / 0.8, 0.0, 1.0)
	if kind == Beat.TAMP and _pause <= 0.0:
		# The tamper squashes the mound down as it comes.
		heap = clampf((HEAP_FOOT - _tamp_face(_level)) / HEAP_RISE, 0.0, 1.0)
	if grinding:
		_paint_grounds(c, docks[0], s)
	if kind == Beat.TAMP or (made == 1 and _pause > 0.0):
		_paint_tamper(c, mat, s, kind == Beat.TAMP and _pause <= 0.0)
	_place(c, _carried(docks, s), s)
	CoffeeArt.portafilter(c, heap, made >= 2)


## Where the portafilter is: docked for the beat in hand, or on its way to the next one
## while the last beat's grade is showing.
func _carried(docks: Array, s: float) -> Vector2:
	var here: Vector2 = docks[clampi(_beat, 0, docks.size() - 1)]
	if _pause <= 0.0 or _beat + 1 >= docks.size() or _grades.size() <= _beat:
		return here
	var t := smoothstep(0.15, 1.0, 1.0 - _pause / BEAT_PAUSE)
	var there: Vector2 = docks[_beat + 1]
	# Lifted over the counter to the mat; brought in from underneath to lock into the group.
	var arc := -46.0 if _beat == 0 else 30.0
	return here.lerp(there, t) + Vector2(0.0, sin(t * PI) * arc * s)


## The grind gauge, on the grinder's own dial: the band near the end of it, and the needle
## that climbs towards it while the grinder runs.
func _paint_dial(c: Control) -> void:
	var at := CoffeeArt.DIAL_AT
	var r := CoffeeArt.DIAL_R
	c.draw_arc(at, r - 7.0, PI, TAU, 24, Style.tint(Style.WALNUT, 0.35), 3.0, true)
	var live := _kind() == Beat.GRIND and _state == State.RUNNING
	if live:
		var a0 := PI + (_mark - DIAL_GOOD) * PI
		var a1 := PI + (_mark + DIAL_GOOD) * PI
		c.draw_arc(at, r - 12.0, a0, a1, 12, Style.tint(Style.FOREST, 0.45), 14.0)
		var p0 := PI + (_mark - DIAL_PERFECT) * PI
		var p1 := PI + (_mark + DIAL_PERFECT) * PI
		c.draw_arc(at, r - 12.0, p0, p1, 8, Style.FOREST, 14.0)
		var notch := PI + _mark * PI
		var rim := Vector2(cos(notch), sin(notch))
		c.draw_line(at + rim * (r - 3.0), at + rim * (r + 5.0), Style.BRASS, 4.0)
	var ang := PI + (_level if live else 0.0) * PI
	c.draw_line(at, at + Vector2(cos(ang), sin(ang)) * (r - 6.0), Style.CLAY, 4.0, true)
	c.draw_circle(at, 6.0, Style.BRASS)


## Ground coffee falling from the chute into the basket.
func _paint_grounds(c: Control, dock: Vector2, s: float) -> void:
	_place(c, dock, s)
	for k in 7:
		var t := fmod(_anim * 2.2 + k / 7.0, 1.0)
		var x := sin(k * 7.3) * 7.0
		c.draw_circle(Vector2(x, lerpf(-30.0, -10.0, t)), 2.5, Style.BROWN.darkened(0.3))


## How high the tamper's face is over the mat for a gauge level: it drops quickly onto the
## mound, then grinds slowly down into the basket — so at the mark it is pressing the puck.
func _tamp_face(level: float) -> float:
	if level < TAMP_TOUCH:
		return lerpf(TAMP_TOP, HEAP_FOOT - HEAP_RISE, level / TAMP_TOUCH)
	return lerpf(HEAP_FOOT - HEAP_RISE, TAMP_BOTTOM, (level - TAMP_TOUCH) / (1.0 - TAMP_TOUCH))


## The tamper over the mat, coming down onto the coffee, and a pressure rule beside it
## whose brass pointer slides down with the gauge: the pointer against the band is the game.
func _paint_tamper(c: Control, mat: Vector2, s: float, live: bool) -> void:
	# Once the tamp is made the tamper lifts clear again, ahead of the portafilter leaving.
	var lifting := clampf(_pause / BEAT_PAUSE * 2.5 - 1.5, 0.0, 1.0)
	var press := _level if live else _tamped * lifting
	var face := _tamp_face(press)
	var gauge := lerpf(TAMP_TOP, TAMP_BOTTOM, press)
	_place(c, mat, s)
	var span := TAMP_BOTTOM - TAMP_TOP
	var rule := Rect2(64.0, TAMP_TOP, 24.0, span)
	c.draw_rect(rule, Style.tint(Style.WALNUT, 0.12))
	c.draw_rect(rule, Style.WALNUT, false, 2.0)
	if live:
		var y := lerpf(TAMP_TOP, TAMP_BOTTOM, _mark)
		var good := GOOD_BAND * span
		var fine := PERFECT_BAND * span
		c.draw_rect(Rect2(64.0, y - good, 24.0, good * 2.0), Style.tint(Style.FOREST, 0.3))
		c.draw_rect(Rect2(64.0, y - fine, 24.0, fine * 2.0), Style.tint(Style.FOREST, 0.55))
		c.draw_line(Vector2(58.0, y), Vector2(98.0, y), Style.BRASS, 3.0)
	var tip := PackedVector2Array(
		[Vector2(66.0, gauge), Vector2(52.0, gauge - 8.0), Vector2(52.0, gauge + 8.0)]
	)
	c.draw_colored_polygon(tip, Style.BRASS)
	_place(c, mat + Vector2(0.0, face) * s, s)
	CoffeeArt.tamper(c)


## A glass with the game in it: the level while it is being poured, the line to stop at,
## what was poured once it is done, and the mess if it went over.
func _paint_vessel(c: Control, dims: Vector3, handle: bool) -> void:
	var pouring := _kind() == Beat.POUR and _beat >= 0
	var level := _level if pouring else 0.0
	if _state == State.SUCCESS or (pouring and _pause > 0.0):
		level = _poured
	CoffeeArt.glass(c, dims, level, handle)
	if pouring and _state == State.RUNNING and _pause <= 0.0:
		CoffeeArt.fill_mark(c, dims, _mark, GOOD_BAND, PERFECT_BAND)
	if _state == State.SPILLED:
		CoffeeArt.spill(c, dims)
	elif _state == State.SUCCESS or (pouring and _pause > 0.0):
		CoffeeArt.steam(c, Vector2(0.0, -dims.z - 6.0), _anim)


## The shot: two thin streams from the portafilter's spouts into the glass.
func _paint_shot(c: Control) -> void:
	var from := CoffeeArt.GROUP_AT - CoffeeArt.TRAY_AT + Vector2(0.0, 22.0)
	var to := CoffeeArt.level_y(CoffeeArt.SHOT_GLASS, _level)
	for side in [-1.0, 1.0]:
		var a := from + Vector2(9.0 * side, 0.0)
		c.draw_line(a, Vector2(a.x - 3.0 * side, to), CoffeeArt.coffee(), 3.0, true)


## Each beat's name on the counter's front, under its station: the one in hand bright and
## underlined in brass, the ones made with their grade.
func _paint_labels(c: Control, rect: Rect2, top: float) -> void:
	var font := Style.bold_font()
	var spots := [0.14, 0.43, 0.77] if _beat_list.size() > 1 else [0.6]
	for i in _beat_list.size():
		var text: String = BEAT_NAME[_beat_list[i]]
		if i < _grades.size():
			text += " · " + GRADE_WORD[_grades[i]]
		var active := i == _beat and _state == State.RUNNING
		var col := Style.CREAM if active or i < _grades.size() else Style.tint(Style.CREAM, 0.45)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_BODY).x
		var at := Vector2(rect.position.x + rect.size.x * spots[i] - width * 0.5, top + 38.0)
		c.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_BODY, col)
		if active:
			c.draw_line(at + Vector2(0.0, 7.0), at + Vector2(width, 7.0), Style.BRASS, 3.0, true)

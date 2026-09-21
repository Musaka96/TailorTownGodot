extends Control

## The HUD clock as a tailor's brass pocket watch on a chain: cream face with dot hour
## marks, chunky hands, a green START / red END pip for the shift window, and the time
## on a little swing ticket underneath. Reads DayNight; pulses red and says "CLOSED"
## once the shift ends. Purely presentational — it never advances time itself.

const FACE := Color(0.99, 0.96, 0.90)
const RIM := Color("c9a24a")  # brass case
const RIM_DARK := Color("8a6a2a")
const TICK := Color(0.45, 0.36, 0.30)
const HAND := Color(0.24, 0.19, 0.16)
const MIN_HAND := Color(0.45, 0.38, 0.32)
const START_COL := Color(0.30, 0.72, 0.38)
const END_COL := Color(0.90, 0.34, 0.30)
const TEXT := Color(0.35, 0.28, 0.24)

var _ended := false
var _flash := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(104, 142)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.shift_started.connect(func(_h: float) -> void: _ended = false)
	EventBus.shift_ended.connect(func() -> void: _ended = true)


## Show (or clear) the CLOSED state without the bell — for a day loaded after hours.
func show_closed(closed: bool) -> void:
	_ended = closed


func _process(delta: float) -> void:
	if _ended:
		_flash += delta
	queue_redraw()


func _draw() -> void:
	var r := _radius()
	var c := _center()
	var now := _hour_now()

	_draw_chain(c, r)
	# Crown + bow on top, then the brass case (shadow, outer ring, bevel) and the face.
	draw_rect(Rect2(c + Vector2(-4, -r - 9), Vector2(8, 7)), RIM)
	draw_rect(Rect2(c + Vector2(-4, -r - 9), Vector2(8, 7)), RIM_DARK, false, 1.2)
	draw_arc(c + Vector2(0, -r - 12), 5.0, 0.0, TAU, 16, RIM, 2.5, true)
	draw_circle(c + Vector2(0, 4), r + 5.0, Color(0, 0, 0, 0.22))
	draw_circle(c, r + 5.0, RIM)
	draw_arc(c, r + 5.0, 0.0, TAU, 48, RIM_DARK, 1.5, true)
	draw_arc(c, r + 1.5, 0.0, TAU, 48, RIM_DARK, 1.0, true)
	draw_circle(c, r, FACE)
	draw_arc(c + Vector2(-2, -2), r - 3.0, PI * 1.05, PI * 1.45, 10, Color(1, 1, 1, 0.8), 2.0, true)

	# Dot hour marks (bigger at 12/3/6/9).
	for i in 12:
		var big := i % 3 == 0
		draw_circle(_pf(i / 12.0, r * 0.80), 2.4 if big else 1.3, TICK)

	# Shift start / end pips.
	draw_circle(_pf(fmod(_hour_start(), 12.0) / 12.0, r * 0.62), 3.2, START_COL)
	draw_circle(_pf(fmod(_hour_end(), 12.0) / 12.0, r * 0.62), 3.2, END_COL)

	# Chunky hands (minute from the fractional hour, hour from the 12h position).
	draw_line(c, _pf(fmod(now, 1.0), r * 0.70), MIN_HAND, 2.0)
	draw_line(c, _pf(fmod(now, 12.0) / 12.0, r * 0.48), HAND, 3.5)
	draw_circle(c, 3.0, RIM)
	draw_circle(c, 3.0, RIM_DARK, false, 1.0, true)

	if _ended:
		var pulse := 0.35 + 0.35 * sin(_flash * 6.0)
		draw_arc(c, r, 0.0, TAU, 40, Color(END_COL.r, END_COL.g, END_COL.b, pulse), 3.0, true)

	_draw_labels(c, r)


## The time reads bold, like focus_widget's own numerals; "Ends" stays body weight,
## the smaller of the two so the readout still keeps its own emphasis.
func _draw_labels(c: Vector2, r: float) -> void:
	var y := c.y + r + 22.0
	var status := "CLOSED" if _ended else _time_text()
	var status_col := END_COL if _ended else TEXT
	# A little swing ticket behind the time readout.
	var tag := Craft.ticket(Rect2(Vector2(size.x * 0.5 - 34, y - 17), Vector2(68, 38)), 7.0)
	Craft.card(self, tag, Style.CARD, Style.WALNUT, 1.5)
	draw_string(
		Style.font_bold(),
		Vector2(0.0, y + 1),
		status,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		Style.T_BODY,
		status_col
	)
	draw_string(
		Style.font_body(),
		Vector2(0.0, y + 15.0),
		"Ends %s" % _fmt(_hour_end()),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		Style.T_MICRO,
		Color(TEXT, 0.7)
	)


## A fine brass chain drooping from off the top-left edge to the watch's bow: small
## alternating links (open rings and side-on ovals) along a gentle curve.
func _draw_chain(c: Vector2, r: float) -> void:
	var bow := c + Vector2(0, -r - 12)
	var start := Vector2(-18, -4)
	var links := 14
	for i in links:
		var t := (i + 0.5) / links
		var p := start.lerp(bow, t) + Vector2(0, sin(t * PI) * 9.0)
		if i % 2 == 0:
			draw_arc(p, 2.4, 0.0, TAU, 12, RIM_DARK, 1.2, true)
			draw_arc(p, 2.4, PI * 1.1, PI * 1.6, 5, RIM, 1.0, true)
		else:
			var along := (bow - start).normalized()
			draw_line(p - along * 2.2, p + along * 2.2, RIM_DARK, 2.2, true)
			draw_line(p - along * 1.6, p + along * 1.6, RIM, 1.0, true)


# --- Geometry --------------------------------------------------------------


func _radius() -> float:
	return size.x * 0.36


func _center() -> Vector2:
	return Vector2(size.x * 0.5, _radius() + 20.0)


# Point on the face at `frac` of a full turn (0 = top, clockwise) and radius `rad`.
func _pf(frac: float, rad: float) -> Vector2:
	var a := frac * TAU - PI / 2.0
	return _center() + Vector2(cos(a), sin(a)) * rad


# --- DayNight access (safe if the autoload is absent) ----------------------


func _hour_now() -> float:
	return DayNight.hour if DayNight != null else 12.0


func _hour_start() -> float:
	return DayNight.start_hour() if DayNight != null else 8.0


func _hour_end() -> float:
	return DayNight.end_hour() if DayNight != null else 17.0


func _time_text() -> String:
	return DayNight.time_string() if DayNight != null else "08:00"


func _fmt(h: float) -> String:
	return "%02d:%02d" % [int(floor(h)) % 24, int(floor(fmod(h, 1.0) * 60.0))]

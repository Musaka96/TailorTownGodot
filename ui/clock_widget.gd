extends Control

## Analog wall clock for the HUD. Reads DayNight for the current hour and the shift
## window and draws a 12-hour face with hour/minute hands, plus a green START marker
## and a red END marker (with a highlighted arc between them) so the player can read
## at a glance how much of the shift is left. Pulses red and shows "CLOSED" once the
## shift ends. Purely presentational — it never advances time itself.

const FACE := Color(0.98, 0.95, 0.88)
const RIM := Color(0.20, 0.16, 0.13)
const TICK := Color(0.35, 0.28, 0.22)
const HAND := Color(0.15, 0.12, 0.10)
const MIN_HAND := Color(0.30, 0.25, 0.20)
const START_COL := Color(0.28, 0.70, 0.35)
const END_COL := Color(0.88, 0.28, 0.24)
const ARC_COL := Color(0.96, 0.80, 0.35, 0.6)
const TEXT := Color(0.97, 0.93, 0.85)

var _ended := false
var _flash := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(150, 188)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.shift_started.connect(func(_h: float) -> void: _ended = false)
	EventBus.shift_ended.connect(func() -> void: _ended = true)


func _process(delta: float) -> void:
	if _ended:
		_flash += delta
	queue_redraw()


func _draw() -> void:
	var r := size.x * 0.42
	var c := Vector2(size.x * 0.5, r + 6.0)
	var start_h := _hour_start()
	var end_h := _hour_end()
	var now := _hour_now()

	# Highlighted work window (start → end), then the face on top of its edge.
	draw_arc(c, r * 0.99, _ang(start_h), _ang(end_h), 48, ARC_COL, 7.0, true)
	draw_circle(c, r, FACE)
	draw_arc(c, r, 0.0, TAU, 64, RIM, 3.0, true)

	for i in 12:
		var big := i % 3 == 0
		draw_line(_pf(i / 12.0, r * 0.90), _pf(i / 12.0, r * (0.80 if big else 0.84)),
			TICK, 3.0 if big else 1.5)

	# Shift start / end markers.
	draw_circle(_pf(fmod(start_h, 12.0) / 12.0, r * 0.68), 5.0, START_COL)
	draw_circle(_pf(fmod(end_h, 12.0) / 12.0, r * 0.68), 5.0, END_COL)

	# Hands (minute from the fractional hour, hour from the 12h position).
	var minute_frac := fmod(now, 1.0)
	var hour_frac := fmod(now, 12.0) / 12.0
	draw_line(c, _pf(minute_frac, r * 0.74), MIN_HAND, 2.0)
	draw_line(c, _pf(hour_frac, r * 0.52), HAND, 4.0)
	draw_circle(c, 4.0, RIM)

	if _ended:
		var pulse := 0.35 + 0.35 * sin(_flash * 6.0)
		draw_arc(c, r, 0.0, TAU, 64, Color(END_COL.r, END_COL.g, END_COL.b, pulse), 4.0, true)

	_draw_labels(c, r)


# --- Text ------------------------------------------------------------------


func _draw_labels(c: Vector2, r: float) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var y := c.y + r + 16.0
	var status := "CLOSED" if _ended else _time_text()
	var status_col := END_COL if _ended else TEXT
	draw_string(font, Vector2(0.0, y), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, status_col)
	draw_string(
		font,
		Vector2(0.0, y + 20.0),
		"Ends %s" % _fmt(_hour_end()),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		13,
		Color(TEXT, 0.75)
	)


# --- DayNight access (safe if the autoload is absent) ----------------------


func _hour_now() -> float:
	return DayNight.hour if DayNight != null else 12.0


func _hour_start() -> float:
	return DayNight.start_hour() if DayNight != null else 12.0


func _hour_end() -> float:
	return DayNight.end_hour() if DayNight != null else 22.0


func _time_text() -> String:
	return DayNight.time_string() if DayNight != null else "12:00"


func _fmt(h: float) -> String:
	return "%02d:%02d" % [int(floor(h)) % 24, int(floor(fmod(h, 1.0) * 60.0))]


# 12-hour clock angle for a value in hours; noon/12 sits at the top.
func _ang(h: float) -> float:
	return fmod(h, 12.0) / 12.0 * TAU - PI / 2.0


# Point on the face at `frac` of a full turn (0 = top, clockwise) and radius `rad`.
func _pf(frac: float, rad: float) -> Vector2:
	var a := frac * TAU - PI / 2.0
	var r := size.x * 0.42
	var c := Vector2(size.x * 0.5, r + 6.0)
	return c + Vector2(cos(a), sin(a)) * rad

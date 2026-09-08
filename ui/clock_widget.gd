extends Control

## Small, cute analog shift clock for the HUD. Reads DayNight for the current hour
## and the shift window and draws a compact 12-hour face with dot hour marks, a soft
## coral rim, chunky little hands, and a green START / red END pip so the player can
## read at a glance how much of the shift is left. Pulses red and shows "CLOSED" once
## the shift ends. Purely presentational — it never advances time itself.

const FACE := Color(0.99, 0.96, 0.90)
const RIM := Color(0.91, 0.57, 0.46)  # soft coral
const TICK := Color(0.45, 0.36, 0.30)
const HAND := Color(0.24, 0.19, 0.16)
const MIN_HAND := Color(0.45, 0.38, 0.32)
const START_COL := Color(0.30, 0.72, 0.38)
const END_COL := Color(0.90, 0.34, 0.30)
const TEXT := Color(0.35, 0.28, 0.24)

var _ended := false
var _flash := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(104, 126)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.shift_started.connect(func(_h: float) -> void: _ended = false)
	EventBus.shift_ended.connect(func() -> void: _ended = true)


func _process(delta: float) -> void:
	if _ended:
		_flash += delta
	queue_redraw()


func _draw() -> void:
	var r := _radius()
	var c := _center()
	var now := _hour_now()

	# Soft halo, cream face, coral rim.
	draw_circle(c, r + 2.5, Color(RIM.r, RIM.g, RIM.b, 0.30))
	draw_circle(c, r, FACE)
	draw_arc(c, r, 0.0, TAU, 40, RIM, 3.0, true)

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
	draw_circle(c, 2.8, RIM)

	if _ended:
		var pulse := 0.35 + 0.35 * sin(_flash * 6.0)
		draw_arc(c, r, 0.0, TAU, 40, Color(END_COL.r, END_COL.g, END_COL.b, pulse), 3.0, true)

	_draw_labels(c, r)


func _draw_labels(c: Vector2, r: float) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var y := c.y + r + 13.0
	var status := "CLOSED" if _ended else _time_text()
	var status_col := END_COL if _ended else TEXT
	draw_string(font, Vector2(0.0, y), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, status_col)
	draw_string(
		font,
		Vector2(0.0, y + 15.0),
		"Ends %s" % _fmt(_hour_end()),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		10,
		Color(TEXT, 0.7)
	)


# --- Geometry --------------------------------------------------------------


func _radius() -> float:
	return size.x * 0.40


func _center() -> Vector2:
	return Vector2(size.x * 0.5, _radius() + 4.0)


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

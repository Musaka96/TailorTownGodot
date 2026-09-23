extends Control

## The HUD clock as a tailor's brass pocket watch on a chain. The bezel carries the
## day ring: a faint track over the whole opening window (opening hour to closing,
## clockwise) with the part still to come lit green, reddening through the final hour.
## Four faint quarter dots keep the face readable; the time sits in a small window on
## the lower face and reads "Closed" once the bell has gone. Bolts of cloth on the way
## ride the dial as little side-on rolls at the hour they land, in their own colour;
## one that lands tomorrow waits grey at the opening hour. Rolls landing together fan
## out as a small stack of bolts (up to four), and a delivery pops a ring where it
## arrived. The watch pulses red after the bell. Reads DayNight and the phone
## (found lazily, optional); purely presentational, it never advances time itself.

const FACE := Color(0.99, 0.96, 0.90)
const RIM := Color("c9a24a")  # brass case
const RIM_DARK := Color("8a6a2a")
const TICK := Color(0.45, 0.36, 0.30)
const HAND := Color(0.24, 0.19, 0.16)
const MIN_HAND := Color(0.45, 0.38, 0.32)
const START_COL := Color(0.30, 0.72, 0.38)
const END_COL := Color(0.90, 0.34, 0.30)
const TEXT := Color(0.35, 0.28, 0.24)
const WINDOW := Color(0.93, 0.89, 0.82)
const WINDOW_SIZE := Vector2(40, 14)
const RING_W := 4.0
const PIP_GAP := 0.35  # radians; pips closer than this fan out as one stack
const FAN_MAX := 4
const FAN_SHADE := 0.15  # each bolt further back leans this much further toward TICK
const POP_TIME := 0.6
const POLL_SECS := 1.0

var _ended := false
var _flash := 0.0
## Bolts on the way, as the phone reported them last: [{mat, length, day, hour}].
var _pending: Array = []
## Arrival rings: [{angle, t}].
var _pops: Array = []
var _poll := 0.0
var _phone: Node


func _ready() -> void:
	custom_minimum_size = Vector2(104, 108)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.shift_started.connect(func(_h: float) -> void: _ended = false)
	EventBus.shift_ended.connect(func() -> void: _ended = true)
	# A new morning: the hands stand at opening time, not at last night's CLOSED.
	EventBus.day_began.connect(_on_day_began)
	EventBus.order_placed.connect(func(_m, _l, _c) -> void: _refresh_pending.call_deferred())
	EventBus.order_delivered.connect(_on_delivered)


## Show (or clear) the CLOSED state without the bell — for a day loaded after hours.
func show_closed(closed: bool) -> void:
	_ended = closed


func _process(delta: float) -> void:
	if _ended:
		_flash += delta
	_poll += delta
	if _poll >= POLL_SECS:
		_poll = 0.0
		_refresh_pending()
	for p: Dictionary in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < POP_TIME)
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

	# Four faint quarter dots, only for orientation.
	for i in 4:
		draw_circle(_pf(i / 4.0, r * 0.80), 1.3, Color(TICK, 0.5))

	_draw_ring(c, r, now)
	_draw_pips(c, r)
	_draw_pops(c, r)

	# Chunky hands (minute from the fractional hour, hour from the 12h position).
	draw_line(c, _pf(fmod(now, 1.0), r * 0.70), MIN_HAND, 2.0)
	draw_line(c, _pf(fmod(now, 12.0) / 12.0, r * 0.48), HAND, 3.5)
	draw_circle(c, 3.0, RIM)
	draw_circle(c, 3.0, RIM_DARK, false, 1.0, true)
	# The time window sits over the hands so the digits always read.
	_draw_window(c, r)

	if _ended:
		var pulse := 0.35 + 0.35 * sin(_flash * 6.0)
		draw_arc(c, r, 0.0, TAU, 40, Color(END_COL.r, END_COL.g, END_COL.b, pulse), 3.0, true)


## The day ring on the bezel: the whole opening window as a faint track, and what's
## left of it lit, green turning red over the last hour. Nothing lit after the bell.
func _draw_ring(c: Vector2, r: float, now: float) -> void:
	var start := _hour_start()
	var end := _hour_end()
	var a0 := _ang(start)
	var a1 := _ang(end)
	if a1 <= a0:
		a1 += TAU
	var rad := r - 4.0
	var track := Color(TICK, 0.40)
	draw_arc(c, rad, a0, a1, 48, track, RING_W, true)
	draw_circle(c + Vector2.from_angle(a0) * rad, RING_W * 0.5, track)
	draw_circle(c + Vector2.from_angle(a1) * rad, RING_W * 0.5, track)
	if _ended:
		return
	var a_now := a0 + (clampf(now, start, end) - start) / 12.0 * TAU
	var col := START_COL.lerp(END_COL, clampf(1.0 - (end - now), 0.0, 1.0))
	if a1 - a_now > 0.001:
		draw_arc(c, rad, a_now, a1, 48, col, RING_W, true)
	draw_circle(c + Vector2.from_angle(a_now) * rad, RING_W * 0.5, col)
	draw_circle(c + Vector2.from_angle(a1) * rad, RING_W * 0.5, col)


## The little time window on the lower face; "Closed" in red after the bell.
func _draw_window(c: Vector2, r: float) -> void:
	var box := Rect2(c + Vector2(0, r * 0.45) - WINDOW_SIZE * 0.5, WINDOW_SIZE)
	var poly := Craft.rounded(box, 3.0, 3)
	draw_colored_polygon(poly, WINDOW)
	Craft.outline(self, poly, RIM_DARK, 1.0)
	var font := Style.font_bold()
	var fs := Style.T_MICRO
	var base := box.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var text := "Closed" if _ended else _time_text()
	var col := END_COL if _ended else TEXT
	draw_string(
		font, Vector2(box.position.x, base), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, fs, col
	)


## One bolt per spot on the dial, riding the day track at the hour its rolls land
## (tomorrow's wait grey at the opening hour). Rolls landing within PIP_GAP of each
## other fan out: up to FAN_MAX bolts, each further one stepped anticlockwise and a
## touch inward, drawn back to front and shading toward TICK the further back it sits.
func _draw_pips(c: Vector2, r: float) -> void:
	var rad := r - 4.0
	for g: Dictionary in _pip_groups():
		var a := float(g["angle"])
		var out := Vector2.from_angle(a)
		var back := out.orthogonal() * 3.0 - out  # one step: anticlockwise and inward
		var at := c + out * rad
		var body: Color = g["body"]
		var edge: Color = g["edge"]
		for i in range(mini(int(g["count"]), FAN_MAX) - 1, -1, -1):
			var k := FAN_SHADE * i
			_draw_bolt(at + back * i, a, body.lerp(TICK, k), edge.lerp(TICK, k))


## Pending rolls grouped by dial position, greedily in list order: each joins the first
## group whose angle is within PIP_GAP, and a group takes its first roll's angle and
## colours. [{angle, count, body, edge}]
func _pip_groups() -> Array:
	var today := _today()
	var groups: Array = []
	for p: Dictionary in _pending:
		var tomorrow := int(p.get("day", today)) > today
		var a := _ang(_hour_start() if tomorrow else float(p.get("hour", 0.0)))
		var joined := false
		for g: Dictionary in groups:
			if absf(angle_difference(float(g["angle"]), a)) < PIP_GAP:
				g["count"] = int(g["count"]) + 1
				joined = true
				break
		if joined:
			continue
		var mat := p.get("mat") as MaterialType
		var body := Color(TICK, 0.45)
		var edge := TICK
		if not tomorrow and mat != null:
			body = mat.cloth_color
			edge = mat.cloth_color.darkened(0.25)
		groups.append({"angle": a, "count": 1, "body": body, "edge": edge})
	return groups


## A rolled bolt seen from the side, lying along the dial: the cloth as a rounded bar
## and the cardboard tube end showing at the trailing (anticlockwise) end.
func _draw_bolt(at: Vector2, angle: float, body: Color, edge: Color) -> void:
	draw_set_transform(at, angle + PI / 2.0, Vector2.ONE)
	var poly := Craft.rounded(Rect2(Vector2(-3.5, -2.5), Vector2(9, 5)), 2.5, 3)
	draw_colored_polygon(poly, body)
	Craft.outline(self, poly, edge, 1.0)
	draw_circle(Vector2(-3.5, 0), 2.6, edge)
	draw_circle(Vector2(-3.5, 0), 0.9, FACE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A ring swelling and fading where a bolt just arrived.
func _draw_pops(c: Vector2, r: float) -> void:
	for p: Dictionary in _pops:
		var k := clampf(float(p["t"]) / POP_TIME, 0.0, 1.0)
		var at := c + Vector2.from_angle(float(p["angle"])) * (r - 4.0)
		draw_arc(at, lerpf(4.0, 14.0, k), 0.0, TAU, 24, Color(START_COL, 1.0 - k), 2.0, true)


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


# --- Deliveries -------------------------------------------------------------


func _on_day_began(_d: int) -> void:
	_ended = false
	_refresh_pending.call_deferred()


func _on_delivered(_roll: Node) -> void:
	_pops.append({"angle": _ang(_hour_now()), "t": 0.0})
	_refresh_pending.call_deferred()


func _refresh_pending() -> void:
	var phone := _find_phone()
	_pending = phone.pending() if phone != null else []


## The shop's phone, cached; none in dev scenes without one.
func _find_phone() -> Node:
	if is_instance_valid(_phone):
		return _phone
	_phone = null
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return null
	for n in scene.find_children("*", "Phone", true, false):
		if n.has_method("pending"):
			_phone = n
			break
	return _phone


# --- Geometry --------------------------------------------------------------


func _radius() -> float:
	return size.x * 0.36


func _center() -> Vector2:
	return Vector2(size.x * 0.5, _radius() + 20.0)


# Point on the face at `frac` of a full turn (0 = top, clockwise) and radius `rad`.
func _pf(frac: float, rad: float) -> Vector2:
	var a := frac * TAU - PI / 2.0
	return _center() + Vector2(cos(a), sin(a)) * rad


# Dial angle of hour `h` (12 at the top, clockwise).
func _ang(h: float) -> float:
	return fmod(h, 12.0) / 12.0 * TAU - PI / 2.0


# --- DayNight access (safe if the autoload is absent) ----------------------


func _hour_now() -> float:
	return DayNight.hour if DayNight != null else 12.0


func _hour_start() -> float:
	return DayNight.start_hour() if DayNight != null else 8.0


func _hour_end() -> float:
	return DayNight.end_hour() if DayNight != null else 17.0


func _time_text() -> String:
	return DayNight.time_string() if DayNight != null else "08:00"


func _today() -> int:
	return Shift.day if Shift != null else 1

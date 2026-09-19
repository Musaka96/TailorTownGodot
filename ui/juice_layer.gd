class_name JuiceLayer
extends Control

## The celebrating half of a bench game, laid over its play surface so no game's painter
## has to know about it: little hand-drawn sparks that fly off a perfect stitch or stroke,
## and the rubber-stamp verdict that thumps onto the finished piece. Flat shapes from Style
## tokens; nothing here touches the rules. MinigameScreen owns one and drives it
## (_perfect_beat / _stamp_verdict).
##
## The stamp has three weights (Fanfare): PLAIN is ink on paper; FINE throws a ring of
## thread snippets as it lands; GRAND — a truly flawless piece, 100% — is gold foil between
## two stars, on turning rays, with confetti and twinkles for as long as it is up.

enum Fanfare { PLAIN, FINE, GRAND }

const SPARK_LIFE := 0.34
const SPARK_SPEED := 190.0
const GRAVITY := 260.0
const STAMP_IN := 0.16  # seconds for the stamp to come down
const STAMP_TILT := -0.13  # radians: stamped by hand, never square
const RAYS := 14
const RAY_TURN := 0.35  # rad/s the rays drift round
const TWINKLE_EVERY := 0.11  # seconds between twinkles around a GRAND stamp
## Confetti is cut from the workroom: thread and cloth colours, never neon.
const CONFETTI := [Style.BRASS_LIGHT, Style.BRASS, Style.FOREST, Style.BURGUNDY, Style.CHALK]

var _sparks: Array[Dictionary] = []  # {pos, vel, life, max, col, len}
var _twinkles: Array[Dictionary] = []  # {pos, life, max, size}
var _stamp_text := ""
var _stamp_col := Style.FOREST
var _stamp_t := -1.0  # seconds since the stamp started; < 0 = no stamp
var _fanfare: int = Fanfare.PLAIN
var _landed := false
var _next_twinkle := 0.0
var _speckles := PackedVector2Array()  # where the ink didn't take (unit box)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## Clear everything for a new run.
func reset() -> void:
	_sparks.clear()
	_twinkles.clear()
	_stamp_t = -1.0
	_stamp_text = ""
	set_process(false)
	queue_redraw()


## A puff of `count` short dashes flying up and out from `at` (layer-local pixels).
func burst(at: Vector2, col: Color, count := 6) -> void:
	for i in count:
		var angle := randf_range(-PI, 0.0) + randf_range(-0.5, 0.5)  # mostly upward
		_add_spark(at, angle, SPARK_SPEED * randf_range(0.5, 1.0), SPARK_LIFE, col)
	set_process(true)


## Bring the verdict stamp down in the middle of the surface.
func stamp(text: String, col: Color, fanfare: int = Fanfare.PLAIN) -> void:
	_stamp_text = text.to_upper()
	_stamp_col = col
	_fanfare = fanfare
	_stamp_t = 0.0
	_landed = false
	_next_twinkle = 0.0
	_speckles.clear()
	for i in 14:
		_speckles.append(Vector2(randf(), randf()))
	set_process(true)


func _process(delta: float) -> void:
	for spark in _sparks:
		spark["life"] = float(spark["life"]) - delta
		spark["vel"] = (spark["vel"] as Vector2) + Vector2(0.0, GRAVITY * delta)
		spark["pos"] = (spark["pos"] as Vector2) + (spark["vel"] as Vector2) * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)
	for tw in _twinkles:
		tw["life"] = float(tw["life"]) - delta
	_twinkles = _twinkles.filter(func(t: Dictionary) -> bool: return float(t["life"]) > 0.0)
	if _stamp_t >= 0.0:
		_stamp_t += delta
		if not _landed and _stamp_t >= STAMP_IN:
			_landed = true
			_on_landed()
		if _landed and _fanfare == Fanfare.GRAND:
			_next_twinkle -= delta
			if _next_twinkle <= 0.0:
				_next_twinkle = TWINKLE_EVERY
				_add_twinkle()
	var idle := _sparks.is_empty() and _twinkles.is_empty()
	if idle and (_stamp_t < 0.0 or (_landed and _fanfare != Fanfare.GRAND)):
		set_process(false)
	queue_redraw()


## The moment the rubber meets the paper: the better the verdict, the more flies off it.
func _on_landed() -> void:
	if _fanfare == Fanfare.PLAIN:
		return
	var grand := _fanfare == Fanfare.GRAND
	var count := 46 if grand else 16
	for i in count:
		var angle := TAU * float(i) / count + randf_range(-0.15, 0.15)
		var speed := SPARK_SPEED * randf_range(0.9, 2.1 if grand else 1.4)
		var col: Color = CONFETTI.pick_random() if grand else _stamp_col.lightened(0.25)
		_add_spark(size * 0.5, angle, speed, SPARK_LIFE * (2.6 if grand else 1.5), col)


func _add_spark(at: Vector2, angle: float, speed: float, life: float, col: Color) -> void:
	var lived := life * randf_range(0.7, 1.0)
	var spark := {
		"pos": at,
		"vel": Vector2.from_angle(angle) * speed,
		"life": lived,
		"max": lived,
		"col": col,
		"len": randf_range(7.0, 12.0),
	}
	_sparks.append(spark)


func _add_twinkle() -> void:
	var lived := randf_range(0.35, 0.6)
	var reach := Vector2(size.x * 0.34, size.y * 0.36)
	var at := size * 0.5 + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * reach
	_twinkles.append({"pos": at, "life": lived, "max": lived, "size": randf_range(5.0, 11.0)})


func _draw() -> void:
	if _stamp_t >= 0.0 and _fanfare == Fanfare.GRAND:
		_draw_rays()
	for spark in _sparks:
		var fade := clampf(float(spark["life"]) / float(spark["max"]), 0.0, 1.0)
		var pos: Vector2 = spark["pos"]
		var dir := (spark["vel"] as Vector2).normalized()
		var col := Style.tint(spark["col"], fade)
		draw_line(pos, pos - dir * float(spark["len"]) * fade, col, 3.0, true)
	if _stamp_t >= 0.0:
		_draw_stamp()
	for tw in _twinkles:
		_draw_twinkle(tw)


## Soft brass rays fanning out behind a GRAND stamp, turning slowly, easing in as it lands.
func _draw_rays() -> void:
	var show := clampf((_stamp_t - STAMP_IN * 0.6) / 0.25, 0.0, 1.0)
	if show <= 0.0:
		return
	var reach := size.length() * 0.5
	var turn := _stamp_t * RAY_TURN
	for i in RAYS:
		# Alternate strong and faint, so the fan reads as light rather than a wheel.
		var col := Style.tint(Style.BRASS_LIGHT, (0.42 if i % 2 == 0 else 0.22) * show)
		var a := turn + TAU * float(i) / RAYS
		var half := TAU / RAYS * 0.25
		var pts := PackedVector2Array(
			[
				size * 0.5,
				size * 0.5 + Vector2.from_angle(a - half) * reach * show,
				size * 0.5 + Vector2.from_angle(a + half) * reach * show,
			]
		)
		draw_colored_polygon(pts, col)


## A four-point glint that swells and fades.
func _draw_twinkle(tw: Dictionary) -> void:
	var life := sin(clampf(float(tw["life"]) / float(tw["max"]), 0.0, 1.0) * PI)
	var at: Vector2 = tw["pos"]
	var r := float(tw["size"]) * life
	var col := Style.tint(Style.CHALK, life)
	draw_line(at - Vector2(r, 0), at + Vector2(r, 0), col, 2.0, true)
	draw_line(at - Vector2(0, r), at + Vector2(0, r), col, 2.0, true)
	draw_circle(at, r * 0.22, col)


## A double-ruled box with the word in the display face, slammed down from large to
## life-size, a touch crooked, with specks where the ink didn't take. GRAND is gold foil
## with a star either side, and it lands with a bounce.
func _draw_stamp() -> void:
	var grand := _fanfare == Fanfare.GRAND
	var font := Style.font_display()
	var font_size := Style.T_HERO if grand else Style.T_TITLE
	var text_size := font.get_string_size(_stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var star_room := 44.0 if grand else 0.0
	var pad := Vector2(18.0 + star_room, 8.0)
	var box := Rect2(-text_size * 0.5 - pad, text_size + pad * 2.0)
	var land := clampf(_stamp_t / STAMP_IN, 0.0, 1.0)
	var grow := lerpf(2.6 if grand else 2.4, 1.0, ease(land, 0.35))
	if grand and _landed:
		# A little bounce after the thump, settling in a quarter of a second.
		var since := _stamp_t - STAMP_IN
		grow += 0.09 * exp(-since * 9.0) * cos(since * 26.0)
	var ink := Style.tint(Style.RIM_DARK if grand else _stamp_col, lerpf(0.0, 0.95, land))
	var paper := Style.BRASS_LIGHT if grand else Style.CREAM
	draw_set_transform(size * 0.5, STAMP_TILT, Vector2(grow, grow))
	draw_colored_polygon(Craft.rounded(box.grow(3.0), 9.0), Style.tint(paper, 0.9 * land))
	if grand:
		# The foil catches the light along its top half.
		var sheen := Rect2(box.position, Vector2(box.size.x, box.size.y * 0.45))
		draw_colored_polygon(Craft.rounded(sheen, 6.0), Style.tint(Style.CHALK, 0.28 * land))
	Craft.outline(self, Craft.rounded(box.grow(3.0), 9.0), ink, 3.5)
	Craft.outline(self, Craft.rounded(box.grow(-3.0), 5.0), ink, 1.5)
	var base := Vector2(-text_size.x * 0.5, text_size.y * 0.5 - font.get_descent(font_size))
	var word := Style.tint(Style.WALNUT, land) if grand else ink
	draw_string(font, base, _stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, word)
	if grand:
		for side: float in [-1.0, 1.0]:
			_draw_star(Vector2((text_size.x * 0.5 + star_room * 0.55) * side, 0.0), 15.0, word)
	if land >= 1.0 and not grand:
		for speck in _speckles:
			draw_circle(box.position + speck * box.size, 1.4, Style.tint(Style.CREAM, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_star(at: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		pts.append(at + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * r)
	draw_colored_polygon(pts, col)

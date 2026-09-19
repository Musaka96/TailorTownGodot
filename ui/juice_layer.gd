class_name JuiceLayer
extends Control

## The celebrating half of a bench game, laid over its play surface so no game's painter
## has to know about it: little hand-drawn sparks that fly off a perfect stitch or stroke,
## and the rubber-stamp verdict that thumps onto the finished piece. Flat shapes from Style
## tokens; nothing here touches the rules. MinigameScreen owns one and drives it
## (_perfect_beat / _stamp_verdict).

const SPARK_LIFE := 0.34
const SPARK_SPEED := 190.0
const GRAVITY := 260.0
const STAMP_IN := 0.16  # seconds for the stamp to come down
const STAMP_TILT := -0.13  # radians: stamped by hand, never square

var _sparks: Array[Dictionary] = []  # {pos, vel, life, col, len}
var _stamp_text := ""
var _stamp_col := Style.FOREST
var _stamp_t := -1.0  # seconds since the stamp started; < 0 = no stamp
var _speckles := PackedVector2Array()  # where the ink didn't take (unit box)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## Clear everything for a new run.
func reset() -> void:
	_sparks.clear()
	_stamp_t = -1.0
	_stamp_text = ""
	set_process(false)
	queue_redraw()


## A puff of `count` short dashes flying out from `at` (layer-local pixels).
func burst(at: Vector2, col: Color, count := 6) -> void:
	for i in count:
		var angle := randf_range(-PI, 0.0) + randf_range(-0.5, 0.5)  # mostly upward
		var speed := SPARK_SPEED * randf_range(0.5, 1.0)
		var spark := {
			"pos": at,
			"vel": Vector2.from_angle(angle) * speed,
			"life": SPARK_LIFE * randf_range(0.7, 1.0),
			"col": col,
			"len": randf_range(7.0, 12.0),
		}
		_sparks.append(spark)
	set_process(true)


## Bring the verdict stamp down in the middle of the surface.
func stamp(text: String, col: Color) -> void:
	_stamp_text = text.to_upper()
	_stamp_col = col
	_stamp_t = 0.0
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
	if _stamp_t >= 0.0:
		_stamp_t += delta
	if _sparks.is_empty() and (_stamp_t < 0.0 or _stamp_t > STAMP_IN + 0.3):
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for spark in _sparks:
		var fade := clampf(float(spark["life"]) / SPARK_LIFE, 0.0, 1.0)
		var pos: Vector2 = spark["pos"]
		var dir := (spark["vel"] as Vector2).normalized()
		var col := Style.tint(spark["col"], fade)
		draw_line(pos, pos - dir * float(spark["len"]) * fade, col, 3.0, true)
	if _stamp_t >= 0.0:
		_draw_stamp()


## A double-ruled box with the word in the display face, slammed down from large to
## life-size, a touch crooked, with specks where the ink didn't take.
func _draw_stamp() -> void:
	var font := Style.font_display()
	var text_size := font.get_string_size(_stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_TITLE)
	var box := Rect2(-text_size * 0.5 - Vector2(18, 8), text_size + Vector2(36, 16))
	var land := clampf(_stamp_t / STAMP_IN, 0.0, 1.0)
	var grow := lerpf(2.4, 1.0, ease(land, 0.35))
	var ink := Style.tint(_stamp_col, lerpf(0.0, 0.92, land))
	draw_set_transform(size * 0.5, STAMP_TILT, Vector2(grow, grow))
	draw_colored_polygon(Craft.rounded(box.grow(3.0), 9.0), Style.tint(Style.CREAM, 0.82 * land))
	Craft.outline(self, Craft.rounded(box.grow(3.0), 9.0), ink, 3.5)
	Craft.outline(self, Craft.rounded(box.grow(-3.0), 5.0), ink, 1.5)
	var base := Vector2(-text_size.x * 0.5, text_size.y * 0.5 - font.get_descent(Style.T_TITLE))
	draw_string(font, base, _stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_TITLE, ink)
	if land >= 1.0:
		for speck in _speckles:
			var at := box.position + speck * box.size
			draw_circle(at, 1.4, Style.tint(Style.CREAM, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

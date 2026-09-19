extends Control

## Coffee focus on the HUD, beside the reputation patch: a stitched walnut patch with a
## steaming cream cup and one brass bean per focused bench job left (GameState.focus).
## Hidden while there is no focus; pops in on a fresh cup, and bumps as each job spends
## a bean. Listens to EventBus.focus_changed. Presentational.

const CUP_W := 18.0
const BEAN_R := 4.0
const BEAN_STEP := 12.0
const PAD := 12.0
const GAP := 10.0
const HEIGHT := 32.0
const MAX_BEANS := 8  # past this the patch shows a number instead of more beans

var _jobs := 0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation_degrees = 1.5
	EventBus.focus_changed.connect(_on_changed)
	_on_changed(GameState.focus)


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()  # the steam drifts


func _on_changed(jobs: int) -> void:
	var was := _jobs
	_jobs = jobs
	visible = jobs > 0
	custom_minimum_size = Vector2(_width(), HEIGHT)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	if jobs > was and was == 0:
		Craft.pop_in(self, 0.7, 0.3)
	elif jobs != was and jobs > 0:
		Craft.bump(self, 1.15)
	queue_redraw()


func _width() -> float:
	var beans := _jobs if _jobs <= MAX_BEANS else 1
	var extra := 16.0 if _jobs > MAX_BEANS else 0.0
	return PAD * 2.0 + CUP_W + GAP + (beans - 1) * BEAN_STEP + BEAN_R * 2.0 + extra


func _draw() -> void:
	var patch := Craft.rounded(Rect2(Vector2.ZERO, size), size.y * 0.5, 6)
	Craft.card(self, patch, Style.BROWN, Style.WALNUT)
	Craft.stitch(self, patch, Style.CHALK, 4.0, 1.2)
	_draw_cup(Vector2(PAD, size.y * 0.5 + 3.0))
	var x0 := PAD + CUP_W + GAP + BEAN_R
	var cy := size.y * 0.5
	if _jobs > MAX_BEANS:
		_draw_bean(Vector2(x0, cy))
		var font := Style.bold_font()
		var at := Vector2(x0 + BEAN_R + 3.0, cy + 5.0)
		draw_string(
			font, at, str(_jobs), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_CAPTION, Style.CHALK
		)
		return
	for i in _jobs:
		_draw_bean(Vector2(x0 + i * BEAN_STEP, cy))


## A little cream cup (left edge at `at.x`, vertically centred on `at.y`) with a handle
## and two wisps of steam.
func _draw_cup(at: Vector2) -> void:
	var top := at.y - 6.0
	var body := PackedVector2Array(
		[
			Vector2(at.x, top),
			Vector2(at.x + CUP_W - 4.0, top),
			Vector2(at.x + CUP_W - 6.0, top + 10.0),
			Vector2(at.x + 2.0, top + 10.0),
		]
	)
	var handle := Vector2(at.x + CUP_W - 4.0, top + 4.5)
	draw_arc(handle, 3.5, -PI * 0.5, PI * 0.5, 8, Style.CREAM, 2.0)
	draw_colored_polygon(body, Style.CREAM)
	Craft.outline(self, body, Style.WALNUT, 1.0)
	var saucer := top + 11.0
	draw_line(Vector2(at.x - 1.0, saucer), Vector2(at.x + CUP_W - 3.0, saucer), Style.CREAM, 1.5)
	for k in 2:
		var sx := at.x + 4.0 + k * 6.0
		var pts := PackedVector2Array()
		for j in 5:
			var y := top - 2.0 - j * 2.0
			pts.append(Vector2(sx + sin(_time * 3.0 + j * 0.9 + k * 1.7) * 1.4, y))
		draw_polyline(pts, Color(Style.CHALK, 0.55), 1.2, true)


## A roasted bean: a brass oval with its centre crease.
func _draw_bean(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		pts.append(c + Vector2(cos(a) * BEAN_R * 0.8, sin(a) * BEAN_R).rotated(0.4))
	draw_colored_polygon(pts, Style.BRASS)
	Craft.outline(self, pts, Style.WALNUT, 1.0)
	var crease := Vector2(0, BEAN_R * 0.7).rotated(0.4)
	draw_line(c - crease, c + crease, Style.RIM_DARK, 1.0)

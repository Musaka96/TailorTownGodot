class_name CuttingMinigame
extends MinigameScreen

## Orient-the-scissors cutting minigame. A kraft pattern piece is pinned to the
## cutting mat and chalked round its edge; you steer the scissors (WASD / left stick)
## to keep them along that edge as the cut travels round it, and the paper opens
## behind them. Staying off the line racks up slips — 3 spoils the piece. The chrome
## (panel, ticket, slip pins, prompts) comes from MinigameScreen.
## Emits finished(success, quality).

signal finished(success: bool, quality: float)

enum State { RUNNING, SUCCESS, RUINED }

const GOOD_TOL := deg_to_rad(26.0)  # within this of the outline = clean cut
const TARGET_SECONDS := 15.0  # time to cut the whole shape when aligned
const MISTAKE_COST := 0.85  # accumulated error that equals one mistake
const MAX_MISTAKES := 3
const ROT_SPEED := 14.0
const SPRINT_MULT := 1.8  # hold Shift: cut faster, but misalignment bites faster too

# Normalized garment silhouettes (roughly [-1, 1]); jittered at generation.
const SHAPES := {
	Enums.GarmentType.SHIRT:
	[
		Vector2(-0.6, -0.72),
		Vector2(0.6, -0.72),
		Vector2(0.86, -0.34),
		Vector2(0.5, -0.14),
		Vector2(0.55, 0.8),
		Vector2(-0.55, 0.8),
		Vector2(-0.5, -0.14),
		Vector2(-0.86, -0.34),
	],
	Enums.GarmentType.PANTS:
	[
		Vector2(-0.5, -0.8),
		Vector2(0.5, -0.8),
		Vector2(0.45, 0.8),
		Vector2(0.12, 0.8),
		Vector2(0.0, 0.05),
		Vector2(-0.12, 0.8),
		Vector2(-0.45, 0.8),
	],
	Enums.GarmentType.JACKET:
	[
		Vector2(-0.7, -0.68),
		Vector2(0.7, -0.68),
		Vector2(0.88, -0.2),
		Vector2(0.55, 0.8),
		Vector2(0.12, 0.8),
		Vector2(0.0, -0.22),
		Vector2(-0.12, 0.8),
		Vector2(-0.55, 0.8),
		Vector2(-0.88, -0.2),
	],
}

const TITLE := "Cutting Table"
## Optional painted mat. Without it the mat is drawn from the palette (see _paint_mat).
const MAT_ART := "res://assets/textures/ui/cutting_mat.png"
const MAT_INSET := 10.0
const GRID_STEP := 30.0
const PIN_PULL := 0.72  # how far in from a corner the pattern pins sit
const BLADE := 1.25  # scissors size — they are the cursor, so they read first
const OPEN_DEG := 21.0  # blade spread at rest
const SHUT_DEG := 3.0  # blade spread at the bite of a snip
const SPLAY_DEG := 15.0  # extra bend in the handles, so the loops clear each other

var _good_tol := GOOD_TOL
var _seconds := TARGET_SECONDS
var _lead := 0.0
var _state := State.RUNNING
var _pts: PackedVector2Array = []
var _cum: PackedFloat32Array = []
var _total := 0.0
var _cursor := 0.0
var _angle := 0.0
var _error := 0.0
var _cooldown := 0.0
var _aligned := false
var _snip_accum := 0.0
var _snip_phase := 0.0  # 0..1 through one open-and-close of the blades
var _nicks: PackedVector2Array = []
var _mat_tex: Texture2D

var _snip: AudioStream
var _slip: AudioStream
var _complete: AudioStream
var _ruined: AudioStream


## A garment shape needs height more than width, so the bench takes the tall frame
## (the seam in the sewing game is the other way round, and keeps the wide one).
func _ready() -> void:
	_ensure_chrome(TITLE, _paint, Style.FRAME_TALL)


func _load_assets() -> void:
	_snip = _load("snip")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_mat_tex = _load_art(MAT_ART)


func start(garment_type: int, title: String) -> void:
	_ensure_chrome(TITLE, _paint, Style.FRAME_TALL)
	var c := Config.data
	_lead = 1.6
	_max_mistakes = MAX_MISTAKES
	if c != null:
		_good_tol = deg_to_rad(c.cut_tolerance_deg)
		_seconds = c.cut_seconds
		_max_mistakes = c.cut_max_mistakes
		_lead = c.cut_lead_seconds
	_generate(garment_type)
	_state = State.RUNNING
	_cursor = 0.0
	_mistakes = 0
	_error = 0.0
	_cooldown = 0.0
	_nicks = []
	_angle = _tangent_at(0.0)
	_set_job(title)
	_rebuild_hints.call_deferred()
	_build_pips()
	_show_panel()
	_update_status()
	set_process(true)
	_repaint()


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

	# Lead-in: let the player line up before the cut starts — the blades and the guide
	# arrow already answer, so lining up is something you can actually do.
	if _lead > 0.0:
		_lead -= delta
		_aligned = absf(angle_difference(_angle, _tangent_at(_cursor))) <= _good_tol
		_update_status()
		_repaint()
		return

	# Sharp Scissors upgrade: hold Shift to race the cut (faster, but slips rack up
	# faster). Master Shears add an always-on speed bump.
	var boost := Upgrades.cutting_speed()
	if Upgrades.cutting_sprint() and Input.is_action_pressed("sprint"):
		boost *= SPRINT_MULT

	# The scissors must point the way the cut is travelling — facing backwards (180° off)
	# does NOT count, so the player actually steers along the line.
	var tangent := _tangent_at(_cursor)
	var err := absf(angle_difference(_angle, tangent))
	_aligned = err <= _good_tol

	if _aligned:
		_cursor += (_total / _seconds) * boost * delta
		_error = maxf(0.0, _error - delta * 0.7)
		_snip_accum += delta
		var period := 0.13 / boost
		if _snip_accum >= period:
			_snip_accum = 0.0
			_play(_snip, 0.35)
		_snip_phase = _snip_accum / period
		if _cursor >= _total:
			_succeed()
	elif _cooldown <= 0.0:
		_error += (err - _good_tol) * boost * delta
		if _error >= MISTAKE_COST:
			_register_mistake()

	_update_status()
	_repaint()


## Debug (F2, debug builds only): skip the cut and finish it perfectly.
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.RUNNING or not OS.is_debug_build():
		return
	if event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		finished.emit(true, 1.0)


func _register_mistake() -> void:
	_mistakes += 1
	_error = 0.0
	_cooldown = 0.5
	_nicks.append(_point_at(_cursor))
	_play(_slip, 0.8)
	_slip_feedback()
	if _mistakes >= _max_mistakes:
		_fail()


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	_play(_complete, 0.7)
	_set_status("Cut complete — a clean piece!", Style.FOREST)
	_repaint()
	var quality := clampf(1.0 - 0.22 * _mistakes, 0.15, 1.0)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, quality)


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	_play(_ruined, 0.8)
	_set_status("Oh no — the piece is spoiled.", Style.CLAY)
	_repaint()
	await get_tree().create_timer(1.0).timeout
	finished.emit(false, 0.0)


## Key hints for this run — Shift only appears once its upgrade is owned.
func _rebuild_hints() -> void:
	var pairs := [["WASD", "Aim the scissors"]]
	if Upgrades != null and Upgrades.cutting_sprint():
		pairs.append(["Shift", "Cut faster (riskier)"])
	_set_hints(pairs)


func _update_status() -> void:
	if _state != State.RUNNING:
		return
	if _lead > 0.0:
		_set_status("Line up the scissors…  %d" % ceili(_lead), Style.AMBER)
		return
	var pct := int(_cursor / _total * 100.0)
	if not _aligned:
		_set_status("Off the line — turn the blades   ·   %d%%" % pct, Style.CLAY)
		return
	var tip := "Follow the chalk line   ·   %d%% cut" % pct
	if OS.is_debug_build():
		tip += "   ·   F2 skip"
	_set_status(tip, Style.INK_SOFT)


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


func _origin() -> Vector2:
	return _canvas.size * 0.5


func _scale() -> float:
	return minf(_canvas.size.x, _canvas.size.y) * 0.46


func _world(p: Vector2) -> Vector2:
	return _origin() + p * _scale()


# --- Painting (called from the MinigameCanvas) -----------------------------


func _paint(c: Control) -> void:
	var rect := Rect2(
		Vector2(MAT_INSET, MAT_INSET), c.size - Vector2(MAT_INSET * 2.0, MAT_INSET * 2.0)
	)
	_paint_mat(c, rect)
	if _pts.is_empty():
		return
	_paint_pattern_piece(c)
	_paint_cut(c)
	for n in _nicks:
		_paint_x(c, _world(n), Style.CLAY, 7.0)
	var cur := _world(_point_at(_cursor))
	_paint_guide(c, cur)
	_paint_scissors(c, cur, _angle)


## The bench: a tan cutting mat in a walnut edge, gridded and ruled off in
## centimetres along its top and left edges.
func _paint_mat(c: Control, rect: Rect2) -> void:
	var mat := StyleBoxFlat.new()
	mat.bg_color = Style.MAT.darkened(0.16)
	mat.set_corner_radius_all(14)
	mat.set_border_width_all(3)
	mat.border_color = Style.WALNUT
	c.draw_style_box(mat, rect)
	if _mat_tex != null:
		c.draw_texture_rect(_mat_tex, rect.grow(-3.0), true)  # the art carries its own grid
	else:
		_paint_grid(c, rect)
	_paint_rule(c, rect)  # the ruler runs along the canvas edges, so it is never tiled


func _paint_grid(c: Control, rect: Rect2) -> void:
	var col := Style.tint(Style.WALNUT, 0.09)
	var x := rect.position.x + GRID_STEP
	while x < rect.end.x:
		c.draw_line(Vector2(x, rect.position.y + 5), Vector2(x, rect.end.y - 5), col, 1.0)
		x += GRID_STEP
	var y := rect.position.y + GRID_STEP
	while y < rect.end.y:
		c.draw_line(Vector2(rect.position.x + 5, y), Vector2(rect.end.x - 5, y), col, 1.0)
		y += GRID_STEP


## Ruler ticks down two edges — a long one every fifth mark, like a real mat.
func _paint_rule(c: Control, rect: Rect2) -> void:
	var col := Style.tint(Style.WALNUT, 0.35)
	var step := GRID_STEP * 0.5
	var i := 0
	var x := rect.position.x
	while x < rect.end.x:
		var h := 9.0 if i % 5 == 0 else 5.0
		c.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + h), col, 1.0)
		x += step
		i += 1
	i = 0
	var y := rect.position.y
	while y < rect.end.y:
		var w := 9.0 if i % 5 == 0 else 5.0
		c.draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + w, y), col, 1.0)
		y += step
		i += 1


## The piece itself: kraft pattern paper pinned to the mat, chalked round its edge
## and marked with the grain line the cloth has to follow.
func _paint_pattern_piece(c: Control) -> void:
	var poly := PackedVector2Array()
	for p in _pts:
		poly.append(_world(p))
	Craft.card(c, poly, Style.PAPER, Style.tint(Style.WALNUT, 0.4), 1.5)
	var chalk := Style.tint(Style.CHALK, 0.8)
	for i in _pts.size():
		_dashed(c, _world(_pts[i]), _world(_pts[(i + 1) % _pts.size()]), chalk)
	for i in _pts.size():
		if i % 3 == 0:
			var at: Vector2 = _pts[i]
			# Pinned across the edge, the way you actually pin a pattern down.
			Craft.dress_pin(c, _world(at * PIN_PULL), at.angle() + PI * 0.5, Style.BURGUNDY)


func _paint_arrow_head(c: Control, at: Vector2, dir: Vector2, col: Color) -> void:
	var back := at - dir * 8.0
	var side := dir.orthogonal() * 4.5
	c.draw_line(at, back + side, col, 1.5)
	c.draw_line(at, back - side, col, 1.5)


## What has been cut: the paper lies open along the line with the mat showing
## through it, so progress reads as a real gap rather than a coloured stripe.
func _paint_cut(c: Control) -> void:
	var start_pt := _world(_point_at(0.0))
	if _cursor > 0.0:
		var pl: PackedVector2Array = []
		pl.append(start_pt)
		for i in _pts.size():
			if _cum[i + 1] <= _cursor:
				pl.append(_world(_pts[(i + 1) % _pts.size()]))
		pl.append(_world(_point_at(_cursor)))
		if pl.size() >= 2:
			c.draw_polyline(pl, Style.MAT.darkened(0.16), 7.0)
			c.draw_polyline(pl, Style.FOREST, 2.0)
	Craft.eyelet(c, start_pt, 0.0)


## Where the cut is heading, and — when the blades are off it — which way to turn.
## The scissors carry the state colour, but the arrow says it in shape too (§2).
func _paint_guide(c: Control, at: Vector2) -> void:
	var tangent := _tangent_at(_cursor)
	var dir := Vector2.RIGHT.rotated(tangent)
	var col := Style.tint(Style.CHALK, 0.85) if _aligned else Style.CLAY
	var tip := at + dir * 46.0
	c.draw_line(at + dir * 18.0, tip, col, 2.0)
	_paint_arrow_head(c, tip, dir, col)
	if _aligned or _lead > 0.0:
		return
	var turn := signf(angle_difference(_angle, tangent))
	var from := _angle - 0.5 * turn
	c.draw_arc(at, 34.0, from, from + turn, 14, Style.CLAY, 2.5)


## Steel shears on a brass rivet, lifted off the mat by their shadow: the blades open
## and shut on the snip, and the finger loops carry whether the cut is running clean.
func _paint_scissors(c: Control, pos: Vector2, angle: float) -> void:
	var spread := _blade_spread()
	_paint_shears(c, pos + Craft.SHADOW_OFFSET * 0.7, angle, spread, true)
	_paint_shears(c, pos, angle, spread, false)
	if _aligned and _lead <= 0.0:
		_paint_dust(c, pos, angle)


## How far the blades stand apart right now: wide open while you line up or wander off
## the line, closing to the bite once per snip while the cut runs.
func _blade_spread() -> float:
	if not _aligned or _lead > 0.0:
		return deg_to_rad(OPEN_DEG)
	var t := 0.5 - 0.5 * cos(_snip_phase * TAU)  # shut exactly when the snip sounds
	return deg_to_rad(lerpf(SHUT_DEG, OPEN_DEG, t))


func _paint_shears(c: Control, pos: Vector2, angle: float, spread: float, shadow: bool) -> void:
	var grip := Style.FOREST if _aligned else Style.CLAY
	for side in [-1.0, 1.0]:
		var half: float = angle + spread * 0.5 * side
		_paint_blade(c, pos, half, shadow)
		_paint_loop(c, pos, half, side, Style.SHADOW if shadow else grip, shadow)
	c.draw_circle(pos, 3.8 * BLADE, Style.SHADOW if shadow else Style.BRASS)


## One tapered blade, pivot to point, with a lit edge down its back.
func _paint_blade(c: Control, pivot: Vector2, at: float, shadow: bool) -> void:
	var dir := Vector2.RIGHT.rotated(at)
	var n := dir.orthogonal()
	var tip := pivot + dir * 34.0 * BLADE
	var w := 5.0 * BLADE
	var poly := PackedVector2Array(
		[pivot + n * w, tip + n * 1.3, tip - n * 1.3, pivot - n * w * 0.45]
	)
	if shadow:
		c.draw_colored_polygon(poly, Style.SHADOW)
		return
	c.draw_colored_polygon(poly, Style.STEEL)
	Craft.outline(c, poly, Style.STEEL_DARK, 1.5)
	c.draw_line(pivot + n * w * 0.55, tip + n * 0.9, Style.tint(Style.CHALK, 0.85), 1.5)


## The handle behind the pivot: an arm carrying its blade's finger loop, bent out by
## SPLAY_DEG the way real shears are so the two loops never sit on top of each other.
func _paint_loop(c: Control, pivot: Vector2, at: float, side: float, col: Color, sh: bool) -> void:
	var dir := Vector2.RIGHT.rotated(at + PI + deg_to_rad(SPLAY_DEG) * side)
	var back := pivot + dir * 26.0 * BLADE
	c.draw_line(pivot, back, col, 5.0 * BLADE)
	c.draw_circle(back, 7.5 * BLADE, col, false, 5.0 * BLADE, true)
	if not sh:
		c.draw_circle(back, 9.5 * BLADE, Style.WALNUT, false, 1.0, true)
		c.draw_circle(back, 5.0 * BLADE, Style.WALNUT, false, 1.0, true)


## Chalk dust off the blades, flickering in time with the snips.
func _paint_dust(c: Control, pos: Vector2, angle: float) -> void:
	var perp := Vector2.RIGHT.rotated(angle).orthogonal()
	var t := _snip_accum * 40.0
	for i in 3:
		var side := 1.0 if i % 2 == 0 else -1.0
		var off := perp * (6.0 + i * 5.0) * side
		c.draw_circle(pos + off, maxf(1.5 + sin(t + i) * 0.8, 0.6), Style.tint(Style.CHALK, 0.55))

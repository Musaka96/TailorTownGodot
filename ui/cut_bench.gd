class_name CutBench
extends MinigameScreen

## The bench the v2/v3 cutting games share (v1, CuttingMinigame, stands alone): the
## customer's cloth laid on the mat and chalked round a garment outline with real
## curves in it, the seam allowance shaded outside the chalk, the cut left open behind
## the shears, and the scoring. Each variant only decides how the shears move and
## where the camera looks — see docs/RESEARCH_cutting_minigame.md.
##
## Every stretch of the cut lands in a zone: on the chalk (PERFECT), out in the seam
## allowance (GOOD — wide and safe), too far out (ROUGH — wasted cloth) or inside the
## line (NICK — into the garment). Quality is the length-weighted score of those, less
## a slice per slip. Emits finished(success, quality).

signal finished(success: bool, quality: float)

enum State { READY, RUNNING, SUCCESS, RUINED }
enum Zone { PERFECT, GOOD, ROUGH, NICK }

const TITLE := "Cutting Table"
const ZONE_SCORE := [1.0, 0.8, 0.4, 0.2]
const ZONE_NAME := ["Perfect", "Good", "Rough", "Nicked"]
const SLIP_COST := 0.1
const CLEAN_CUT := 0.97  # quality that earns the "Clean cut" stamp
const MAX_MISTAKES := 3
const CORNER_DEG := 35.0  # a turn sharper than this is a corner the shears pivot at
const STEP := 0.015  # outline spacing, in shape units (1 unit ≈ 40 cm of cloth)
const CURVE_SAMPLES := 24
const JITTER := 0.03
const CLOTH_HALF := Vector2(1.25, 1.2)
const MAT_INSET := 10.0
const VIEW_FILL := 0.46  # the whole piece at zoom 1, like v1
## Optional painted surfaces; each falls back to the palette without them.
const MAT_ART := "res://assets/textures/ui/cutting_mat.png"
const WEAVE_ART := "res://assets/textures/ui/cloth_weave.png"
const BLADE := 1.25
const OPEN_DEG := 21.0
const SHUT_DEG := 3.0
const SPLAY_DEG := 15.0

## Garment outlines, roughly [-1, 1]. A Vector2 is a corner; a Vector3 is the bezier
## control of the run from the corner before it to the corner after it — the armholes,
## necklines, crotch curve and hip that make cutting a real job.
const SHAPES := {
	Enums.GarmentType.SHIRT:
	[
		Vector2(-0.34, -0.82),
		Vector3(0.0, -0.52, 0.0),
		Vector2(0.34, -0.82),
		Vector2(0.64, -0.7),
		Vector3(0.46, -0.4, 0.0),
		Vector2(0.7, -0.12),
		Vector2(0.62, 0.8),
		Vector3(0.0, 0.98, 0.0),
		Vector2(-0.62, 0.8),
		Vector2(-0.7, -0.12),
		Vector3(-0.46, -0.4, 0.0),
		Vector2(-0.64, -0.7),
	],
	Enums.GarmentType.PANTS:
	[
		Vector2(-0.46, -0.86),
		Vector2(0.3, -0.86),
		Vector2(0.33, -0.22),
		Vector3(0.36, 0.04, 0.0),
		Vector2(0.62, 0.06),
		Vector2(0.32, 0.9),
		Vector2(-0.36, 0.9),
		Vector3(-0.66, -0.25, 0.0),
	],
	Enums.GarmentType.JACKET:
	[
		Vector2(-0.06, -0.86),
		Vector2(0.54, -0.72),
		Vector3(0.38, -0.38, 0.0),
		Vector2(0.62, -0.1),
		Vector3(0.5, 0.38, 0.0),
		Vector2(0.6, 0.86),
		Vector2(-0.44, 0.9),
		Vector3(-0.72, 0.9, 0.0),
		Vector2(-0.7, 0.58),
		Vector2(-0.7, -0.24),
		Vector2(-0.42, -0.58),
		Vector3(-0.2, -0.56, 0.0),
	],
}

## How each cloth is drawn: [spacing, thread width (units), opacity, checked?].
const SOLID_LOOK := [0.02, 0.002, 0.3, true]
const PATTERN_LOOK := {
	Enums.Pattern.PINSTRIPE: [0.07, 0.005, 0.6, false],
	Enums.Pattern.HERRINGBONE: [0.03, 0.008, 0.18, false],
	Enums.Pattern.HOUNDSTOOTH: [0.035, 0.012, 0.3, true],
	Enums.Pattern.WINDOWPANE: [0.24, 0.007, 0.55, true],
	Enums.Pattern.GLEN_CHECK: [0.09, 0.01, 0.3, true],
	Enums.Pattern.BIRDSEYE: [0.025, 0.006, 0.15, true],
	Enums.Pattern.SHARKSKIN: [0.02, 0.006, 0.18, false],
	Enums.Pattern.NAILHEAD: [0.03, 0.005, 0.2, true],
	Enums.Pattern.BENGAL_STRIPE: [0.08, 0.03, 0.45, false],
	Enums.Pattern.UNIVERSITY_STRIPE: [0.1, 0.018, 0.5, false],
	Enums.Pattern.GINGHAM: [0.07, 0.035, 0.35, true],
	Enums.Pattern.TATTERSALL: [0.11, 0.006, 0.6, true],
	Enums.Pattern.END_ON_END: [0.018, 0.006, 0.18, false],
}

var _state := State.READY
var _armed := false  # the Cut button has been let go since the screen opened
var _band_perfect := 0.015
var _band_good := 0.05
var _band_nick := 0.02
var _zoom := 1.0
var _cam := Vector2.ZERO  # the shape-space point under the canvas centre
var _view_rot := 0.0

var _path := PackedVector2Array()  # closed: the last point is the first
var _normals := PackedVector2Array()  # outward, per point
var _cum := PackedFloat32Array()
var _corners := {}  # path index -> true where the shears pivot
var _total := 0.0
var _out := 1.0  # which side of the travel direction is "outside"

var _trail := PackedVector2Array()
var _trail_zone := PackedInt32Array()
var _zone_len := [0.0, 0.0, 0.0, 0.0]
var _score_sum := 0.0
var _score_len := 0.0
var _nicks := PackedVector2Array()

var _cloth := Style.LINEN
var _accent := Style.WALNUT
var _chalk := Style.CHALK
var _pattern := 0
var _fabric := 0

var _snip: AudioStream
var _slip: AudioStream
var _complete: AudioStream
var _ruined: AudioStream
var _mat_tex: Texture2D
var _weave_tex: Texture2D


func _ready() -> void:
	_ensure_chrome(TITLE, _paint, Style.FRAME_TALL)


func _load_assets() -> void:
	_snip = _load("snip")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_mat_tex = _load_art(MAT_ART)
	_weave_tex = _load_art(WEAVE_ART)


## Same contract as v1: the garment, the ticket text, and (new) the cloth it's cut from.
func start(garment_type: int, title: String, material: MaterialType = null) -> void:
	_ensure_chrome(TITLE, _paint, Style.FRAME_TALL)
	_canvas.clip_contents = true  # the cloth runs off the edges of the bench
	_max_mistakes = MAX_MISTAKES
	var c := Config.data
	if c != null:
		_band_perfect = c.cut_band_perfect
		_band_good = c.cut_band_good
		_band_nick = c.cut_band_nick
		_max_mistakes = c.cut_max_mistakes
	_read_cloth(material)
	_generate(garment_type)
	_state = State.READY
	_armed = false
	_mistakes = 0
	_zone_len = [0.0, 0.0, 0.0, 0.0]
	_score_sum = 0.0
	_score_len = 0.0
	_nicks = PackedVector2Array()
	_trail = PackedVector2Array()
	_trail_zone = PackedInt32Array()
	_set_job(title if material == null else "%s  ·  %s" % [title, material.display_name])
	_begin()
	_rebuild_hints.call_deferred()
	_build_pips()
	_show_panel()
	_update_status()
	set_process(true)
	_repaint()


## Overridden: reset the variant's own state once the outline exists.
func _begin() -> void:
	pass


## Overridden: the variant's key prompts.
func _hint_pairs() -> Array:
	return []


## Overridden: the variant's status line.
func _update_status() -> void:
	pass


func _rebuild_hints() -> void:
	var pairs := _hint_pairs()
	if Upgrades != null and Upgrades.cutting_sprint():
		pairs.append(["Shift", "Faster (riskier)"])
	_set_hints(pairs)


func _read_cloth(material: MaterialType) -> void:
	_cloth = Style.LINEN
	_accent = Style.WALNUT
	_pattern = Enums.Pattern.SOLID
	_fabric = Enums.Fabric.WORSTED_WOOL
	if material != null:
		_cloth = material.cloth_color
		_accent = material.pattern_color
		_pattern = material.pattern
		_fabric = material.fabric
	# Tailor's chalk comes white for dark cloth and red for pale.
	_chalk = Style.CHALK if _cloth.get_luminance() < 0.55 else Style.BURGUNDY


# --- Input -----------------------------------------------------------------


## Any of the "do it" buttons (F / Space / E / pad A, X, Y) holds the shears shut.
func _cut_held() -> bool:
	for action in ["cut", "jump", "interact", "ui_accept"]:
		if Input.is_action_pressed(action):
			return true
	return false


## The press that opened the bench may still be held; nothing cuts until it's let go.
func _update_armed() -> void:
	if not _armed and not _cut_held():
		_armed = true


func _speed_boost() -> float:
	var boost := Upgrades.cutting_speed()
	if Upgrades.cutting_sprint() and Input.is_action_pressed("sprint"):
		boost *= 1.6
	return boost


## Debug (F2, debug builds only): skip the cut and finish it perfectly.
func _unhandled_input(event: InputEvent) -> void:
	if _state > State.RUNNING or not OS.is_debug_build():
		return
	if event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		finished.emit(true, 1.0)


# --- Outline ---------------------------------------------------------------


func _generate(garment_type: int) -> void:
	var spec: Array = SHAPES.get(garment_type, SHAPES[Enums.GarmentType.SHIRT])
	var pts: Array = []
	for p in spec:
		var j := Vector2(randf_range(-JITTER, JITTER), randf_range(-JITTER, JITTER))
		pts.append(Vector3(p.x + j.x * 0.5, p.y + j.y * 0.5, 0.0) if p is Vector3 else p + j)
	_path = PackedVector2Array()
	var starts: Array[int] = []
	var i := 0
	while i < pts.size():
		var nxt := (i + 1) % pts.size()
		var curved: bool = pts[nxt] is Vector3
		var ctrl := Vector2.ZERO
		if curved:
			ctrl = Vector2(pts[nxt].x, pts[nxt].y)
			nxt = (nxt + 1) % pts.size()
		starts.append(_path.size())
		_append_run(pts[i], pts[nxt], curved, ctrl)
		i += 2 if curved else 1
	_path.append(_path[0])
	_measure()
	_find_corners(starts)


## One corner-to-corner run, resampled evenly so every step of the cut is the same
## length of cloth. The end corner is left for the next run to start on.
func _append_run(a: Vector2, b: Vector2, curved: bool, ctrl: Vector2) -> void:
	var raw := PackedVector2Array()
	var n := CURVE_SAMPLES if curved else 1
	for k in n + 1:
		var t := float(k) / n
		raw.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t) if curved else a.lerp(b, t))
	var lens := PackedFloat32Array([0.0])
	for k in range(1, raw.size()):
		lens.append(lens[k - 1] + raw[k - 1].distance_to(raw[k]))
	var run_len := lens[lens.size() - 1]
	var count := maxi(1, roundi(run_len / STEP))
	var seg := 0
	for k in count:
		var target := run_len * k / count
		while seg < raw.size() - 2 and lens[seg + 1] < target:
			seg += 1
		var span := lens[seg + 1] - lens[seg]
		var t := 0.0 if span <= 0.0 else (target - lens[seg]) / span
		_path.append(raw[seg].lerp(raw[seg + 1], t))


func _measure() -> void:
	var m := _path.size()
	_cum = PackedFloat32Array([0.0])
	for i in range(1, m):
		_cum.append(_cum[i - 1] + _path[i - 1].distance_to(_path[i]))
	_total = _cum[m - 1]
	var centre := Vector2.ZERO
	for i in m - 1:
		centre += _path[i]
	centre /= m - 1
	var sense := 0.0
	for i in m - 1:
		sense += _seg_dir(i).orthogonal().dot(_path[i] - centre)
	_out = 1.0 if sense >= 0.0 else -1.0
	_normals = PackedVector2Array()
	for i in m:
		var prev := _path[i - 1] if i > 0 else _path[m - 2]
		var nxt := _path[i + 1] if i < m - 1 else _path[1]
		_normals.append((nxt - prev).normalized().orthogonal() * _out)


func _find_corners(starts: Array[int]) -> void:
	_corners = {}
	var m := _path.size()
	for k in starts:
		var prev := _path[k] - (_path[k - 1] if k > 0 else _path[m - 2])
		var nxt := _path[k + 1] - _path[k]
		if absf(angle_difference(prev.angle(), nxt.angle())) > deg_to_rad(CORNER_DEG):
			_corners[k] = true


func _seg_dir(i: int) -> Vector2:
	i = clampi(i, 0, _path.size() - 2)
	return (_path[i + 1] - _path[i]).normalized()


func _seg_normal(i: int) -> Vector2:
	return _seg_dir(i).orthogonal() * _out


## How far `p` sits outside (+) or inside (−) the line along segment i.
func _offset(i: int, p: Vector2) -> float:
	return (p - _path[clampi(i, 0, _path.size() - 2)]).dot(_seg_normal(i))


func _zone_of(d: float) -> int:
	if d < -_band_nick:
		return Zone.NICK
	if absf(d) <= _band_perfect:
		return Zone.PERFECT
	if d <= _band_good:
		return Zone.GOOD  # out in the allowance, or a hair inside but not into the piece
	return Zone.ROUGH


# --- Scoring ---------------------------------------------------------------


func _record(zone: int, length: float, score: float) -> void:
	_zone_len[zone] += length
	_score_sum += score * length
	_score_len += length


func _quality() -> float:
	var q := 1.0 if _score_len <= 0.0 else _score_sum / _score_len
	return clampf(q - SLIP_COST * _mistakes, 0.15, 1.0)


func _breakdown() -> String:
	var total := 0.0
	for z in 4:
		total += _zone_len[z]
	if total <= 0.0:
		return ""
	var bits: PackedStringArray = []
	for z in 4:
		if _zone_len[z] > 0.0:
			bits.append("%s %d%%" % [ZONE_NAME[z], roundi(_zone_len[z] / total * 100.0)])
	return "  ·  ".join(bits)


func _register_mistake(at: Vector2) -> void:
	_mistakes += 1
	_nicks.append(at)
	_play(_slip, 0.8)
	_slip_feedback()
	if _mistakes >= _max_mistakes:
		_fail()


func _succeed(extra := "") -> void:
	_state = State.SUCCESS
	set_process(false)
	var q := _quality()
	_play(_complete, 0.7)
	var head := "Clean cut!  " if q >= CLEAN_CUT else ""
	_set_status("%s%s%s  →  %d%%" % [head, _breakdown(), extra, roundi(q * 100.0)], Style.FOREST)
	_repaint()
	await get_tree().create_timer(2.4).timeout
	finished.emit(true, q)


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	_play(_ruined, 0.8)
	_set_status("Oh no — the shears went into the piece. It's spoiled.", Style.CLAY)
	_repaint()
	await get_tree().create_timer(1.2).timeout
	finished.emit(false, 0.0)


func _zone_color(zone: int) -> Color:
	match zone:
		Zone.PERFECT:
			return Style.BRASS
		Zone.GOOD:
			return Style.CHALK
		Zone.ROUGH:
			return Style.AMBER
	return Style.CLAY


func _zone_status_color(zone: int) -> Color:
	match zone:
		Zone.PERFECT:
			return Style.FOREST
		Zone.GOOD:
			return Style.INK_SOFT
		Zone.ROUGH:
			return Style.AMBER
	return Style.CLAY


# --- View ------------------------------------------------------------------


func _px() -> float:
	return minf(_canvas.size.x, _canvas.size.y) * VIEW_FILL * _zoom


## Shape space → canvas-local, *inside* the world transform set by _paint.
func _w(p: Vector2) -> Vector2:
	return (p - _cam) * _px()


## Shape space → canvas pixels, for things drawn upright over the world.
func _to_screen(p: Vector2) -> Vector2:
	return _canvas.size * 0.5 + _w(p).rotated(_view_rot)


# --- Painting --------------------------------------------------------------


func _paint(c: Control) -> void:
	_paint_mat(c)
	if _path.is_empty():
		return
	c.draw_set_transform(c.size * 0.5, _view_rot, Vector2.ONE)
	_paint_cloth(c)
	_paint_allowance(c)
	_paint_chalk(c)
	_paint_trail(c)
	for n in _nicks:
		_paint_x(c, _w(n), Style.CLAY, 7.0)
	_paint_world_extra(c)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_paint_overlay(c)


## Overridden: anything else that lies on the cloth (guides, ghosts, jags).
func _paint_world_extra(_c: Control) -> void:
	pass


## Overridden: the shears and anything else drawn upright over the cloth.
func _paint_overlay(_c: Control) -> void:
	pass


func _paint_mat(c: Control) -> void:
	var rect := Rect2(
		Vector2(MAT_INSET, MAT_INSET), c.size - Vector2(MAT_INSET * 2.0, MAT_INSET * 2.0)
	)
	var mat := StyleBoxFlat.new()
	mat.bg_color = Style.MAT.darkened(0.16)
	mat.set_corner_radius_all(14)
	mat.set_border_width_all(3)
	mat.border_color = Style.WALNUT
	c.draw_style_box(mat, rect)
	if _mat_tex != null:
		c.draw_texture_rect(_mat_tex, rect.grow(-3.0), true)


## The bolt laid out on the mat: pinked edges, the weave, and its stripes or checks —
## so you can see it's *this* customer's cloth under the shears.
func _paint_cloth(c: Control) -> void:
	var px := _px()
	var r := Rect2(_w(-CLOTH_HALF), CLOTH_HALF * 2.0 * px)
	Craft.card(c, Craft.pinked(r, 0.03 * px), _cloth, _cloth.darkened(0.3), 2.0)
	var inner := r.grow(-0.03 * px)
	if _weave_tex != null:
		c.draw_texture_rect(_weave_tex, inner, true, _cloth)
	var look: Array = PATTERN_LOOK.get(_pattern, SOLID_LOOK)
	var col := Style.tint(_accent, look[2])
	if _pattern == Enums.Pattern.SOLID:
		col = Style.tint(_cloth.darkened(0.25), look[2])
	var step: float = maxf(3.0, float(look[0]) * px)
	var width: float = maxf(1.0, float(look[1]) * px)
	var x := inner.position.x + step * 0.5
	while x < inner.end.x:
		c.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), col, width)
		x += step
	if not look[3]:
		return
	var y := inner.position.y + step * 0.5
	while y < inner.end.y:
		c.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), col, width)
		y += step


## The seam allowance: a soft band outside the chalk, edged with a faint dashed rule.
## Anywhere in here is a good cut — it's the safe side.
func _paint_allowance(c: Control) -> void:
	var px := _px()
	var mid := PackedVector2Array()
	var edge := PackedVector2Array()
	for i in _path.size():
		mid.append(_w(_path[i] + _normals[i] * _band_good * 0.5))
		edge.append(_w(_path[i] + _normals[i] * _band_good))
	c.draw_polyline(mid, Style.tint(_chalk, 0.16), _band_good * px)
	for i in edge.size() - 1:
		if int(_cum[i] * px / 7.0) % 2 == 0:
			c.draw_line(edge[i], edge[i + 1], Style.tint(_chalk, 0.4), 1.5)


## The chalk line itself, drawn as wide as the "perfect" band so being on it is literal.
func _paint_chalk(c: Control) -> void:
	var px := _px()
	var width := maxf(2.5, _band_perfect * px)
	var col := Style.tint(_chalk, 0.85)
	for i in _path.size() - 1:
		if int(_cum[i] * px / 12.0) % 3 != 2:
			c.draw_line(_w(_path[i]), _w(_path[i + 1]), col, width)
	Craft.eyelet(c, _w(_path[0]), 0.0)


## The cut so far: the cloth parted along it with the mat showing through, and a
## thread of colour down the middle saying how clean each stretch was.
func _paint_trail(c: Control) -> void:
	if _trail.size() < 2:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in _trail.size():
		pts.append(_w(_trail[i]))
		cols.append(_zone_color(_trail_zone[i]))
	c.draw_polyline(pts, Style.WALNUT, 8.0)
	c.draw_polyline(pts, Style.MAT.darkened(0.1), 5.5)
	c.draw_polyline_colors(pts, cols, 2.0)


# --- Shears (upright, over the world) --------------------------------------


func _paint_scissors(c: Control, pos: Vector2, angle: float, spread: float, grip: Color) -> void:
	_paint_shears(c, pos + Craft.SHADOW_OFFSET * 0.7, angle, spread, Style.SHADOW, true)
	_paint_shears(c, pos, angle, spread, grip, false)


func _paint_shears(
	c: Control, pos: Vector2, angle: float, spread: float, grip: Color, shadow: bool
) -> void:
	for side in [-1.0, 1.0]:
		var half: float = angle + spread * 0.5 * side
		_paint_blade(c, pos, half, shadow)
		_paint_loop(c, pos, half, side, grip, shadow)
	c.draw_circle(pos, 3.8 * BLADE, Style.SHADOW if shadow else Style.BRASS)


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


func _paint_loop(c: Control, pivot: Vector2, at: float, side: float, col: Color, sh: bool) -> void:
	var dir := Vector2.RIGHT.rotated(at + PI + deg_to_rad(SPLAY_DEG) * side)
	var back := pivot + dir * 26.0 * BLADE
	c.draw_line(pivot, back, col, 5.0 * BLADE)
	c.draw_circle(back, 7.5 * BLADE, col, false, 5.0 * BLADE, true)
	if not sh:
		c.draw_circle(back, 9.5 * BLADE, Style.WALNUT, false, 1.0, true)
		c.draw_circle(back, 5.0 * BLADE, Style.WALNUT, false, 1.0, true)

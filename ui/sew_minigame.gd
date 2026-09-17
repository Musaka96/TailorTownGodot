class_name SewMinigame
extends MinigameScreen

## Rhythm sewing minigame. A pinked strip of the customer's cloth lies on the machine
## bed; the needle bar runs the seam and you tap the stitch button (E / Space / F / A)
## as it reaches each marked point, laying thread behind it. Early taps and missed
## points are slips — 3 ruins the piece. The chrome (panel, ticket, slip pins,
## prompts) comes from MinigameScreen. Emits finished(success, quality).

signal finished(success: bool, quality: float)

enum State { RUNNING, SUCCESS, RUINED }
enum Stitch { PENDING, PERFECT, GOOD, MISS }

const STITCHES := 9
const CROSS_SECONDS := 7.5
const GOOD_WINDOW := 0.05  # in seam fraction (0..1)
const PERFECT_WINDOW := 0.025
const MAX_MISTAKES := 3
const SPRINT_MULT := 1.7  # hold Shift: the needle races, so the timing is tighter

const TITLE := "Sewing Machine"
const CLOTH_DEFAULT := Style.LINEN  # when the piece has no fabric colour yet
## Optional painted surfaces. Without them both are drawn from the palette.
const BED_ART := "res://assets/textures/ui/machine_bed.png"
const WEAVE_ART := "res://assets/textures/ui/cloth_weave.png"
const BED_INSET := 10.0
const ARM_H := 30.0  # the machine's arm, across the top of the bed
const SPOOL_X := 54.0  # spool centre, in from the bed's left edge

var _stitches := STITCHES
var _cross_seconds := CROSS_SECONDS
var _good_window := GOOD_WINDOW
var _perfect_window := PERFECT_WINDOW
var _lead := 0.0
var _state := State.RUNNING
var _needle := 0.0
var _pts: PackedFloat32Array = []
var _judge: PackedInt32Array = []
var _bob := 0.0
var _cloth := CLOTH_DEFAULT
var _bed_tex: Texture2D
var _weave_tex: Texture2D

var _stitch_snd: AudioStream
var _slip: AudioStream
var _complete: AudioStream
var _ruined: AudioStream


func _ready() -> void:
	_ensure_chrome(TITLE, _paint)


func _load_assets() -> void:
	_stitch_snd = _load("stitch")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_bed_tex = _load_art(BED_ART)
	_weave_tex = _load_art(WEAVE_ART)


func start(title: String, cloth := CLOTH_DEFAULT) -> void:
	_ensure_chrome(TITLE, _paint)
	_cloth = cloth
	var c := Config.data
	_lead = 1.6
	_max_mistakes = MAX_MISTAKES
	if c != null:
		_stitches = maxi(2, c.sew_stitches)
		_cross_seconds = c.sew_cross_seconds
		_good_window = c.sew_good_window
		_perfect_window = c.sew_perfect_window
		_max_mistakes = c.sew_max_mistakes
		_lead = c.sew_lead_seconds
	_state = State.RUNNING
	_needle = 0.0
	_mistakes = 0
	_pts = _random_points()
	_judge = PackedInt32Array()
	for i in _pts.size():
		_judge.append(Stitch.PENDING)
	_set_job(title)
	_rebuild_hints.call_deferred()
	_build_pips()
	_show_panel()
	_update_status()
	set_process(true)
	Sfx.start_loop("sew_machine_loop", -6.0)
	_repaint()


func _process(delta: float) -> void:
	if _state != State.RUNNING:
		return
	_bob += delta * 12.0

	# Lead-in: hold at the start so the player can find the rhythm.
	if _lead > 0.0:
		_lead -= delta
		_update_status()
		_repaint()
		return

	# Oiled Machine upgrade: hold Shift to run the needle faster (tighter timing).
	# Industrial Motor adds an always-on speed bump.
	var boost := Upgrades.sewing_speed()
	if Upgrades.sewing_sprint() and Input.is_action_pressed("sprint"):
		boost *= SPRINT_MULT
	_needle += (delta / _cross_seconds) * boost

	# Points the needle has passed without a stitch are misses.
	for i in _pts.size():
		if _judge[i] == Stitch.PENDING and _needle > _pts[i] + _good_window:
			_judge[i] = Stitch.MISS
			_register_mistake()

	if _needle >= 1.0:
		_succeed()
	_update_status()
	_repaint()


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.RUNNING:
		return
	# Debug (F2, debug builds only): skip the seam and finish it perfectly.
	if OS.is_debug_build() and event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		finished.emit(true, 1.0)
		return
	if not (
		event.is_action_pressed("interact")
		or event.is_action_pressed("jump")
		or event.is_action_pressed("cut")
		or event.is_action_pressed("ui_accept")
	):
		return
	get_viewport().set_input_as_handled()
	_try_stitch()


func _try_stitch() -> void:
	if _lead > 0.0:
		return  # ignore taps during the lead-in
	var idx := _next_pending()
	if idx == -1:
		return
	var d: float = absf(_needle - _pts[idx])
	if d <= _good_window:
		_judge[idx] = Stitch.PERFECT if d <= _perfect_window else Stitch.GOOD
		_play(_stitch_snd, 0.6)
	else:
		# Tapped too early (no point in range yet) — a wasted stitch.
		_register_mistake()
	_repaint()


func _next_pending() -> int:
	for i in _pts.size():
		if _judge[i] == Stitch.PENDING:
			return i
	return -1


## Stitch points at uneven, random spacing along the seam (scaled to fit 0.08..0.92),
## so the rhythm isn't a metronome — the player has to watch the needle, not the beat.
func _random_points() -> PackedFloat32Array:
	var gaps: Array[float] = []
	var total := 0.0
	for i in _stitches - 1:
		var g := randf_range(0.55, 1.55)
		gaps.append(g)
		total += g
	var pts := PackedFloat32Array()
	pts.append(_map01(0.0, total))
	var acc := 0.0
	for i in _stitches - 1:
		acc += gaps[i]
		pts.append(_map01(acc, total))
	return pts


func _map01(v: float, total: float) -> float:
	return lerpf(0.08, 0.92, v / total if total > 0.0 else 0.0)


func _register_mistake() -> void:
	_mistakes += 1
	_play(_slip, 0.7)
	_slip_feedback()
	if _mistakes >= _max_mistakes:
		_fail()


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	Sfx.stop_loop("sew_machine_loop")
	_play(_complete, 0.7)
	_set_status("Seam finished — looking sharp!", Style.FOREST)
	_repaint()
	var score := 0.0
	for j in _judge:
		score += 1.0 if j == Stitch.PERFECT else (0.7 if j == Stitch.GOOD else 0.0)
	var quality := clampf(score / _pts.size(), 0.15, 1.0)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, quality)


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	Sfx.stop_loop("sew_machine_loop")
	_play(_ruined, 0.8)
	_set_status("Ruined — the seam is a mess.", Style.CLAY)
	_repaint()
	await get_tree().create_timer(1.0).timeout
	finished.emit(false, 0.0)


## Key hints for this run — Shift only appears once its upgrade is owned.
func _rebuild_hints() -> void:
	var pairs := [["E / Space", "Stitch"]]
	if Upgrades != null and Upgrades.sewing_sprint():
		pairs.append(["Shift", "Speed up (riskier)"])
	_set_hints(pairs)


func _update_status() -> void:
	if _state != State.RUNNING:
		return
	if _lead > 0.0:
		_set_status("Find the rhythm…  %d" % ceili(_lead), Style.AMBER)
		return
	var done := 0
	for j in _judge:
		if j != Stitch.PENDING:
			done += 1
	var tip := "Tap as the needle meets each stitch   ·   %d/%d" % [done, _pts.size()]
	if OS.is_debug_build():
		tip += "   ·   F2 skip"
	_set_status(tip, Style.INK_SOFT)


# --- Painting (called from the MinigameCanvas) -----------------------------


func _seam_y() -> float:
	return _canvas.size.y * 0.5


func _seam_x(frac: float) -> float:
	var pad := _canvas.size.x * 0.1
	return pad + frac * (_canvas.size.x - pad * 2.0)


## The machine's deck, inside the play surface.
func _bed_rect(c: Control) -> Rect2:
	return Rect2(Vector2(BED_INSET, BED_INSET), c.size - Vector2(BED_INSET * 2.0, BED_INSET * 2.0))


## The strip of cloth under the needle.
func _band_rect(c: Control) -> Rect2:
	var h: float = minf(c.size.y * 0.56, 176.0)
	var inset := BED_INSET + 10.0
	return Rect2(inset, _seam_y() - h * 0.5, c.size.x - inset * 2.0, h)


func _paint(c: Control) -> void:
	_paint_bed(c)
	_paint_cloth(c)
	_paint_seam(c)
	_paint_stitches(c)
	_paint_head(c)
	if _state == State.RUNNING:
		_paint_machine(c)


## The machine bed: a dark deck with a brass needle plate let into it, and the feed
## dogs showing along the plate either side of the cloth.
func _paint_bed(c: Control) -> void:
	var rect := _bed_rect(c)
	var bed := StyleBoxFlat.new()
	bed.bg_color = Style.WALNUT.lightened(0.08)
	bed.set_corner_radius_all(14)
	bed.set_border_width_all(3)
	bed.border_color = Style.WALNUT
	c.draw_style_box(bed, rect)
	if _bed_tex != null:
		c.draw_texture_rect(_bed_tex, rect.grow(-3.0), true)
	var band := _band_rect(c)
	var plate := Rect2(
		rect.position.x + 6.0, band.position.y - 10.0, rect.size.x - 12.0, band.size.y + 20.0
	)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Style.RIM_DARK
	pb.set_corner_radius_all(8)
	c.draw_style_box(pb, plate)
	var col := Style.tint(Style.CHALK, 0.3)
	var x := plate.position.x + 12.0
	while x < plate.end.x - 8.0:
		c.draw_line(
			Vector2(x, band.position.y - 5.0), Vector2(x + 6.0, band.position.y - 5.0), col, 2.0
		)
		c.draw_line(Vector2(x, band.end.y + 5.0), Vector2(x + 6.0, band.end.y + 5.0), col, 2.0)
		x += 12.0


## The customer's cloth, cut with pinking shears and lying on the bed: woven texture,
## a pressed fold near the top, and a shadow so it sits ON the machine, not in it.
func _paint_cloth(c: Control) -> void:
	var r := _band_rect(c)
	Craft.card(c, Craft.pinked(r, 7.0), _cloth, _cloth.darkened(0.3), 2.0)
	var inner := r.grow(-6.0)
	if _weave_tex != null:
		c.draw_texture_rect(_weave_tex, inner, true, _cloth)
	else:
		_paint_weave(c, inner)
	var fold_y := r.position.y + r.size.y * 0.22
	c.draw_line(
		Vector2(inner.position.x, fold_y), Vector2(inner.end.x, fold_y), _cloth.lightened(0.2), 2.0
	)


## Warp and weft, drawn thread by thread so the strip reads as cloth, not a swatch.
func _paint_weave(c: Control, r: Rect2) -> void:
	var warp := _cloth.darkened(0.07)
	var weft := _cloth.lightened(0.07)
	var x := r.position.x
	while x < r.end.x:
		c.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), warp, 1.0)
		x += 5.0
	var y := r.position.y
	while y < r.end.y:
		c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), weft, 1.0)
		y += 5.0


## The chalked seam line, and the window for the next stitch — a bracket that the
## chalk ring closes into as the needle arrives, so the cue is shape as well as green.
func _paint_seam(c: Control) -> void:
	var y := _seam_y()
	var guide := Style.tint(Style.CHALK, 0.7)
	_dashed(c, Vector2(_seam_x(0.0), y), Vector2(_seam_x(1.0), y), guide, 2.0)
	var nxt := _next_pending()
	if nxt == -1 or _state != State.RUNNING or _lead > 0.0:
		return
	var gx0 := _seam_x(_pts[nxt] - _good_window)
	var gx1 := _seam_x(_pts[nxt] + _good_window)
	c.draw_rect(Rect2(gx0, y - 26.0, gx1 - gx0, 52.0), Style.tint(Style.FOREST, 0.18))
	_paint_bracket(c, gx0, y, 1.0)
	_paint_bracket(c, gx1, y, -1.0)
	var d: float = absf(_needle - _pts[nxt])
	var reach := maxf(_good_window * 3.0, 0.001)
	if d <= reach:
		var t := d / reach
		var at := Vector2(_seam_x(_pts[nxt]), y)
		c.draw_arc(at, lerpf(10.0, 40.0, t), 0, TAU, 24, Style.tint(Style.CHALK, 1.0 - t), 2.0)


func _paint_bracket(c: Control, x: float, y: float, dir: float) -> void:
	var col := Style.tint(Style.CHALK, 0.9)
	c.draw_line(Vector2(x, y - 26.0), Vector2(x, y + 26.0), col, 2.0)
	c.draw_line(Vector2(x, y - 26.0), Vector2(x + 8.0 * dir, y - 26.0), col, 2.0)
	c.draw_line(Vector2(x, y + 26.0), Vector2(x + 8.0 * dir, y + 26.0), col, 2.0)


## The seam as it is actually made: thread laid behind the needle, a lock-knot at
## every point caught, and a bare gap wherever one was missed.
func _paint_stitches(c: Control) -> void:
	var y := _seam_y()
	var thread := _cloth.darkened(0.45)
	var done: float = clampf(_needle, 0.0, 1.0)
	if done > 0.0:
		_dashed(c, Vector2(_seam_x(0.0), y), Vector2(_seam_x(done), y), thread, 3.0)
	for i in _pts.size():
		var p := Vector2(_seam_x(_pts[i]), y)
		match _judge[i]:
			Stitch.PERFECT:
				_paint_knot(c, p, thread, Style.FOREST, true)
			Stitch.GOOD:
				_paint_knot(c, p, thread, Style.AMBER, false)
			Stitch.MISS:
				_paint_x(c, p, Style.CLAY, 7.0)
			_:
				c.draw_arc(p, 8.0, 0, TAU, 18, Style.tint(Style.CHALK, 0.75), 2.5)


## A finished stitch. A clean one is crossed over twice, a rushed one caught once —
## the bead grades it, the crossing says it again without colour.
func _paint_knot(c: Control, p: Vector2, thread: Color, grade: Color, tight: bool) -> void:
	c.draw_line(p + Vector2(-6.0, -5.0), p + Vector2(6.0, 5.0), thread, 2.5)
	if tight:
		c.draw_line(p + Vector2(-6.0, 5.0), p + Vector2(6.0, -5.0), thread, 2.5)
	c.draw_circle(p, 3.5, grade)


## The machine's arm across the top of the bed, with the thread spool set into it.
func _paint_head(c: Control) -> void:
	var rect := _bed_rect(c)
	var arm := Rect2(rect.position.x + 4.0, rect.position.y + 4.0, rect.size.x - 8.0, ARM_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.WALNUT.darkened(0.42)
	sb.set_corner_radius_all(10)
	c.draw_style_box(sb, arm)
	c.draw_line(
		Vector2(arm.position.x + 10.0, arm.end.y - 4.0),
		Vector2(arm.end.x - 10.0, arm.end.y - 4.0),
		Style.RIM_DARK,
		2.0
	)
	var at := _spool_at(c)
	var w := 11.0
	var h := 22.0
	c.draw_rect(Rect2(at.x - w, at.y - h * 0.5, w * 2.0, h), _cloth.darkened(0.35))
	c.draw_rect(Rect2(at.x - w - 3.0, at.y - h * 0.5 - 4.0, (w + 3.0) * 2.0, 5.0), Style.BRASS)
	c.draw_rect(Rect2(at.x - w - 3.0, at.y + h * 0.5 - 1.0, (w + 3.0) * 2.0, 5.0), Style.BRASS)


func _spool_at(c: Control) -> Vector2:
	var rect := _bed_rect(c)
	return Vector2(rect.position.x + SPOOL_X, rect.position.y + 4.0 + ARM_H * 0.5)


## Thread from the spool to the needle, sagging under its own weight.
func _paint_thread(c: Control, to: Vector2) -> void:
	var from := _spool_at(c) + Vector2(0.0, 14.0)
	var sag := from.distance_to(to) * 0.12
	var line := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		line.append(from.lerp(to, t) + Vector2(0.0, sin(t * PI) * sag))
	c.draw_polyline(line, _cloth.darkened(0.45), 1.5, true)


## The needle bar and its presser foot, riding the seam and bobbing as they stitch.
func _paint_machine(c: Control) -> void:
	var y := _seam_y()
	var nx := _seam_x(_needle)
	var dip: float = absf(sin(_bob)) * 10.0
	var top := Vector2(nx, y - 52.0 + dip)
	_paint_thread(c, top)
	var foot := Style.BRASS
	for side in [-1.0, 1.0]:
		var fx: float = nx + 14.0 * side
		c.draw_line(Vector2(fx, y - 14.0), Vector2(fx, y + 9.0), foot, 5.0)
		c.draw_line(Vector2(fx, y + 9.0), Vector2(fx + 4.0 * side, y + 9.0), foot, 5.0)
	c.draw_line(Vector2(nx - 14.0, y - 14.0), Vector2(nx + 14.0, y - 14.0), foot, 5.0)
	var arm_bottom := _bed_rect(c).position.y + 4.0 + ARM_H
	c.draw_line(Vector2(nx, arm_bottom), top, Style.WALNUT.darkened(0.42), 7.0)
	c.draw_circle(Vector2(nx, arm_bottom), 6.0, Style.BRASS)
	c.draw_line(top, Vector2(nx, y + 2.0), Style.STEEL, 3.0)
	c.draw_circle(top, 4.5, Style.BRASS)

class_name CutAllowanceMinigame
extends CutBench

## Cutting v2 — "Seam Allowance". The camera rides on the shears and the cloth turns
## under them, so the cut always runs up the screen: hold Cut to push the shears on,
## steer left / right to follow the chalk. Straight runs look after themselves; the
## curves (armholes, necklines, the crotch, the hip) are where you steer. At a corner
## the shears stop, open, and the cloth pivots on its own — nothing can get stuck.
##
## On a straight run, held on the line, the shears **glide**: real shears on a long
## straight are pushed half-open through the cloth rather than snipped, so the dull
## stretches go quickly and the time goes where the skill is — the curves.
##
## Only one axis and one button, so keyboard and pad play the same. The seam allowance
## outside the chalk is wide and safe; the chalk itself is the "perfect" line; inside it
## you're into the garment, and a long enough nick is a slip.

const ZOOM := 1.9
const LOOK_AHEAD := 0.28  # the shears sit below centre so you see the line coming
const STEER_RAMP := 6.0  # 0 → full lock in ~1/6 s: a tap on a key is a small nudge
const MAX_OFF_ANGLE := deg_to_rad(70.0)  # the shears never turn back on themselves
const MAX_WANDER := 0.12  # how far off the line the shears can get before the cloth stops them
const NICK_LEN := 0.05  # length of cutting inside the line that costs a slip
const PIVOT_TIME := 0.24
const GLIDE_UP := 1.6  # glide build-up per second
const GLIDE_DOWN := 5.0  # and how fast it falls away off the line or into a curve
const GLIDING := 1.2  # past this the blades are held half-open and the snips give way
const GLIDE_OPEN_DEG := 11.0  # blade spread while gliding
const GLIDE_LOOP := "scissors_glide"
const GLIDE_DB_QUIET := -20.0  # the glide loop fades in from here …
const GLIDE_DB_FULL := -10.0  # … to here at full glide
## Push speed is set against a whole garment's outline, so a shorter cut (on the fold)
## really is quicker rather than the same time spread thinner.
const REF_OUTLINE := 5.5
const ROTARY_GLIDE := 3.0  # the Rotary Cutter rolls straight runs this fast
const ROTARY_SNAP := 12.0  # how quickly the rule pulls the blade onto the chalk
const TRAIL_STEP := 0.008
const SNIP_PERIOD := 0.13
## How much each cloth pulls the blades aside (deg/s): loose, slippery weaves wander,
## dense wools sit still.
const DRIFT := {
	Enums.Fabric.WORSTED_WOOL: 4.0,
	Enums.Fabric.FLANNEL: 2.0,
	Enums.Fabric.TWEED: 2.0,
	Enums.Fabric.MOHAIR_BLEND: 10.0,
	Enums.Fabric.LINEN: 14.0,
	Enums.Fabric.COTTON: 6.0,
	Enums.Fabric.POPLIN: 7.0,
	Enums.Fabric.OXFORD_CLOTH: 4.0,
}
## Only the zones worth a word: on the chalk or in the allowance, the line just shows
## progress (the trail's colour already says how clean it is).
const WARNINGS := {
	CutBench.Zone.ROUGH: "Too wide — steer back to the chalk",
	CutBench.Zone.NICK: "Into the piece! Steer out",
}

var _seconds := 12.0
var _glide_max := 1.8
var _glide := 1.0
var _rolling := false  # the Rotary Cutter's rule is down on a straight run
var _turn := deg_to_rad(170.0)
var _p := Vector2.ZERO
var _heading := 0.0
var _seg := 0
var _steer := 0.0
var _zone: int = CutBench.Zone.PERFECT
var _moving := false
var _nick_run := 0.0
var _pivot_t := 0.0
var _pivot_from := Vector2.ZERO
var _pivot_to := Vector2.ZERO
var _pivot_h0 := 0.0
var _pivot_h1 := 0.0
var _view_angle := 0.0
var _time := 0.0
var _snip_accum := 0.0
var _noise := FastNoiseLite.new()


func _begin() -> void:
	var c := Config.data
	if c != null:
		_seconds = c.cut2_seconds
		_turn = deg_to_rad(c.cut2_turn_deg)
		_glide_max = c.cut2_glide
	_glide_max += Upgrades.bonus("cut_glide_bonus")
	_zoom = ZOOM
	_seg = 0
	_p = _path[0]
	_heading = _seg_dir(0).angle()
	_view_angle = _heading
	_steer = 0.0
	_zone = Zone.PERFECT
	_moving = false
	_nick_run = 0.0
	_pivot_t = 0.0
	_time = 0.0
	_glide = 1.0
	_rolling = false
	_noise.seed = randi()
	_noise.frequency = 0.02
	_trail.append(_p)
	_trail_zone.append(Zone.PERFECT)
	_follow(1.0)


func _hint_pairs() -> Array:
	return [["Space / F", "Hold to cut"], ["A / D", "Steer"]]


func _process(delta: float) -> void:
	if _state > State.RUNNING:
		return
	_update_armed()
	_time += delta
	_steer = move_toward(_steer, Input.get_axis("move_left", "move_right"), STEER_RAMP * delta)
	if _rescue_t > 0.0:
		_steer = 0.0
		_tick_rescue(delta)
	elif _pivot_t > 0.0:
		_tick_pivot(delta)
	else:
		_moving = _armed and _cut_held()
		if not _moving:
			_glide_sound()  # let go mid-glide: the hiss stops with you
		if _moving and _state == State.READY:
			_state = State.RUNNING
		if _moving:
			_caught = false
		# You can turn the shears standing still, too — lining up before you push on.
		_heading += _steer * _turn * delta
		if _moving:
			_heading += _drift() * delta
			_advance(delta)
		_clamp_heading()
	if _state > State.RUNNING:
		return  # finished inside _advance
	_follow(1.0 - exp(-9.0 * delta))
	_update_status()
	_repaint()


## The cloth pulling the blades aside, in rad/s — a slow wander, never a jerk.
func _drift() -> float:
	var rate: float = DRIFT.get(_fabric, 4.0) * Upgrades.mult("cut_drift")
	if _focused:
		rate *= 0.5
	return deg_to_rad(rate) * _noise.get_noise_1d(_time * 60.0)


## Build up to a glide while the run ahead is straight and you're on (or near) the
## chalk; drop out of it at once for a curve, a corner or a wander.
func _update_glide(delta: float) -> void:
	var clean := _zone == Zone.PERFECT or _zone == Zone.GOOD
	var straight := _straight[mini(_seg, _straight.size() - 1)] == 1
	_rolling = straight and Upgrades.has("cut_rotary")
	if _rolling:
		_glide = move_toward(_glide, ROTARY_GLIDE, GLIDE_UP * 2.0 * delta)
	elif clean and straight:
		_glide = move_toward(
			_glide, _glide_max, GLIDE_UP * Upgrades.mult("cut_glide_build") * delta
		)
	else:
		_glide = move_toward(_glide, 1.0, GLIDE_DOWN * delta)


func _advance(delta: float) -> void:
	_update_glide(delta)
	var step := (REF_OUTLINE / _seconds) * _speed_boost() * _glide * delta
	if _rolling:
		_hold_to_rule(delta)
	_p += Vector2.from_angle(_heading) * step
	var last := _path.size() - 1
	# Walk the outline as the shears pass each point of it.
	while _seg < last and (_p - _path[_seg + 1]).dot(_seg_dir(_seg)) >= 0.0:
		_seg += 1
		if _seg < last and _corners.has(_seg):
			_start_pivot()
			break
	var d := _offset(_seg, _p)
	if absf(d) > MAX_WANDER:
		var held := clampf(d, -MAX_WANDER, MAX_WANDER)
		_p -= _seg_normal(_seg) * (d - held)
		d = held
	_zone = _zone_of(d)
	_record(_zone, step, ZONE_SCORE[_zone])
	_lay_trail()
	_snip_sound(delta)
	if _zone == Zone.NICK:
		_nick_run += step
		if _nick_run >= NICK_LEN:
			_nick_run = 0.0
			_register_mistake(_p)
	else:
		_nick_run = maxf(0.0, _nick_run - step * 0.5)
		_clear_slip_run()
	if _seg >= last and _state == State.RUNNING:
		_succeed()


## Two slips in one dive: the shears stop, back out along the slit and settle on the
## chalk, pointing down the line. Let go of Cut and carry on from there.
func _catch() -> void:
	_moving = false
	_nick_run = 0.0
	_glide = 1.0
	_glide_sound()
	var on_line := _p - _seg_normal(_seg) * _offset(_seg, _p)
	_start_rescue(_way_back(_p, on_line), _heading, _seg_dir(_seg).angle())


func _place_tool(p_at: Vector2, heading_to: float) -> void:
	_p = p_at
	_heading = heading_to
	if _rescue_t <= 0.0:
		_trail.append(_p)
		_trail_zone.append(Zone.PERFECT)


## Rotary Cutter: the rule lies along the chalk, so the wheel is drawn onto the line and
## runs true down it — only the curves are left to steer.
func _hold_to_rule(delta: float) -> void:
	var pull := minf(1.0, ROTARY_SNAP * delta)
	_p -= _seg_normal(_seg) * _offset(_seg, _p) * pull
	_heading = lerp_angle(_heading, _seg_dir(_seg).angle(), pull)


func _lay_trail() -> void:
	# The last point rides with the shears; a new one is laid each TRAIL_STEP.
	var n := _trail.size()
	if n < 2 or _trail[n - 2].distance_to(_p) >= TRAIL_STEP:
		_trail.append(_p)
		_trail_zone.append(_zone)
	else:
		_trail[n - 1] = _p


func _is_gliding() -> bool:
	return _moving and _pivot_t <= 0.0 and _glide >= GLIDING


## Snips while cutting, and a steady hiss of cloth on steel once you're gliding.
func _snip_sound(delta: float) -> void:
	_glide_sound()
	if _is_gliding():
		return
	_snip_accum += delta * _speed_boost() * _glide
	if _snip_accum >= SNIP_PERIOD:
		_snip_accum = 0.0
		_play(_snip, 0.35)


func _glide_sound() -> void:
	if not _is_gliding():
		Sfx.stop_loop(GLIDE_LOOP)
		return
	Sfx.start_loop(GLIDE_LOOP, GLIDE_DB_QUIET)
	var t := clampf((_glide - GLIDING) / maxf(_glide_max - GLIDING, 0.01), 0.0, 1.0)
	Sfx.set_loop_volume(GLIDE_LOOP, lerpf(GLIDE_DB_QUIET, GLIDE_DB_FULL, t))
	var pitch := lerpf(0.94, 1.06, t) * pow(_speed_boost(), 0.3)
	if _rolling:
		pitch *= 1.25  # the wheel sings a little higher than the shears
	Sfx.set_loop_pitch(GLIDE_LOOP, pitch)


func _stop_sounds() -> void:
	Sfx.stop_loop(GLIDE_LOOP)


## At a corner: open the blades and turn the cloth to the next edge, keeping however
## far out (or in) of the line you were — the pivot never fixes or spoils your cut.
func _start_pivot() -> void:
	var d := _offset(_seg - 1, _p)
	_pivot_from = _p
	_pivot_to = _path[_seg] + _seg_normal(_seg) * d
	_pivot_h0 = _heading
	_pivot_h1 = _seg_dir(_seg).angle()
	_pivot_t = PIVOT_TIME
	_moving = false
	_glide = 1.0
	_glide_sound()
	_play(_snip, 0.5)


func _tick_pivot(delta: float) -> void:
	_pivot_t = maxf(0.0, _pivot_t - delta)
	var t := smoothstep(0.0, 1.0, 1.0 - _pivot_t / PIVOT_TIME)
	_p = _pivot_from.lerp(_pivot_to, t)
	_heading = lerp_angle(_pivot_h0, _pivot_h1, t)
	if _pivot_t <= 0.0:
		_trail.append(_p)
		_trail_zone.append(_zone)


func _clamp_heading() -> void:
	var along := _seg_dir(_seg).angle()
	var off := clampf(angle_difference(along, _heading), -MAX_OFF_ANGLE, MAX_OFF_ANGLE)
	_heading = along + off


## Ride the camera on the shears, turned so they always point up the screen.
func _follow(weight: float) -> void:
	_view_angle = lerp_angle(_view_angle, _heading, weight)
	_view_rot = -PI * 0.5 - _view_angle
	var target := _p + Vector2.from_angle(_view_angle) * LOOK_AHEAD
	_cam = _cam.lerp(target, weight)


func _update_status() -> void:
	if _state > State.RUNNING:
		return
	if _state == State.READY:
		_set_status("Hold Cut to start — steer along the chalk", Style.AMBER)
		return
	var pct := int(_cum[mini(_seg, _cum.size() - 1)] / _total * 100.0)
	var tip := "%d%% cut" % pct
	if _caught:
		_set_status("%s   ·   %s" % [_caught_word(), tip], Style.AMBER)
		return
	var col := Style.INK_SOFT
	if _moving and _pivot_t <= 0.0 and WARNINGS.has(_zone):
		tip = "%s   ·   %s" % [WARNINGS[_zone], tip]
		col = _zone_status_color(_zone)
	if OS.is_debug_build():
		tip += "   ·   F2 skip"
	_set_status(tip, col)


# --- Painting --------------------------------------------------------------


## Where the shears would run if you stopped steering — a faint line straight ahead,
## so a curve reads as "the chalk bends away from here".
func _paint_world_extra(c: Control) -> void:
	var dir := Vector2.from_angle(_heading)
	if _rolling:
		_paint_rule(c, dir)
		return
	var from := _w(_p + dir * 0.06)
	var to := _w(_p + dir * 0.34)
	_dashed(c, from, to, Style.tint(_chalk, 0.35), 1.5)


## The cutting rule laid along the straight, just inside the line, ticked every 2 cm.
func _paint_rule(c: Control, dir: Vector2) -> void:
	var inward := -_seg_normal(_seg)
	var a := _p - dir * 0.12 + inward * 0.02
	var b := _p + dir * 0.5 + inward * 0.02
	var w := inward * 0.06
	var poly := PackedVector2Array([_w(a), _w(b), _w(b + w), _w(a + w)])
	c.draw_colored_polygon(poly, Style.tint(Style.CHALK, 0.35))
	Craft.outline(c, poly, Style.tint(Style.STEEL_DARK, 0.8), 1.5)
	var t := 0.0
	while t < 0.62:
		var at := a + dir * t
		c.draw_line(_w(at), _w(at + inward * 0.015), Style.STEEL_DARK, 1.0)
		t += 0.05


func _tool_at() -> Vector2:
	return _to_screen(_p)


func _paint_overlay(c: Control) -> void:
	var pos := _to_screen(_p)
	var angle := _heading + _view_rot
	if _rolling and _moving:
		_paint_wheel(c, pos, angle)
		return
	var spread := deg_to_rad(OPEN_DEG)
	if _is_gliding():
		# Held half-open and pushed, with the faint tremble of the cloth on the blade.
		spread = deg_to_rad(GLIDE_OPEN_DEG + sin(_time * 38.0) * 0.6)
	elif _moving and _pivot_t <= 0.0:
		var t := 0.5 - 0.5 * cos(_snip_accum / SNIP_PERIOD * TAU)
		spread = deg_to_rad(lerpf(SHUT_DEG, OPEN_DEG, t))
	var grip := _zone_color(_zone) if _state == State.RUNNING else Style.FOREST
	if _zone == Zone.GOOD:
		grip = Style.FOREST
	_paint_scissors(c, pos, angle, spread, grip)


## The rotary cutter: a steel wheel spinning on its guard, handle trailing behind.
func _paint_wheel(c: Control, pos: Vector2, angle: float) -> void:
	var back := Vector2.from_angle(angle + PI)
	var shadow := Craft.SHADOW_OFFSET * 0.7
	c.draw_line(pos + shadow, pos + back * 44.0 + shadow, Style.SHADOW, 12.0)
	c.draw_line(pos, pos + back * 44.0, Style.FOREST, 12.0)
	c.draw_circle(pos, 14.0, Style.STEEL)
	c.draw_circle(pos, 14.0, Style.STEEL_DARK, false, 1.5, true)
	var spin := _time * 18.0
	for k in 3:
		var spoke := Vector2.from_angle(spin + k * TAU / 3.0) * 10.0
		c.draw_line(pos - spoke, pos + spoke, Style.tint(Style.STEEL_DARK, 0.6), 1.0)
	c.draw_circle(pos, 3.5, Style.BRASS)

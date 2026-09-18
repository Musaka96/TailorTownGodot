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
const GLIDE_LOOK := 12  # outline points ahead (~18 cm) that must be straight to glide
const GLIDE_BEND := 1.2  # rad per unit: gentler than this counts as straight
const GLIDE_UP := 1.6  # glide build-up per second
const GLIDE_DOWN := 5.0  # and how fast it falls away off the line or into a curve
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
const STATUS := {
	CutBench.Zone.PERFECT: "On the chalk",
	CutBench.Zone.GOOD: "In the allowance",
	CutBench.Zone.ROUGH: "Too wide — wasting cloth",
	CutBench.Zone.NICK: "Into the piece!",
}

var _seconds := 12.0
var _glide_max := 1.8
var _glide := 1.0
var _straight := PackedByteArray()  # per outline point: a glide-able run lies ahead
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
	_find_straights()
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
	if _pivot_t > 0.0:
		_tick_pivot(delta)
	else:
		_moving = _armed and _cut_held()
		if _moving and _state == State.READY:
			_state = State.RUNNING
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
	var rate: float = DRIFT.get(_fabric, 4.0)
	return deg_to_rad(rate) * _noise.get_noise_1d(_time * 60.0)


## Mark where the next stretch is straight enough to glide (no corner, no curve).
func _find_straights() -> void:
	var m := _path.size()
	var bend := PackedFloat32Array()
	bend.resize(m)
	for i in range(1, m - 1):
		var turn := absf(angle_difference(_seg_dir(i - 1).angle(), _seg_dir(i).angle()))
		bend[i] = INF if _corners.has(i) else turn / STEP
	_straight = PackedByteArray()
	_straight.resize(m)
	for i in m:
		var ok := true
		for k in range(i + 1, mini(i + GLIDE_LOOK, m - 1)):
			if bend[k] > GLIDE_BEND:
				ok = false
				break
		_straight[i] = 1 if ok else 0


## Build up to a glide while the run ahead is straight and you're on (or near) the
## chalk; drop out of it at once for a curve, a corner or a wander.
func _update_glide(delta: float) -> void:
	var clean := _zone == Zone.PERFECT or _zone == Zone.GOOD
	var gliding := clean and _straight[mini(_seg, _straight.size() - 1)] == 1
	if gliding:
		_glide = move_toward(_glide, _glide_max, GLIDE_UP * delta)
	else:
		_glide = move_toward(_glide, 1.0, GLIDE_DOWN * delta)


func _advance(delta: float) -> void:
	_update_glide(delta)
	var step := (_total / _seconds) * _speed_boost() * _glide * delta
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
	if _seg >= last and _state == State.RUNNING:
		_succeed()


func _lay_trail() -> void:
	# The last point rides with the shears; a new one is laid each TRAIL_STEP.
	var n := _trail.size()
	if n < 2 or _trail[n - 2].distance_to(_p) >= TRAIL_STEP:
		_trail.append(_p)
		_trail_zone.append(_zone)
	else:
		_trail[n - 1] = _p


func _snip_sound(delta: float) -> void:
	_snip_accum += delta * _speed_boost() * _glide
	if _snip_accum >= SNIP_PERIOD:
		_snip_accum = 0.0
		_play(_snip, 0.35)


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
	var tip := "%s   ·   %d%% cut" % [STATUS[_zone], pct]
	if _glide > 1.3:
		tip = "Gliding   ·   %d%% cut" % pct
	if _pivot_t > 0.0:
		tip = "Turning the cloth   ·   %d%% cut" % pct
	elif not _moving:
		tip = "Paused   ·   %d%% cut" % pct
	if OS.is_debug_build():
		tip += "   ·   F2 skip"
	_set_status(tip, _zone_status_color(_zone) if _moving else Style.INK_SOFT)


# --- Painting --------------------------------------------------------------


## Where the shears would run if you stopped steering — a faint line straight ahead,
## so a curve reads as "the chalk bends away from here".
func _paint_world_extra(c: Control) -> void:
	var dir := Vector2.from_angle(_heading)
	var from := _w(_p + dir * 0.06)
	var to := _w(_p + dir * 0.34)
	_dashed(c, from, to, Style.tint(_chalk, 0.35), 1.5)


func _paint_overlay(c: Control) -> void:
	var pos := _to_screen(_p)
	var angle := _heading + _view_rot
	var spread := deg_to_rad(OPEN_DEG)
	if _moving and _pivot_t <= 0.0:
		var t := 0.5 - 0.5 * cos(_snip_accum / SNIP_PERIOD * TAU)
		spread = deg_to_rad(lerpf(SHUT_DEG, OPEN_DEG, t))
	var grip := _zone_color(_zone) if _state == State.RUNNING else Style.FOREST
	if _zone == Zone.GOOD:
		grip = Style.FOREST
	_paint_scissors(c, pos, angle, spread, grip)

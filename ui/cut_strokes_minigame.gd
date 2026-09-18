class_name CutStrokesMinigame
extends CutBench

## Cutting v3 — "Long Strokes & Snips". One button: hold Cut to open the shears wider,
## let go to close them — one stroke, cut in a straight line from where the blades sit
## to the chalk that far ahead. A ghost shows the stroke you'd make, coloured by how
## clean it would be.
##
## Straight edges want long strokes (one clean bite to the corner). On a curve a long
## straight stroke cuts across it — into the piece on a convex curve, out into the
## allowance on a hollow one — so there you take measured strokes. Tiny snips are
## always safe but chew the edge, so snipping all the way round is a solid, easy
## finish while reading the curves is where the last fifth of the quality lives.
## No steering and no tempo, so keyboard and pad are the same game.

const ZOOM := 1.6
const STROKE_TIME := 0.12
const CHOPPY_SCORE := 0.8  # the best a short snip can score — the edge is chewed
const INSIDE_GRACE := 0.8  # a stroke nicks only past this much of the allowance, inside
const CM_PER_UNIT := 40.0

var _max_stroke := 0.45
var _min_stroke := 0.04
var _charge_seconds := 0.9
var _short := 0.12
var _idx := 0
var _charge := 0.0
var _charging := false
var _ghost_idx := 0
var _ghost_zone: int = CutBench.Zone.PERFECT
var _anim_t := 0.0
var _anim_from := Vector2.ZERO
var _anim_to := Vector2.ZERO
var _anim_idx := 0
var _anim_zone: int = CutBench.Zone.PERFECT
var _anim_spread := 0.0
var _draw_angle := 0.0
var _strokes := 0
var _choppy := 0
var _jags := PackedVector2Array()


func _begin() -> void:
	var c := Config.data
	if c != null:
		_max_stroke = c.cut3_max_stroke
		_min_stroke = c.cut3_min_stroke
		_charge_seconds = c.cut3_charge_seconds
		_short = c.cut3_short_stroke
	_zoom = ZOOM
	_view_rot = 0.0
	_idx = 0
	_charge = 0.0
	_charging = false
	_anim_t = 0.0
	_strokes = 0
	_choppy = 0
	_jags = PackedVector2Array()
	_trail.append(_path[0])
	_trail_zone.append(Zone.PERFECT)
	_ghost_idx = _target_idx(_stroke_len())
	_draw_angle = _seg_dir(0).angle()
	_cam = _path[0]


func _hint_pairs() -> Array:
	return [["Space / F", "Hold to open · let go to cut"]]


func _process(delta: float) -> void:
	if _state > State.RUNNING:
		return
	_update_armed()
	if _anim_t > 0.0:
		_tick_stroke(delta)
	elif _armed and _cut_held():
		if _state == State.READY:
			_state = State.RUNNING
		_charging = true
		_charge = minf(1.0, _charge + delta / _charge_seconds * _sprint())
	elif _charging:
		_release()
	if _state > State.RUNNING:
		return
	if _anim_t <= 0.0:
		_ghost_idx = _target_idx(_stroke_len())
		_ghost_zone = _stroke_zone(_evaluate(_idx, _ghost_idx))
	_aim(delta)
	_update_status()
	_repaint()


## Hold Shift (Sharp Scissors): the blades fly open — quicker, harder to judge.
func _sprint() -> float:
	return _speed_boost() / Upgrades.cutting_speed()


## Charge eases in, so the short end of the stroke is easy to pick precisely. Master
## Shears have longer blades: a longer longest stroke.
func _stroke_len() -> float:
	var longest := _max_stroke * Upgrades.cutting_speed()
	return lerpf(_min_stroke, longest, _charge * _charge)


## The outline point a stroke of length `len` reaches — never past the next corner,
## where the blades stop and you turn the cloth.
func _target_idx(length: float) -> int:
	var last := _path.size() - 1
	var j := _idx
	while j < last and _cum[j + 1] - _cum[_idx] <= length:
		j += 1
		if _corners.has(j):
			break
	return maxi(j, mini(_idx + 1, last))


## How far a straight stroke from point a to point b strays from the chalk between
## them: (most inside, most outside), inside negative.
func _evaluate(a_idx: int, b_idx: int) -> Vector2:
	var a := _path[a_idx]
	var b := _path[b_idx]
	var lo := 0.0
	var hi := 0.0
	for k in range(a_idx + 1, b_idx):
		var q := Geometry2D.get_closest_point_to_segment(_path[k], a, b)
		var d := (q - _path[k]).dot(_normals[k])
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)


func _stroke_zone(ev: Vector2) -> int:
	if ev.x < -_band_good * INSIDE_GRACE:
		return Zone.NICK
	if maxf(-ev.x, ev.y) <= _band_perfect:
		return Zone.PERFECT
	if ev.y <= _band_good:
		return Zone.GOOD
	return Zone.ROUGH


func _release() -> void:
	_charging = false
	var j := _target_idx(_stroke_len())
	_charge = 0.0
	var zone := _stroke_zone(_evaluate(_idx, j))
	var arc := _cum[j] - _cum[_idx]
	var ends_run := _corners.has(j) or j >= _path.size() - 1
	var score: float = ZONE_SCORE[zone]
	# A snip that stops short mid-edge leaves a step in it; one that finishes the edge
	# into a corner doesn't — the corner was always going to cut the stroke short.
	if arc < _short and not ends_run:
		score = minf(score, CHOPPY_SCORE)
		_choppy += 1
		_jags.append(_path[j])
	_record(zone, arc, score)
	_strokes += 1
	_anim_from = _path[_idx]
	_anim_to = _path[j]
	_anim_idx = j
	_anim_zone = zone
	_anim_spread = _open_spread()
	_anim_t = STROKE_TIME
	_play(_snip, lerpf(0.3, 0.85, clampf(arc / _max_stroke, 0.0, 1.0)))
	if zone == Zone.NICK:
		_register_mistake(_anim_from.lerp(_anim_to, 0.5))


func _tick_stroke(delta: float) -> void:
	_anim_t = maxf(0.0, _anim_t - delta)
	if _anim_t > 0.0:
		return
	_idx = _anim_idx
	_trail.append(_path[_idx])
	_trail_zone.append(_anim_zone)
	if _idx >= _path.size() - 1 and _state == State.RUNNING:
		_succeed("  ·  %d strokes, %d choppy" % [_strokes, _choppy])


func _shears_pos() -> Vector2:
	if _anim_t > 0.0:
		var t := 1.0 - _anim_t / STROKE_TIME
		return _anim_from.lerp(_anim_to, t)
	return _path[_idx]


## Point the blades down the stroke you're lining up, and keep the camera just ahead.
func _aim(delta: float) -> void:
	var at := _shears_pos()
	var ahead := _path[_ghost_idx] if _anim_t <= 0.0 else _anim_to
	if ahead.distance_to(at) > 0.001:
		_draw_angle = lerp_angle(_draw_angle, (ahead - at).angle(), 1.0 - exp(-14.0 * delta))
	var target := at.lerp(ahead, 0.4)
	_cam = _cam.lerp(target, 1.0 - exp(-6.0 * delta))


func _open_spread() -> float:
	return deg_to_rad(lerpf(OPEN_DEG * 0.4, OPEN_DEG * 1.7, _charge))


func _update_status() -> void:
	if _state > State.RUNNING:
		return
	if _state == State.READY:
		_set_status("Hold Cut to open the blades — let go to cut", Style.AMBER)
		return
	var pct := int(_cum[_idx] / _total * 100.0)
	if not _charging:
		var tip := "Strokes %d   ·   %d%% cut" % [_strokes, pct]
		if OS.is_debug_build():
			tip += "   ·   F2 skip"
		_set_status(tip, Style.INK_SOFT)
		return
	var arc := _cum[_ghost_idx] - _cum[_idx]
	var ends_run := _corners.has(_ghost_idx) or _ghost_idx >= _path.size() - 1
	var word := _ghost_word()
	if arc < _short and not ends_run and _ghost_zone == Zone.PERFECT:
		word = "short — choppy edge"
	_set_status("%d cm stroke — %s" % [roundi(arc * CM_PER_UNIT), word], _ghost_color())


func _ghost_word() -> String:
	match _ghost_zone:
		Zone.PERFECT:
			return "clean"
		Zone.GOOD:
			return "a touch off the chalk"
		Zone.ROUGH:
			return "too wide — wasting cloth"
	return "into the piece!"


func _ghost_color() -> Color:
	return Style.FOREST if _ghost_zone == Zone.PERFECT else _zone_status_color(_ghost_zone)


# --- Painting --------------------------------------------------------------


## The ghost of the stroke you're holding, and the chewed steps short snips left.
func _paint_world_extra(c: Control) -> void:
	for j in _jags:
		var at := _w(j)
		c.draw_line(at + Vector2(-4, 3), at + Vector2(0, -3), Style.WALNUT, 2.0)
		c.draw_line(at + Vector2(0, -3), at + Vector2(4, 3), Style.WALNUT, 2.0)
	if _anim_t > 0.0 or _state > State.RUNNING:
		return
	var from := _w(_path[_idx])
	var to := _w(_path[_ghost_idx])
	var col := _zone_color(_ghost_zone)
	if not _charging:
		col = Style.tint(col, 0.35)
	_dashed(c, from, to, col, 3.0 if _charging else 1.5)
	c.draw_circle(to, 5.0, col, false, 2.0, true)


func _paint_overlay(c: Control) -> void:
	var spread := _open_spread()
	if _anim_t > 0.0:
		var t := 1.0 - _anim_t / STROKE_TIME
		spread = lerpf(_anim_spread, deg_to_rad(SHUT_DEG), t)
	var grip := Style.FOREST if _state != State.RUNNING else _zone_color(_ghost_zone)
	if grip == Style.CHALK:
		grip = Style.FOREST
	_paint_scissors(c, _to_screen(_shears_pos()), _draw_angle, spread, grip)

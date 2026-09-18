class_name SewPedalMinigame
extends CutBench

## Sewing v2 — "Pedal & Aim". A real machine: the needle stays put and the cloth feeds
## past it, the view turned so the stitching always runs up the screen.
##   * Pedal (Space / F, or the right trigger, analog): the motor spins up while held and
##     coasts down when you let go.
##   * Aim (A / D): turn the cloth. A bright dotted stitch guide runs ahead of the needle
##     showing exactly where the next stitches will land — visible even standing still,
##     so you can line up before you press the pedal. Standing still, the cloth turns
##     quickly about the needle; sewing, it turns gently.
##   * Corners are just aiming: ease off (amber chalk marks the run-in), stop on the
##     corner, turn the cloth to the new edge, carry on. Sew straight past and the
##     stitches leave the line.
##   * Pins (E): a pin glows with an E tag once it's in reach — pull it before the needle
##     gets there, or the needle bends (a slip).
##   * Backstitch (hold S with the pedal): at the start, and at the end — the machine
##     stops on the end mark and waits for you to lock the seam, then E cuts the thread.
##
## Upgrades turn its dials (Upgrades "sew_*" effects): spin-up, coast, drift, turn speed,
## an aim assist on curves, a speed dial near corners and pins, clips instead of pins,
## an auto-lock. Shares the outline, zones, cloth and scoring with the cutting games via
## CutBench. Emits finished(success, quality).

const TITLE_SEW := "Sewing Machine"
const ZOOM := 2.0
const LOOK_AHEAD := 0.24
const STEER_RAMP := 3.5  # a tap on A / D is a nudge; holding it leans in gradually
const STILL := 0.06  # motor below this counts as stopped
const MAX_OFF_ANGLE := deg_to_rad(110.0)
const MAX_WANDER := 0.1
const ALLOWANCE := 0.0375  # 1.5 cm between the seam line and the cloth's raw edge
const WARN := 0.15  # amber chalk runs this far back from each corner
const PIN_EVERY := 0.7
const PIN_CLEAR := 0.16  # no pins this close to a corner or either end
const PULL_RANGE := 0.26  # a pin glows (and can be pulled) once it's this close
const LOCK_ZONE := 0.12  # backstitching counts within this of either end
const LOCK_LEN := 0.02  # sew this far in reverse to lock the seam
const LOCK_BONUS := 0.02
const DIAL_SLOW := 0.4
const GUIDE_PULL := 0.6
const TOP_GEAR := 1.5  # Oiled Machine + Shift
const STITCH_LEN := 0.014
const AIM_LEN := 0.34  # how far ahead the stitch guide reaches
const PULL_FLY := 0.4  # seconds a pulled pin takes to fly off
const MACHINE_LOOP := "sew_machine_loop"
const BED_ART := "res://assets/textures/ui/machine_bed.png"
## How much each cloth pulls the aim aside (deg/s), before any upgrade.
const DRIFT := {
	Enums.Fabric.WORSTED_WOOL: 4.0,
	Enums.Fabric.FLANNEL: 2.0,
	Enums.Fabric.TWEED: 2.0,
	Enums.Fabric.MOHAIR_BLEND: 9.0,
	Enums.Fabric.LINEN: 12.0,
	Enums.Fabric.COTTON: 5.0,
	Enums.Fabric.POPLIN: 6.0,
	Enums.Fabric.OXFORD_CLOTH: 4.0,
}
## One seam per garment, sewn as an open line: [corner, control, corner, ...] as SHAPES.
## Each runs so the raw edge is on the right of the needle, the way cloth sits on a real
## machine (edge along the guide on the right, garment off to the left) — so the machine
## is always drawn in the same place.
const SEAMS := {
	Enums.GarmentType.SHIRT:
	[
		Vector2(0.62, 0.8),
		Vector2(0.7, -0.12),
		Vector3(0.46, -0.4, 0.0),
		Vector2(0.64, -0.7),
		Vector2(0.34, -0.82),
	],
	Enums.GarmentType.PANTS:
	[
		Vector2(0.33, -0.22),
		Vector2(0.3, -0.86),
		Vector2(-0.46, -0.86),
		Vector3(-0.66, -0.25, 0.0),
		Vector2(-0.36, 0.9),
	],
	Enums.GarmentType.JACKET:
	[
		Vector2(-0.7, -0.24),
		Vector2(-0.7, 0.58),
		Vector3(-0.72, 0.9, 0.0),
		Vector2(-0.44, 0.9),
		Vector2(0.6, 0.86),
		Vector3(0.5, 0.38, 0.0),
		Vector2(0.62, -0.1),
	],
}
const STATUS := {
	CutBench.Zone.PERFECT: "On the seam line",
	CutBench.Zone.GOOD: "Near the line",
	CutBench.Zone.ROUGH: "Off the line — aim back with A / D",
	CutBench.Zone.NICK: "Too deep — aim back with A / D",
}

var _top := 0.36
var _spin := 1.0
var _coast := 0.35
var _turn_still := deg_to_rad(80.0)  # turning the cloth about a stopped needle
var _turn_sewing := deg_to_rad(50.0)  # guiding it while the machine runs
var _tight := PackedByteArray()  # per point: a curve too tight to follow at full speed
var _garment := 0
var _piece_poly := PackedVector2Array()
var _bed_tex: Texture2D

var _p := Vector2.ZERO
var _heading := 0.0
var _seg := 0
var _steer := 0.0
var _pedal := 0.0
var _motor := 0.0
var _reversing := false
var _at_end := false
var _zone: int = CutBench.Zone.PERFECT
var _view_angle := 0.0
var _time := 0.0
var _stitch_phase := 0.0
var _noise := FastNoiseLite.new()
var _pins: Array = []  # [{s, state: 0 in / 1 pulled / 2 bent the needle, t: pulled at}]
var _locked := {"start": false, "end": false}
var _rev_run := 0.0
var _locks_drawn: Array = []  # needle positions where a backstitch was laid


func _screen_title() -> String:
	return TITLE_SEW


func _fold_allowed() -> bool:
	return false


func _open_outline() -> bool:
	return true


func _outline_spec(garment_type: int) -> Array:
	_garment = garment_type
	return SEAMS.get(garment_type, SEAMS[Enums.GarmentType.SHIRT])


func _jitter() -> float:
	return 0.0  # the seam follows the cut piece's edge exactly


func _interior() -> Vector2:
	return Vector2(0.0, 0.02)


func _forgives_rough() -> bool:
	return false


func _shows_wheel() -> bool:
	return false


func _sprint_owned() -> bool:
	return Upgrades.sewing_sprint()


func _load_assets() -> void:
	super()
	_bed_tex = _load_art(BED_ART)


## The contract the sewing station uses for every sewing game.
func start_piece(garment_type: int, title: String, material: MaterialType) -> void:
	start(garment_type, title, material)


func _begin() -> void:
	var c := Config.data
	if c != null:
		_top = c.sew2_top_speed
		_spin = c.sew2_spin_seconds
		_coast = c.sew2_coast_seconds
		_turn_still = deg_to_rad(c.sew2_turn_still_deg)
		_turn_sewing = deg_to_rad(c.sew2_turn_sewing_deg)
	_zoom = ZOOM
	_seg = 0
	_p = _path[0]
	_heading = _seg_dir(0).angle()
	_view_angle = _heading
	_steer = 0.0
	_motor = 0.0
	_reversing = false
	_at_end = false
	_zone = Zone.PERFECT
	_time = 0.0
	_rev_run = 0.0
	_locks_drawn = []
	var auto := Upgrades.has("sew_autolock")
	_locked = {"start": auto, "end": auto}
	_noise.seed = randi()
	_noise.frequency = 0.02
	_trail.append(_p)
	_trail_zone.append(Zone.PERFECT)
	_build_piece()
	_find_tight_curves()
	_place_pins()
	_follow(1.0)


func _hint_pairs() -> Array:
	var pairs := [["Space / F", "Pedal"], ["A / D", "Aim"], ["E", "Pull pin · Cut thread"]]
	if not Upgrades.has("sew_autolock"):
		pairs.append(["S + pedal", "Backstitch"])
	return pairs


# --- Setup -----------------------------------------------------------------


## The cut piece this seam belongs to: the whole garment outline, grown by the seam
## allowance, so the raw edge sits 1.5 cm outside the seam line.
func _build_piece() -> void:
	var spec: Array = SHAPES.get(_garment, SHAPES[Enums.GarmentType.SHIRT])
	var starts: Array[int] = []
	var outline := _trace(spec, true, starts)
	outline.remove_at(outline.size() - 1)
	var grown := Geometry2D.offset_polygon(outline, ALLOWANCE, Geometry2D.JOIN_ROUND)
	_piece_poly = grown[0] if not grown.is_empty() else outline


## Mark the curves that bend faster than your hands can turn the cloth at full speed —
## those get amber chalk too, like the corners.
func _find_tight_curves() -> void:
	var can_turn := _turn_sewing * Upgrades.mult("sew_turn") * 0.85
	var full := _top * Upgrades.sewing_speed()
	_tight = PackedByteArray()
	_tight.resize(_path.size())
	for i in range(1, _path.size() - 1):
		if not _corners.has(i) and _bend[i] * full > can_turn:
			_tight[i] = 1


## Pins across the seam every so often — clear of the corners and the two ends.
func _place_pins() -> void:
	_pins = []
	var s := 0.35
	while s < _total - PIN_CLEAR:
		if not _near_a_corner(s):
			_pins.append({"s": s, "state": 0, "t": 0.0})
		s += PIN_EVERY + randf_range(-0.08, 0.08)


func _near_a_corner(s: float) -> bool:
	for k in _corners:
		if absf(_cum[k] - s) < PIN_CLEAR:
			return true
	return false


# --- Frame -----------------------------------------------------------------


func _process(delta: float) -> void:
	if _state > State.RUNNING:
		return
	_update_armed()
	_time += delta
	_steer = move_toward(_steer, Input.get_axis("move_left", "move_right"), STEER_RAMP * delta)
	_pedal = _read_pedal()
	_reversing = Input.is_action_pressed("move_back")
	if _pedal > 0.0 and _state == State.READY:
		_state = State.RUNNING
	_drive_motor(delta)
	_aim(delta)
	if _motor > 0.001:
		_feed(delta)
	if _armed and Input.is_action_just_pressed("interact"):
		_action()
	if _state > State.RUNNING:
		return
	_follow(1.0 - exp(-8.0 * delta))
	_machine_sound()
	_update_status()
	_repaint()


## The pedal: any of the press buttons (full), or the right trigger (analog).
func _read_pedal() -> float:
	if not _armed:
		return 0.0
	var p := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	for action in ["jump", "cut", "ui_accept"]:
		if Input.is_action_pressed(action):
			p = 1.0
	return clampf(p, 0.0, 1.0)


## The motor chases the pedal: slow to spin up, and it coasts when you let go — unless
## the upgrades make it snappier. At the end mark it won't sew on, only back.
func _drive_motor(delta: float) -> void:
	var target := _pedal * _dial_cap()
	if _at_end and not _reversing:
		target = 0.0
	var up := Upgrades.mult("sew_spin") / maxf(_spin, 0.01)
	var down := Upgrades.mult("sew_coast") / maxf(_coast, 0.01)
	_motor = move_toward(_motor, target, (up if target > _motor else down) * delta)


## Speed Dial: the machine eases itself down near a corner or a pin.
func _dial_cap() -> float:
	if Upgrades.has("sew_dial") and (_corner_ahead() or not _pin_in_reach().is_empty()):
		return DIAL_SLOW
	return 1.0


## Turn the cloth: quickly about a stopped needle, gently while sewing. The cloth pulls
## a little on its own; the Roller Foot nudges the aim along curves.
func _aim(delta: float) -> void:
	var still := _motor < STILL
	var rate := (_turn_still if still else _turn_sewing) * Upgrades.mult("sew_turn")
	_heading += _steer * rate * delta
	if not still:
		var drift: float = DRIFT.get(_fabric, 4.0) * Upgrades.mult("sew_drift")
		if _focused:
			drift *= 0.5
		_heading += deg_to_rad(drift) * _noise.get_noise_1d(_time * 60.0) * delta
		var assist := Upgrades.bonus("sew_assist")
		if assist > 0.0:
			var along := _seg_dir(_seg).angle()
			_heading = lerp_angle(_heading, along, minf(1.0, assist * 3.0 * delta))
	var tangent := _seg_dir(_seg).angle()
	var off := clampf(angle_difference(tangent, _heading), -MAX_OFF_ANGLE, MAX_OFF_ANGLE)
	_heading = tangent + off


func _speed() -> float:
	var v := _motor * _top * Upgrades.sewing_speed()
	if Upgrades.sewing_sprint() and Input.is_action_pressed("sprint"):
		v *= TOP_GEAR
	return v


func _speed_ratio() -> float:
	return _speed() / maxf(_top, 0.001)


# --- Feeding the cloth -----------------------------------------------------


func _feed(delta: float) -> void:
	var step := _speed() * delta * (0.5 if _reversing else 1.0)
	if _reversing and _arc() <= -0.02:
		return  # backed off the start of the seam: nothing left to sew over
	var dir := Vector2.from_angle(_heading) * (-1.0 if _reversing else 1.0)
	_p += dir * step
	_track()
	var d := _offset(_seg, _p)
	if absf(d) > MAX_WANDER:
		_p -= _seg_normal(_seg) * (d - clampf(d, -MAX_WANDER, MAX_WANDER))
		d = clampf(d, -MAX_WANDER, MAX_WANDER)
	if Upgrades.has("sew_guide"):
		_p -= _seg_normal(_seg) * d * minf(1.0, GUIDE_PULL * delta)
	_stitch_phase += step / STITCH_LEN
	_lay_trail()
	if _reversing:
		_backstitch(step)
		return
	_zone = _zone_of(d)
	_record(_zone, step, ZONE_SCORE[_zone])
	_check_pins()
	if _arc() >= _total - 0.002:
		_reach_end()


## Which bit of the seam the needle is over: the nearest segment a little behind or
## ahead of the last one, so a corner turned (or sewn past) is followed naturally.
func _track() -> void:
	var last := _path.size() - 2
	var best := _seg
	var best_d := INF
	for i in range(maxi(0, _seg - 4), mini(last, _seg + 30) + 1):
		var q := Geometry2D.get_closest_point_to_segment(_p, _path[i], _path[i + 1])
		var dist := q.distance_to(_p)
		if dist < best_d - 0.0005:
			best_d = dist
			best = i
	_seg = best


## How far along the seam the needle is.
func _arc() -> float:
	return _cum[_seg] + clampf((_p - _path[_seg]).dot(_seg_dir(_seg)), 0.0, _seg_len(_seg))


func _seg_len(i: int) -> float:
	return _cum[i + 1] - _cum[i]


func _lay_trail() -> void:
	var n := _trail.size()
	if n < 2 or _trail[n - 2].distance_to(_p) >= STITCH_LEN * 0.5:
		_trail.append(_p)
		_trail_zone.append(_zone)
	else:
		_trail[n - 1] = _p


## The needle reaching a pin still in: a bent needle — unless it's a clip.
func _check_pins() -> void:
	var s := _arc()
	for pin: Dictionary in _pins:
		if pin["state"] != 0 or s < pin["s"]:
			continue
		if Upgrades.has("sew_clips"):
			pin["state"] = 1
			pin["t"] = _time
			Sfx.play("sew_tap")
			continue
		pin["state"] = 2
		_motor = 0.0
		_register_mistake(_point_at_arc(pin["s"]))


## Sewing in reverse near either end locks the seam there.
func _backstitch(step: float) -> void:
	var s := _arc()
	var key := ""
	if s < LOCK_ZONE:
		key = "start"
	elif s > _total - LOCK_ZONE:
		key = "end"
	if key == "" or _locked[key]:
		return
	_rev_run += step
	if _rev_run >= LOCK_LEN:
		_locked[key] = true
		_rev_run = 0.0
		_locks_drawn.append(_p)
		Sfx.play("sew_stitch_perfect")


## The end mark: the machine stops and waits for you to lock the seam and cut the thread.
func _reach_end() -> void:
	if not _at_end:
		_at_end = true
		_motor = 0.0
		Sfx.play("sew_tap")


# --- The E button ----------------------------------------------------------


func _action() -> void:
	var pin := _pin_in_reach()
	if not pin.is_empty():
		pin["state"] = 1
		pin["t"] = _time
		Sfx.play("pin_out")
		return
	if _at_end:
		_finish()
		return
	Sfx.play("sew_tap")


## The nearest pin still in, within reach ahead of the needle ({} if none).
func _pin_in_reach() -> Dictionary:
	if Upgrades.has("sew_clips"):
		return {}
	var s := _arc()
	for pin: Dictionary in _pins:
		var ahead: float = pin["s"] - s
		if pin["state"] == 0 and ahead >= -0.005 and ahead <= PULL_RANGE:
			return pin
	return {}


## A corner inside its amber run-in ahead of the needle.
func _corner_ahead() -> bool:
	var s := _arc()
	for k in _corners:
		if _cum[k] > s - 0.01 and _cum[k] - s <= WARN:
			return true
	return false


## A tight curve under the needle or just ahead of it.
func _curve_ahead() -> bool:
	var s := _arc()
	for i in range(_seg, mini(_seg + 20, _tight.size())):
		if _tight[i] == 1 and _cum[i] - s <= WARN * 0.6:
			return true
	return false


func _follow(weight: float) -> void:
	_view_angle = lerp_angle(_view_angle, _heading, weight)
	_view_rot = -PI * 0.5 - _view_angle
	var target := _p + Vector2.from_angle(_view_angle) * LOOK_AHEAD
	_cam = _cam.lerp(target, weight)


func _point_at_arc(s: float) -> Vector2:
	for i in _path.size() - 1:
		if _cum[i + 1] >= s:
			var span := _cum[i + 1] - _cum[i]
			var t := 0.0 if span <= 0.0 else (s - _cum[i]) / span
			return _path[i].lerp(_path[i + 1], t)
	return _path[_path.size() - 1]


func _index_at_arc(s: float) -> int:
	for i in _path.size() - 1:
		if _cum[i + 1] >= s:
			return i
	return _path.size() - 1


# --- Finish ----------------------------------------------------------------


func _finish() -> void:
	var locks := int(_locked["start"]) + int(_locked["end"])
	_succeed("  ·  locked %d/2" % locks)


## The seam's own score, plus a little for each locked end.
func _quality() -> float:
	var q := super()
	q += LOCK_BONUS * (int(_locked["start"]) + int(_locked["end"]))
	return clampf(q, 0.15, 1.0)


func _stop_sounds() -> void:
	Sfx.stop_loop(MACHINE_LOOP)


func _machine_sound() -> void:
	if _motor < 0.02:
		Sfx.stop_loop(MACHINE_LOOP)
		return
	Sfx.start_loop(MACHINE_LOOP, -20.0)
	Sfx.set_loop_volume(MACHINE_LOOP, lerpf(-16.0, -2.0, _motor))
	var gear := _speed() / maxf(_motor * _top, 0.001)
	Sfx.set_loop_pitch(MACHINE_LOOP, lerpf(0.7, 1.1, _motor) * lerpf(1.0, gear, 0.5))


# --- Status ----------------------------------------------------------------


func _update_status() -> void:
	if _state > State.RUNNING:
		return
	if _state == State.READY:
		var tip := "Line up with A / D, then press the pedal"
		if not _locked["start"]:
			tip += " — S + pedal first to backstitch the start"
		_set_status(tip, Style.AMBER)
		return
	var pct := int(clampf(_arc() / _total, 0.0, 1.0) * 100.0)
	var msg := _situation()
	var col := Style.AMBER
	if msg == "":
		msg = STATUS[_zone] if _motor > STILL else "Needle down — aim, then pedal"
		col = _zone_status_color(_zone) if _motor > STILL else Style.INK_SOFT
	_set_status("%s   ·   %d%% sewn" % [msg, pct], col)


## Whatever needs doing right now, most urgent first ("" when it's just sewing).
func _situation() -> String:
	if _at_end:
		return _end_situation()
	if not _pin_in_reach().is_empty():
		return "Pin! Press E to pull it"
	if _reversing:
		return "Backstitching"
	return _ahead_situation()


## A tight curve or a corner coming up.
func _ahead_situation() -> String:
	if _curve_ahead() and _speed_ratio() > DIAL_SLOW + 0.2:
		return "Tight curve — ease off so you can turn with it"
	if not _corner_ahead():
		return ""
	if _motor > STILL:
		return "Corner — ease off and stop on it"
	return "Turn the cloth to the new edge with A / D"


func _end_situation() -> String:
	if _locked["end"]:
		return "Locked! Press E to cut the thread"
	return "End of the seam — S + pedal to backstitch, E to cut the thread"


# --- Painting --------------------------------------------------------------


## The machine bed under the cloth rather than a cutting mat.
func _paint_mat(c: Control) -> void:
	var rect := Rect2(
		Vector2(MAT_INSET, MAT_INSET), c.size - Vector2(MAT_INSET * 2.0, MAT_INSET * 2.0)
	)
	var bed := StyleBoxFlat.new()
	bed.bg_color = Style.PAPER_MIRROR.darkened(0.12)
	bed.set_corner_radius_all(14)
	bed.set_border_width_all(3)
	bed.border_color = Style.WALNUT
	c.draw_style_box(bed, rect)
	if _bed_tex != null:
		c.draw_texture_rect(_bed_tex, rect.grow(-3.0), true)


## The cut piece lying on the bed, pattern and all.
func _paint_cloth(c: Control) -> void:
	var poly := PackedVector2Array()
	for p in _piece_poly:
		poly.append(_w(p))
	Craft.card(c, poly, _cloth, _cloth.darkened(0.3), 2.0)
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	_paint_pattern(c, box, poly)


## The seam line chalked faint and fine, amber chalk into each corner, and a bold end
## mark where the machine will stop for the backstitch.
func _paint_chalk(c: Control) -> void:
	var px := _px()
	var col := Style.tint(_chalk, 0.4)
	for i in _path.size() - 1:
		if int(_cum[i] * px / 8.0) % 2 == 0:
			c.draw_line(_w(_path[i]), _w(_path[i + 1]), col, 1.5)
	for k in _corners:
		_paint_amber(c, maxf(_cum[k] - WARN, 0.0), _cum[k], px)
	_paint_tight(c, px)
	var end := _path[_path.size() - 1]
	var across := _normals[_normals.size() - 1] * 0.03
	c.draw_line(_w(end - across), _w(end + across), Style.tint(_chalk, 0.9), 4.0)


## Amber along each tight curve, starting a little before it.
func _paint_tight(c: Control, px: float) -> void:
	var lead := int(WARN * 0.6 / STEP)
	var col := Style.tint(Style.AMBER, 0.85)
	for i in range(1, _path.size() - 1):
		var near := false
		for k in range(i, mini(i + lead, _tight.size())):
			if _tight[k] == 1:
				near = true
				break
		if near and int(_cum[i] * px / 6.0) % 2 == 0:
			var n := _normals[i] * 0.012
			c.draw_line(_w(_path[i] + n), _w(_path[i + 1] + n), col, 4.0)


func _paint_amber(c: Control, from: float, to: float, px: float) -> void:
	var col := Style.tint(Style.AMBER, 0.85)
	for i in range(_index_at_arc(from), mini(_index_at_arc(to) + 1, _path.size() - 1)):
		if int(_cum[i] * px / 6.0) % 2 == 0:
			var n := _normals[i] * 0.012
			c.draw_line(_w(_path[i] + n), _w(_path[i + 1] + n), col, 4.0)


## No shaded band here — the seam guide on the plate does that job.
func _paint_allowance(_c: Control) -> void:
	pass


## The stitches: short dashes of thread along where the needle has been, with a knot of
## zig-zag where each backstitch locked the seam.
func _paint_trail(c: Control) -> void:
	var thread := _thread_color()
	if _trail.size() >= 2:
		var pts := _resample(_trail, STITCH_LEN)
		for k in pts.size() - 1:
			c.draw_line(_w(pts[k]), _w(pts[k].lerp(pts[k + 1], 0.62)), thread, 3.0)
	for at in _locks_drawn:
		var o := _w(at)
		for k in 3:
			var y := float(k) * 4.0 - 4.0
			c.draw_line(o + Vector2(-6, y), o + Vector2(6, y + 2.0), thread, 2.0)


## Points every `step` along a polyline — one per stitch.
func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	var carry := 0.0
	for i in range(1, line.size()):
		var a := line[i - 1]
		var seg := a.distance_to(line[i])
		var t := step - carry
		while t <= seg:
			out.append(a.lerp(line[i], t / seg))
			t += step
		carry = seg - (t - step)
	return out


func _thread_color() -> Color:
	return _cloth.lightened(0.7) if _cloth.get_luminance() < 0.5 else _cloth.darkened(0.55)


## The stitch guide ahead of the needle, and the pins (a pulled one flying off).
func _paint_world_extra(c: Control) -> void:
	var dir := Vector2.from_angle(_heading)
	if not _at_end:
		# Brass, not chalk: this is where you're aiming, not where you should be.
		var tip := _w(_p + dir * AIM_LEN)
		_dashed(c, _w(_p + dir * 0.02), tip, Style.tint(Style.BRASS, 0.95), 3.5)
		c.draw_circle(tip, 4.5, Style.BRASS)
	for pin: Dictionary in _pins:
		_paint_pin(c, pin)


func _paint_pin(c: Control, pin: Dictionary) -> void:
	var s: float = pin["s"]
	var out := _normals[mini(_index_at_arc(s), _normals.size() - 1)]
	var at := _point_at_arc(s) - out * 0.015
	var alpha := 1.0
	if pin["state"] == 1:
		var t := (_time - float(pin["t"])) / PULL_FLY
		if t >= 1.0:
			return
		at += out * 0.12 * t  # drawn out towards the raw edge and away
		alpha = 1.0 - t
	var col := Style.BURGUNDY if pin["state"] != 2 else Style.CLAY
	if Upgrades.has("sew_clips"):
		_paint_clip(c, _w(at + out * 0.045), out.angle(), Style.tint(col, alpha))
	else:
		Craft.dress_pin(c, _w(at), (-out).angle(), Style.tint(col, alpha), 0.08 * _px())


func _paint_clip(c: Control, at: Vector2, angle: float, col: Color) -> void:
	var d := Vector2.from_angle(angle) * 9.0
	var n := d.orthogonal() * 0.6
	c.draw_colored_polygon(
		PackedVector2Array([at - d - n, at + d - n, at + d + n, at - d + n]), col
	)


## The machine, drawn upright over the moving cloth: the needle plate with its seam
## guide, the presser foot, the needle bobbing, the arm with its speed dial — and the
## E tag on a pin that's in reach.
func _paint_overlay(c: Control) -> void:
	var at := _to_screen(_p)
	_paint_plate(c, at, 1.0)  # the raw edge always rides the guide on the right
	_paint_foot(c, at)
	_paint_machine(c, at)
	var pin := _pin_in_reach()
	if not pin.is_empty():
		_paint_pull_tag(c, _to_screen(_point_at_arc(pin["s"])))


func _paint_pull_tag(c: Control, at: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 10.0)
	c.draw_circle(at, 16.0 + pulse * 3.0, Style.tint(Style.BRASS, 0.9), false, 3.0, true)
	var chip := Rect2(at + Vector2(14, -30), Vector2(26, 26))
	var box := StyleBoxFlat.new()
	box.bg_color = Style.WALNUT
	box.set_corner_radius_all(6)
	c.draw_style_box(box, chip)
	var font := Style.bold_font()
	c.draw_string(
		font, chip.position + Vector2(7, 19), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Style.CREAM
	)


func _paint_plate(c: Control, at: Vector2, side: float) -> void:
	var rect := Rect2(at - Vector2(70, 46), Vector2(140, 92))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Style.tint(Style.STEEL, 0.55)
	plate.set_corner_radius_all(10)
	plate.set_border_width_all(1)
	plate.border_color = Style.tint(Style.STEEL_DARK, 0.7)
	c.draw_style_box(plate, rect)
	var px := _px()
	# Seam guide: 1, 1.5 and 2 cm lines on the outside — the raw edge rides the 1.5.
	for cm: float in [1.0, 1.5, 2.0]:
		var x := at.x + side * (cm / 40.0) * px
		var col := Style.tint(Style.STEEL_DARK, 0.9 if cm == 1.5 else 0.45)
		c.draw_line(Vector2(x, rect.position.y + 4), Vector2(x, rect.end.y - 4), col, 1.5)
	for dx in [-9.0, 9.0]:
		c.draw_rect(Rect2(at + Vector2(dx - 2.5, -14), Vector2(5, 28)), Style.STEEL_DARK)


func _paint_foot(c: Control, at: Vector2) -> void:
	for dx in [-7.0, 7.0]:
		var toe := PackedVector2Array(
			[
				at + Vector2(dx - 4, -20),
				at + Vector2(dx + 4, -20),
				at + Vector2(dx + 3, 14),
				at + Vector2(dx - 3, 14),
			]
		)
		c.draw_colored_polygon(toe, Style.STEEL)
		Craft.outline(c, toe, Style.STEEL_DARK, 1.0)
	var bob := sin(_stitch_phase * TAU) * 4.0 if _motor > 0.02 else 0.0
	c.draw_line(at + Vector2(0, -34), at + Vector2(0, bob), Style.STEEL_DARK, 2.0)
	c.draw_circle(at + Vector2(0, bob), 1.6, Style.WALNUT)


## A classic machine seen from above, standing still while the cloth moves under it:
## the head just right of the needle (never over the seam ahead), the arm running off to
## the right, the pillar with the thread spool and the speed dial, and the handwheel at
## the far end. Black enamel with gold lining, like the old ones.
func _paint_machine(c: Control, needle: Vector2) -> void:
	var right := c.size.x - MAT_INSET
	var head := Rect2(needle + Vector2(14, -38), Vector2(62, 70))
	var pillar := Rect2(Vector2(right - 118.0, needle.y - 50.0), Vector2(84, 96))
	var arm := Rect2(
		Vector2(head.end.x - 6.0, needle.y - 26.0),
		Vector2(pillar.position.x - head.end.x + 12.0, 44)
	)
	var enamel := Style.INK.darkened(0.55)
	_machine_box(c, arm, enamel, 14)
	_machine_box(c, head, enamel, 18)
	_machine_box(c, pillar, enamel, 16)
	# Gold lining along the arm, and the face plate on the head.
	var gold := Style.tint(Style.BRASS, 0.85)
	c.draw_line(
		arm.position + Vector2(10, 7), Vector2(arm.end.x - 10, arm.position.y + 7), gold, 1.5
	)
	c.draw_line(Vector2(arm.position.x + 10, arm.end.y - 7), arm.end - Vector2(10, 7), gold, 1.5)
	var face := Rect2(head.position + Vector2(8, 8), Vector2(20, head.size.y - 16))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Style.STEEL
	plate.set_corner_radius_all(6)
	c.draw_style_box(plate, face)
	# Tension dial on the head, spool on the pillar, handwheel off the end.
	c.draw_circle(head.position + Vector2(44, 52), 7.0, Style.STEEL)
	c.draw_circle(head.position + Vector2(44, 52), 7.0, Style.STEEL_DARK, false, 1.5, true)
	var spool := Vector2(pillar.position.x + 26.0, pillar.position.y + 24.0)
	c.draw_circle(spool, 12.0, _thread_color())
	c.draw_circle(spool, 12.0, Style.WALNUT, false, 1.5, true)
	c.draw_circle(spool, 3.0, Style.WALNUT)
	_paint_handwheel(c, Vector2(right - 20.0, needle.y - 2.0))
	_paint_dial(c, Vector2(pillar.position.x + 48.0, pillar.end.y - 26.0))


func _machine_box(c: Control, rect: Rect2, col: Color, radius: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = col
	box.set_corner_radius_all(radius)
	box.border_color = Style.tint(Style.BRASS, 0.5)
	box.set_border_width_all(1)
	box.shadow_color = Style.SHADOW
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 4)
	c.draw_style_box(box, rect)


## The handwheel turns with the motor.
func _paint_handwheel(c: Control, at: Vector2) -> void:
	c.draw_circle(at, 26.0, Style.STEEL_DARK)
	c.draw_circle(at, 26.0, Style.STEEL, false, 3.0, true)
	for k in 3:
		var spoke := Vector2.from_angle(_stitch_phase * 0.6 + k * TAU / 3.0) * 20.0
		c.draw_line(at, at + spoke, Style.STEEL, 3.0)
	c.draw_circle(at, 5.0, Style.BRASS)


## The speed dial: a needle sweeping a half-circle; the slow stretch is green, and the
## rest turns red while a corner is coming.
func _paint_dial(c: Control, at: Vector2) -> void:
	var r := 20.0
	c.draw_circle(at, r + 3.0, Style.CREAM)
	c.draw_arc(at, r - 3.0, PI, PI + PI * DIAL_SLOW, 12, Style.FOREST, 5.0)
	var warn := _corner_ahead() or _curve_ahead()
	var rest := Style.CLAY if warn else Style.tint(Style.WALNUT, 0.3)
	c.draw_arc(at, r - 3.0, PI + PI * DIAL_SLOW, TAU, 16, rest, 5.0)
	var hot := warn and _speed_ratio() > DIAL_SLOW
	var needle := Vector2.from_angle(PI + PI * clampf(_speed_ratio(), 0.0, 1.0)) * (r - 2.0)
	c.draw_line(at, at + needle, Style.CLAY if hot else Style.WALNUT, 2.5)
	c.draw_circle(at, 3.0, Style.BRASS)


## At the end, lift the whole sewn piece off the bed with its seam showing.
func _paint_piece(c: Control) -> void:
	var lift := Vector2(0, -6.0) * smoothstep(0.0, 0.4, _reveal)
	var poly := PackedVector2Array()
	for p in _piece_poly:
		poly.append(_w(p) + lift)
	Craft.card(c, poly, _cloth.lightened(0.05), _cloth.darkened(0.4), 2.0)
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	_paint_pattern(c, box, poly)
	var seam := PackedVector2Array()
	for p in _trail:
		seam.append(_w(p) + lift)
	if seam.size() >= 2:
		c.draw_polyline(seam, _thread_color(), 2.0)

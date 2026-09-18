class_name SewPedalMinigame
extends CutBench

## Sewing v2 — "Pedal & Guide". A real machine: the needle stays put and the cloth feeds
## past it. The pedal (Space / F, or the right trigger — analog) spins the motor up and
## it runs down when you let go; your hands (A / D) guide the cloth so the stitches run
## down the seam line, the raw edge riding the guide lines on the plate.
##
## Corners are the pedal skill: ease off so the needle stops on the chalk corner, then
## pivot (E). Stop short or coast past and the corner comes out rounded or crooked.
## Pins lie across the seam — pull each (E) before the needle reaches it, or bend the
## needle. Hold S with the pedal near either end to backstitch and lock the seam.
##
## Every one of those is a dial an upgrade turns (Upgrades "sew_*" effects): spin-up,
## coast, drift, pivot time, a speed dial near corners and pins, needle-down snapping,
## clips instead of pins, an auto-lock. Shares the outline, zones, cloth and scoring
## with the cutting games via CutBench. Emits finished(success, quality).

const TITLE_SEW := "Sewing Machine"
const ZOOM := 2.0
const LOOK_AHEAD := 0.24
const STEER_RAMP := 6.0
const MAX_OFF_ANGLE := deg_to_rad(60.0)
const MAX_WANDER := 0.1
const ALLOWANCE := 0.0375  # 1.5 cm between the seam line and the cloth's raw edge
const CORNER_PERFECT := 0.015  # stop this close to the chalk corner for a crisp one
const CORNER_GOOD := 0.04
const CORNER_MAX := 0.07  # coast further past it and the machine jams to a halt
const CORNER_WEIGHT := 0.12  # how much a corner counts, as a length of seam
const PIN_EVERY := 0.5
const PIN_CLEAR := 0.14  # no pins this close to a corner or either end
const PULL_RANGE := 0.3  # a pin can be pulled once it's this close ahead
const LOCK_ZONE := 0.12  # backstitching counts within this of either end
const LOCK_LEN := 0.015  # sew this far in reverse to lock
const LOCK_BONUS := 0.02
const CLIP_COST := 0.02
const DIAL_RANGE := 0.14
const DIAL_SLOW := 0.45
const GUIDE_PULL := 1.2
const TOP_GEAR := 1.5  # Oiled Machine + Shift
const STITCH_LEN := 0.014
const MACHINE_LOOP := "sew_machine_loop"
const BED_ART := "res://assets/textures/ui/machine_bed.png"
## How much each cloth wanders under your hands (deg/s), before any upgrade.
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
		Vector2(-0.36, 0.9),
		Vector3(-0.66, -0.25, 0.0),
		Vector2(-0.46, -0.86),
		Vector2(0.3, -0.86),
		Vector2(0.33, -0.22),
	],
	Enums.GarmentType.JACKET:
	[
		Vector2(0.62, -0.1),
		Vector3(0.5, 0.38, 0.0),
		Vector2(0.6, 0.86),
		Vector2(-0.44, 0.9),
		Vector3(-0.72, 0.9, 0.0),
		Vector2(-0.7, 0.58),
		Vector2(-0.7, -0.24),
	],
}
const STATUS := {
	CutBench.Zone.PERFECT: "On the seam line",
	CutBench.Zone.GOOD: "Near the line",
	CutBench.Zone.ROUGH: "Too close to the edge",
	CutBench.Zone.NICK: "Too deep — it'll fit tight",
}

var _top := 0.3
var _spin := 1.0
var _coast := 0.35
var _pivot_time := 0.6
var _turn := deg_to_rad(120.0)
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
var _zone: int = CutBench.Zone.PERFECT
var _jammed := false  # coasted too far past a corner; waits for a pivot
var _pivot_t := 0.0
var _pivot_from := Vector2.ZERO
var _pivot_to := Vector2.ZERO
var _pivot_h0 := 0.0
var _pivot_h1 := 0.0
var _view_angle := 0.0
var _time := 0.0
var _stitch_phase := 0.0
var _noise := FastNoiseLite.new()
var _pins: Array = []  # [{s: float, state: 0 in / 1 pulled / 2 sewn over}]
var _corners_done := 0
var _corners_clean := 0
var _locked := {"start": false, "end": false}
var _rev_run := 0.0
var _clip_hits := 0
var _hint_text := ""


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
		_pivot_time = c.sew2_pivot_seconds
		_turn = deg_to_rad(c.sew2_turn_deg)
	_zoom = ZOOM
	_seg = 0
	_p = _path[0]
	_heading = _seg_dir(0).angle()
	_view_angle = _heading
	_steer = 0.0
	_motor = 0.0
	_zone = Zone.PERFECT
	_jammed = false
	_pivot_t = 0.0
	_time = 0.0
	_corners_done = 0
	_corners_clean = 0
	_rev_run = 0.0
	_clip_hits = 0
	var auto := Upgrades.has("sew_autolock")
	_locked = {"start": auto, "end": auto}
	_noise.seed = randi()
	_noise.frequency = 0.02
	_trail.append(_p)
	_trail_zone.append(Zone.PERFECT)
	_build_piece()
	_place_pins()
	_follow(1.0)


func _hint_pairs() -> Array:
	var pairs := [
		["Space / F", "Pedal"],
		["A / D", "Guide"],
		["E", "Pull pin · Pivot"],
	]
	if not Upgrades.has("sew_autolock"):
		pairs.append(["S", "Reverse (lock)"])
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


## Pins across the seam every so often — clear of the corners and the two ends.
func _place_pins() -> void:
	_pins = []
	var s := 0.25
	while s < _total - PIN_CLEAR:
		if not _near_a_corner(s):
			_pins.append({"s": s, "state": 0})
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
	if _pivot_t > 0.0:
		_tick_pivot(delta)
	else:
		_drive_motor(delta)
		_heading += _steer * _turn * delta
		if _motor > 0.001:
			_heading += _drift() * delta
			_feed(delta)
		_clamp_heading()
		if Input.is_action_just_pressed("interact"):
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
## the upgrades make it snappier. A jammed corner holds it stopped.
func _drive_motor(delta: float) -> void:
	var target := 0.0 if _jammed else _pedal * _dial_cap()
	var up := Upgrades.mult("sew_spin") / maxf(_spin, 0.01)
	var down := Upgrades.mult("sew_coast") / maxf(_coast, 0.01)
	_motor = move_toward(_motor, target, (up if target > _motor else down) * delta)


## Speed Dial: ease down to a crawl as a corner or a pin comes up.
func _dial_cap() -> float:
	if not Upgrades.has("sew_dial"):
		return 1.0
	var s := _arc()
	var corner := _next_corner()
	if corner < _path.size() - 1 and _cum[corner] - s < DIAL_RANGE:
		return DIAL_SLOW
	for pin: Dictionary in _pins:
		if pin["state"] == 0 and pin["s"] - s > -0.01 and pin["s"] - s < DIAL_RANGE:
			return DIAL_SLOW
	return 1.0


func _drift() -> float:
	var rate: float = DRIFT.get(_fabric, 4.0) * Upgrades.mult("sew_drift")
	if _focused:
		rate *= 0.5
	return deg_to_rad(rate) * _noise.get_noise_1d(_time * 60.0)


func _speed() -> float:
	var v := _motor * _top * Upgrades.sewing_speed()
	if Upgrades.sewing_sprint() and Input.is_action_pressed("sprint"):
		v *= TOP_GEAR
	return v


# --- Feeding the cloth -----------------------------------------------------


func _feed(delta: float) -> void:
	if _reversing and _arc() <= -0.03:
		return  # backed off the start of the seam: nothing left to sew over
	var step := _speed() * delta * (0.5 if _reversing else 1.0)
	var dir := Vector2.from_angle(_heading) * (-1.0 if _reversing else 1.0)
	_p += dir * step
	_walk()
	var d := _offset(_seg, _p)
	if absf(d) > MAX_WANDER:
		var held := clampf(d, -MAX_WANDER, MAX_WANDER)
		_p -= _seg_normal(_seg) * (d - held)
		d = held
	if Upgrades.has("sew_guide"):
		_p -= _seg_normal(_seg) * d * minf(1.0, GUIDE_PULL * delta)
	_stitch_phase += step / STITCH_LEN
	if _reversing:
		_backstitch(step)
		return
	_zone = _zone_of(d)
	_record(_zone, step, ZONE_SCORE[_zone])
	_lay_trail()
	_check_pins()
	_check_corner()
	_check_end()


## Follow the seam as the cloth moves: forward up to (never past) the next corner — the
## needle stays on this edge until you pivot — and back again when reversing.
func _walk() -> void:
	var corner := _next_corner()
	while _seg + 1 < corner and (_p - _path[_seg + 1]).dot(_seg_dir(_seg)) >= 0.0:
		_seg += 1
	while _seg > 0 and not _corners.has(_seg) and (_p - _path[_seg]).dot(_seg_dir(_seg)) < 0.0:
		_seg -= 1


## The first corner (or the seam's end) ahead of the needle's edge.
func _next_corner() -> int:
	var last := _path.size() - 1
	for k in range(_seg + 1, last):
		if _corners.has(k):
			return k
	return last


## How far along the seam the needle is.
func _arc() -> float:
	return _cum[_seg] + (_p - _path[_seg]).dot(_seg_dir(_seg))


## How far past (+) or short of (−) the next corner the needle sits.
func _past_corner() -> float:
	var corner := _next_corner()
	return (_p - _path[corner]).dot(_seg_dir(corner - 1))


func _lay_trail() -> void:
	var n := _trail.size()
	if n < 2 or _trail[n - 2].distance_to(_p) >= STITCH_LEN * 0.5:
		_trail.append(_p)
		_trail_zone.append(_zone)
	else:
		_trail[n - 1] = _p


func _check_pins() -> void:
	var s := _arc()
	for pin: Dictionary in _pins:
		if pin["state"] != 0 or s < pin["s"]:
			continue
		pin["state"] = 2
		if Upgrades.has("sew_clips"):
			_clip_hits += 1  # a clip rides over; the seam wears a little of it
			Sfx.play("sew_tap")
		else:
			_motor = 0.0
			_register_mistake(_point_at_arc(pin["s"]))  # bent needle


## Coast too far past a corner and the machine jams: the seam has run off its line.
func _check_corner() -> void:
	if _next_corner() >= _path.size() - 1:
		return
	if _past_corner() > CORNER_MAX and not _jammed:
		_jammed = true
		_motor = 0.0
		Sfx.play("sew_tap")


func _check_end() -> void:
	var last := _path.size() - 1
	if _next_corner() == last and (_p - _path[last]).dot(_seg_dir(last - 1)) >= 0.0:
		if _state == State.RUNNING:
			_finish()


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
		Sfx.play("sew_stitch_perfect")


# --- The E button ----------------------------------------------------------


## Pull the next pin if one is in reach; otherwise pivot if you're stopped on a corner.
func _action() -> void:
	var pin := _pin_in_reach()
	if not pin.is_empty():
		pin["state"] = 1
		Sfx.play("pin_out")
		return
	if _next_corner() >= _path.size() - 1:
		Sfx.play("sew_tap")
		return
	if _motor > 0.08:
		_hint_text = "Stop the machine first"
		Sfx.play("error")
		return
	var past := _past_corner()
	if not _jammed and past < -_corner_window(CORNER_GOOD):
		_hint_text = "Not at the corner yet"
		Sfx.play("sew_tap")
		return
	_pivot(past)


func _pin_in_reach() -> Dictionary:
	var s := _arc()
	for pin: Dictionary in _pins:
		var ahead: float = pin["s"] - s
		if pin["state"] == 0 and ahead >= -0.005 and ahead <= PULL_RANGE:
			return pin
	return {}


## Needle-Down Stop snaps onto a corner from twice as far.
func _corner_window(base: float) -> float:
	return base * (2.0 if Upgrades.has("sew_needle_down") else 1.0)


## Lift the foot, turn the cloth, drop the foot. The corner is scored on how close to
## the chalk mark the needle stopped.
func _pivot(past: float) -> void:
	var corner := _next_corner()
	var miss := absf(past)
	var zone := Zone.ROUGH
	if not _jammed and miss <= _corner_window(CORNER_PERFECT):
		zone = Zone.PERFECT
		_corners_clean += 1
	elif not _jammed and miss <= _corner_window(CORNER_GOOD):
		zone = Zone.GOOD
	_record(zone, CORNER_WEIGHT, ZONE_SCORE[zone])
	_corners_done += 1
	var d := _offset(_seg, _p)
	_seg = corner
	_pivot_from = _p
	_pivot_to = _path[corner] + _seg_normal(corner) * d
	_pivot_h0 = _heading
	_pivot_h1 = _seg_dir(corner).angle()
	_pivot_t = _pivot_time * Upgrades.mult("sew_pivot")
	_jammed = false
	_motor = 0.0
	Sfx.play("cloth_rustle")


func _tick_pivot(delta: float) -> void:
	var total := maxf(_pivot_time * Upgrades.mult("sew_pivot"), 0.01)
	_pivot_t = maxf(0.0, _pivot_t - delta)
	var t := smoothstep(0.0, 1.0, 1.0 - _pivot_t / total)
	_p = _pivot_from.lerp(_pivot_to, t)
	_heading = lerp_angle(_pivot_h0, _pivot_h1, t)
	if _pivot_t <= 0.0:
		_trail.append(_p)
		_trail_zone.append(_zone)


func _clamp_heading() -> void:
	var along := _seg_dir(_seg).angle()
	var off := clampf(angle_difference(along, _heading), -MAX_OFF_ANGLE, MAX_OFF_ANGLE)
	_heading = along + off


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


# --- Finish ----------------------------------------------------------------


func _finish() -> void:
	var locks := int(_locked["start"]) + int(_locked["end"])
	var extra := "  ·  corners %d/%d clean  ·  locked %d/2" % [_corners_clean, _corners_done, locks]
	_succeed(extra)


## The seam's own score, plus a little for each locked end, less a little per clip sewn
## over.
func _quality() -> float:
	var q := super()
	q += LOCK_BONUS * (int(_locked["start"]) + int(_locked["end"]))
	q -= CLIP_COST * _clip_hits
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
		_set_status("Press the pedal to start — guide the cloth along the chalk", Style.AMBER)
		return
	var pct := int(clampf(_arc() / _total, 0.0, 1.0) * 100.0)
	var msg := _situation()
	var col := Style.INK_SOFT
	if msg == "":
		msg = STATUS[_zone] if _motor > 0.05 else "Foot down, needle waiting"
		col = _zone_status_color(_zone) if _motor > 0.05 else Style.INK_SOFT
	else:
		col = Style.AMBER
	_set_status("%s   ·   %d%% sewn" % [msg, pct], col)


## Whatever needs doing right now, most urgent first ("" when it's just sewing).
func _situation() -> String:
	if _pivot_t > 0.0:
		return "Turning the cloth"
	if _jammed:
		return "Whoa — past the corner! Press E to pivot"
	if not _pin_in_reach().is_empty():
		return "Pin ahead — press E to pull it"
	var corner := _corner_situation()
	if corner != "":
		return corner
	if _reversing:
		return "Reversing — backstitch to lock the seam"
	var hint := _hint_text
	_hint_text = ""
	return hint


func _corner_situation() -> String:
	if _next_corner() >= _path.size() - 1:
		return ""
	var past := _past_corner()
	if past > -_corner_window(CORNER_GOOD) and _motor < 0.08:
		return "On the corner — press E to pivot"
	if past > -0.15:
		return "Corner coming — ease off the pedal"
	return ""


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


## The seam line chalked faint and fine, so the thread laid over it stands out.
func _paint_chalk(c: Control) -> void:
	var px := _px()
	var col := Style.tint(_chalk, 0.4)
	for i in _path.size() - 1:
		if int(_cum[i] * px / 8.0) % 2 == 0:
			c.draw_line(_w(_path[i]), _w(_path[i + 1]), col, 1.5)


## No shaded band here — the seam guide on the plate does that job.
func _paint_allowance(_c: Control) -> void:
	pass


## The stitches: short dashes of thread along where the needle has been, with a
## zig-zag knot at each end once it's locked.
func _paint_trail(c: Control) -> void:
	if _trail.size() < 2:
		return
	var thread := _thread_color()
	var pts := _resample(_trail, STITCH_LEN)
	for k in pts.size() - 1:
		c.draw_line(_w(pts[k]), _w(pts[k].lerp(pts[k + 1], 0.62)), thread, 3.0)
	for key in ["start", "end"]:
		if _locked[key]:
			_paint_lock(c, _path[0] if key == "start" else _path[_path.size() - 1], thread)


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


func _paint_lock(c: Control, at: Vector2, col: Color) -> void:
	var o := _w(at)
	for k in 3:
		var y := float(k) * 3.0 - 3.0
		c.draw_line(o + Vector2(-5, y), o + Vector2(5, y + 1.5), col, 1.6)


func _thread_color() -> Color:
	return _cloth.lightened(0.7) if _cloth.get_luminance() < 0.5 else _cloth.darkened(0.55)


## Pins across the seam: the bead on the raw-edge side, where your hand would grab it.
func _paint_world_extra(c: Control) -> void:
	for pin: Dictionary in _pins:
		if pin["state"] == 1:
			continue
		var s: float = pin["s"]
		var at := _point_at_arc(s)
		var i := mini(_index_at_arc(s), _normals.size() - 1)
		var out := _normals[i]
		# Centred just inside the line, so the bead sits on the allowance (2.5 cm out) and
		# the point crosses the seam into the garment.
		var centre := at - out * 0.015
		var col := Style.BURGUNDY if pin["state"] == 0 else Style.CLAY
		if Upgrades.has("sew_clips"):
			_paint_clip(c, _w(at + out * 0.03), out.angle(), col)
		else:
			Craft.dress_pin(c, _w(centre), (-out).angle(), col, 0.08 * _px())


func _paint_clip(c: Control, at: Vector2, angle: float, col: Color) -> void:
	var d := Vector2.from_angle(angle) * 9.0
	var n := d.orthogonal() * 0.6
	c.draw_colored_polygon(
		PackedVector2Array([at - d - n, at + d - n, at + d + n, at - d + n]), col
	)


func _index_at_arc(s: float) -> int:
	for i in _path.size() - 1:
		if _cum[i + 1] >= s:
			return i
	return _path.size() - 1


## The machine, drawn upright over the moving cloth: the needle plate with its seam
## guide, the feed dogs, the presser foot, the needle bobbing, and the arm off to the
## side.
func _paint_overlay(c: Control) -> void:
	var at := _to_screen(_p)
	var side := signf(_seg_normal(_seg).rotated(_view_rot).x)
	if side == 0.0:
		side = 1.0
	_paint_plate(c, at, side)
	_paint_foot(c, at)
	_paint_arm(c, at, side)


func _paint_plate(c: Control, at: Vector2, side: float) -> void:
	var rect := Rect2(at - Vector2(70, 46), Vector2(140, 92))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Style.tint(Style.STEEL, 0.55)
	plate.set_corner_radius_all(10)
	plate.set_border_width_all(1)
	plate.border_color = Style.tint(Style.STEEL_DARK, 0.7)
	c.draw_style_box(plate, rect)
	var px := _px()
	# Seam guide: 1, 1.5 and 2 cm lines on the outside — keep the raw edge on the 1.5.
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
				at + Vector2(dx - 3, 14)
			]
		)
		c.draw_colored_polygon(toe, Style.STEEL)
		Craft.outline(c, toe, Style.STEEL_DARK, 1.0)
	var bob := sin(_stitch_phase * TAU) * 4.0 if _motor > 0.02 else 0.0
	c.draw_line(at + Vector2(0, -34), at + Vector2(0, bob), Style.STEEL_DARK, 2.0)
	c.draw_circle(at + Vector2(0, bob), 1.6, Style.WALNUT)


func _paint_arm(c: Control, at: Vector2, side: float) -> void:
	# The head sits beside the needle (never over the seam ahead of it) and the arm runs
	# off across the bulk of the garment, the way the cloth passes under a real machine.
	var head := Rect2(at + Vector2(-side * 16.0 - 22.0, -20.0), Vector2(44, 40))
	var edge := c.size.x - MAT_INSET if side < 0.0 else MAT_INSET
	var from := head.end.x if side < 0.0 else head.position.x
	var arm := Rect2(Vector2(minf(from, edge), at.y - 14.0), Vector2(absf(edge - from), 28))
	var body := StyleBoxFlat.new()
	body.bg_color = Style.BURGUNDY
	body.set_corner_radius_all(10)
	body.shadow_color = Style.SHADOW
	body.shadow_size = 6
	c.draw_style_box(body, arm)
	body.bg_color = Style.BURGUNDY.darkened(0.1)
	c.draw_style_box(body, head)
	var light := Style.BRASS if _motor > 0.02 else Style.tint(Style.BRASS, 0.4)
	c.draw_circle(head.get_center(), 5.0, light)


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

class_name SewPedalMinigame
extends CutBench

## Sewing v2 — "Pedal & Guide". A real machine, kept simple: the needle stays put and the
## machine feeds the cloth along the seam by itself — the seam always runs up the screen.
## You do two things:
##   * the pedal (Space / F, or the right trigger, analog) — the motor spins up while held
##     and coasts down when you let go;
##   * push the cloth left / right (A / D) to keep the needle on the chalk line. The cloth
##     wanders a little on its own, and on a curve it pulls outward — harder the faster
##     you go.
## One rule for everything else: **ease off through the amber marks.** Amber chalk runs up
## to every pin and corner, and the speed dial on the machine goes red when you're too
## fast for what's coming. Pass a pin slowly and your hand pulls it; hit it fast and the
## needle bends (a slip). Reach a corner slowly and it turns crisp; arrive fast and the
## stitches run past it. The machine turns the cloth at the corner for you.
##
## Upgrades turn its dials (Upgrades "sew_*" effects): spin-up, coast, drift, curve pull,
## corner-turn time, a speed dial that slows itself at the marks, clips instead of pins.
## Shares the outline, zones, cloth and scoring with the cutting games via CutBench.
## Emits finished(success, quality).

const TITLE_SEW := "Sewing Machine"
const ZOOM := 2.0
const LOOK_AHEAD := 0.24
const STEER_RAMP := 6.0
const NUDGE := 0.12  # how fast your hands slide the cloth sideways (units/s)
const MAX_WANDER := 0.1
const ALLOWANCE := 0.0375  # 1.5 cm between the seam line and the cloth's raw edge
const SAFE := 0.4  # share of top speed that is "slow enough" at a pin or a corner
const GOOD_CORNER := 0.7  # arrive under this and the corner is only a touch rounded
const WARN := 0.15  # the amber marks run this far back from each pin and corner
const OVERSHOOT := 0.05  # stitches run past a corner by up to this at full speed
const CORNER_WEIGHT := 0.12  # how much a corner counts, as a length of seam
const CURVE_PULL := 0.08  # how hard a curve drags the cloth outward, per unit of speed
const DRIFT_SCALE := 0.004  # fabric drift table (deg-ish) → units/s of wander
const PIN_EVERY := 0.75
const PIN_CLEAR := 0.16  # no pins this close to a corner or either end
const GUIDE_PULL := 0.6
const TOP_GEAR := 1.5  # Oiled Machine + Shift
const STITCH_LEN := 0.014
const MACHINE_LOOP := "sew_machine_loop"
const BED_ART := "res://assets/textures/ui/machine_bed.png"
## How much each cloth wanders under your hands, before any upgrade.
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

var _top := 0.36
var _spin := 1.0
var _coast := 0.35
var _pivot_time := 0.45
var _garment := 0
var _piece_poly := PackedVector2Array()
var _pull := PackedFloat32Array()  # per point: which way (and how hard) a curve drags
var _bed_tex: Texture2D

var _s := 0.0  # how far along the seam the needle is
var _d := 0.0  # how far off the line, along the outward normal
var _seg := 0
var _p := Vector2.ZERO
var _steer := 0.0
var _pedal := 0.0
var _motor := 0.0
var _zone: int = CutBench.Zone.PERFECT
var _pivot_t := 0.0
var _pivot_from := Vector2.ZERO
var _pivot_to := Vector2.ZERO
var _pivot_h0 := 0.0
var _pivot_h1 := 0.0
var _heading := 0.0
var _view_angle := 0.0
var _time := 0.0
var _stitch_phase := 0.0
var _noise := FastNoiseLite.new()
var _pins: Array = []  # [{s: float, state: 0 in / 1 pulled / 2 bent the needle}]
var _corner_done := {}  # corner index -> true once turned
var _corners_done := 0
var _corners_clean := 0
var _stubs: Array = []  # [from, to] stitches that ran past a corner


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
	_zoom = ZOOM
	_s = 0.0
	_d = 0.0
	_seg = 0
	_p = _path[0]
	_heading = _seg_dir(0).angle()
	_view_angle = _heading
	_steer = 0.0
	_motor = 0.0
	_zone = Zone.PERFECT
	_pivot_t = 0.0
	_time = 0.0
	_corner_done = {}
	_corners_done = 0
	_corners_clean = 0
	_stubs = []
	_noise.seed = randi()
	_noise.frequency = 0.02
	_trail.append(_p)
	_trail_zone.append(Zone.PERFECT)
	_build_piece()
	_measure_pull()
	_place_pins()
	_follow(1.0)


func _hint_pairs() -> Array:
	return [["Space / F", "Pedal"], ["A / D", "Push the cloth"]]


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


## On a curve the cloth wants to keep going straight, so the needle drifts to the outside
## of the bend: + where that's the raw-edge side, − where it's the garment side.
func _measure_pull() -> void:
	_pull = PackedFloat32Array()
	_pull.resize(_path.size())
	for i in range(1, _path.size() - 1):
		if _corners.has(i):
			continue
		_pull[i] = -(_seg_dir(i) - _seg_dir(i - 1)).dot(_normals[i]) / STEP


## Pins across the seam every so often — clear of the corners and the two ends.
func _place_pins() -> void:
	_pins = []
	var s := 0.3
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
	if _pedal > 0.0 and _state == State.READY:
		_state = State.RUNNING
	if _pivot_t > 0.0:
		_tick_pivot(delta)
	else:
		_drive_motor(delta)
		_slide(delta)
		if _motor > 0.001:
			_feed(delta)
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
	for action in ["jump", "cut", "ui_accept", "interact"]:
		if Input.is_action_pressed(action):
			p = 1.0
	return clampf(p, 0.0, 1.0)


## The motor chases the pedal: slow to spin up, and it coasts when you let go — unless
## the upgrades make it snappier.
func _drive_motor(delta: float) -> void:
	var target := _pedal * _dial_cap()
	var up := Upgrades.mult("sew_spin") / maxf(_spin, 0.01)
	var down := Upgrades.mult("sew_coast") / maxf(_coast, 0.01)
	_motor = move_toward(_motor, target, (up if target > _motor else down) * delta)


## Speed Dial: the machine slows itself to a safe crawl through the amber marks.
func _dial_cap() -> float:
	if Upgrades.has("sew_dial") and _mark_ahead() != "":
		return SAFE * 0.9
	return 1.0


func _speed() -> float:
	var v := _motor * _top * Upgrades.sewing_speed()
	if Upgrades.sewing_sprint() and Input.is_action_pressed("sprint"):
		v *= TOP_GEAR
	return v


## How fast we're going, as a share of the plain machine's top speed.
func _speed_ratio() -> float:
	return _speed() / maxf(_top, 0.001)


## Your hands slide the cloth; the cloth wanders, and a curve drags it outward.
func _slide(delta: float) -> void:
	# D pushes the cloth right on screen, which moves the needle left across it.
	_d -= _steer * _screen_side() * NUDGE * delta
	if _motor > 0.001:
		var wander: float = DRIFT.get(_fabric, 4.0) * DRIFT_SCALE * Upgrades.mult("sew_drift")
		if _focused:
			wander *= 0.5
		_d += wander * _noise.get_noise_1d(_time * 60.0) * delta
		_d += _pull[_seg] * _speed() * CURVE_PULL * Upgrades.mult("sew_curve") * delta
	if Upgrades.has("sew_guide"):
		_d -= _d * minf(1.0, GUIDE_PULL * delta)
	_d = clampf(_d, -MAX_WANDER, MAX_WANDER)


## Which way (screen x) the raw edge lies from the seam line right now.
func _screen_side() -> float:
	var side := signf(_seg_normal(_seg).rotated(_view_rot).x)
	return side if side != 0.0 else 1.0


# --- Feeding the cloth -----------------------------------------------------


func _feed(delta: float) -> void:
	var v := _speed()
	var step := v * delta
	var to := _s + step
	var corner := _next_corner()
	var at_corner := corner < _path.size() - 1 and to >= _cum[corner]
	if at_corner:
		to = _cum[corner]
	_pass_pins(_s, to, v)
	if _state > State.RUNNING:
		return
	_s = to
	while _seg < _path.size() - 2 and _cum[_seg + 1] <= _s and not _corner_ahead_blocks():
		_seg += 1
	_p = _point_at_arc(_s) + _seg_normal(_seg) * _d
	_stitch_phase += step / STITCH_LEN
	_zone = _zone_of(_d)
	_record(_zone, step, ZONE_SCORE[_zone])
	_lay_trail()
	if at_corner:
		_arrive_at_corner(corner, v)
	elif _s >= _total - 0.0005 and _state == State.RUNNING:
		_finish()


## Don't step the edge past an unturned corner — the turn does that.
func _corner_ahead_blocks() -> bool:
	return _corners.has(_seg + 1) and not _corner_done.has(_seg + 1)


## The first unturned corner ahead (or the seam's end).
func _next_corner() -> int:
	var last := _path.size() - 1
	for k in range(_seg + 1, last):
		if _corners.has(k) and not _corner_done.has(k):
			return k
	return last


## Every pin the needle reaches this step: pulled if you're slow, a bent needle if not.
func _pass_pins(from: float, to: float, v: float) -> void:
	for pin: Dictionary in _pins:
		if pin["state"] != 0 or pin["s"] <= from or pin["s"] > to:
			continue
		if Upgrades.has("sew_clips") or v <= SAFE * _top:
			pin["state"] = 1
			Sfx.play("pin_out")
		else:
			pin["state"] = 2
			_motor = 0.0
			_register_mistake(_point_at_arc(pin["s"]))  # bent needle


## The corner: scored on how fast you came in, then the machine stops (needle down),
## lifts the foot and turns the cloth for you.
func _arrive_at_corner(corner: int, v: float) -> void:
	var ratio := v / maxf(_top, 0.001)
	var zone := Zone.PERFECT
	if ratio > GOOD_CORNER:
		zone = Zone.ROUGH
	elif ratio > SAFE:
		zone = Zone.GOOD
	if zone == Zone.PERFECT:
		_corners_clean += 1
	else:
		var run := OVERSHOOT * clampf(ratio, 0.0, 1.0)
		_stubs.append([_p, _p + _seg_dir(corner - 1) * run])
	_record(zone, CORNER_WEIGHT, ZONE_SCORE[zone])
	_corners_done += 1
	_corner_done[corner] = true
	_motor = 0.0
	_pivot_from = _p
	_seg = corner
	_pivot_to = _path[corner] + _seg_normal(corner) * _d
	_pivot_h0 = _heading
	_pivot_h1 = _seg_dir(corner).angle()
	_pivot_t = _pivot_time * Upgrades.mult("sew_pivot")
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


func _lay_trail() -> void:
	_heading = _seg_dir(_seg).angle()
	var n := _trail.size()
	if n < 2 or _trail[n - 2].distance_to(_p) >= STITCH_LEN * 0.5:
		_trail.append(_p)
		_trail_zone.append(_zone)
	else:
		_trail[n - 1] = _p


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


## "pin" or "corner" when one is inside its amber stretch ahead of the needle, else "".
func _mark_ahead() -> String:
	var corner := _next_corner()
	if corner < _path.size() - 1 and _cum[corner] - _s <= WARN:
		return "corner"
	if Upgrades.has("sew_clips"):
		return ""
	for pin: Dictionary in _pins:
		if pin["state"] == 0 and pin["s"] > _s and pin["s"] - _s <= WARN:
			return "pin"
	return ""


# --- Finish ----------------------------------------------------------------


func _finish() -> void:
	_succeed("  ·  corners %d/%d clean" % [_corners_clean, _corners_done])


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
		_set_status("Hold the pedal to sew — A / D pushes the cloth onto the chalk", Style.AMBER)
		return
	var pct := int(clampf(_s / _total, 0.0, 1.0) * 100.0)
	var msg := ""
	var col := Style.INK_SOFT
	var mark := _mark_ahead()
	if _pivot_t > 0.0:
		msg = "Turning the corner"
	elif mark != "" and _speed_ratio() > SAFE:
		msg = "Ease off — %s ahead!" % mark
		col = Style.CLAY
	elif mark != "":
		msg = "Nice and slow past the %s" % mark
		col = Style.FOREST
	elif _zone != Zone.PERFECT and _motor > 0.05:
		msg = "Off the line — push with %s" % ("D" if _d * _screen_side() > 0.0 else "A")
		col = _zone_status_color(_zone)
	elif _motor > 0.05:
		msg = STATUS[_zone]
		col = _zone_status_color(_zone)
	else:
		msg = "Foot down, needle waiting"
	_set_status("%s   ·   %d%% sewn" % [msg, pct], col)


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


## The seam line chalked faint and fine, so the thread laid over it stands out — and
## amber chalk up to every pin and corner still ahead: the "ease off" stretches.
func _paint_chalk(c: Control) -> void:
	var px := _px()
	var col := Style.tint(_chalk, 0.4)
	for i in _path.size() - 1:
		if int(_cum[i] * px / 8.0) % 2 == 0:
			c.draw_line(_w(_path[i]), _w(_path[i + 1]), col, 1.5)
	for s in _mark_arcs():
		_paint_amber(c, maxf(s - WARN, 0.0), s, px)


## Arc positions of every pin and corner the needle hasn't reached yet.
func _mark_arcs() -> Array:
	var out: Array = []
	for k in _corners:
		if not _corner_done.has(k):
			out.append(_cum[k])
	if not Upgrades.has("sew_clips"):
		for pin: Dictionary in _pins:
			if pin["state"] == 0:
				out.append(pin["s"])
	return out


func _paint_amber(c: Control, from: float, to: float, px: float) -> void:
	var col := Style.tint(Style.AMBER, 0.85)
	var i0 := _index_at_arc(from)
	var i1 := _index_at_arc(to)
	for i in range(i0, mini(i1 + 1, _path.size() - 1)):
		if int(_cum[i] * px / 6.0) % 2 == 0:
			var n := _normals[i] * 0.012
			c.draw_line(_w(_path[i] + n), _w(_path[i + 1] + n), col, 4.0)


## No shaded band here — the seam guide on the plate does that job.
func _paint_allowance(_c: Control) -> void:
	pass


## The stitches: short dashes of thread along where the needle has been, plus the few
## that ran past a corner taken too fast.
func _paint_trail(c: Control) -> void:
	if _trail.size() < 2:
		return
	var thread := _thread_color()
	var pts := _resample(_trail, STITCH_LEN)
	for k in pts.size() - 1:
		c.draw_line(_w(pts[k]), _w(pts[k].lerp(pts[k + 1], 0.62)), thread, 3.0)
	for stub in _stubs:
		var run := _resample(PackedVector2Array([stub[0], stub[1]]), STITCH_LEN)
		for k in run.size() - 1:
			c.draw_line(_w(run[k]), _w(run[k].lerp(run[k + 1], 0.62)), Style.CLAY, 3.0)


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


## Pins across the seam: the bead on the raw-edge side, the point into the garment.
func _paint_world_extra(c: Control) -> void:
	for pin: Dictionary in _pins:
		if pin["state"] == 1:
			continue
		var s: float = pin["s"]
		var at := _point_at_arc(s)
		var out := _normals[mini(_index_at_arc(s), _normals.size() - 1)]
		var col := Style.BURGUNDY if pin["state"] == 0 else Style.CLAY
		if Upgrades.has("sew_clips"):
			_paint_clip(c, _w(at + out * 0.03), out.angle(), col)
		else:
			Craft.dress_pin(c, _w(at - out * 0.015), (-out).angle(), col, 0.08 * _px())


func _paint_clip(c: Control, at: Vector2, angle: float, col: Color) -> void:
	var d := Vector2.from_angle(angle) * 9.0
	var n := d.orthogonal() * 0.6
	c.draw_colored_polygon(
		PackedVector2Array([at - d - n, at + d - n, at + d + n, at - d + n]), col
	)


## The machine, drawn upright over the moving cloth: the needle plate with its seam
## guide, the presser foot, the needle bobbing, the arm off to the side, and the speed
## dial on its head.
func _paint_overlay(c: Control) -> void:
	var at := _to_screen(_p)
	var side := _screen_side()
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
	# Seam guide: 1, 1.5 and 2 cm lines on the outside — the raw edge rides the 1.5.
	for cm: float in [1.0, 1.5, 2.0]:
		var x := at.x + side * (cm / 40.0) * px
		var col := Style.tint(Style.STEEL_DARK, 0.9 if cm == 1.5 else 0.45)
		c.draw_line(Vector2(x, rect.position.y + 4), Vector2(x, rect.end.y - 4), col, 1.5)
	for dx in [-9.0, 9.0]:
		c.draw_rect(Rect2(at + Vector2(dx - 2.5, -14), Vector2(5, 28)), Style.STEEL_DARK)
	# Off the line: a chevron on the side to push the cloth towards.
	if _zone != Zone.PERFECT and _state == State.RUNNING:
		var push := 1.0 if _d * side > 0.0 else -1.0
		var tip := at + Vector2(push * 84.0, 0.0)
		var col := _zone_color(_zone)
		c.draw_line(tip, tip + Vector2(-push * 12.0, -10.0), col, 4.0)
		c.draw_line(tip, tip + Vector2(-push * 12.0, 10.0), col, 4.0)


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


func _paint_arm(c: Control, at: Vector2, side: float) -> void:
	# The head sits beside the needle (never over the seam ahead of it) and the arm runs
	# off across the bulk of the garment, the way the cloth passes under a real machine.
	var head := Rect2(at + Vector2(-side * 50.0 - 30.0, -30.0), Vector2(60, 60))
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
	_paint_dial(c, head.get_center() + Vector2(0, 6))


## The speed dial: a needle sweeping a half-circle, with the safe stretch in green. When a
## pin or a corner is coming and you're past safe, it all goes red.
func _paint_dial(c: Control, at: Vector2) -> void:
	var r := 20.0
	var start := PI
	var span := PI
	c.draw_circle(at, r + 3.0, Style.CREAM)
	c.draw_arc(at, r - 3.0, start, start + span * SAFE, 12, Style.FOREST, 5.0)
	var hot := _mark_ahead() != "" and _speed_ratio() > SAFE
	var rest := Style.CLAY if _mark_ahead() != "" else Style.tint(Style.WALNUT, 0.3)
	c.draw_arc(at, r - 3.0, start + span * SAFE, start + span, 16, rest, 5.0)
	var needle := Vector2.from_angle(start + span * clampf(_speed_ratio(), 0.0, 1.0)) * (r - 2.0)
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

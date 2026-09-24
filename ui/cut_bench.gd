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
const SLIP_COST := 0.1
## The one-word verdict shown when the piece is done: [lowest quality, word].
const FINE_WORK := 0.85
const MAX_MISTAKES := 3
## Slips in a row before the bench steps in: it stops the tool and sets it back on the
## line, so one fast dive into the piece can never spoil it on its own (see _catch).
const RESCUE_AFTER := 2
const RESCUE_TIME := 0.5
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

## Half outlines for Cut on the Fold: from the fold at the top, round one side, back to
## the fold at the bottom (x = 0 is the fold). The shirt is its own right half; a jacket
## on the fold is cut as its back, which is symmetric where the front is not.
const FOLD_SHAPES := {
	Enums.GarmentType.SHIRT:
	[
		Vector2(0.0, -0.67),
		Vector3(0.17, -0.67, 0.0),
		Vector2(0.34, -0.82),
		Vector2(0.64, -0.7),
		Vector3(0.46, -0.4, 0.0),
		Vector2(0.7, -0.12),
		Vector2(0.62, 0.8),
		Vector3(0.31, 0.89, 0.0),
		Vector2(0.0, 0.89),
	],
	Enums.GarmentType.JACKET:
	[
		Vector2(0.0, -0.78),
		Vector3(0.16, -0.78, 0.0),
		Vector2(0.3, -0.88),
		Vector2(0.66, -0.74),
		Vector3(0.5, -0.4, 0.0),
		Vector2(0.64, -0.1),
		Vector3(0.52, 0.36, 0.0),
		Vector2(0.58, 0.88),
		Vector2(0.0, 0.9),
	],
}
const STRAIGHT_LOOK := 12  # outline points ahead (~18 cm) that must be straight to glide
const STRAIGHT_BEND := 1.2  # rad per unit: gentler than this counts as straight
const WHEEL_AHEAD := 6  # Chalk Wheel: how many points before a turn its mark goes
const REVEAL_TIME := 0.9
const BEAT_LEN := 0.4  # shape units of perfect line per streak beat (~16 cm of cloth)

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
var _closed := true  # false when cutting on the fold: the fold edge isn't cut
var _folded := false
var _bend := PackedFloat32Array()  # per point: how sharply the line turns there
var _straight := PackedByteArray()  # per point: a straight run lies ahead
var _marks := PackedInt32Array()  # Chalk Wheel: points that carry a "turn ahead" mark
var _reveal := 0.0  # 0 -> 1 as the finished piece is lifted (and unfolded) for show
var _reveal_from := {}

var _trail := PackedVector2Array()
var _trail_zone := PackedInt32Array()
var _zone_len := [0.0, 0.0, 0.0, 0.0]
var _score_sum := 0.0
var _score_len := 0.0
var _nicks := PackedVector2Array()
var _perfect_run := 0.0  # line kept perfect since the last streak beat
var _slips_in_row := 0  # slips since the tool was last out of trouble
var _rescue_t := 0.0  # > 0 while the bench is drawing the tool back to the line
var _rescue_route := PackedVector2Array()
var _rescue_turn := Vector2.ZERO  # heading from (x) and to (y)
var _caught := false  # just set back on the line: the status says so until you go on

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
	_ensure_chrome(_screen_title(), _paint, Style.FRAME_TALL)


func _load_assets() -> void:
	_snip = _load("snip")
	_slip = _load("slip")
	_complete = _load("complete")
	_ruined = _load("ruined")
	_mat_tex = _load_art(MAT_ART)
	_weave_tex = _load_art(WEAVE_ART)


## Same contract as v1: the garment, the ticket text, and (new) the cloth it's cut from.
## "started": the player has got going (cutting, or sewing on the machine games).
func coach_flags() -> Dictionary:
	return {"started": _state != State.READY}


func start(garment_type: int, title: String, material: MaterialType = null) -> void:
	_ensure_chrome(_screen_title(), _paint, Style.FRAME_TALL)
	_canvas.clip_contents = true  # the cloth runs off the edges of the bench
	_max_mistakes = MAX_MISTAKES
	var c := Config.data
	if c != null:
		_band_perfect = c.cut_band_perfect
		_band_good = c.cut_band_good
		_band_nick = c.cut_band_nick
		_max_mistakes = c.cut_max_mistakes
	_band_perfect *= Upgrades.mult("bench_band")
	var focus := _take_focus()
	_band_perfect *= focus
	_band_good *= focus
	_band_nick *= focus
	_folded = _fold_allowed() and FOLD_SHAPES.has(garment_type)
	_closed = not _folded and not _open_outline()
	_reveal = 0.0
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


## Overridden: the bench's name in the title row.
func _screen_title() -> String:
	return TITLE


## Overridden: may this game cut on the fold? (Only the cutting table can.)
func _fold_allowed() -> bool:
	return Upgrades.has("cut_fold")


## Overridden: an open outline (a single seam) rather than a whole closed piece.
func _open_outline() -> bool:
	return false


## Overridden: the outline to follow for this garment — Vector2 corners and Vector3
## bezier controls, as SHAPES.
func _outline_spec(garment_type: int) -> Array:
	var shapes: Dictionary = FOLD_SHAPES if _folded else SHAPES
	return shapes.get(garment_type, SHAPES[Enums.GarmentType.SHIRT])


## Overridden: a point inside the garment, to tell the outside of the line from the
## inside. The outline's own centre works for whole pieces and halves on the fold.
func _interior() -> Vector2:
	var centre := Vector2.ZERO
	for i in _path.size() - 1:
		centre += _path[i]
	return centre / maxf(_path.size() - 1, 1)


## Overridden: how much each corner of the outline wanders from the pattern.
func _jitter() -> float:
	return JITTER


## Overridden: does a too-wide stretch score as good? (Pinking Shears, cutting only.)
func _forgives_rough() -> bool:
	return Upgrades.has("cut_pinking")


## Overridden: does the Chalk Wheel mark the turns? (Cutting only.)
func _shows_wheel() -> bool:
	return Upgrades.has("cut_chalk_wheel")


## Overridden: is the Shift speed-up owned for this bench?
func _sprint_owned() -> bool:
	return Upgrades.cutting_sprint()


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
	if Upgrades != null and _sprint_owned():
		pairs.append(["Shift", "Faster (riskier)"])
	_set_hints(_focus_hint(pairs))


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


func is_settled() -> bool:
	return _state > State.RUNNING


## Debug (F2, debug builds only): skip the cut and finish it perfectly.
func _unhandled_input(event: InputEvent) -> void:
	if _state > State.RUNNING or not OS.is_debug_build():
		return
	if event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		_stop_sounds()
		finished.emit(true, 1.0)


# --- Outline ---------------------------------------------------------------


func _generate(garment_type: int) -> void:
	var jitter := _jitter()
	var pts: Array = []
	for p in _outline_spec(garment_type):
		var j := Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		if _folded and p is Vector2 and absf(p.x) < 0.001:
			j.x = 0.0  # the ends of a half outline sit exactly on the fold
		pts.append(Vector3(p.x + j.x * 0.5, p.y + j.y * 0.5, 0.0) if p is Vector3 else p + j)
	var starts: Array[int] = []
	_path = _trace(pts, _closed, starts)
	_measure()
	_find_corners(starts)
	_measure_bends()


## An outline spec (corners + bezier controls) as evenly spaced points; `starts` gets
## the index each corner-to-corner run begins at. Closed: the last point is the first.
func _trace(pts: Array, closed: bool, starts: Array[int]) -> PackedVector2Array:
	var out := PackedVector2Array()
	var runs := pts.size() if closed else pts.size() - 1
	var i := 0
	while i < runs:
		var nxt := (i + 1) % pts.size()
		var curved: bool = pts[nxt] is Vector3
		var ctrl := Vector2.ZERO
		if curved:
			ctrl = Vector2(pts[nxt].x, pts[nxt].y)
			nxt = (nxt + 1) % pts.size()
		starts.append(out.size())
		out.append_array(_run_points(pts[i], pts[nxt], curved, ctrl))
		i += 2 if curved else 1
	out.append(out[0] if closed else pts[pts.size() - 1])
	return out


## One corner-to-corner run, resampled evenly so every step of the cut is the same
## length of cloth. The end corner is left for the next run to start on.
func _run_points(a: Vector2, b: Vector2, curved: bool, ctrl: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
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
		out.append(raw[seg].lerp(raw[seg + 1], t))
	return out


func _measure() -> void:
	var m := _path.size()
	_cum = PackedFloat32Array([0.0])
	for i in range(1, m):
		_cum.append(_cum[i - 1] + _path[i - 1].distance_to(_path[i]))
	_total = _cum[m - 1]
	var centre := _interior()
	var sense := 0.0
	for i in m - 1:
		sense += _seg_dir(i).orthogonal().dot(_path[i] - centre)
	_out = 1.0 if sense >= 0.0 else -1.0
	_normals = PackedVector2Array()
	for i in m:
		var prev := _path[i - 1] if i > 0 else (_path[m - 2] if _closed else _path[0])
		var nxt := _path[i + 1] if i < m - 1 else (_path[1] if _closed else _path[m - 1])
		_normals.append((nxt - prev).normalized().orthogonal() * _out)


func _find_corners(starts: Array[int]) -> void:
	_corners = {}
	var m := _path.size()
	for k in starts:
		if k == 0 and not _closed:
			continue  # an open outline just starts; there's nothing to turn from
		var prev := _path[k] - (_path[k - 1] if k > 0 else _path[m - 2])
		var nxt := _path[k + 1] - _path[k]
		if absf(angle_difference(prev.angle(), nxt.angle())) > deg_to_rad(CORNER_DEG):
			_corners[k] = true


## How sharply the line bends at each point, which runs ahead are straight (for gliding
## and the rotary rule), and where the Chalk Wheel marks a turn coming.
func _measure_bends() -> void:
	var m := _path.size()
	_bend = PackedFloat32Array()
	_bend.resize(m)
	for i in range(1, m - 1):
		var turn := absf(angle_difference(_seg_dir(i - 1).angle(), _seg_dir(i).angle()))
		_bend[i] = INF if _corners.has(i) else turn / STEP
	_straight = PackedByteArray()
	_straight.resize(m)
	for i in m:
		var ok := true
		for k in range(i + 1, mini(i + STRAIGHT_LOOK, m - 1)):
			if _bend[k] > STRAIGHT_BEND:
				ok = false
				break
		_straight[i] = 1 if ok else 0
	_marks = PackedInt32Array()
	for i in range(1, m - 1):
		var turning := _bend[i] > STRAIGHT_BEND
		if turning and _bend[i - 1] <= STRAIGHT_BEND and i - WHEEL_AHEAD > 0:
			_marks.append(i - WHEEL_AHEAD)


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
	if zone == Zone.ROUGH and _forgives_rough():
		score = maxf(score, ZONE_SCORE[Zone.GOOD])  # a pinked edge can't fray
	_zone_len[zone] += length
	_score_sum += score * length
	_score_len += length
	_celebrate(zone, length)


## Every BEAT_LEN of line kept perfect is one beat of the streak (one at most per call,
## so a long stroke is a note, not a chord). A good stretch holds the streak; rough work
## or a nick ends it.
func _celebrate(zone: int, length: float) -> void:
	if zone == Zone.PERFECT:
		_perfect_run += length
		if _perfect_run >= BEAT_LEN:
			_perfect_run = 0.0
			_perfect_beat(_tool_at(), Style.BRASS_LIGHT)  # reads on any cloth
	elif zone != Zone.GOOD:
		_perfect_run = 0.0
		_break_streak()


## Where the tool is on the play surface, for the sparks. Variants override.
func _tool_at() -> Vector2:
	return _canvas.size * 0.5


func _quality() -> float:
	var q := 1.0 if _score_len <= 0.0 else _score_sum / _score_len
	return clampf(q - SLIP_COST * _mistakes, 0.15, 1.0)


func _register_mistake(at: Vector2) -> void:
	_mistakes += 1
	_nicks.append(at)
	_play(_slip, 0.8)
	_slip_feedback()
	if _mistakes >= _max_mistakes:
		_fail()
		return
	_slips_in_row += 1
	if _slips_in_row >= RESCUE_AFTER:
		_slips_in_row = 0
		_catch()


# --- Safeguard: two slips in a row -----------------------------------------


## The tool is out of trouble again (back on the line, or in the allowance): the next slip
## starts a fresh run.
func _clear_slip_run() -> void:
	_slips_in_row = 0


## Overridden by the steered variants: stop the tool and set it back on the line (via
## _start_rescue). A variant with separate strokes can't run away, so it does nothing.
func _catch() -> void:
	pass


## Overridden: put the tool at `p`, pointing along `heading` (shape space).
func _place_tool(_p_at: Vector2, _heading_to: float) -> void:
	pass


## The words for "caught you" — the variant knows whether it's shears or a needle.
func _caught_word() -> String:
	return "Caught it: the shears are back on the chalk. Let go, then carry on"


## Draw the tool along `route` over RESCUE_TIME, turning it from `from_heading` to
## `to_heading`. It then waits for the player to let go of the button before going on.
func _start_rescue(route: PackedVector2Array, from_heading: float, to_heading: float) -> void:
	_rescue_route = route
	_rescue_turn = Vector2(from_heading, to_heading)
	_rescue_t = RESCUE_TIME
	_armed = false
	_caught = true
	_perfect_run = 0.0
	Sfx.play("cloth_rustle", -4.0)


func _tick_rescue(delta: float) -> void:
	_rescue_t = maxf(0.0, _rescue_t - delta)
	var t := smoothstep(0.0, 1.0, 1.0 - _rescue_t / RESCUE_TIME)
	_place_tool(_along(_rescue_route, t), lerp_angle(_rescue_turn.x, _rescue_turn.y, t))


## Back out of a dive into the piece: along the cut to where it went in (so the retrace
## sits on the slit already made), then across onto the chalk at `on_line`.
func _way_back(from: Vector2, on_line: Vector2) -> PackedVector2Array:
	var i := _trail.size() - 1
	while i > 0 and _trail_zone[i] == Zone.NICK:
		i -= 1
	var entry := _trail[i]
	_trail.append(entry)
	_trail_zone.append(Zone.NICK)
	return PackedVector2Array([from, entry, on_line])


## The point `t` (0..1) of the way along a polyline, by length.
static func _along(route: PackedVector2Array, t: float) -> Vector2:
	var total := 0.0
	for i in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	var want := total * clampf(t, 0.0, 1.0)
	for i in range(1, route.size()):
		var leg := route[i - 1].distance_to(route[i])
		if want <= leg and leg > 0.0:
			return route[i - 1].lerp(route[i], want / leg)
		want -= leg
	return route[route.size() - 1]


## Overridden: silence any loop the variant keeps running.
func _stop_sounds() -> void:
	pass


func _exit_tree() -> void:
	_stop_sounds()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_stop_sounds()


## Done: one verdict and one number — nothing else to read.
func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	_stop_sounds()
	var q := _quality()
	_play(_complete, 0.7)
	_start_reveal()
	var col := Style.FOREST if q >= FINE_WORK else Style.INK_SOFT
	_set_status("%s  ·  %d%%" % [_verdict(q), roundi(q * 100.0)], col)
	_repaint()
	# The stamp lands as the piece finishes lifting off the cloth.
	get_tree().create_timer(REVEAL_TIME).timeout.connect(_stamp_verdict.bind(q))
	await get_tree().create_timer(REVEAL_TIME + _stamp_hold(q) + 0.2).timeout
	finished.emit(true, q)


## Lift the finished piece off the cloth, pulling the camera back to see all of it —
## and, cut on the fold, open it out to its full shape.
func _start_reveal() -> void:
	_reveal_from = {"zoom": _zoom, "cam": _cam, "rot": _view_rot}
	var tw := create_tween()
	tw.tween_method(_set_reveal, 0.0, 1.0, REVEAL_TIME).set_trans(Tween.TRANS_SINE)


func _set_reveal(t: float) -> void:
	_reveal = t
	var e := smoothstep(0.0, 1.0, t)
	_zoom = lerpf(_reveal_from["zoom"], 0.95, e)
	_cam = (_reveal_from["cam"] as Vector2).lerp(Vector2(0.0, 0.02), e)
	_view_rot = lerp_angle(_reveal_from["rot"], 0.0, e)
	_repaint()


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	_stop_sounds()
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
	if _folded:
		_paint_fold(c)
	_paint_allowance(c)
	_paint_chalk(c)
	_paint_trail(c)
	for n in _nicks:
		_paint_x(c, _w(n), Style.CLAY, 7.0)
	if _reveal > 0.0:
		_paint_piece(c)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
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
	if _folded:
		# Folded in half along x = 0: only the doubled half lies on the mat.
		var half := Vector2(CLOTH_HALF.x, CLOTH_HALF.y * 2.0) * px
		r = Rect2(_w(Vector2(0.0, -CLOTH_HALF.y)), half)
	Craft.card(c, Craft.pinked(r, 0.03 * px), _cloth, _cloth.darkened(0.3), 2.0)
	var inner := r.grow(-0.03 * px)
	if _weave_tex != null:
		c.draw_texture_rect(_weave_tex, inner, true, _cloth)
	_paint_pattern(c, inner, PackedVector2Array())


## The cloth's stripes or checks across `area`; with a `clip` polygon, only inside it
## (the lifted piece keeps its pattern).
func _paint_pattern(c: Control, area: Rect2, clip: PackedVector2Array) -> void:
	var look: Array = PATTERN_LOOK.get(_pattern, SOLID_LOOK)
	var col := Style.tint(_accent, look[2])
	if _pattern == Enums.Pattern.SOLID:
		col = Style.tint(_cloth.darkened(0.25), look[2])
	var px := _px()
	var step: float = maxf(3.0, float(look[0]) * px)
	var width: float = maxf(1.0, float(look[1]) * px)
	var x := area.position.x + step * 0.5
	while x < area.end.x:
		_thread(c, Vector2(x, area.position.y), Vector2(x, area.end.y), clip, col, width)
		x += step
	if not look[3]:
		return
	var y := area.position.y + step * 0.5
	while y < area.end.y:
		_thread(c, Vector2(area.position.x, y), Vector2(area.end.x, y), clip, col, width)
		y += step


## One stripe. Clipped, it is cut as a band (not a centreline drawn wide), so its end
## follows the piece's edge instead of stepping square across it at every check.
func _thread(
	c: Control, a: Vector2, b: Vector2, clip: PackedVector2Array, col: Color, width: float
) -> void:
	if clip.is_empty():
		c.draw_line(a, b, col, width)
		return
	var n := (b - a).normalized().orthogonal() * width * 0.5
	var band := PackedVector2Array([a + n, b + n, b - n, a - n])
	for part in Geometry2D.intersect_polygons(band, clip):
		if not Geometry2D.triangulate_polygon(part).is_empty():  # skip hairline slivers
			c.draw_colored_polygon(part, col)


## The folded edge: a soft rounded crease, darker than the cloth.
func _paint_fold(c: Control) -> void:
	var top := _w(Vector2(0.0, -CLOTH_HALF.y))
	var bottom := _w(Vector2(0.0, CLOTH_HALF.y))
	c.draw_line(top, bottom, _cloth.darkened(0.4), 5.0)
	c.draw_line(top + Vector2(3, 0), bottom + Vector2(3, 0), _cloth.lightened(0.15), 2.0)


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
	if _shows_wheel():
		_paint_wheel_marks(c, px)


## Chalk Wheel: a little chevron of tracing dots across the line before each turn.
func _paint_wheel_marks(c: Control, px: float) -> void:
	var col := Style.tint(Style.BRASS, 0.95)
	var r := maxf(2.0, 0.006 * px)
	for i in _marks:
		var at := _path[i]
		var n := _normals[i] * 0.03
		var back := -_seg_dir(i) * 0.02
		for f in [-1.0, 0.0, 1.0]:
			c.draw_circle(_w(at + n * f + back * absf(f)), r, col)


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
	if Upgrades.has("cut_pinking"):
		_paint_pinked(c, pts)


## Pinking Shears leave a zig-zag: small teeth along both lips of the cut.
func _paint_pinked(c: Control, pts: PackedVector2Array) -> void:
	var gap := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		gap += seg.length()
		if gap < 7.0 or seg.length() < 0.01:
			continue
		gap = 0.0
		var n := seg.normalized().orthogonal() * 4.5
		var d := seg.normalized() * 2.5
		for side in [-1.0, 1.0]:
			var tooth := PackedVector2Array(
				[pts[i] + n * side - d, pts[i] + n * side * 1.8, pts[i] + n * side + d]
			)
			c.draw_colored_polygon(tooth, Style.WALNUT)


## The finished piece, lifted off the cloth for a moment — opened out if it was folded.
func _paint_piece(c: Control) -> void:
	var lift := Vector2(0, -6.0) * smoothstep(0.0, 0.4, _reveal)
	var half := PackedVector2Array()
	for p in _path:
		half.append(_w(p) + lift)
	_paint_piece_part(c, half, _cloth.lightened(0.05))
	var open := smoothstep(0.3, 1.0, _reveal)
	if not _folded or open < 0.03:
		return
	var other := PackedVector2Array()
	for p in _path:
		other.append(_w(Vector2(-p.x * open, p.y)) + lift)
	_paint_piece_part(c, other, _cloth.darkened(0.05))


func _paint_piece_part(c: Control, poly: PackedVector2Array, fill: Color) -> void:
	var edge := _cloth.darkened(0.4)
	Craft.card(c, poly, fill, edge, 2.0)
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	_paint_pattern(c, box, poly)
	# The edge again over the pattern, so the stripes end under a clean antialiased line.
	Craft.outline(c, poly, edge, 2.0)


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

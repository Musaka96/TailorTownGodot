class_name PressMinigame
extends MinigameScreen

## Pressing minigame: "smooth the wrinkles". The piece lies on the ironing board with a
## handful of wrinkles in it. Slide the iron along with A / D, hold the button to press it
## down; a wrinkle under the pressed iron steams flat. The cloth under a pressed iron heats
## up — it glows amber as a warning — and an iron left sitting scorches it: that is a slip.
## All the wrinkles flat finishes the job; three scorches ruins the press. The chrome
## (panel, ticket, slip pins, prompts) comes from MinigameScreen.
##
## Emits finished(success, quality): quality is 1.0 for a clean press and falls by half for
## every scorch, so the ironing board can scale what the press is worth.

signal finished(success: bool, quality: float)

enum State { RUNNING, SUCCESS, RUINED }

const TITLE := "Ironing Board"
const CLOTH_DEFAULT := Style.LINEN
const WRINKLES := 5
const MAX_MISTAKES := 3
const MIN_GAP := 0.12  # least spacing between wrinkles, in board fraction
const IRON_HALF := 0.075  # half the soleplate's reach, in board fraction
const SPEED_LIFTED := 0.85  # board fractions a second, iron in the air
const SPEED_PRESSED := 0.4  # …and dragging on the cloth
const STEER_RAMP := 14.0  # how fast the iron picks up and sheds speed
const FLATTEN_SECONDS := 0.65
const SCORCH_SECONDS := 1.25  # a pressed iron held still this long burns the cloth
const COOL_RATE := 0.45  # heat a second a cell sheds once the iron has moved on
const WARN_HEAT := 0.6
const CELLS := 28
const SCORCH_COST := 0.5  # quality lost per scorch

const GLIDE_LOOP := "iron_glide"
const GLIDE_DB := -6.0
const BOARD_INSET := 10.0

var _state := State.RUNNING
var _armed := false  # the press that opened the board must be let go first
var _pressing := false
var _pressed_once := false
var _iron := 0.5
var _vel := 0.0
var _puff := 0.0
var _cloth := CLOTH_DEFAULT
var _at: PackedFloat32Array = []  # wrinkle positions, 0..1 along the board
var _flat: PackedFloat32Array = []  # how far each has been pressed out, 0..1
var _heat: PackedFloat32Array = []
var _burns: PackedFloat32Array = []  # where the cloth was scorched

var _slip: AudioStream
var _complete: AudioStream
var _ruined: AudioStream


func _ready() -> void:
	_ensure_chrome(TITLE, _paint)


func _load_assets() -> void:
	_slip = _load("scorch")
	_complete = _load("complete")
	_ruined = _load("ruined")


func coach_flags() -> Dictionary:
	return {"started": _state == State.RUNNING, "pressed": _pressed_once}


## Same contract as the sewing games: the piece's type, its ticket title and its cloth.
func start_piece(_garment_type: int, title: String, material: MaterialType) -> void:
	_ensure_chrome(TITLE, _paint)
	_cloth = material.cloth_color if material != null else CLOTH_DEFAULT
	_state = State.RUNNING
	_armed = false
	_pressing = false
	_pressed_once = false
	_iron = 0.5
	_vel = 0.0
	_mistakes = 0
	_max_mistakes = MAX_MISTAKES
	_at = _random_wrinkles()
	_flat = PackedFloat32Array()
	_flat.resize(_at.size())
	_heat = PackedFloat32Array()
	_heat.resize(CELLS)
	_burns = PackedFloat32Array()
	_set_job(title)
	_set_hints.call_deferred([["A / D", "Slide the iron"], ["E / Space", "Hold to press"]])
	_build_pips()
	_show_panel()
	_update_status()
	set_process(true)
	_repaint()


## Whatever takes the screen away, the iron's rub stops with it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		Sfx.stop_loop(GLIDE_LOOP)


func _exit_tree() -> void:
	Sfx.stop_loop(GLIDE_LOOP)


func _process(delta: float) -> void:
	if _state != State.RUNNING:
		return
	var held := _press_held()
	if not _armed and not held:
		_armed = true
	_pressing = _armed and held
	_pressed_once = _pressed_once or _pressing
	_slide(delta)
	_warm(delta)
	_puff = fmod(_puff + delta, 1.0)
	if _state != State.RUNNING:
		return
	if _pressing:
		_flatten(delta)
	_update_status()
	_repaint()


## Debug (F2, debug builds only): skip the press and finish it cleanly.
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.RUNNING or not OS.is_debug_build():
		return
	if event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()
		_state = State.SUCCESS
		set_process(false)
		Sfx.stop_loop(GLIDE_LOOP)
		finished.emit(true, 1.0)


## Any of the "do it" buttons (F / Space / E / pad A, X, Y) holds the iron down.
func _press_held() -> bool:
	for action in ["cut", "jump", "interact", "ui_accept"]:
		if Input.is_action_pressed(action):
			return true
	return false


func _slide(delta: float) -> void:
	var top := SPEED_PRESSED if _pressing else SPEED_LIFTED
	var want := Input.get_axis("move_left", "move_right") * top
	_vel = lerpf(_vel, want, clampf(STEER_RAMP * delta, 0.0, 1.0))
	_iron = clampf(_iron + _vel * delta, 0.0, 1.0)
	if _pressing:
		Sfx.start_loop(GLIDE_LOOP, GLIDE_DB)
		var moving := clampf(absf(_vel) / SPEED_PRESSED, 0.0, 1.0)
		Sfx.set_loop_volume(GLIDE_LOOP, lerpf(GLIDE_DB - 14.0, GLIDE_DB, moving))
	else:
		Sfx.stop_loop(GLIDE_LOOP)


## Cells under the pressed iron heat, the rest cool; a cell that tops out is a scorch.
func _warm(delta: float) -> void:
	for i in CELLS:
		var x := (i + 0.5) / CELLS
		if _pressing and absf(x - _iron) <= IRON_HALF:
			_heat[i] += delta / SCORCH_SECONDS
		else:
			_heat[i] = maxf(0.0, _heat[i] - COOL_RATE * delta)
	for i in CELLS:
		if _heat[i] >= 1.0:
			_scorch()
			return


func _scorch() -> void:
	_burns.append(_iron)
	for i in CELLS:
		_heat[i] = minf(_heat[i], 0.3)
	_armed = false  # the iron jumps off the cloth; press again to carry on
	_pressing = false
	_mistakes += 1
	_play(_slip, 0.7)
	_slip_feedback()
	if _mistakes >= _max_mistakes:
		_fail()


func _flatten(delta: float) -> void:
	for i in _at.size():
		if _flat[i] >= 1.0 or absf(_at[i] - _iron) > IRON_HALF:
			continue
		_flat[i] = minf(1.0, _flat[i] + delta / FLATTEN_SECONDS)
		if _flat[i] >= 1.0:
			Sfx.play("steam_hiss", -4.0)
			var board := _board_rect(_canvas)
			_perfect_beat(Vector2(_x_of(_canvas, _at[i]), board.get_center().y), Style.CHALK)
	if _smooth_count() >= _at.size():
		_succeed()


func _smooth_count() -> int:
	var n := 0
	for f in _flat:
		if f >= 1.0:
			n += 1
	return n


## Wrinkles scattered along the board, never bunched closer than MIN_GAP.
func _random_wrinkles() -> PackedFloat32Array:
	var pts := PackedFloat32Array()
	var tries := 0
	while pts.size() < WRINKLES and tries < 200:
		tries += 1
		var x := randf_range(0.08, 0.92)
		var clear := true
		for p in pts:
			if absf(p - x) < MIN_GAP:
				clear = false
		if clear:
			pts.append(x)
	return pts


func _quality() -> float:
	return clampf(1.0 - SCORCH_COST * _mistakes, 0.0, 1.0)


func _succeed() -> void:
	_state = State.SUCCESS
	set_process(false)
	_pressing = false
	Sfx.stop_loop(GLIDE_LOOP)
	_play(_complete, 0.7)
	var word := "Crisp" if _mistakes == 0 else ("Pressed" if _mistakes == 1 else "Singed")
	_set_status(word, Style.FOREST if _mistakes < 2 else Style.AMBER)
	_repaint()
	_stamp_verdict(_quality(), word)
	await get_tree().create_timer(_stamp_hold(_quality())).timeout
	finished.emit(true, _quality())


func _fail() -> void:
	_state = State.RUINED
	set_process(false)
	Sfx.stop_loop(GLIDE_LOOP)
	_play(_ruined, 0.8)
	_set_status("Scorched", Style.CLAY)
	_repaint()
	await get_tree().create_timer(1.0).timeout
	finished.emit(false, 0.0)


## Progress, and a warning only when something is wrong.
func _update_status() -> void:
	if _state != State.RUNNING:
		return
	if _pressing and _heat_under() >= WARN_HEAT:
		_set_status("Too hot — move the iron on!", Style.AMBER)
		return
	var tip := "%d of %d smooth" % [_smooth_count(), _at.size()]
	if OS.is_debug_build():
		tip += "   ·   F2 skip"
	_set_status(tip, Style.INK_SOFT)


func _heat_under() -> float:
	var hot := 0.0
	for i in CELLS:
		if absf((i + 0.5) / CELLS - _iron) <= IRON_HALF:
			hot = maxf(hot, _heat[i])
	return hot


# --- Painting (called from the MinigameCanvas) -----------------------------


func _board_rect(c: Control) -> Rect2:
	return Rect2(
		Vector2(BOARD_INSET, BOARD_INSET), c.size - Vector2(BOARD_INSET * 2.0, BOARD_INSET * 2.0)
	)


## The piece on the board.
func _cloth_rect(c: Control) -> Rect2:
	var board := _board_rect(c)
	var h: float = minf(board.size.y * 0.5, 130.0)
	return Rect2(board.position.x + 26.0, board.end.y - h - 40.0, board.size.x - 52.0, h)


func _x_of(c: Control, frac: float) -> float:
	var r := _cloth_rect(c)
	return r.position.x + frac * r.size.x


func _paint(c: Control) -> void:
	_paint_board(c)
	_paint_cloth(c)
	_paint_heat(c)
	_paint_wrinkles(c)
	_paint_burns(c)
	_paint_iron(c)


## The board's padded cover, with a stitched hem.
func _paint_board(c: Control) -> void:
	var rect := _board_rect(c)
	var cover := StyleBoxFlat.new()
	cover.bg_color = Style.PAPER_COOL
	cover.set_corner_radius_all(40)
	cover.set_border_width_all(3)
	cover.border_color = Style.STEEL_DARK
	c.draw_style_box(cover, rect)
	var hem := rect.grow(-9.0)
	var col := Style.tint(Style.STEEL_DARK, 0.45)
	_dashed(c, hem.position + Vector2(34.0, 0.0), Vector2(hem.end.x - 34.0, hem.position.y), col, 2)
	_dashed(c, Vector2(hem.position.x + 34.0, hem.end.y), hem.end - Vector2(34.0, 0.0), col, 2)


func _paint_cloth(c: Control) -> void:
	var r := _cloth_rect(c)
	Craft.card(c, Craft.pinked(r, 7.0), _cloth, _cloth.darkened(0.3), 2.0)
	var inner := r.grow(-7.0)
	var warp := _cloth.darkened(0.06)
	var x := inner.position.x
	while x < inner.end.x:
		c.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), warp, 1.0)
		x += 6.0


## Hot cloth glows under the iron's path, and a gauge along the board's edge below it says
## the same in height — so the warning reads on any colour of cloth, and without colour.
func _paint_heat(c: Control) -> void:
	var r := _cloth_rect(c).grow(-7.0)
	var w := r.size.x / CELLS
	for i in CELLS:
		var h := _heat[i]
		if h <= 0.05:
			continue
		var col := Style.AMBER if h < WARN_HEAT else Style.CLAY
		var glow := Rect2(r.position.x + i * w, r.position.y, w + 1.0, r.size.y)
		c.draw_rect(glow, Style.tint(col, h * 0.4))
		c.draw_rect(Rect2(r.position.x + i * w, r.end.y + 12.0, w - 1.0, 18.0 * h), col)


## A wrinkle is a little run of creases; pressing it irons the wave out of them.
func _paint_wrinkles(c: Control) -> void:
	var r := _cloth_rect(c).grow(-14.0)
	var dark := _cloth.darkened(0.35)
	var light := _cloth.lightened(0.25)
	for i in _at.size():
		var left := 1.0 - _flat[i]
		var cx := _x_of(c, _at[i])
		if left <= 0.0:
			c.draw_circle(Vector2(cx, r.position.y + 2.0), 3.0, Style.FOREST)
			continue
		for k in 3:
			var ox := (k - 1) * 9.0
			var crease := PackedVector2Array()
			for s in 13:
				var t := s / 12.0
				var wave := sin(t * TAU * 1.5 + i + k) * 7.0 * left
				crease.append(Vector2(cx + ox + wave, lerpf(r.position.y, r.end.y, t)))
			c.draw_polyline(crease, Style.tint(dark, 0.35 + 0.5 * left), 2.5, true)
			for s in crease.size():
				crease[s] += Vector2(2.0, 0.0)
			c.draw_polyline(crease, Style.tint(light, 0.5 * left), 1.5, true)


func _paint_burns(c: Control) -> void:
	var r := _cloth_rect(c)
	for b in _burns:
		var p := Vector2(_x_of(c, b), r.get_center().y)
		c.draw_circle(p, 20.0, Style.tint(Style.WALNUT, 0.35))
		c.draw_circle(p, 12.0, Style.tint(Style.WALNUT, 0.5))
		_paint_x(c, p, Style.CLAY, 7.0)


## The iron from the side, nose to the right: a polished soleplate, an enamel body that
## slopes down to the nose, a walnut handle arched over it, a brass heat dial and a cord
## trailing off the heel. Lifted, it hangs a little nose-up above its own shadow; pressed,
## it sits flat on the cloth and breathes steam from under the plate.
func _paint_iron(c: Control) -> void:
	var r := _cloth_rect(c)
	var half := IRON_HALF * r.size.x
	var lift := 0.0 if _pressing else 26.0
	var base := Vector2(_x_of(c, _iron), r.position.y + 12.0 - lift)
	var shade := Rect2(base.x - half * 0.95, r.position.y + 8.0, half * 1.9, 10.0)
	var dark := 0.32 if _pressing else 0.14
	c.draw_colored_polygon(Craft.rounded(shade, 5.0), Style.tint(Style.WALNUT, dark))
	if _pressing and _state == State.RUNNING:
		_paint_steam(c, base, half)
	var lean := 0.0 if _pressing else -0.06
	c.draw_set_transform(base, lean + _vel * 0.05)
	_paint_cord(c, half)
	_paint_iron_body(c, half)
	_paint_iron_handle(c, half)
	c.draw_set_transform(Vector2.ZERO)


## Everything below is drawn around the iron's own origin: the middle of the soleplate's
## underside, x to the nose, y up the page negative.
func _paint_iron_body(c: Control, half: float) -> void:
	var body := PackedVector2Array([Vector2(-half + 3.0, -8.0)])
	body.append_array(
		_curve(Vector2(-half + 3.0, -8.0), Vector2(-half - 5.0, -36.0), Vector2(-half * 0.7, -44.0))
	)
	body.append_array(
		_curve(Vector2(-half * 0.7, -44.0), Vector2(half * 0.6, -46.0), Vector2(half - 3.0, -8.0))
	)
	var enamel := Style.BURGUNDY
	c.draw_colored_polygon(body, enamel)
	# A band of light along the shoulder, and a cream pinstripe above the plate.
	var shine := _curve(
		Vector2(-half * 0.55, -38.0), Vector2(half * 0.45, -40.0), Vector2(half * 0.78, -15.0)
	)
	c.draw_polyline(shine, Style.tint(Style.CREAM, 0.35), 4.0, true)
	var stripe := Style.tint(Style.CREAM, 0.7)
	c.draw_line(Vector2(-half + 5.0, -13.0), Vector2(half - 10.0, -13.0), stripe, 1.5, true)
	Craft.outline(c, body, Style.WALNUT, 2.0)
	# The heat dial.
	var dial := Vector2(-half * 0.2, -25.0)
	c.draw_circle(dial, 7.5, Style.RIM_DARK)
	c.draw_circle(dial, 6.0, Style.BRASS)
	c.draw_line(dial, dial + Vector2(3.0, -4.0), Style.WALNUT, 2.0, true)
	# The soleplate: a steel slab, bevelled up at the nose, bright along its top edge.
	var sole := PackedVector2Array(
		[
			Vector2(-half, 0.0),
			Vector2(half - 9.0, 0.0),
			Vector2(half + 2.0, -6.0),
			Vector2(half - 2.0, -9.0),
			Vector2(-half, -9.0),
		]
	)
	c.draw_colored_polygon(sole, Style.STEEL)
	c.draw_line(Vector2(-half, -7.5), Vector2(half - 3.0, -7.5), Style.CHALK, 1.5, true)
	Craft.outline(c, sole, Style.STEEL_DARK, 1.5)


## The handle: one thick walnut arch from the heel to the shoulder, with rounded ends and a
## line of light along the top of the grip.
func _paint_iron_handle(c: Control, half: float) -> void:
	var grip := _cubic(
		Vector2(-half * 0.6, -41.0),
		Vector2(-half * 0.85, -84.0),
		Vector2(half * 0.62, -86.0),
		Vector2(half * 0.42, -36.0)
	)
	c.draw_polyline(grip, Style.WALNUT.darkened(0.3), 13.0, true)
	c.draw_polyline(grip, Style.WALNUT, 10.0, true)
	for end in [grip[0], grip[grip.size() - 1]]:
		c.draw_circle(end, 6.5, Style.WALNUT.darkened(0.3))
	var light := PackedVector2Array()
	for i in range(3, grip.size() - 3):
		light.append(grip[i] + Vector2(0.0, -2.5))
	c.draw_polyline(light, Style.tint(Style.CREAM, 0.3), 2.5, true)


func _paint_cord(c: Control, half: float) -> void:
	var cord := _cubic(
		Vector2(-half * 0.72, -42.0),
		Vector2(-half - 30.0, -60.0),
		Vector2(-half - 20.0, -120.0),
		Vector2(-half - 90.0, -150.0)
	)
	c.draw_polyline(cord, Style.INK, 3.5, true)
	c.draw_circle(cord[0], 5.0, Style.INK)


## Steam sighing out from under the plate, either side and off the nose.
func _paint_steam(c: Control, base: Vector2, half: float) -> void:
	for k in 5:
		var t := fmod(_puff + k / 5.0, 1.0)
		var side := (k - 2) / 2.0
		var at := base + Vector2(side * half * 1.15, -4.0 - t * 46.0 - absf(side) * 6.0)
		at.x += sin((t + k) * 5.0) * 5.0
		c.draw_circle(at, 5.0 + t * 9.0, Style.tint(Style.CHALK, 0.5 * (1.0 - t)))


## A quadratic curve as points (without its first point, so curves chain).
func _curve(a: Vector2, ctrl: Vector2, b: Vector2, steps := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(1, steps + 1):
		var t := float(i) / steps
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts


func _cubic(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, steps := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(a.bezier_interpolate(c1, c2, b, float(i) / steps))
	return pts

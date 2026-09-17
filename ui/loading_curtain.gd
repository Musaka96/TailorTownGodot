class_name LoadingCurtain
extends CanvasLayer

## The shop's stage curtain, drawn over everything — the HUD and the retro filter included —
## while a game scene loads. It falls from the top to hide the swap, then sweeps aside to
## reveal the shop.
##
## Godot builds a material's render pipeline the first time it is actually drawn, and the
## autoloaded effects (PostFX's grade, Outline's quad, PostFxLighting's environment and sun
## overrides) only latch onto a scene once it is in the tree. So the first frames of a fresh
## shop visibly settle: the grade, the outlines and the lighting snap into place one after
## the other. The curtain holds that behind burgundy velvet, waits for a handful of real
## rendered frames, then opens on a shop that already looks the way it will keep looking.
## Owned by SaveManager, which draws it before a scene swap.
##
## Everything is painted in code (Style palette, no art needed): vertical pleats shaded
## crest-to-fold, a scalloped hem, brass binding down the leading edges, and a short settle
## wobble when the fabric lands.

signal closed  ## fully drawn across the screen
signal opened  ## fully swept aside

enum Phase { OPEN, CLOSING, CLOSED, OPENING }

## Above PostFX (100), so even the filter's own first frame is hidden.
const LAYER := 200
const DROP_SECONDS := 0.5
const PART_SECONDS := 0.75
## How far the hem hangs past the bottom of the screen once the curtain is all the way
## down — just enough to hide the scallop, so the whole fall stays on screen.
const HEM_CLEARANCE := 20.0
## Pleats per half, and how many strips each half is shaded with.
const PLEATS := 7
const STRIPS := 128
const FOLD_DARKEN := 0.7
const CREST_LIGHTEN := 0.1
## Above 1 the folds widen and the lit crests narrow — velvet rather than corduroy.
const PLEAT_SHARPNESS := 1.8
const SCALLOP_PIXELS := 12.0
## How much each half narrows as it sweeps aside — the pleats bunch up, the way real
## curtains stack against the wall instead of sliding off rigid.
const GATHER := 0.45
## Shadow under the rail, as a share of the panel height, and along the leading edge.
const HEAD_SHADOW := 0.22
const EDGE_SHADOW := 16.0
const SHADE_BANDS := 8
## How far and how long the fabric wobbles after it lands.
const SWAY_PIXELS := 10.0
const SWAY_SECONDS := 0.9
const TRIM_WIDTH := 3.0
## Drawn frames to wait for before opening (pipelines compile on first draw).
const WARMUP_FRAMES := 12
## …and at least this long on top, so a slow first frame still finishes settling.
const WARMUP_SECONDS := 0.6

var _sheet: Control
var _phase := Phase.OPEN
var _t := 0.0
var _sway_left := 0.0


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind it can be clicked
	_sheet.draw.connect(_draw_sheet)
	add_child(_sheet)


func _process(delta: float) -> void:
	match _phase:
		Phase.CLOSING:
			_advance(delta / DROP_SECONDS)
		Phase.OPENING:
			_advance(delta / PART_SECONDS)
		Phase.CLOSED:
			_sway_left = maxf(_sway_left - delta, 0.0)
		_:
			return
	if _sheet != null:
		_sheet.queue_redraw()


# --- Public API ------------------------------------------------------------


## Draw the curtain across the screen. Awaitable: returns once it is fully down.
func close() -> void:
	if _phase == Phase.CLOSED:
		return
	if _phase != Phase.CLOSING:
		_phase = Phase.CLOSING
		_t = 0.0
		visible = true
	await closed


## Hold while the fresh scene draws itself into shape. Awaitable.
func warm_up(tree: SceneTree) -> void:
	for _i in WARMUP_FRAMES:
		await tree.process_frame
	await tree.create_timer(WARMUP_SECONDS).timeout


## Sweep both halves aside. Awaitable: returns once the screen is clear.
func open() -> void:
	if _phase == Phase.OPEN:
		return
	if _phase != Phase.OPENING:
		_phase = Phase.OPENING
		_t = 0.0
	await opened


# --- Animation -------------------------------------------------------------


func _advance(step: float) -> void:
	_t = minf(_t + step, 1.0)
	if _t < 1.0:
		return
	_t = 0.0
	if _phase == Phase.CLOSING:
		_phase = Phase.CLOSED
		_sway_left = SWAY_SECONDS
		closed.emit()
	else:
		_phase = Phase.OPEN
		visible = false
		opened.emit()


## 0 = still up out of sight, 1 = all the way down. Eases out, like cloth falling.
func _drop() -> float:
	if _phase != Phase.CLOSING:
		return 1.0
	return 1.0 - pow(1.0 - _t, 3.0)


## 0 = shut, 1 = swept right off the sides. Eases in and out, like a stage curtain.
func _part() -> float:
	if _phase != Phase.OPENING:
		return 0.0
	return _t * _t * (3.0 - 2.0 * _t)


## Sideways wobble as the fabric settles, fading out over SWAY_SECONDS.
func _settle() -> float:
	if _sway_left <= 0.0:
		return 0.0
	var age := SWAY_SECONDS - _sway_left
	return sin(age * TAU * 1.8) * (_sway_left / SWAY_SECONDS) * SWAY_PIXELS


# --- Drawing ---------------------------------------------------------------


func _draw_sheet() -> void:
	var view: Vector2 = _sheet.size
	# Each half reaches past its outer screen edge, so the settle wobble never opens a gap.
	var bleed := SWAY_PIXELS + 2.0
	var panel := Vector2(view.x * 0.5 + bleed, view.y + HEM_CLEARANCE)
	var top := -panel.y * (1.0 - _drop())
	var part := _part()
	# Both halves hang from their leading edge, which sweeps out while the fabric bunches.
	var lead := view.x * 0.5 + _settle()
	var slide := panel.x * part
	var width := Vector2(panel.x * (1.0 - GATHER * part), panel.y)
	_draw_half(Rect2(Vector2(lead - slide - width.x, top), width), false)
	_draw_half(Rect2(Vector2(lead + slide, top), width), true)


## One half of the curtain: the pleated velvet, the shadow under the rail, and the brass
## binding down its leading edge (the right edge, or the left one when `mirrored`).
func _draw_half(rect: Rect2, mirrored: bool) -> void:
	_draw_pleats(rect)
	_draw_shade(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * HEAD_SHADOW)), true)
	var inner := rect.position.x if mirrored else rect.end.x - EDGE_SHADOW
	_draw_shade(Rect2(inner, rect.position.y, EDGE_SHADOW, rect.size.y), not mirrored)
	var trim := rect.position.x if mirrored else rect.end.x - TRIM_WIDTH
	_sheet.draw_rect(Rect2(trim, rect.position.y, TRIM_WIDTH, rect.size.y), Style.BRASS)


## Vertical pleats shaded crest-to-fold, hung on a scalloped hem. A slow second harmonic
## breathes the pleat widths so they drape instead of marching.
func _draw_pleats(rect: Rect2) -> void:
	var fold: Color = Style.BURGUNDY.darkened(FOLD_DARKEN)
	var crest: Color = Style.BURGUNDY.lightened(CREST_LIGHTEN)
	var strip := rect.size.x / STRIPS
	for i in STRIPS:
		var u := (float(i) + 0.5) / STRIPS
		var lit := pow(0.5 + 0.5 * cos(u * TAU * PLEATS + sin(u * TAU) * 0.7), PLEAT_SHARPNESS)
		var hem := rect.end.y + (1.0 - lit) * SCALLOP_PIXELS
		var x := rect.position.x + u * rect.size.x - strip * 0.5
		_sheet.draw_rect(
			Rect2(x, rect.position.y, strip + 1.0, hem - rect.position.y), fold.lerp(crest, lit)
		)


## A soft shadow fading out across `area` — downward from the rail when `vertical`, or
## inward from the leading edge otherwise.
func _draw_shade(area: Rect2, vertical: bool) -> void:
	var step := (area.size.y if vertical else area.size.x) / SHADE_BANDS
	for b in SHADE_BANDS:
		var tint: Color = Style.SHADOW
		tint.a *= 1.0 - float(b) / SHADE_BANDS
		var band := area
		if vertical:
			band.position.y = area.position.y + b * step
			band.size.y = step + 1.0
		else:
			band.position.x = area.position.x + (SHADE_BANDS - 1 - b) * step
			band.size.x = step + 1.0
		_sheet.draw_rect(band, tint)

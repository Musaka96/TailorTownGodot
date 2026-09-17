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
## Art is optional. Drop the three PNGs named below into assets/textures/ui and the curtain
## uses them; with any of them missing it paints that part itself from the Style palette
## (pleats shaded crest-to-fold, a scalloped hem, a brass binding), so the game always has a
## curtain. Either way the fabric gathers as it opens and wobbles briefly when it lands.

signal closed  ## fully drawn across the screen
signal opened  ## fully swept aside

enum Phase { OPEN, CLOSING, CLOSED, OPENING }

## Above PostFX (100), so even the filter's own first frame is hidden.
const LAYER := 200
## Optional art. PANEL_ART is the LEFT half, mirrored for the right, and is stretched to
## half the screen. TRIM_ART is the braid down each leading edge, tiled vertically and kept
## at its own width so it never squashes. VALANCE_ART is the pelmet across the top, tiled
## horizontally, which rides down with the curtain and flies out again as it opens.
const PANEL_ART := "res://assets/textures/ui/curtain_panel.png"
const TRIM_ART := "res://assets/textures/ui/curtain_trim.png"
const VALANCE_ART := "res://assets/textures/ui/curtain_valance.png"
## Pelmet height as a share of the screen.
const VALANCE_SHARE := 0.2
## Width of the braid, as a share of the screen height, so it reads the same at any
## resolution rather than however many pixels wide TRIM_ART happens to be.
const TRIM_SHARE := 0.018
## Share of PANEL_ART's height taken by the scalloped hem at its bottom (the rest being
## solid fabric). The panel is scaled so that whole band hangs below the screen once the
## curtain is down, instead of letting the scene peek through the scallops.
const ART_HEM_SHARE := 0.04
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
var _panel: Texture2D
var _trim: Texture2D
var _valance: Texture2D
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
	_sheet.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the trim and pelmet tile
	_sheet.draw.connect(_draw_sheet)
	add_child(_sheet)
	_panel = _art(PANEL_ART)
	_trim = _art(TRIM_ART)
	_valance = _art(VALANCE_ART)


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
	var panel := Vector2(view.x * 0.5 + bleed, _panel_height(view.y))
	var top := -panel.y * (1.0 - _drop())
	var part := _part()
	# Both halves hang from their leading edge, which sweeps out while the fabric bunches.
	var lead := view.x * 0.5 + _settle()
	var slide := panel.x * part
	var width := Vector2(panel.x * (1.0 - GATHER * part), panel.y)
	_draw_half(Rect2(Vector2(lead - slide - width.x, top), width), false)
	_draw_half(Rect2(Vector2(lead + slide, top), width), true)
	_draw_valance(view, top, part)


## An optional art file, or null when it isn't there (the curtain paints itself then).
static func _art(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## How tall each half is drawn: enough to hide its hem below the bottom of the screen.
func _panel_height(view_height: float) -> float:
	var covered := view_height + HEM_CLEARANCE
	return covered if _panel == null else covered / (1.0 - ART_HEM_SHARE)


## One half of the curtain: the velvet, then the braid down its leading edge (the right
## edge, or the left one when `mirrored`).
func _draw_half(rect: Rect2, mirrored: bool) -> void:
	if _panel != null:
		_draw_flipped(_panel, rect, mirrored)
	else:
		_draw_pleats(rect)
		_draw_shade(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * HEAD_SHADOW)), true)
		var inner := rect.position.x if mirrored else rect.end.x - EDGE_SHADOW
		_draw_shade(Rect2(inner, rect.position.y, EDGE_SHADOW, rect.size.y), not mirrored)
	_draw_binding(rect, mirrored)


## `tex` stretched to `rect`, flipped left-to-right when `mirrored` so one painted panel
## serves both halves.
func _draw_flipped(tex: Texture2D, rect: Rect2, mirrored: bool) -> void:
	if not mirrored:
		_sheet.draw_texture_rect(tex, rect, false)
		return
	_sheet.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	_sheet.draw_texture_rect(
		tex, Rect2(-rect.end.x, rect.position.y, rect.size.x, rect.size.y), false
	)
	_sheet.draw_set_transform(Vector2.ZERO)


## The braid down a leading edge, tiled down its length and held at a constant width so it
## doesn't squash with the fabric as the half gathers.
func _draw_binding(rect: Rect2, mirrored: bool) -> void:
	if _trim == null:
		var edge := rect.position.x if mirrored else rect.end.x - TRIM_WIDTH
		_sheet.draw_rect(Rect2(edge, rect.position.y, TRIM_WIDTH, rect.size.y), Style.BRASS)
		return
	var width := _sheet.size.y * TRIM_SHARE
	var scale := width / float(_trim.get_width())
	var x := rect.position.x if mirrored else rect.end.x - width
	# Stop at the hem, or the braid dangles past the fabric while the curtain is falling.
	var length := rect.size.y * (1.0 - ART_HEM_SHARE) if _panel != null else rect.size.y
	_sheet.draw_set_transform(Vector2(x, rect.position.y), 0.0, Vector2(scale, scale))
	_sheet.draw_texture_rect(_trim, Rect2(0.0, 0.0, _trim.get_width(), length / scale), true)
	_sheet.draw_set_transform(Vector2.ZERO)


## The pelmet across the top: it hangs from the curtain's own top edge, and once the halves
## start sweeping aside it flies out of view with them.
func _draw_valance(view: Vector2, top: float, part: float) -> void:
	if _valance == null:
		return
	var scale := view.y * VALANCE_SHARE / float(_valance.get_height())
	var lift := view.y * VALANCE_SHARE * part
	_sheet.draw_set_transform(Vector2(0.0, top - lift), 0.0, Vector2(scale, scale))
	_sheet.draw_texture_rect(_valance, Rect2(0.0, 0.0, view.x / scale, _valance.get_height()), true)
	_sheet.draw_set_transform(Vector2.ZERO)


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

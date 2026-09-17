class_name LoadingCurtain
extends CanvasLayer

## A plain sheet drawn over the whole screen while a game scene loads, on a layer above
## everything — the HUD and the retro filter included.
##
## Godot builds a material's render pipeline the first time it is actually drawn, and the
## autoloaded effects (PostFX's grade, Outline's quad, PostFxLighting's environment and sun
## overrides) only latch onto a scene once it is in the tree. So the first frames of a fresh
## shop visibly settle: the grade, the outlines and the lighting snap into place one after
## the other. The curtain keeps that behind a solid colour, waits for a handful of real
## rendered frames, then fades away on a shop that already looks the way it will keep
## looking. Owned by SaveManager, which raises it before a scene swap.

## Above PostFX (100), so even the filter's own first frame is hidden.
const LAYER := 200
const COLOR := Color(0.05, 0.06, 0.12, 1.0)
## Drawn frames to wait for before revealing (pipelines compile on first draw).
const WARMUP_FRAMES := 12
## …and at least this long on top, so a slow first frame still finishes settling.
const WARMUP_SECONDS := 0.6
const FADE_SECONDS := 0.5

var _rect: ColorRect
var _fade_left := 0.0


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.color = COLOR
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func _process(delta: float) -> void:
	if _fade_left <= 0.0 or _rect == null:
		return
	_fade_left -= delta
	_rect.modulate.a = clampf(_fade_left / FADE_SECONDS, 0.0, 1.0)
	if _fade_left <= 0.0:
		visible = false


## Cover the screen at once (called before swapping scenes).
func cover() -> void:
	_fade_left = 0.0
	if _rect != null:
		_rect.modulate.a = 1.0
	visible = true


## Hold while the fresh scene draws itself into shape. Awaitable.
func warm_up(tree: SceneTree) -> void:
	for _i in WARMUP_FRAMES:
		await tree.process_frame
	await tree.create_timer(WARMUP_SECONDS).timeout


## Fade the sheet away. Awaitable: returns once the screen is clear.
func reveal() -> void:
	if not visible:
		return
	_fade_left = FADE_SECONDS
	await get_tree().create_timer(FADE_SECONDS).timeout
	visible = false

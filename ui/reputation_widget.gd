extends Control

## Minimal reputation readout under the HUD clock: just a row of stars, filled to
## the shop's current rank (1 = Unknown … up to the top tier). Reads the Reputation
## autoload and repaints on EventBus.reputation_changed with a brief brass flash.
## Purely presentational.

const STAR_ON := Color(0.82, 0.66, 0.30)  # brass
const STAR_HOT := Color(1.0, 0.86, 0.42)  # flash on a change
const STAR_OFF := Color(0.35, 0.28, 0.20, 0.55)
const STAR_R := 7.0
const STEP := 19.0
const PAD := 9.0

var _flash := 0.0
var _pill: StyleBoxFlat


func _ready() -> void:
	var count := _count()
	custom_minimum_size = Vector2(PAD * 2.0 + (count - 1) * STEP + STAR_R * 2.0, 26)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill = StyleBoxFlat.new()
	_pill.bg_color = Color(0.14, 0.10, 0.07, 0.42)
	_pill.set_corner_radius_all(13)
	EventBus.reputation_changed.connect(_on_changed)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.2, 0.0)
		queue_redraw()


func _on_changed(_points: int, _tier: int) -> void:
	_flash = 1.0
	queue_redraw()


func _draw() -> void:
	draw_style_box(_pill, Rect2(Vector2.ZERO, size))
	var filled := _filled()
	var on := STAR_ON.lerp(STAR_HOT, _flash)
	var cy := size.y * 0.5
	for i in _count():
		var c := Vector2(PAD + STAR_R + i * STEP, cy)
		draw_colored_polygon(_star(c, STAR_R), on if i < filled else STAR_OFF)


## A five-pointed star polygon centred on `c`.
func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.42
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


# --- Reputation access (safe if the autoload is absent) --------------------


func _count() -> int:
	return Reputation.TIERS.size() if Reputation != null else 5


func _filled() -> int:
	return (Reputation.tier() + 1) if Reputation != null else 1

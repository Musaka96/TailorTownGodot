extends Control

## Reputation readout under the HUD clock: a row of brass stars on an embroidered cloth
## patch (stitched edge), and the stars ARE the progress bar. One star per rank above
## "Unknown", so a new shop shows none lit; each star fills left to right as the points
## for its rank come in, and a full star means that rank is reached. Under the patch, the
## rank's name and how many points are still to go. Reads the Reputation autoload and
## repaints on EventBus.reputation_changed with a brass flash and a little bump.

const STAR_ON := Color(0.82, 0.66, 0.30)  # brass
const STAR_HOT := Color(1.0, 0.86, 0.42)  # flash on a change
const STAR_OFF := Color(0.93, 0.95, 0.96, 0.28)  # faint chalk outline stitch
const STAR_EMPTY := Color(0.0, 0.0, 0.0, 0.18)  # the unfilled part, a shade on the patch
const STAR_R := 10.0
const STEP := 25.0
const PAD := 12.0
const PATCH_H := 34.0
const TEXT_Y := 50.0  # baseline of the rank line
const NOTE_Y := 64.0  # baseline of the points-to-go line

var _flash := 0.0


func _ready() -> void:
	var count := _count()
	custom_minimum_size = Vector2(PAD * 2.0 + (count - 1) * STEP + STAR_R * 2.0, NOTE_Y + 6.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation_degrees = -2.0
	EventBus.reputation_changed.connect(_on_changed)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.2, 0.0)
		queue_redraw()


func _on_changed(_points: int, _tier: int) -> void:
	_flash = 1.0
	Craft.bump(self, 1.18)
	queue_redraw()


func _draw() -> void:
	var patch := Craft.rounded(Rect2(Vector2.ZERO, Vector2(size.x, PATCH_H)), PATCH_H * 0.5, 6)
	Craft.card(self, patch, Style.PATCH, Style.WALNUT)
	Craft.stitch(self, patch, Style.CHALK, 4.0, 1.2)
	var on := STAR_ON.lerp(STAR_HOT, _flash)
	var cy := PATCH_H * 0.5
	for i in _count():
		var c := Vector2(PAD + STAR_R + i * STEP, cy)
		var star := _star(c, STAR_R)
		var fill := _star_fill(i)
		draw_colored_polygon(star, STAR_EMPTY)
		if fill >= 1.0:
			draw_colored_polygon(star, on)
		elif fill > 0.0:
			# Clip the star to the part left of the fill line.
			var cut := c.x - STAR_R + fill * STAR_R * 2.0
			var left := PackedVector2Array(
				[
					Vector2(c.x - STAR_R - 1, cy - STAR_R - 1),
					Vector2(cut, cy - STAR_R - 1),
					Vector2(cut, cy + STAR_R + 1),
					Vector2(c.x - STAR_R - 1, cy + STAR_R + 1),
				]
			)
			for piece in Geometry2D.intersect_polygons(star, left):
				draw_colored_polygon(piece, on)
		Craft.outline(self, star, Style.WALNUT if fill >= 1.0 else STAR_OFF, 1.2)
	if Reputation != null:
		_label(Reputation.tier_name(), TEXT_Y, Style.font_bold(), Style.CHALK)
		_label(_to_go(), NOTE_Y, Style.font_body(), Style.BRASS_LIGHT)


## 0..1, how full star `i` is: star i stands for rank i + 1, and fills over the points
## between rank i and rank i + 1.
func _star_fill(i: int) -> float:
	if Reputation == null:
		return 0.0
	var tier: int = Reputation.tier()
	if i < tier:
		return 1.0
	if i > tier:
		return 0.0
	return Reputation.tier_progress()


## "12 more for Local Name", or the top rank's own line.
func _to_go() -> String:
	var next := Reputation.tier() + 1
	if next >= Reputation.TIERS.size():
		return "%d points · top of the Row" % Reputation.points
	var left := int(Reputation.TIERS[next]["at"]) - Reputation.points
	return "%d more for %s" % [left, str(Reputation.TIERS[next]["name"])]


## One outlined line of text, readable over the floor or the walls.
func _label(text: String, y: float, font: Font, col: Color) -> void:
	var at := Vector2(4.0, y)
	var ink := Style.WALNUT
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO, 4, ink)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO, col)


## A five-pointed star polygon centred on `c`.
func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.42
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


# --- Reputation access (safe if the autoload is absent) --------------------


## One star per rank above "Unknown".
func _count() -> int:
	return Reputation.TIERS.size() - 1 if Reputation != null else 4

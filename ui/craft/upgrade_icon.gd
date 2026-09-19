class_name UpgradeIcon
extends Control

## A little drawn icon for a shop upgrade: an embroidered-patch disc with a simple glyph
## (shears, oil can, coffee cup, bicycle…). Everything is drawn from Style tokens in a
## -16..16 unit box and scaled to the control, so one drawing serves the phone's list row
## and its big preview. Unknown ids fall back to a glyph for their category.

enum State { AVAILABLE, OWNED, LOCKED }

## Half the unit canvas: the glyph box is -16..16, the patch disc reaches 19.
const UNIT := 20.0
## How far a glyph may reach from the centre: just inside the stitched ring (16.2).
## A glyph that reaches further is scaled down to fit, so nothing crosses the stitching.
const FIT := 14.2

var id := "":
	set(value):
		id = value
		queue_redraw()
var state: int = State.AVAILABLE:
	set(value):
		state = value
		queue_redraw()

# The glyph palette (swapped for muted tones when the upgrade is locked).
var _light := Style.CHALK
var _brass := Style.BRASS
var _steel := Style.STEEL
var _dark := Style.WALNUT
var _warm := Style.CLAY
# While measuring, the helpers record how far the glyph reaches instead of drawing.
var _measuring := false
var _reach := 0.0


static func make(upgrade_id: String, px: float, icon_state: int = State.AVAILABLE) -> UpgradeIcon:
	var icon := UpgradeIcon.new()
	icon.id = upgrade_id
	icon.state = icon_state
	icon.custom_minimum_size = Vector2(px, px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## The state an upgrade is in right now, for the phone's rows.
static func state_of(upgrade_id: String, needs_other: bool) -> int:
	if Upgrades.has(upgrade_id):
		return State.OWNED
	if not Upgrades.tier_met(upgrade_id) or needs_other:
		return State.LOCKED
	return State.AVAILABLE


func _draw() -> void:
	var s := minf(size.x, size.y) / (UNIT * 2.0)
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	var locked := state == State.LOCKED
	_light = Style.INK_SOFT if locked else Style.CHALK
	_brass = Style.BROWN if locked else Style.BRASS
	_steel = Style.INK_SOFT if locked else Style.STEEL
	_dark = Style.BROWN if locked else Style.WALNUT
	_warm = Style.BROWN if locked else Style.CLAY
	_plate(locked)
	var k := minf(1.0, FIT / maxf(glyph_reach(), 0.001))
	draw_set_transform(size * 0.5, 0.0, Vector2(s * k, s * k))
	_glyph()
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	if state == State.OWNED:
		_badge_tick()
	elif locked:
		_badge_lock()
	draw_set_transform(Vector2.ZERO)


func _plate(locked: bool) -> void:
	draw_circle(Vector2(0, 1.5), 19.0, Style.SHADOW)
	draw_circle(Vector2.ZERO, 19.0, Style.CREAM_DARK if locked else Style.PATCH)
	draw_arc(Vector2.ZERO, 19.0, 0, TAU, 40, Style.INK_SOFT if locked else Style.WALNUT, 1.5, true)
	var thread := Style.INK_SOFT if locked else Style.tint(Style.CREAM, 0.7)
	for i in 20:
		var a := TAU * i / 20.0
		draw_arc(Vector2.ZERO, 16.2, a, a + TAU / 40.0, 4, thread, 1.0, true)


## How far this icon's glyph reaches from the centre, stroke widths included (unscaled).
func glyph_reach() -> float:
	_measuring = true
	_reach = 0.0
	_glyph()
	_measuring = false
	return _reach


func _glyph() -> void:
	var fn := "_i_" + id
	if not has_method(fn):
		fn = "_i_" + _category_fallback()
	call(fn)


func _category_fallback() -> String:
	match str(Upgrades.data(id).get("category", "")):
		"Cutting Table":
			return "cut_sharp"
		"Sewing Machine":
			return "sew_needle_down"
		"Workshop":
			return "shop_lamp"
		"Staff":
			return "apprentice"
		"Clothing Rack":
			return "rack_hooks"
	return "bulk_orders"


# --- Badges --------------------------------------------------------------------


func _badge_tick() -> void:
	var c := Vector2(12.5, 12.5)
	draw_circle(c, 6.5, Style.CARD_SELECTED)
	draw_arc(c, 6.5, 0, TAU, 20, Style.FOREST, 1.5, true)
	_line([c + Vector2(-3, 0), c + Vector2(-0.8, 2.4), c + Vector2(3.2, -2.4)], Style.FOREST, 2.0)


func _badge_lock() -> void:
	var c := Vector2(12.5, 12.5)
	draw_circle(c, 6.5, Style.CARD_SELECTED)
	draw_arc(c, 6.5, 0, TAU, 20, Style.BROWN, 1.5, true)
	draw_arc(c + Vector2(0, -1), 2.4, PI, TAU, 8, Style.BROWN, 1.5, true)
	draw_rect(Rect2(c + Vector2(-3.2, -1), Vector2(6.4, 4.8)), Style.BRASS)


# --- Drawing helpers -------------------------------------------------------------

# Every glyph draws through these, so glyph_reach() sees exactly what gets drawn.


func _grow(pts: Array, pad: float) -> void:
	for p: Vector2 in pts:
		_reach = maxf(_reach, p.length() + pad)


func _line(pts: Array, col: Color, width := 2.0) -> void:
	if _measuring:
		_grow(pts, width * 0.5)
		return
	draw_polyline(PackedVector2Array(pts), col, width, true)


func _poly(pts: Array, col: Color) -> void:
	if _measuring:
		_grow(pts, 0.0)
		return
	draw_colored_polygon(PackedVector2Array(pts), col)


func _dot(at: Vector2, rad: float, col: Color) -> void:
	if _measuring:
		_reach = maxf(_reach, at.length() + rad)
		return
	draw_circle(at, rad, col)


func _arc(
	at: Vector2, rad: float, from: float, to: float, segs: int, col: Color, width := 2.0
) -> void:
	if _measuring:
		var pts := []
		for i in segs + 1:
			var a := lerpf(from, to, float(i) / segs)
			pts.append(at + Vector2(cos(a), sin(a)) * rad)
		_grow(pts, width * 0.5)
		return
	draw_arc(at, rad, from, to, segs, col, width, true)


func _ring(at: Vector2, rad: float, col: Color, width := 2.0) -> void:
	_arc(at, rad, 0, TAU, 20, col, width)


func _dash(a: Vector2, b: Vector2, col: Color, width := 1.5, dash := 2.5) -> void:
	if _measuring:
		_grow([a, b], width * 0.5)
		return
	draw_dashed_line(a, b, col, width, dash)


func _box(r: Rect2, col: Color, rad := 2.0) -> void:
	_poly(Array(Craft.rounded(r, rad, 3)), col)


## A pair of shears, points up. `zig` gives the right blade a pinked edge.
func _shears(zig := false) -> void:
	var pivot := Vector2(0, 1)
	_line([Vector2(-5.5, 9), pivot, Vector2(6, -13)], _steel, 2.6)
	_line([Vector2(5.5, 9), pivot, Vector2(-6, -13)], _steel, 2.6)
	if zig:
		var teeth := []
		for i in 7:
			var t := 0.2 + i * 0.12
			var p := pivot.lerp(Vector2(6, -13), t)
			teeth.append(p + Vector2(1.6 if i % 2 == 0 else 3.4, 0.6))
		_line(teeth, _light, 1.4)
	_ring(Vector2(-6.5, 11), 3.6, _brass, 2.4)
	_ring(Vector2(6.5, 11), 3.6, _brass, 2.4)
	_dot(pivot, 1.6, _dark)


func _star(at: Vector2, rad: float, col: Color) -> void:
	var pts := []
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * (rad if i % 2 == 0 else rad * 0.45))
	_poly(pts, col)


## A presser foot: shank down to a flat shoe.
func _foot() -> void:
	_line([Vector2(0, -13), Vector2(0, 0)], _steel, 2.6)
	_poly([Vector2(-10, 0), Vector2(7, 0), Vector2(10, 4), Vector2(-10, 4)], _steel)


# --- Cutting table -----------------------------------------------------------------


func _i_cut_weights() -> void:
	for x: float in [-7.0, 7.0]:
		_poly(
			[Vector2(x - 6, 9), Vector2(x - 4, -1), Vector2(x + 4, -1), Vector2(x + 6, 9)],
			_brass,
		)
		_ring(Vector2(x, -4.5), 2.8, _brass, 2.0)
	_line([Vector2(-14, 10), Vector2(14, 10)], _light, 1.6)


func _i_cut_chalk_wheel() -> void:
	_line([Vector2(9, -10), Vector2(-2, 3)], _brass, 3.4)
	_dot(Vector2(-5, 6), 6.0, _light)
	_ring(Vector2(-5, 6), 6.0, _dark, 1.4)
	_dot(Vector2(-5, 6), 1.5, _dark)
	_dash(Vector2(-10, 12), Vector2(4, 12), _light, 1.4, 2.5)


func _i_cut_sharp() -> void:
	_shears()


func _i_cut_master() -> void:
	_shears()
	_star(Vector2(0, -9), 4.6, _brass)


func _i_cut_pinking() -> void:
	_shears(true)


func _i_cut_fold() -> void:
	_poly([Vector2(-12, -8), Vector2(12, -8), Vector2(12, 10), Vector2(-12, 10)], _light)
	_poly([Vector2(12, -8), Vector2(12, 10), Vector2(0, 10)], Style.CREAM_DARK)
	_dash(Vector2(0, -12), Vector2(0, 13), _warm, 1.6, 2.5)
	_line([Vector2(-5, -2), Vector2(-9, 1), Vector2(-5, 4)], _dark, 1.5)


func _i_cut_rotary() -> void:
	_line([Vector2(9, -10), Vector2(1, 0)], _brass, 3.6)
	_dot(Vector2(-3, 4), 7.0, _steel)
	_ring(Vector2(-3, 4), 7.0, _dark, 1.4)
	_dot(Vector2(-3, 4), 1.8, _brass)
	_box(Rect2(-10, 9.5, 20, 3.5), Style.TAPE if state != State.LOCKED else _light, 1.0)


# --- Sewing machine ----------------------------------------------------------------


func _i_sew_dial() -> void:
	_dot(Vector2(0, 1), 12.0, _light)
	_ring(Vector2(0, 1), 12.0, _brass, 2.2)
	for i in 5:
		var a := PI + PI * i / 4.0
		var d := Vector2(cos(a), sin(a))
		_line([Vector2(0, 1) + d * 8.0, Vector2(0, 1) + d * 10.5], _dark, 1.4)
	_line([Vector2(0, 1), Vector2(6, -6)], _warm, 2.2)
	_dot(Vector2(0, 1), 2.0, _dark)


func _i_sew_oiled() -> void:
	_poly([Vector2(-9, 11), Vector2(-7, 0), Vector2(5, 0), Vector2(7, 11)], _brass)
	_line([Vector2(-1, 0), Vector2(-1, -5), Vector2(10, -12)], _brass, 2.2)
	_poly([Vector2(12, -8), Vector2(14, -4), Vector2(12, -2.5), Vector2(10, -4)], _light)


func _i_sew_guide() -> void:
	_arc(Vector2(0, 1), 8.0, 0, PI, 16, _warm, 5.0)
	_line([Vector2(-8, 1), Vector2(-8, -6)], _warm, 5.0)
	_line([Vector2(8, 1), Vector2(8, -6)], _warm, 5.0)
	_line([Vector2(-8, -7), Vector2(-8, -11)], _steel, 5.0)
	_line([Vector2(8, -7), Vector2(8, -11)], _steel, 5.0)


func _i_sew_needle_down() -> void:
	_line([Vector2(-4, -13), Vector2(-4, 6)], _steel, 2.4)
	_poly([Vector2(-5.4, 6), Vector2(-2.6, 6), Vector2(-4, 12)], _steel)
	_dot(Vector2(-4, 3), 1.0, _dark)
	_line([Vector2(7, -8), Vector2(7, 6)], _brass, 2.4)
	_line([Vector2(3, 2), Vector2(7, 7), Vector2(11, 2)], _brass, 2.4)


func _i_sew_industrial() -> void:
	_box(Rect2(-12, -7, 20, 15), _steel, 4.0)
	_box(Rect2(8, -2.5, 6, 5), _dark, 1.0)
	_line([Vector2(-9, 11), Vector2(5, 11)], _dark, 2.4)
	_poly(
		[
			Vector2(0, -5),
			Vector2(-6, 1.5),
			Vector2(-2.5, 1.5),
			Vector2(-4, 6),
			Vector2(2.5, -0.5),
			Vector2(-1, -0.5),
		],
		_brass,
	)


func _i_sew_walking_foot() -> void:
	_foot()
	var teeth := []
	for i in 9:
		teeth.append(Vector2(-10 + i * 2.5, 8.0 if i % 2 == 0 else 11.0))
	_line(teeth, _brass, 1.8)


func _i_sew_knee() -> void:
	_line([Vector2(-11, -11), Vector2(8, -11)], _steel, 2.6)
	_line([Vector2(4, -11), Vector2(4, 3), Vector2(-5, 9)], _brass, 3.0)
	_box(Rect2(-12, 6, 8, 7), _light, 2.5)


func _i_sew_clips() -> void:
	_poly([Vector2(-12, -2), Vector2(6, -7), Vector2(11, -3), Vector2(-12, 2)], _warm)
	_poly([Vector2(-12, 2), Vector2(11, 3), Vector2(6, 8), Vector2(-12, 5)], _light)
	_dot(Vector2(-7, 1.6), 1.6, _dark)


func _i_sew_roller() -> void:
	_foot()
	for x: float in [-5.5, 4.5]:
		_dot(Vector2(x, 8.5), 3.6, _brass)
		_dot(Vector2(x, 8.5), 1.2, _dark)


func _i_sew_autolock() -> void:
	_dot(Vector2.ZERO, 11.0, _warm)
	_ring(Vector2.ZERO, 11.0, _dark, 1.5)
	_ring(Vector2.ZERO, 7.5, _light, 1.2)
	_line(
		[Vector2(-6, 2), Vector2(-3, -2), Vector2(0, 2), Vector2(3, -2), Vector2(6, 2)],
		_light,
		1.8,
	)


# --- Workshop ----------------------------------------------------------------------


func _i_shop_lamp() -> void:
	_box(Rect2(-9, 10, 14, 3), _dark, 1.0)
	_line([Vector2(-2, 10), Vector2(-7, -1), Vector2(3, -8)], _steel, 2.4)
	_poly([Vector2(1, -13), Vector2(12, -6), Vector2(8, -1), Vector2(-2, -7)], _brass)
	_poly(
		[Vector2(3, -4), Vector2(8, -1), Vector2(12, 9), Vector2(-1, 9)], Style.tint(_light, 0.35)
	)


func _i_shop_coffee() -> void:
	_poly([Vector2(-10, -2), Vector2(7, -2), Vector2(5, 11), Vector2(-8, 11)], _light)
	_arc(Vector2(7.5, 3.5), 4.0, -PI / 2.0, PI / 2.0, 10, _light, 2.2)
	_line([Vector2(-10, -2), Vector2(7, -2)], _dark, 1.6)
	for x: float in [-5.0, 1.0]:
		_line(
			[Vector2(x, -5), Vector2(x + 2, -8), Vector2(x, -11), Vector2(x + 2, -14)], _light, 1.5
		)


func _i_shop_espresso() -> void:
	_box(Rect2(-10, -6, 13, 9), _steel, 2.0)
	_line([Vector2(3, -3), Vector2(14, -3)], _dark, 3.4)
	_line([Vector2(-6, 3), Vector2(-6, 6)], _steel, 1.8)
	_line([Vector2(-1, 3), Vector2(-1, 6)], _steel, 1.8)
	_poly([Vector2(-8, 8), Vector2(1, 8), Vector2(0, 13), Vector2(-7, 13)], _light)


func _i_shop_iron() -> void:
	_poly(
		[Vector2(-13, 9), Vector2(12, 9), Vector2(12, 3), Vector2(3, -2), Vector2(-6, 0)],
		_steel,
	)
	_line([Vector2(-13, 9), Vector2(12, 9)], _dark, 2.0)
	_arc(Vector2(3, -1), 7.0, PI * 1.05, TAU * 0.98, 12, _dark, 2.8)
	for x: float in [-8.0, -3.0]:
		_line([Vector2(x, -5), Vector2(x - 1.5, -8), Vector2(x, -11)], _light, 1.4)


# --- Staff, rack, ordering ---------------------------------------------------------


func _i_apprentice() -> void:
	_dot(Vector2(0, 0), 7.5, Style.LINEN if state != State.LOCKED else _light)
	_poly([Vector2(-9, -3), Vector2(-7, -10), Vector2(6, -11), Vector2(9, -3)], _warm)
	_line([Vector2(6, -3.5), Vector2(14, -2.5)], _warm, 2.4)
	_dot(Vector2(-2.5, 1), 1.0, _dark)
	_dot(Vector2(3, 1), 1.0, _dark)
	_arc(Vector2(0.2, 2.5), 3.0, 0.3, PI - 0.3, 8, _dark, 1.2)
	_poly([Vector2(-10, 13), Vector2(-5, 8), Vector2(5, 8), Vector2(10, 13)], _light)


func _i_rack_hooks() -> void:
	_line([Vector2(-14, -9), Vector2(14, -9)], _brass, 3.0)
	for x: float in [-9.0, 0.0, 9.0]:
		_line([Vector2(x, -9), Vector2(x, 2)], _steel, 2.0)
		_arc(Vector2(x - 2.5, 2), 2.5, 0, PI, 8, _steel, 2.0)
	_line([Vector2(-5, 10), Vector2(0, 6), Vector2(5, 10), Vector2(-5, 10)], _light, 1.6)


func _i_bulk_orders() -> void:
	var cols := [_light, _warm, _brass]
	for i in 3:
		var y := 6.0 - i * 7.0
		_box(Rect2(-12 + i * 1.5, y, 22, 6.5), cols[i], 3.0)
		_dot(Vector2(10 + i * 1.5, y + 3.25), 3.25, Style.CREAM_DARK)
		_dot(Vector2(10 + i * 1.5, y + 3.25), 1.0, _dark)


func _i_courier() -> void:
	_ring(Vector2(-8, 6), 5.5, _light, 2.0)
	_ring(Vector2(8, 6), 5.5, _light, 2.0)
	_line([Vector2(-8, 6), Vector2(-3, -3), Vector2(5, -3), Vector2(0, 6), Vector2(-8, 6)], _brass)
	_line([Vector2(8, 6), Vector2(4.5, -6), Vector2(8, -7)], _brass)
	_line([Vector2(-5.5, -5), Vector2(-0.5, -5)], _dark, 2.4)
	_box(Rect2(-13, -11, 7, 6), _warm, 1.0)

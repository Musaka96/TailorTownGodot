class_name CoffeeArt

## The things on the coffee counter, drawn from the palette: a glass mug and an espresso
## glass, the filter machine and its carafe, a bean grinder, a tamper, a portafilter, and a
## single-group espresso machine. Everything is static and draws onto the CanvasItem it is
## given around its own origin — the middle of the thing's foot on the counter, y going up
## the page negative — so the caller places, scales and tilts it with draw_set_transform().
## CoffeeBench composes these into its two scenes and lays the game's marks over them.

const WALL := 5.0  # a glass's wall and floor thickness
## The grinder's dial face, relative to the grinder's foot — the grind beat's gauge.
const DIAL_AT := Vector2(0.0, -96.0)
const DIAL_R := 46.0
## Where a portafilter's basket sits when docked: in the grinder's fork, on the tamping
## mat, and locked into the machine's group head (each relative to that thing's foot).
const FORK_AT := Vector2(0.0, -30.0)
const MAT_AT := Vector2(0.0, -22.0)
const GROUP_AT := Vector2(-24.0, -146.0)
## Where the espresso glass stands on the machine's drip tray.
const TRAY_AT := Vector2(-24.0, -34.0)
const SHOT_GLASS := Vector3(70.0, 54.0, 72.0)  # top width, bottom width, height
const MUG := Vector3(124.0, 96.0, 118.0)

# --- Vessels -----------------------------------------------------------------


static func coffee() -> Color:
	return Style.WALNUT.darkened(0.4)


## A glass, `dims` = (top width, bottom width, height), filled to `level` (0..1 of its
## inside). Glass so the pour can be read from the side.
static func glass(c: CanvasItem, dims: Vector3, level: float, handle := false) -> void:
	var top := dims.x * 0.5
	var bot := dims.y * 0.5
	var h := dims.z
	if handle:
		var grip := Vector2(top - 3.0, -h * 0.52)
		c.draw_arc(grip, h * 0.27, -PI * 0.5, PI * 0.5, 16, Style.STEEL_DARK, 11.0, true)
		c.draw_arc(grip, h * 0.27, -PI * 0.5, PI * 0.5, 16, Style.CHALK, 6.0, true)
	var outer := PackedVector2Array(
		[Vector2(-top, -h), Vector2(top, -h), Vector2(bot, 0.0), Vector2(-bot, 0.0)]
	)
	c.draw_colored_polygon(outer, Style.tint(Style.CHALK, 0.6))
	if level > 0.0:
		var y := level_y(dims, level)
		var at_top := half_at(dims, y) - WALL
		var at_bot := bot - WALL
		var drink := PackedVector2Array(
			[
				Vector2(-at_top, y),
				Vector2(at_top, y),
				Vector2(at_bot, -WALL),
				Vector2(-at_bot, -WALL)
			]
		)
		c.draw_colored_polygon(drink, coffee())
		var crema := minf(5.0, -WALL - y)
		c.draw_line(
			Vector2(-at_top, y + crema * 0.5), Vector2(at_top, y + crema * 0.5), Style.LINEN, crema
		)
	Craft.outline(c, outer, Style.STEEL_DARK, 2.5)
	c.draw_line(Vector2(-top, -h), Vector2(top, -h), Style.STEEL_DARK, 4.0, true)
	var shine := Style.tint(Style.CHALK, 0.85)
	c.draw_line(Vector2(-top + 9.0, -h + 12.0), Vector2(-bot + 8.0, -14.0), shine, 3.0, true)


## The y of a fill level inside a glass, and the glass's half-width at a y.
static func level_y(dims: Vector3, level: float) -> float:
	return lerpf(-WALL, -dims.z, clampf(level, 0.0, 1.0))


static func half_at(dims: Vector3, y: float) -> float:
	return lerpf(dims.y, dims.x, clampf(-y / dims.z, 0.0, 1.0)) * 0.5


## The fill line on a glass: the good band, the perfect band inside it, and a brass line
## that overhangs either side and ends in a tick, so it reads without the green.
static func fill_mark(c: CanvasItem, dims: Vector3, mark: float, good: float, fine: float) -> void:
	var y := level_y(dims, mark)
	var span := dims.z - WALL
	var w := half_at(dims, y) - WALL
	c.draw_rect(
		Rect2(-w, y - good * span, w * 2.0, good * span * 2.0), Style.tint(Style.FOREST, 0.28)
	)
	c.draw_rect(
		Rect2(-w, y - fine * span, w * 2.0, fine * span * 2.0), Style.tint(Style.FOREST, 0.5)
	)
	var reach := w + WALL + 12.0
	c.draw_line(Vector2(-reach, y), Vector2(reach, y), Style.BRASS, 3.0, true)
	for side in [-1.0, 1.0]:
		c.draw_line(
			Vector2(reach * side, y - 6.0), Vector2(reach * side, y + 6.0), Style.BRASS, 3.0
		)


## Coffee over the rim: runs down both sides and pools at the foot.
static func spill(c: CanvasItem, dims: Vector3) -> void:
	var top := dims.x * 0.5
	var bot := dims.y * 0.5
	for side in [-1.0, 1.0]:
		var run := PackedVector2Array(
			[
				Vector2(top * side, -dims.z),
				Vector2((top + 5.0) * side, -dims.z * 0.5),
				Vector2((bot + 8.0) * side, 0.0)
			]
		)
		c.draw_polyline(run, coffee(), 5.0, true)
	var pool := Rect2(-bot - 26.0, -4.0, (bot + 26.0) * 2.0, 8.0)
	c.draw_colored_polygon(Craft.rounded(pool, 4.0), coffee())


static func saucer(c: CanvasItem, width: float) -> void:
	var plate := Craft.rounded(Rect2(-width * 0.5, -9.0, width, 9.0), 4.5)
	c.draw_colored_polygon(plate, Style.CARD)
	Craft.outline(c, plate, Style.BROWN, 2.0)
	c.draw_line(Vector2(-width * 0.3, 0.0), Vector2(width * 0.3, 0.0), Style.BROWN, 3.0, true)


## Steam curling off a finished cup; `time` keeps it moving.
static func steam(c: CanvasItem, at: Vector2, time: float) -> void:
	for k in 3:
		var wisp := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			var sway := sin(t * 5.0 + time * 2.0 + k * 2.1) * (4.0 + t * 7.0)
			wisp.append(at + Vector2((k - 1) * 16.0 + sway, -t * 44.0))
		c.draw_polyline(wisp, Style.tint(Style.CHALK, 0.55), 3.0, true)


# --- The filter machine and its carafe ---------------------------------------


## The carafe, drawn around the tip of its SPOUT (so it tilts about the pour). `tilt` is the
## angle the caller has turned it by: the coffee inside stays level with the counter.
static func carafe(c: CanvasItem, tilt: float) -> void:
	var globe := Vector2(-72.0, 50.0)
	var r := 56.0
	var grip := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		grip.append(
			Vector2(-108.0, -6.0).bezier_interpolate(
				Vector2(-172.0, -14.0), Vector2(-176.0, 84.0), Vector2(-122.0, 82.0), t
			)
		)
	c.draw_polyline(grip, Style.INK, 13.0, true)
	c.draw_circle(globe, r, Style.tint(Style.CHALK, 0.55))
	# The coffee: the part of the globe below a level line, whichever way it is tipped.
	var inner := r - 4.0
	var a0 := asin(clampf(6.0 / inner, -1.0, 1.0))
	var drink := PackedVector2Array()
	for i in 25:
		var world := lerpf(a0, PI - a0, i / 24.0)
		drink.append(globe + Vector2(cos(world - tilt), sin(world - tilt)) * inner)
	c.draw_colored_polygon(drink, coffee())
	c.draw_arc(globe, r, 0.0, TAU, 40, Style.STEEL_DARK, 2.5, true)
	c.draw_arc(globe, r - 9.0, PI * 1.05, PI * 1.45, 10, Style.tint(Style.CHALK, 0.9), 4.0, true)
	var collar := Craft.rounded(Rect2(-108.0, -16.0, 72.0, 22.0), 5.0)
	c.draw_colored_polygon(collar, Style.INK)
	var lip := PackedVector2Array([Vector2(-40.0, -14.0), Vector2(0.0, 0.0), Vector2(-38.0, 6.0)])
	c.draw_colored_polygon(lip, Style.INK)
	c.draw_colored_polygon(Craft.rounded(Rect2(-84.0, -25.0, 24.0, 10.0), 4.0), Style.INK)
	c.draw_line(Vector2(-106.0, 5.0), Vector2(-38.0, 5.0), Style.BRASS, 2.5, true)


## The filter machine the carafe came off: tower, reservoir, filter cone, empty hot plate.
static func filter_machine(c: CanvasItem) -> void:
	var shell := Style.INK.lightened(0.12)
	c.draw_colored_polygon(Craft.rounded(Rect2(-84.0, -18.0, 168.0, 18.0), 6.0), shell)
	c.draw_rect(Rect2(-52.0, -24.0, 116.0, 6.0), Style.STEEL_DARK)
	c.draw_colored_polygon(Craft.rounded(Rect2(-84.0, -196.0, 46.0, 182.0), 8.0), shell)
	c.draw_colored_polygon(Craft.rounded(Rect2(-84.0, -214.0, 168.0, 56.0), 12.0), shell)
	c.draw_line(Vector2(-72.0, -170.0), Vector2(72.0, -170.0), Style.BRASS, 2.5, true)
	var cone := PackedVector2Array(
		[
			Vector2(-34.0, -158.0),
			Vector2(62.0, -158.0),
			Vector2(30.0, -118.0),
			Vector2(-2.0, -118.0)
		]
	)
	c.draw_colored_polygon(cone, Style.INK)
	c.draw_rect(Rect2(10.0, -118.0, 8.0, 8.0), Style.STEEL_DARK)
	c.draw_circle(Vector2(-61.0, -60.0), 5.0, Style.AMBER)
	c.draw_line(Vector2(-72.0, -188.0), Vector2(-72.0, -40.0), Style.tint(Style.CHALK, 0.12), 4.0)


# --- The espresso kit --------------------------------------------------------


## The bean grinder: a glass hopper of beans over a steel-fronted body whose dial is the
## grind gauge (left blank here — the game draws the band and needle on it), a chute, and
## the fork the portafilter docks in. `shake` > 0 rattles the beans while it runs.
static func grinder(c: CanvasItem, shake: float) -> void:
	var shell := Style.INK.lightened(0.1)
	c.draw_colored_polygon(Craft.rounded(Rect2(-74.0, -10.0, 148.0, 10.0), 4.0), Style.INK)
	var body := Craft.rounded(Rect2(-66.0, -158.0, 132.0, 150.0), 14.0)
	c.draw_colored_polygon(body, shell)
	Craft.outline(c, body, Style.INK, 2.0)
	c.draw_colored_polygon(Craft.rounded(Rect2(-48.0, -58.0, 96.0, 50.0), 8.0), Style.INK)
	c.draw_rect(Rect2(-9.0, -60.0, 18.0, 16.0), Style.STEEL)
	c.draw_line(Vector2(-34.0, -20.0), Vector2(34.0, -20.0), Style.STEEL_DARK, 5.0, true)
	var hopper := PackedVector2Array(
		[
			Vector2(-58.0, -236.0),
			Vector2(58.0, -236.0),
			Vector2(30.0, -158.0),
			Vector2(-30.0, -158.0)
		]
	)
	c.draw_colored_polygon(hopper, Style.tint(Style.CHALK, 0.5))
	for i in 26:
		var row := i / 26.0
		var y := lerpf(-164.0, -214.0, row)
		var reach := lerpf(24.0, 46.0, row)
		var x := sin(i * 12.9898) * reach + sin(shake * 40.0 + i) * minf(shake, 1.0) * 2.0
		c.draw_circle(Vector2(x, y), 5.0, Style.BROWN.darkened(0.25 + 0.2 * sin(i * 3.1)))
	Craft.outline(c, hopper, Style.STEEL_DARK, 2.5)
	c.draw_colored_polygon(Craft.rounded(Rect2(-62.0, -246.0, 124.0, 12.0), 5.0), Style.INK)
	c.draw_circle(DIAL_AT, DIAL_R + 6.0, Style.STEEL_DARK)
	c.draw_circle(DIAL_AT, DIAL_R + 3.0, Style.STEEL)
	c.draw_circle(DIAL_AT, DIAL_R, Style.CARD)


## The tamper, drawn around the middle of its pressing face.
static func tamper(c: CanvasItem) -> void:
	c.draw_rect(Rect2(-7.0, -30.0, 14.0, 20.0), Style.STEEL_DARK)
	var base := Craft.rounded(Rect2(-27.0, -12.0, 54.0, 12.0), 3.0)
	c.draw_colored_polygon(base, Style.STEEL)
	Craft.outline(c, base, Style.STEEL_DARK, 1.5)
	var knob := Craft.rounded(Rect2(-21.0, -68.0, 42.0, 40.0), 16.0)
	c.draw_colored_polygon(knob, Style.WALNUT)
	Craft.outline(c, knob, Style.WALNUT.darkened(0.3), 2.0)
	c.draw_line(
		Vector2(-10.0, -60.0), Vector2(6.0, -62.0), Style.tint(Style.CREAM, 0.35), 3.0, true
	)


static func tamp_mat(c: CanvasItem) -> void:
	c.draw_colored_polygon(Craft.rounded(Rect2(-82.0, -9.0, 164.0, 9.0), 4.0), Style.INK)
	c.draw_line(Vector2(-70.0, -9.0), Vector2(70.0, -9.0), Style.tint(Style.CHALK, 0.2), 2.0)


## A portafilter around the middle of its basket, handle to the left. `heap` is how much
## loose coffee is mounded in it (0..1); `puck` > 0 shows it tamped flat instead.
static func portafilter(c: CanvasItem, heap: float, puck: bool) -> void:
	var handle_end := Vector2(-118.0, 7.0)
	c.draw_line(Vector2(-34.0, 0.0), handle_end, Style.INK, 15.0, true)
	c.draw_circle(handle_end, 7.5, Style.INK)
	c.draw_line(
		Vector2(-108.0, 3.0), Vector2(-60.0, -1.0), Style.tint(Style.CHALK, 0.18), 3.0, true
	)
	c.draw_rect(Rect2(-50.0, -6.0, 16.0, 12.0), Style.STEEL)
	if puck:
		c.draw_rect(Rect2(-27.0, -11.0, 54.0, 5.0), Style.BROWN.darkened(0.35))
	elif heap > 0.0:
		var mound := PackedVector2Array([Vector2(-28.0, -9.0)])
		for i in 9:
			var t := i / 8.0
			mound.append(Vector2(lerpf(-28.0, 28.0, t), -9.0 - sin(t * PI) * 16.0 * heap))
		mound.append(Vector2(28.0, -9.0))
		c.draw_colored_polygon(mound, Style.BROWN.darkened(0.3))
	var basket := PackedVector2Array(
		[Vector2(-32.0, -10.0), Vector2(32.0, -10.0), Vector2(26.0, 11.0), Vector2(-26.0, 11.0)]
	)
	c.draw_colored_polygon(basket, Style.STEEL)
	Craft.outline(c, basket, Style.STEEL_DARK, 2.0)
	c.draw_rect(Rect2(-37.0, -12.0, 74.0, 5.0), Style.STEEL_DARK)
	c.draw_line(Vector2(-22.0, -3.0), Vector2(-19.0, 7.0), Style.CHALK, 2.5, true)
	c.draw_rect(Rect2(-12.0, 11.0, 24.0, 5.0), Style.STEEL_DARK)
	for side in [-1.0, 1.0]:
		c.draw_line(Vector2(9.0 * side, 14.0), Vector2(9.0 * side, 22.0), Style.STEEL_DARK, 5.0)


## A single-group espresso machine, front on: drip tray, a dark back panel, the polished
## head with its group, a pressure gauge (`needle` 0..1), a lever, a steam wand, and cups
## warming on the rail on top.
static func machine(c: CanvasItem, needle: float) -> void:
	for side in [-1.0, 1.0]:
		c.draw_rect(Rect2(98.0 * side - 12.0, -6.0, 24.0, 6.0), Style.INK)
	c.draw_rect(Rect2(-116.0, -172.0, 232.0, 142.0), Style.INK.lightened(0.06))
	var tray := Craft.rounded(Rect2(-128.0, -36.0, 256.0, 30.0), 6.0)
	c.draw_colored_polygon(tray, Style.STEEL)
	Craft.outline(c, tray, Style.STEEL_DARK, 2.0)
	var x := -112.0
	while x < 112.0:
		c.draw_line(Vector2(x, -33.0), Vector2(x + 10.0, -33.0), Style.STEEL_DARK, 3.0)
		x += 16.0
	var head := Craft.rounded(Rect2(-128.0, -272.0, 256.0, 102.0), 16.0)
	c.draw_colored_polygon(head, Style.STEEL)
	c.draw_rect(Rect2(-120.0, -262.0, 240.0, 12.0), Style.tint(Style.CHALK, 0.55))
	c.draw_rect(Rect2(-120.0, -194.0, 240.0, 18.0), Style.tint(Style.STEEL_DARK, 0.35))
	Craft.outline(c, head, Style.STEEL_DARK, 2.5)
	c.draw_line(Vector2(-116.0, -202.0), Vector2(116.0, -202.0), Style.BRASS, 2.5, true)
	# The group head, and the lever that opens it.
	var group := Craft.rounded(Rect2(GROUP_AT.x - 40.0, -178.0, 80.0, 24.0), 5.0)
	c.draw_colored_polygon(group, Style.STEEL_DARK)
	c.draw_rect(Rect2(GROUP_AT.x - 34.0, -160.0, 68.0, 6.0), Style.INK)
	c.draw_line(
		Vector2(GROUP_AT.x, -226.0), Vector2(GROUP_AT.x + 26.0, -252.0), Style.STEEL_DARK, 6.0, true
	)
	c.draw_circle(Vector2(GROUP_AT.x + 26.0, -252.0), 9.0, Style.WALNUT)
	c.draw_circle(Vector2(GROUP_AT.x, -226.0), 8.0, Style.STEEL_DARK)
	# Pressure gauge.
	var dial := Vector2(78.0, -226.0)
	c.draw_circle(dial, 25.0, Style.RIM_DARK)
	c.draw_circle(dial, 22.0, Style.BRASS)
	c.draw_circle(dial, 18.0, Style.CARD)
	c.draw_arc(dial, 14.0, PI * 1.55, PI * 2.1, 8, Style.tint(Style.FOREST, 0.6), 4.0)
	var swing := lerpf(PI * 0.8, PI * 2.05, clampf(needle, 0.0, 1.0))
	c.draw_line(dial, dial + Vector2(cos(swing), sin(swing)) * 15.0, Style.CLAY, 2.5, true)
	c.draw_circle(dial, 3.0, Style.INK)
	c.draw_circle(Vector2(-96.0, -226.0), 6.0, Style.AMBER if needle > 0.05 else Style.RIM_DARK)
	# Steam wand, and the cups warming on the rail.
	var wand := PackedVector2Array(
		[Vector2(112.0, -176.0), Vector2(112.0, -130.0), Vector2(132.0, -56.0)]
	)
	c.draw_polyline(wand, Style.STEEL_DARK, 6.0, true)
	c.draw_polyline(wand, Style.STEEL, 3.0, true)
	c.draw_circle(wand[2], 5.0, Style.INK)
	c.draw_line(Vector2(-120.0, -282.0), Vector2(120.0, -282.0), Style.BRASS, 3.0, true)
	for side in [-1.0, 1.0]:
		c.draw_line(Vector2(118.0 * side, -282.0), Vector2(118.0 * side, -272.0), Style.BRASS, 3.0)
	for at in [-84.0, -44.0, 40.0]:
		var cup := PackedVector2Array(
			[
				Vector2(at - 15.0, -272.0),
				Vector2(at + 15.0, -272.0),
				Vector2(at + 11.0, -294.0),
				Vector2(at - 11.0, -294.0)
			]
		)
		c.draw_colored_polygon(cup, Style.CARD)
		Craft.outline(c, cup, Style.BROWN, 1.5)

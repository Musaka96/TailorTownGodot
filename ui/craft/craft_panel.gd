class_name CraftPanel
extends PanelContainer

## A container that draws itself as a hand-made object (see Craft) instead of a flat
## rounded box: a swing ticket, a price tag, pinked cloth, a sewn patch or a plain
## rounded card — with optional stitching, eyelet + string, push-pin and a tilt.
## Content margins come from `pad` (plus room for the eyelet/point), so children lay out
## inside the silhouette. The card hugs its content (never keeps a stale tall size).

enum Shape { ROUNDED, TICKET, PRICE_TAG, PINKED, PATCH }

var shape: int = Shape.ROUNDED
var fill := Style.CREAM:
	set(v):
		fill = v
		queue_redraw()
var line := Style.WALNUT:
	set(v):
		line = v
		queue_redraw()
var stitch_color := Color(0, 0, 0, 0)  # transparent = no stitching
var pin_color := Color(0, 0, 0, 0)  # transparent = no push-pin
var eyelet := false  # brass eyelet (top centre, or the tag's point)
var string_len := 0.0  # string rising from the eyelet
var radius := 12.0
var pad := Vector2(Style.S3, Style.S2)
var line_width := 2.0
## How far round the stitching is drawn (0..1) — animated by Craft.flourish's sew-in.
var stitch_progress := 1.0:
	set(v):
		stitch_progress = v
		queue_redraw()
var sway := 0.0:  # string sway (animated by callers)
	set(v):
		sway = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## A selectable option card used across the menus: plain cream label normally; when
## selected it brightens, takes the menu's `accent` outline and a matching stitch, and
## gives a small flourish (see Craft.flourish — it varies so scrolling doesn't repeat).
static func option(selected: bool, accent: Color) -> CraftPanel:
	var card := CraftPanel.new()
	card.pad = Vector2(Style.S3, Style.S2)
	card.setup(Shape.ROUNDED, Style.CARD)
	card.set_option_selected(selected, accent)
	if selected:
		card.ready.connect(func() -> void: Craft.flourish(card), CONNECT_ONE_SHOT)
	return card


## Re-style an existing option card in place. Lets a menu move its selection without
## rebuilding the list — a rebuild makes the panel resize for a frame (queue_free is
## deferred), which jolts anything positioned off it.
func set_option_selected(selected: bool, accent: Color, animate := false) -> void:
	fill = Style.CARD_SELECTED if selected else Style.CARD
	line = accent if selected else Style.CREAM_DARK
	line_width = 3.0 if selected else 1.5
	stitch_color = accent if selected else Style.NONE
	stitch_progress = 1.0
	queue_redraw()
	if selected and animate and is_inside_tree():
		Craft.flourish(self)


## Configure in one call; returns self for chaining.
func setup(shape_val: int, fill_col: Color, line_col: Color = Style.WALNUT) -> CraftPanel:
	shape = shape_val
	fill = fill_col
	line = line_col
	_apply_margins()
	queue_redraw()
	return self


func _ready() -> void:
	_apply_margins()


func _process(_delta: float) -> void:
	var want := get_combined_minimum_size()
	if size.y > want.y + 0.5:
		size.y = want.y


func _apply_margins() -> void:
	var sb := StyleBoxEmpty.new()
	var left := pad.x
	var top := pad.y
	if shape == Shape.PRICE_TAG:
		left += 18.0  # the point + eyelet
	elif shape == Shape.TICKET and eyelet:
		top += 22.0
	elif shape == Shape.PINKED:
		top += 5.0
	sb.content_margin_left = left
	sb.content_margin_right = pad.x
	sb.content_margin_top = top
	sb.content_margin_bottom = pad.y + (5.0 if shape == Shape.PINKED else 0.0)
	add_theme_stylebox_override("panel", sb)


func polygon() -> PackedVector2Array:
	var r := Rect2(Vector2.ZERO, size)
	match shape:
		Shape.TICKET:
			return Craft.ticket(r)
		Shape.PRICE_TAG:
			return Craft.price_tag(r)
		Shape.PINKED:
			return Craft.pinked(r)
		_:
			return Craft.rounded(r, radius)


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var poly := polygon()
	Craft.card(self, poly, fill, line, line_width)
	if stitch_color.a > 0.0:
		var inset := 5.0 if shape == Shape.PATCH else 6.0
		Craft.stitch(self, poly, stitch_color, inset, 1.5, stitch_progress)
	if eyelet:
		var at := Vector2(size.x * 0.5, 14.0)
		if shape == Shape.PRICE_TAG:
			at = Vector2(13.0, size.y * 0.5)
		Craft.eyelet(self, at, string_len, sway)
	if pin_color.a > 0.0:
		Craft.pin(self, Vector2(size.x * 0.5, 9.0), pin_color)

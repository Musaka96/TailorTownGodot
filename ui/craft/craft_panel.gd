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
var sway := 0.0:  # string sway (animated by callers)
	set(v):
		sway = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


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
		Craft.stitch(self, poly, stitch_color, 5.0 if shape == Shape.PATCH else 6.0)
	if eyelet:
		var at := Vector2(size.x * 0.5, 14.0)
		if shape == Shape.PRICE_TAG:
			at = Vector2(13.0, size.y * 0.5)
		Craft.eyelet(self, at, string_len, sway)
	if pin_color.a > 0.0:
		Craft.pin(self, Vector2(size.x * 0.5, 9.0), pin_color)

class_name AtelierFrame
extends Control

## Decorative bespoke-tailoring frame drawn over a menu panel: a dashed "stitch"
## line just inside the edge, little chalk corner ticks, and a per-menu motif
## (a measuring-tape ruler, a book ribbon, …) in the skin accent. Transparent
## centre, ignores the mouse — purely presentational. Lay it full-rect over the
## panel with add_child(); it repaints itself when resized.

enum Motif { NONE, TAPE, BOOK, BOLT, MIRROR, TOOLS, BOARD }

const INSET := 9.0
const CORNER := 16.0
const CHALK_R := 0.933
const CHALK_G := 0.949
const CHALK_B := 0.957

var accent := Color("c9a24a")
var trim := Color("4a3826")
var motif: int = Motif.NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func setup(accent_col: Color, trim_col: Color, motif_val: int) -> void:
	accent = accent_col
	trim = trim_col
	motif = motif_val
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_draw_stitch(r)
	_draw_corner_ticks(r)
	_draw_motif(r)


## Dashed accent line just inside each edge, stopping short of the rounded corners.
func _draw_stitch(r: Rect2) -> void:
	var a := Color(accent.r, accent.g, accent.b, 0.75)
	var lo := r.position + Vector2(INSET, INSET)
	var hi := r.end - Vector2(INSET, INSET)
	var c := CORNER
	draw_dashed_line(Vector2(lo.x + c, lo.y), Vector2(hi.x - c, lo.y), a, 2.0, 5.0)
	draw_dashed_line(Vector2(lo.x + c, hi.y), Vector2(hi.x - c, hi.y), a, 2.0, 5.0)
	draw_dashed_line(Vector2(lo.x, lo.y + c), Vector2(lo.x, hi.y - c), a, 2.0, 5.0)
	draw_dashed_line(Vector2(hi.x, lo.y + c), Vector2(hi.x, hi.y - c), a, 2.0, 5.0)


## Short chalk strokes tucked into each corner, like a tailor's registration mark.
func _draw_corner_ticks(r: Rect2) -> void:
	var ch := Color(CHALK_R, CHALK_G, CHALK_B, 0.9)
	var lo := r.position + Vector2(INSET, INSET)
	var hi := r.end - Vector2(INSET, INSET)
	var d := 9.0
	# Each corner: a small L of two strokes.
	draw_line(Vector2(lo.x, lo.y + d), Vector2(lo.x, lo.y), ch, 2.0)
	draw_line(Vector2(lo.x, lo.y), Vector2(lo.x + d, lo.y), ch, 2.0)
	draw_line(Vector2(hi.x - d, lo.y), Vector2(hi.x, lo.y), ch, 2.0)
	draw_line(Vector2(hi.x, lo.y), Vector2(hi.x, lo.y + d), ch, 2.0)
	draw_line(Vector2(lo.x, hi.y - d), Vector2(lo.x, hi.y), ch, 2.0)
	draw_line(Vector2(lo.x, hi.y), Vector2(lo.x + d, hi.y), ch, 2.0)
	draw_line(Vector2(hi.x - d, hi.y), Vector2(hi.x, hi.y), ch, 2.0)
	draw_line(Vector2(hi.x, hi.y - d), Vector2(hi.x, hi.y), ch, 2.0)


func _draw_motif(r: Rect2) -> void:
	match motif:
		Motif.TAPE:
			_motif_tape(r)
		Motif.BOOK:
			_motif_book(r)
		_:
			pass


## Measuring-tape ruler along the top inner edge (order pad).
func _motif_tape(r: Rect2) -> void:
	var a := Color(accent.r, accent.g, accent.b, 0.65)
	var y := r.position.y + INSET + 8.0
	var x0 := r.position.x + INSET + CORNER + 6.0
	var x1 := r.end.x - INSET - CORNER - 6.0
	var x := x0
	var i := 0
	while x < x1:
		var h := 9.0 if i % 5 == 0 else 5.0
		draw_line(Vector2(x, y), Vector2(x, y + h), a, 1.5)
		x += 10.0
		i += 1


## A ribbon bookmark hanging from the top edge (handbook).
func _motif_book(r: Rect2) -> void:
	var a := Color(accent.r, accent.g, accent.b, 0.9)
	var x := r.end.x - INSET - 46.0
	var w := 16.0
	var top := r.position.y + INSET
	var bot := top + 52.0
	draw_rect(Rect2(Vector2(x, top), Vector2(w, bot - top)), a, true)
	# Notched (swallowtail) bottom.
	var pts := PackedVector2Array(
		[
			Vector2(x, bot),
			Vector2(x + w * 0.5, bot - 8.0),
			Vector2(x + w, bot),
			Vector2(x + w, bot + 8.0),
			Vector2(x + w * 0.5, bot),
			Vector2(x, bot + 8.0),
		]
	)
	draw_colored_polygon(pts, a)

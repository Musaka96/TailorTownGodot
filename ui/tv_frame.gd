class_name TvFrame
extends Control

## A cute little retro-TV frame: a rounded bezel with rabbit-ear antennae, two dials
## and a power light, wrapping a live screen (a TextureRect set via set_screen_texture).
## Used for the customer portrait in the greeting speech bubble.

const ANTENNA_H := 18.0
const SCREEN_INSET := 13.0
const CHIN := 14.0  # extra bezel below the screen for the dials/light

var _screen: TextureRect


func _ready() -> void:
	_ensure_screen()
	_relayout()


func set_screen_texture(tex: Texture2D) -> void:
	_ensure_screen()
	_screen.texture = tex


func screen_rect() -> Rect2:
	var bezel_top := ANTENNA_H
	var side := SCREEN_INSET
	var w := size.x - side * 2.0
	var h := size.y - bezel_top - side - CHIN
	return Rect2(side, bezel_top + side, maxf(w, 1.0), maxf(h, 1.0))


func _ensure_screen() -> void:
	if _screen != null:
		return
	_screen = TextureRect.new()
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.clip_contents = true
	add_child(_screen)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _relayout() -> void:
	if _screen != null:
		var r := screen_rect()
		_screen.position = r.position
		_screen.size = r.size
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var dark := Style.BROWN.darkened(0.35)
	# Rabbit-ear antennae poking up behind the bezel.
	draw_line(Vector2(cx - 6, ANTENNA_H), Vector2(cx - 26, 1), dark, 3.0, true)
	draw_line(Vector2(cx + 6, ANTENNA_H), Vector2(cx + 26, 1), dark, 3.0, true)
	draw_circle(Vector2(cx - 26, 1), 3.0, dark)
	draw_circle(Vector2(cx + 26, 1), 3.0, dark)

	# The TV body (rounded bezel) with a soft top highlight.
	var body := Rect2(0, ANTENNA_H, size.x, size.y - ANTENNA_H)
	var bezel := StyleBoxFlat.new()
	bezel.bg_color = Style.BROWN
	bezel.set_corner_radius_all(16)
	bezel.border_width_top = 2
	bezel.border_color = Style.BROWN.lightened(0.18)
	draw_style_box(bezel, body)

	# The screen recess (a touch bigger than the picture, so it frames it).
	var r := screen_rect().grow(3.0)
	var recess := StyleBoxFlat.new()
	recess.bg_color = Color(0.09, 0.10, 0.13)
	recess.set_corner_radius_all(7)
	draw_style_box(recess, r)

	# Two dials and a power light on the chin, to the right.
	var chin_y := body.end.y - CHIN * 0.5
	draw_circle(Vector2(size.x - 20, chin_y), 4.0, dark)
	draw_circle(Vector2(size.x - 34, chin_y), 4.0, dark)
	draw_circle(Vector2(18, chin_y), 3.5, Color(0.45, 0.85, 0.45))

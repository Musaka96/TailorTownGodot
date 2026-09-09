extends SceneTree

## Generates cute PLACEHOLDER face sprites (res://assets/textures/faces/*.png) so the
## animated 2D face works in-game immediately. These are simple flat shapes drawn in
## code — swap them for hand-drawn art (or sliced from a face kit) at the same paths
## and filenames and nothing else needs to change.
##   godot --headless --path . --script res://tools/build_faces.gd
##
## Files: eyes_open, eyes_blink (eyes + brows); mouth_closed, mouth_mid, mouth_open.

const OUT_DIR := "res://assets/textures/faces"

const INK := Color(0.16, 0.13, 0.11)
const HILITE := Color(0.98, 0.98, 0.98)
const LIP := Color(0.55, 0.24, 0.24)
const MOUTH_IN := Color(0.42, 0.18, 0.20)


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_save(_eyes(false), "eyes_open")
	_save(_eyes(true), "eyes_blink")
	_save(_mouth(0), "mouth_closed")
	_save(_mouth(1), "mouth_mid")
	_save(_mouth(2), "mouth_open")
	print("wrote face sprites to ", OUT_DIR)
	quit(0)


# --- Faces ------------------------------------------------------------------


## Eyes + brows. Open = round eyes with a highlight; blink = gentle downward lashes.
func _eyes(closed: bool) -> Image:
	var img := _new(100, 64)
	for cx in [30, 70]:
		# Brow: a soft arch above the eye.
		_curve(img, cx - 14, cx + 14, cx, 16, -5.0, 2.4, INK)
		if closed:
			_curve(img, cx - 12, cx + 12, cx, 42, -4.0, 2.6, INK)
		else:
			_disc_ellipse(img, cx, 40, 11, 14, INK)
			_disc_ellipse(img, cx + 3, 35, 3, 3, HILITE)
	return img


## Mouth states for the talk flap: 0 closed smile, 1 small open, 2 wide open.
func _mouth(state: int) -> Image:
	var img := _new(64, 44)
	match state:
		0:
			_curve(img, 18, 46, 32, 18, 7.0, 2.6, INK)
		1:
			_disc_ellipse(img, 32, 24, 8, 6, MOUTH_IN)
			_disc_ellipse(img, 32, 22, 8, 3, LIP)
		2:
			_disc_ellipse(img, 32, 24, 12, 10, MOUTH_IN)
			_disc_ellipse(img, 32, 30, 8, 4, LIP)
	return img


# --- Tiny raster helpers ----------------------------------------------------


func _new(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Filled ellipse centred at (cx, cy) with radii (rx, ry).
func _disc_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in range(maxi(cy - ry, 0), mini(cy + ry + 1, img.get_height())):
		for x in range(maxi(cx - rx, 0), mini(cx + rx + 1, img.get_width())):
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, col)


## A quadratic stroke from x0..x1 bowing by `amp` (px, +down) about centre `cx`,
## stamped with discs of radius `thick` — for brows, lashes and the smile.
func _curve(
	img: Image, x0: int, x1: int, cx: int, base_y: int, amp: float, thick: float, c: Color
) -> void:
	var half := maxf(float(x1 - cx), float(cx - x0))
	for x in range(x0, x1 + 1):
		var t := float(x - cx) / half
		var y := base_y + amp * (1.0 - t * t)
		_stamp(img, x, int(round(y)), thick, c)


func _stamp(img: Image, cx: int, cy: int, r: float, col: Color) -> void:
	var ri := int(ceil(r))
	for y in range(maxi(cy - ri, 0), mini(cy + ri + 1, img.get_height())):
		for x in range(maxi(cx - ri, 0), mini(cx + ri + 1, img.get_width())):
			if Vector2(x - cx, y - cy).length() <= r:
				img.set_pixel(x, y, col)


func _save(img: Image, name: String) -> void:
	var path := "%s/%s.png" % [OUT_DIR, name]
	if img.save_png(path) != OK:
		push_error("save failed: " + path)

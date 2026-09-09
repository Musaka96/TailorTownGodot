extends SceneTree

## Slices the cute face sprites out of the face kit (assets/textures/pack.png) into
## assets/textures/faces/*.png, keying the cream panel background to transparency
## (border flood-fill over light/low-saturation pixels, so interior highlights
## survive) and auto-trimming each. Also derives a squashed "closed" eye for blinks
## and seeds the default face layout. Re-run after changing the source rects.
##   godot --headless --path . --script res://tools/build_faces.gd
##
## One eye/brow is sliced and mirrored for the other side in the rig, so the gap
## between them is adjustable (see FaceLayout / the Face Editor dock).

const SRC := "res://assets/textures/pack.png"
const OUT_DIR := "res://assets/textures/faces"

# name -> source rect in pack.png (generous; auto-trimmed after keying).
const CELLS := {
	"eye": Rect2i(836, 66, 46, 60),
	"brow": Rect2i(1322, 60, 46, 34),
	"nose": Rect2i(828, 455, 44, 64),
	"mouth_closed": Rect2i(1245, 510, 74, 52),
	"mouth_mid": Rect2i(1105, 512, 60, 52),
	"mouth_open": Rect2i(1240, 455, 82, 58),
}


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var src := Image.load_from_file(SRC)
	var eye: Image = null
	for name: String in CELLS:
		var s := _slice(src, CELLS[name])
		s.save_png("%s/%s.png" % [OUT_DIR, name])
		if name == "eye":
			eye = s
	if eye != null:
		_closed_eye(eye).save_png("%s/eye_closed.png" % OUT_DIR)
	_seed_layout()
	print("sliced face sprites to ", OUT_DIR)
	quit(0)


## A blink frame: the open eye squashed to a thin slit, centred in the same canvas.
func _closed_eye(eye: Image) -> Image:
	var w := eye.get_width()
	var h := eye.get_height()
	var flat := eye.duplicate()
	var sh := maxi(int(round(h * 0.32)), 2)
	flat.resize(w, sh, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(flat, Rect2i(0, 0, w, sh), Vector2i(0, int((h - sh) / 2.0)))
	return out


func _seed_layout() -> void:
	if ResourceLoader.exists(FaceLayout.PATH):
		return
	if ResourceSaver.save(load("res://data/scripts/face_layout.gd").new(), FaceLayout.PATH) != OK:
		push_error("could not seed " + FaceLayout.PATH)


# --- Slicing ---------------------------------------------------------------


func _slice(src: Image, r: Rect2i) -> Image:
	var img := src.get_region(r)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var q: Array[Vector2i] = []
	for x in w:
		_seed(img, bg, q, x, 0, w)
		_seed(img, bg, q, x, h - 1, w)
	for y in h:
		_seed(img, bg, q, 0, y, w)
		_seed(img, bg, q, w - 1, y, w)
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if bg[n.y * w + n.x] == 0 and _is_bg(img.get_pixel(n.x, n.y)):
				bg[n.y * w + n.x] = 1
				q.append(n)
	for y in h:
		for x in w:
			if bg[y * w + x] == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return _trim(img)


func _seed(img: Image, bg: PackedByteArray, q: Array, x: int, y: int, w: int) -> void:
	if bg[y * w + x] == 0 and _is_bg(img.get_pixel(x, y)):
		bg[y * w + x] = 1
		q.append(Vector2i(x, y))


## Cream panel = light and only faintly warm; face parts are darker or saturated.
func _is_bg(c: Color) -> bool:
	var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	return c.a > 0.5 and lum > 0.8 and (mx - mn) / maxf(mx, 0.001) < 0.2


func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	used = used.grow(2).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	return img.get_region(used)

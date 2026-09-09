extends SceneTree

## Slices the cute face sprites out of the two face kits into assets/textures/faces/*.png:
##   - newPack1.png: the eyes (several colours), the closed-eye blink frame, the brow.
##   - newPack2.png: the nose, the three talk mouths, and the glasses overlays.
## The cream panel background is keyed to transparency (border flood-fill over
## light/low-saturation pixels, so interior highlights survive) and each sprite is
## auto-trimmed. On sheets whose background is already transparent the keying is a
## harmless no-op, so re-running after a clean-alpha pass just sharpens the edges.
## Re-run after changing the source rects:
##   godot --headless --path . --script res://tools/build_faces.gd
##
## One eye/brow is sliced and mirrored for the other side in the rig, so the gap
## between them is adjustable (see FaceLayout / the Face Editor dock). Eyes are sliced
## per colour; the rig picks one at random per customer. eye.png is a copy of the
## default (brown) so the Face Editor dock and any default path keep working.

const P1 := "res://assets/textures/newPack1.png"
const P2 := "res://assets/textures/newPack2.png"
const OUT_DIR := "res://assets/textures/faces"
const DEFAULT_EYE := "brown"

# Eye colour -> left-eye rect in newPack1's neutral row (mirrored for the right side).
const EYE_CELLS := {
	"brown": Rect2i(25, 64, 60, 77),
	"green": Rect2i(221, 64, 58, 76),
	"blue": Rect2i(411, 65, 59, 75),
	"amber": Rect2i(790, 65, 64, 75),
	"olive": Rect2i(977, 63, 65, 77),
	"steel": Rect2i(1168, 65, 63, 76),
}

# Everything else -> [source sheet, rect, solid_key]. solid_key removes *every*
# cream/light pixel (not just the border-connected ones), so a frame that encloses a
# light region — the clear lenses of the round glasses — reads as see-through.
const CELLS := {
	"eye_closed": [P1, Rect2i(22, 228, 62, 28), false],
	"brow": [P1, Rect2i(24, 951, 60, 23), false],
	"nose": [P2, Rect2i(282, 550, 43, 39), false],
	"mouth_closed": [P2, Rect2i(39, 703, 82, 17), false],
	"mouth_mid": [P2, Rect2i(1060, 794, 84, 28), false],
	"mouth_open": [P2, Rect2i(188, 692, 98, 44), false],
	"glasses_sun": [P2, Rect2i(31, 922, 145, 50), false],
	"glasses_round": [P2, Rect2i(237, 918, 142, 58), true],
}


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var sheets := {P1: Image.load_from_file(P1), P2: Image.load_from_file(P2)}
	for color: String in EYE_CELLS:
		var eye := _slice(sheets[P1], EYE_CELLS[color])
		eye.save_png("%s/eye_%s.png" % [OUT_DIR, color])
		if color == DEFAULT_EYE:
			eye.save_png("%s/eye.png" % OUT_DIR)  # dock preview + default path
	for name: String in CELLS:
		var spec: Array = CELLS[name]
		_slice(sheets[spec[0]], spec[1], spec[2]).save_png("%s/%s.png" % [OUT_DIR, name])
	_seed_layout()
	print("sliced face sprites to ", OUT_DIR)
	quit(0)


func _seed_layout() -> void:
	if ResourceLoader.exists(FaceLayout.PATH):
		return
	if ResourceSaver.save(load("res://data/scripts/face_layout.gd").new(), FaceLayout.PATH) != OK:
		push_error("could not seed " + FaceLayout.PATH)


# --- Slicing ---------------------------------------------------------------


func _slice(src: Image, r: Rect2i, solid_key := false) -> Image:
	var img := src.get_region(r)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if solid_key:
		for y in h:
			for x in w:
				if _is_bg(img.get_pixel(x, y)):
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		return _trim(img)
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


## Cream panel = light and only faintly warm (or already transparent); face parts are
## darker or saturated, so they survive the key.
func _is_bg(c: Color) -> bool:
	if c.a < 0.5:
		return true
	var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	return lum > 0.8 and (mx - mn) / maxf(mx, 0.001) < 0.2


func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	used = used.grow(2).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	return img.get_region(used)

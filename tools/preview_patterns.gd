extends SceneTree

## Contact sheets for judging fabric patterns without launching the game. Composites
## cloth colour x weave x pattern exactly like materials/cloth.gdshader does, then
## writes two 3x3 grids to .dev/:
##   pattern_near.png  one tile at full size      (what a swatch / close-up shows)
##   pattern_far.png   minified, then blown up    (what a garment shows on screen)
## The "far" sheet is the one that matters: a pattern that turns to mush there is too
## dense, whatever it looks like up close.
##   godot --headless --path . --script res://tools/preview_patterns.gd

const NAMES := [
	"solid",
	"pinstripe",
	"herringbone",
	"houndstooth",
	"windowpane",
	"glen_check",
	"birdseye",
	"sharkskin",
	"nailhead",
]
const CELL := 128
const GAP := 4
const COLS := 3
const FAR := 26  # px a tile shrinks to at roughly garment-on-screen size
# Navy worsted with its pale accent — the combination in the reported screenshots.
const CLOTH := Color("1b2a4a")
const ACCENT := Color("e9ecf2")
const FABRIC_STRENGTH := 0.5
const PATTERN_STRENGTH := 0.85
const OUT_DIR := "res://.dev"


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var weave := _load("res://assets/textures/fabrics/worsted.png")
	var near := _sheet()
	var far := _sheet()
	for i in NAMES.size():
		var tile := _composite(weave, _load("res://assets/textures/patterns/%s.png" % NAMES[i]))
		_blit(near, tile, i)
		_blit(far, _shrink(tile), i)
	_save(near, OUT_DIR + "/pattern_near.png")
	_save(far, OUT_DIR + "/pattern_far.png")
	print("preview_patterns: done (order: %s)" % ", ".join(NAMES))
	quit(0)


## One CELL-sized tile of cloth: base colour x grayscale weave, with the pattern
## tinted on top by its alpha. Mirrors the fragment shader.
func _composite(weave: Image, pattern: Image) -> Image:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in CELL:
		for x in CELL:
			var u := float(x) / CELL
			var v := float(y) / CELL
			var w: float = _sample(weave, u, v).r
			var col: Color = CLOTH * lerp(1.0, w * 1.75, FABRIC_STRENGTH)
			var a: float = _sample(pattern, u, v).a * PATTERN_STRENGTH
			img.set_pixel(x, y, col.lerp(ACCENT, a))
	return img


## Shrink to garment size then blow back up with no smoothing, so aliasing and
## loss of contrast are both visible at a glance.
func _shrink(tile: Image) -> Image:
	var small := tile.duplicate() as Image
	small.resize(FAR, FAR, Image.INTERPOLATE_LANCZOS)
	small.resize(CELL, CELL, Image.INTERPOLATE_NEAREST)
	return small


func _sample(img: Image, u: float, v: float) -> Color:
	var x: int = posmod(int(u * img.get_width()), img.get_width())
	var y: int = posmod(int(v * img.get_height()), img.get_height())
	return img.get_pixel(x, y)


func _sheet() -> Image:
	var rows: int = int(ceil(float(NAMES.size()) / COLS))
	var w: int = COLS * CELL + (COLS - 1) * GAP
	var h: int = rows * CELL + (rows - 1) * GAP
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.5, 0.45))
	return img


func _blit(sheet: Image, tile: Image, index: int) -> void:
	var cx: int = (index % COLS) * (CELL + GAP)
	var cy: int = (index / COLS) * (CELL + GAP)
	sheet.blit_rect(tile, Rect2i(0, 0, CELL, CELL), Vector2i(cx, cy))


func _load(path: String) -> Image:
	var tex: Texture2D = load(path)
	if tex == null:
		push_error("missing texture: " + path)
		return Image.create(4, 4, false, Image.FORMAT_RGBA8)
	return tex.get_image()


func _save(img: Image, path: String) -> void:
	if img.save_png(path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote ", path)

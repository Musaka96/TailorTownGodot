extends SceneTree

## Generates temporary fabric-weave and pattern overlay textures used by the
## material swatch. Pure Image ops (no rendering) so it runs headless:
##   godot --headless --path . --script res://tools/build_textures.gd
## Then run --import so Godot picks up the new PNGs.
##
## Fabrics are grayscale (the shader multiplies the cloth colour by them).
## Patterns are white-on-transparent (the shader tints them with pattern_color).

const SIZE := 128
const FAB_DIR := "res://assets/textures/fabrics"
const PAT_DIR := "res://assets/textures/patterns"


func _initialize() -> void:
	_ensure(FAB_DIR)
	_ensure(PAT_DIR)

	# --- Fabrics (grayscale weave) ---
	_save(_fab_worsted(), FAB_DIR + "/worsted.png")
	_save(_fab_flannel(), FAB_DIR + "/flannel.png")
	_save(_fab_tweed(), FAB_DIR + "/tweed.png")
	_save(_fab_mohair(), FAB_DIR + "/mohair.png")
	_save(_fab_linen(), FAB_DIR + "/linen.png")

	# --- Patterns (alpha) ---
	_save(_blank(), PAT_DIR + "/solid.png")
	_save(_pinstripe(), PAT_DIR + "/pinstripe.png")
	_save(_herringbone(), PAT_DIR + "/herringbone.png")
	_save(_houndstooth(), PAT_DIR + "/houndstooth.png")
	_save(_windowpane(), PAT_DIR + "/windowpane.png")
	_save(_glen_check(), PAT_DIR + "/glen_check.png")
	_save(_birdseye(), PAT_DIR + "/birdseye.png")
	_save(_sharkskin(), PAT_DIR + "/sharkskin.png")
	_save(_nailhead(), PAT_DIR + "/nailhead.png")

	print("build_textures: done.")
	quit(0)


# --- Fabrics ---------------------------------------------------------------

func _fab_worsted() -> Image:
	# Fine tight twill: subtle diagonal weave.
	var img := _gray(0.5)
	for y in SIZE:
		for x in SIZE:
			var v := 0.5
			if (x + y) % 3 == 0:
				v += 0.06
			if (x - y) % 4 == 0:
				v -= 0.04
			v += (_hash(x, y) - 0.5) * 0.04
			img.set_pixel(x, y, _g(v))
	return img


func _fab_flannel() -> Image:
	# Soft brushed cloud: low-frequency noise.
	var img := _gray(0.5)
	for y in SIZE:
		for x in SIZE:
			var n := _value_noise(x * 0.06, y * 0.06)
			var v := 0.5 + (n - 0.5) * 0.18
			img.set_pixel(x, y, _g(v))
	return img


func _fab_tweed() -> Image:
	# Coarse speckle / flecks.
	var img := _gray(0.5)
	for y in SIZE:
		for x in SIZE:
			var h := _hash(x, y)
			var v := 0.5 + (h - 0.5) * 0.34
			var n := _value_noise(x * 0.12, y * 0.12)
			v += (n - 0.5) * 0.12
			img.set_pixel(x, y, _g(v))
	return img


func _fab_mohair() -> Image:
	# Smooth with a faint vertical sheen.
	var img := _gray(0.5)
	for y in SIZE:
		for x in SIZE:
			var sheen: float = sin(float(x) / SIZE * PI) * 0.08
			var v := 0.5 + sheen + (_hash(x, y) - 0.5) * 0.03
			img.set_pixel(x, y, _g(v))
	return img


func _fab_linen() -> Image:
	# Open weave: irregular horizontal + vertical slubs.
	var img := _gray(0.5)
	for y in SIZE:
		for x in SIZE:
			var v := 0.5
			v += sin(float(x) * 0.9) * 0.05
			v += sin(float(y) * 0.9) * 0.05
			v += (_hash(x, y) - 0.5) * 0.08
			img.set_pixel(x, y, _g(v))
	return img


# --- Patterns (alpha, white) ----------------------------------------------

func _pinstripe() -> Image:
	var img := _clear()
	for y in SIZE:
		for x in SIZE:
			if x % 16 == 0:
				img.set_pixel(x, y, _a(0.7))
	return img


func _herringbone() -> Image:
	var img := _clear()
	var band := 12
	for y in SIZE:
		for x in SIZE:
			var up := (y / band) % 2 == 0
			var d := (x + y) if up else (x - y)
			if posmod(d, 8) < 2:
				img.set_pixel(x, y, _a(0.5))
	return img


func _houndstooth() -> Image:
	# Tiled 8x8 broken-check motif.
	var motif := [
		[1, 1, 1, 0, 0, 0, 1, 0],
		[1, 1, 1, 1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 0, 0, 0],
		[0, 1, 1, 1, 1, 0, 0, 0],
		[0, 0, 0, 0, 1, 1, 1, 1],
		[0, 0, 0, 1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1, 1, 1, 1],
		[0, 1, 0, 0, 0, 1, 1, 1],
	]
	var img := _clear()
	var scale := 2  # 16px motif
	for y in SIZE:
		for x in SIZE:
			var mx := (x / scale) % 8
			var my := (y / scale) % 8
			if motif[my][mx] == 1:
				img.set_pixel(x, y, _a(0.55))
	return img


func _windowpane() -> Image:
	var img := _clear()
	for y in SIZE:
		for x in SIZE:
			if x % 42 == 0 or y % 42 == 0:
				img.set_pixel(x, y, _a(0.6))
	return img


func _glen_check() -> Image:
	# Fine check + wider overcheck.
	var img := _clear()
	for y in SIZE:
		for x in SIZE:
			var a := 0.0
			if (x / 4 + y / 4) % 2 == 0 and (x % 2 == 0 or y % 2 == 0):
				a = 0.28
			if x % 32 == 0 or y % 32 == 0:
				a = 0.5
			if a > 0.0:
				img.set_pixel(x, y, _a(a))
	return img


func _birdseye() -> Image:
	var img := _clear()
	for y in SIZE:
		for x in SIZE:
			if x % 8 == 4 and y % 8 == 4:
				img.set_pixel(x, y, _a(0.55))
	return img


func _sharkskin() -> Image:
	var img := _clear()
	for y in SIZE:
		for x in SIZE:
			if (x + y) % 4 == 0:
				img.set_pixel(x, y, _a(0.3))
	return img


func _nailhead() -> Image:
	var img := _clear()
	for y in SIZE:
		for x in SIZE:
			if x % 10 < 2 and y % 10 < 2:
				img.set_pixel(x, y, _a(0.5))
	return img


# --- Helpers ---------------------------------------------------------------

func _gray(v: float) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_g(v))
	return img


func _clear() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	return img


func _blank() -> Image:
	return _clear()


func _g(v: float) -> Color:
	v = clampf(v, 0.0, 1.0)
	return Color(v, v, v, 1.0)


func _a(a: float) -> Color:
	return Color(1, 1, 1, clampf(a, 0.0, 1.0))


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) ^ 0
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


func _value_noise(fx: float, fy: float) -> float:
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	var a := _hash(x0, y0)
	var b := _hash(x0 + 1, y0)
	var c := _hash(x0, y0 + 1)
	var d := _hash(x0 + 1, y0 + 1)
	var top: float = lerp(a, b, tx)
	var bot: float = lerp(c, d, tx)
	return lerp(top, bot, ty)


func _ensure(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)


func _save(img: Image, path: String) -> void:
	if img.save_png(path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote ", path)

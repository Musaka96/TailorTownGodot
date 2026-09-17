extends SceneTree

## Generates the fabric-weave and pattern overlay textures used by cloth materials
## and the material swatch. Pure Image ops (no rendering) so it runs headless:
##   godot --headless --path . --script res://tools/build_textures.gd
## Then run --import so Godot picks up the new PNGs.
##
## Fabrics are grayscale (the shader multiplies the cloth colour by them).
## Patterns are white-on-transparent (the shader tints them with pattern_color).
##
## Patterns are drawn with SOFT (anti-aliased) edges and at a bold motif size, and
## their textures are imported WITH mipmaps — a hard-edged fine pattern turns into
## moire the moment a garment is minified on screen. Ink coverage is also kept in the
## same ballpark for every pattern (see the mean printed per pattern, target ~0.04 to
## ~0.12): because the overlay tints towards the pale accent colour, a pattern that
## inks half its area doesn't read as a check at distance, it just washes the whole
## garment lighter than the swatch the customer picked.

const FAB_SIZE := 128
const PAT_SIZE := 256
const FAB_DIR := "res://assets/textures/fabrics"
const PAT_DIR := "res://assets/textures/patterns"

## Ink opacity per pattern: how strongly the accent colour shows through where the
## pattern covers. Bold patterns get LESS opacity than their coverage suggests so the
## garment keeps the cloth colour it was quoted at.
const PAT_INK := {
	"pinstripe": 0.70,
	"herringbone": 0.42,
	"houndstooth": 0.44,
	"windowpane": 0.60,
	"glen_check": 0.55,
	"birdseye": 0.55,
	"sharkskin": 0.26,
	"nailhead": 0.50,
}

# Houndstooth is woven, so it's generated the way it's woven: a 2/2 twill with a
# 4-and-4 colour order in warp and weft, which produces the dogtooth exactly. The
# result is then eroded, because a real dogtooth inks half its ground and at game
# scale that reads as a pale wash rather than a check.
const HOUND_MOTIF := 64  # px per motif -> 4 bold motifs per tile
const HOUND_CELLS := 32  # motif resolution (threads x 4) the mask is built at
const HOUND_TWILL := 2  # 2/2 twill: warp floats over 2 wefts, then under 2
const HOUND_BLOCK := 4  # threads per colour block in the warp/weft colour order
const HOUND_ERODE_R := 4  # erosion radius, in mask cells
const HOUND_ERODE_T := 0.62  # keep a cell only if this fraction of its window is inked
const HOUND_SS := 4  # supersamples per axis when rasterising the mask


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
	_save(_clear(), PAT_DIR + "/solid.png")
	_pattern("pinstripe", _pinstripe())
	_pattern("herringbone", _herringbone())
	_pattern("houndstooth", _houndstooth())
	_pattern("windowpane", _windowpane())
	_pattern("glen_check", _glen_check())
	_pattern("birdseye", _birdseye())
	_pattern("sharkskin", _sharkskin())
	_pattern("nailhead", _nailhead())

	print("build_textures: done.")
	quit(0)


# --- Fabrics ---------------------------------------------------------------


func _fab_worsted() -> Image:
	# Fine tight twill: subtle diagonal weave.
	var img := _gray(0.5)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
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
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var n := _value_noise(x * 0.06, y * 0.06)
			var v := 0.5 + (n - 0.5) * 0.18
			img.set_pixel(x, y, _g(v))
	return img


func _fab_tweed() -> Image:
	# Coarse speckle / flecks.
	var img := _gray(0.5)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var h := _hash(x, y)
			var v := 0.5 + (h - 0.5) * 0.34
			var n := _value_noise(x * 0.12, y * 0.12)
			v += (n - 0.5) * 0.12
			img.set_pixel(x, y, _g(v))
	return img


func _fab_mohair() -> Image:
	# Smooth with a faint vertical sheen.
	var img := _gray(0.5)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var sheen: float = sin(float(x) / FAB_SIZE * PI) * 0.08
			var v := 0.5 + sheen + (_hash(x, y) - 0.5) * 0.03
			img.set_pixel(x, y, _g(v))
	return img


func _fab_linen() -> Image:
	# Open weave: irregular horizontal + vertical slubs.
	var img := _gray(0.5)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var v := 0.5
			v += sin(float(x) * 0.9) * 0.05
			v += sin(float(y) * 0.9) * 0.05
			v += (_hash(x, y) - 0.5) * 0.08
			img.set_pixel(x, y, _g(v))
	return img


# --- Patterns (alpha, white) ----------------------------------------------
#
# Each builder returns a coverage grid (0..1 per pixel, anti-aliased) which
# _pattern() scales by the pattern's ink opacity and writes out.


func _pinstripe() -> PackedFloat32Array:
	# 8 stripes per tile — the reference density; everything else is judged against it.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			cov[y * PAT_SIZE + x] = _band(x, 32.0, 2.0)
	return cov


func _herringbone() -> PackedFloat32Array:
	# Zigzag twill: diagonal ribs that flip direction every band.
	var cov := _grid()
	var band := 24.0
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			var up := int(y / band) % 2 == 0
			var d: float = float(x + y) if up else float(x - y)
			cov[y * PAT_SIZE + x] = _band(d, 22.0, 3.2)
	return cov


func _houndstooth() -> PackedFloat32Array:
	var mask := _hound_mask()
	var cells_per_px: float = float(HOUND_CELLS) / float(HOUND_MOTIF)
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			var hits := 0
			for sy in HOUND_SS:
				for sx in HOUND_SS:
					var fx: float = (x + (sx + 0.5) / HOUND_SS) * cells_per_px
					var fy: float = (y + (sy + 0.5) / HOUND_SS) * cells_per_px
					var row: PackedByteArray = mask[posmod(int(fy), HOUND_CELLS)]
					hits += row[posmod(int(fx), HOUND_CELLS)]
			cov[y * PAT_SIZE + x] = float(hits) / float(HOUND_SS * HOUND_SS)
	return cov


func _windowpane() -> PackedFloat32Array:
	# Two wide panes per tile: a thin single line each way.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			cov[y * PAT_SIZE + x] = maxf(_band(x, 128.0, 3.0), _band(y, 128.0, 3.0))
	return cov


func _glen_check() -> PackedFloat32Array:
	# Fine thread check with a wider overcheck on top — lines, not filled cells.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			var fine: float = maxf(_band(x, 16.0, 1.6), _band(y, 16.0, 1.6)) * 0.45
			var over: float = maxf(_band(x, 128.0, 3.4), _band(y, 128.0, 3.4))
			cov[y * PAT_SIZE + x] = maxf(fine, over)
	return cov


func _birdseye() -> PackedFloat32Array:
	# Tiny dots on a fine grid: reads as a soft speckle at distance.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			cov[y * PAT_SIZE + x] = _dot(x, y, 16.0, 1.7)
	return cov


func _sharkskin() -> PackedFloat32Array:
	# Very fine diagonal two-tone: a whisper, never a texture you can count.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			cov[y * PAT_SIZE + x] = _band(float(x + y), 11.0, 2.4)
	return cov


func _nailhead() -> PackedFloat32Array:
	# Slightly larger, more spaced dots than birdseye.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			cov[y * PAT_SIZE + x] = _dot(x, y, 22.0, 2.4)
	return cov


# --- Pattern helpers -------------------------------------------------------


## Writes a coverage grid out as a white-on-transparent PNG and reports its mean
## alpha — the amount the pattern shifts the whole garment towards the accent once
## it's too small on screen to resolve.
func _pattern(name: String, cov: PackedFloat32Array) -> void:
	var ink: float = PAT_INK.get(name, 0.5)
	var img := _clear()
	var total := 0.0
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			var a: float = clampf(cov[y * PAT_SIZE + x], 0.0, 1.0) * ink
			total += a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var mean := total / float(PAT_SIZE * PAT_SIZE)
	_save(img, "%s/%s.png" % [PAT_DIR, name])
	print("    %-12s mean alpha %.3f" % [name, mean])


## Soft coverage of a `width`px band repeating every `period`px, with a 1px feather
## either side so the line never aliases when minified.
func _band(coord: float, period: float, width: float) -> float:
	var m: float = fposmod(coord, period)
	var d: float = minf(m, period - m)
	return clampf(width * 0.5 - d + 0.5, 0.0, 1.0)


## Soft coverage of a `radius`px disc repeating on a `spacing`px grid.
func _dot(x: int, y: int, spacing: float, radius: float) -> float:
	var dx: float = fposmod(float(x), spacing) - spacing * 0.5
	var dy: float = fposmod(float(y), spacing) - spacing * 0.5
	return clampf(radius - sqrt(dx * dx + dy * dy) + 0.5, 0.0, 1.0)


## The eroded dogtooth mask: which of the HOUND_CELLS^2 cells of one motif are inked.
func _hound_mask() -> Array:
	var per_thread: int = HOUND_CELLS / (HOUND_BLOCK * 2)
	var woven := []
	for y in HOUND_CELLS:
		var row := PackedByteArray()
		row.resize(HOUND_CELLS)
		for x in HOUND_CELLS:
			var warp: int = x / per_thread
			var weft: int = y / per_thread
			# Whichever thread floats on top at this intersection shows its colour.
			var warp_on_top: bool = posmod(warp - weft, HOUND_TWILL * 2) < HOUND_TWILL
			var thread: int = warp if warp_on_top else weft
			row[x] = 1 if (thread % (HOUND_BLOCK * 2)) < HOUND_BLOCK else 0
		woven.append(row)
	return _hound_erode(woven)


## Drops inked cells whose neighbourhood isn't mostly inked: thins the tooth from the
## outside in, so the silhouette survives on a third of the ink.
func _hound_erode(mask: Array) -> Array:
	var r := HOUND_ERODE_R
	var window := float((r * 2 + 1) * (r * 2 + 1))
	var out := []
	for y in HOUND_CELLS:
		var row := PackedByteArray()
		row.resize(HOUND_CELLS)
		for x in HOUND_CELLS:
			row[x] = 0
			if int(mask[y][x]) == 0:
				continue
			var inked := 0
			for dy in range(-r, r + 1):
				var src: PackedByteArray = mask[posmod(y + dy, HOUND_CELLS)]
				for dx in range(-r, r + 1):
					inked += src[posmod(x + dx, HOUND_CELLS)]
			row[x] = 1 if float(inked) / window >= HOUND_ERODE_T else 0
		out.append(row)
	return out


func _grid() -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(PAT_SIZE * PAT_SIZE)
	return g


# --- Helpers ---------------------------------------------------------------


func _gray(v: float) -> Image:
	var img := Image.create(FAB_SIZE, FAB_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_g(v))
	return img


func _clear() -> Image:
	var img := Image.create(PAT_SIZE, PAT_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	return img


func _g(v: float) -> Color:
	v = clampf(v, 0.0, 1.0)
	return Color(v, v, v, 1.0)


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

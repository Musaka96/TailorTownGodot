extends SceneTree

## Generates the fabric-weave and pattern overlay textures used by cloth materials
## and the material swatch. Pure Image ops (no rendering) so it runs headless:
##   godot --headless --path . --script res://tools/build_textures.gd
## Then run --import so Godot picks up the new PNGs.
##
## Fabrics are grayscale (the shader multiplies the cloth colour by them).
##
## A pattern texture packs two channels (alpha is unused, so nothing depends on the
## importer's alpha handling):
##   R = accent coverage — how much of this pixel is the pattern's contrast thread
##   G = thread relief   — 0.5 neutral, brighter along a thread's crown and darker
##                         where it dives under the crossing one, so the cloth shader
##                         can light the pattern as woven threads instead of tinting a
##                         flat decal over the fabric
##
## Two rules that are easy to break and obvious on screen:
##   * every period here must divide PAT_SIZE exactly, or the tile seam shows up as a
##     broken line running across the garment;
##   * the woven patterns are generated thread by thread from the weave that actually
##     makes them (see WEAVES), not drawn as shapes — that's what keeps a dogtooth's
##     corners square and a herringbone's chevrons meeting, and it's why they read as
##     textile. Ink strength is NOT baked in here: R is honest coverage, and how
##     strongly it tints is ClothMaterial.PATTERN_INTENSITY, tunable without a rebuild.

const FAB_SIZE := 128
const PAT_SIZE := 256
const FAB_DIR := "res://assets/textures/fabrics"
const PAT_DIR := "res://assets/textures/patterns"

# How far thread relief swings either side of neutral in the G channel. The mean is
# normalised to exactly 0.5 so mipmaps fade the relief out instead of shifting the
# garment's brightness as it gets smaller on screen.
const RELIEF_AMP := 0.18
const WEAVE_SS := 3  # supersamples per axis when rasterising threads

## The woven patterns, generated on the loom rather than drawn.
##   pitch   px per thread
##   twill   threads a float crosses before diving under (2 = a 2/2 twill)
##   warp    threads per colour block in the warp colour order;
##           0 = every warp thread is an accent thread, -1 = none are
##   weft    the same for the weft
##   chevron warp threads between twill reversals (0 = a straight twill)
## Houndstooth really is a 2/2 twill with a 4-and-4 colour order both ways, and
## sharkskin the same weave with a 1-and-1 order — so these are the actual cloths.
const WEAVES := {
	"houndstooth": {"pitch": 8, "twill": 2, "warp": 4, "weft": 4, "chevron": 0},
	"herringbone": {"pitch": 4, "twill": 2, "warp": 0, "weft": -1, "chevron": 8},
	"sharkskin": {"pitch": 4, "twill": 2, "warp": 1, "weft": 1, "chevron": 0},
}


func _initialize() -> void:
	_ensure(FAB_DIR)
	_ensure(PAT_DIR)

	# --- Fabrics (grayscale weave) ---
	_save(_fab_worsted(), FAB_DIR + "/worsted.png")
	_save(_fab_flannel(), FAB_DIR + "/flannel.png")
	_save(_fab_tweed(), FAB_DIR + "/tweed.png")
	_save(_fab_mohair(), FAB_DIR + "/mohair.png")
	_save(_fab_linen(), FAB_DIR + "/linen.png")

	# --- Patterns: woven on the loom ---
	for name in WEAVES:
		_woven(name)

	# --- Patterns: stripes and checks printed onto plain cloth ---
	_flat("solid", _grid())
	_flat("pinstripe", _pinstripe())
	_flat("windowpane", _windowpane())
	_flat("glen_check", _glen_check())
	_flat("birdseye", _birdseye())
	_flat("nailhead", _nailhead())

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


# --- Patterns -------------------------------------------------------------


## Renders a woven pattern from WEAVES: coverage from the colour order, relief from
## where each thread crosses over or under.
func _woven(name: String) -> void:
	var spec: Dictionary = WEAVES[name]
	var pitch: int = spec["pitch"]
	var cover := _grid()
	var relief := _grid()
	var samples := float(WEAVE_SS * WEAVE_SS)
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			var c := 0.0
			var r := 0.0
			for sy in WEAVE_SS:
				for sx in WEAVE_SS:
					var s := _thread(
						x + (sx + 0.5) / WEAVE_SS, y + (sy + 0.5) / WEAVE_SS, pitch, spec
					)
					c += s.x
					r += s.y
			cover[y * PAT_SIZE + x] = c / samples
			relief[y * PAT_SIZE + x] = r / samples
	_write(name, cover, relief)


## One point of woven cloth: whether the thread showing here is an accent thread, and
## how its crown and the dip where it passes under catch the light.
func _thread(fx: float, fy: float, pitch: int, spec: Dictionary) -> Vector2:
	var twill: int = spec["twill"]
	var chevron: int = spec["chevron"]
	var warp: int = int(fx) / pitch
	var weft: int = int(fy) / pitch
	# Reversing the twill every `chevron` warp threads is what makes a herringbone's
	# ribs meet in a V; because it happens on the thread grid the ribs always join.
	var dir := 1
	if chevron > 0 and posmod(warp / chevron, 2) == 1:
		dir = -1
	var phase: int = posmod(warp - dir * weft, twill * 2)
	var warp_on_top: bool = phase < twill
	var thread: int = warp if warp_on_top else weft
	var accent := _is_accent(thread, spec["warp"] if warp_on_top else spec["weft"])
	# Across the thread it's a rounded crown; along the float it dips at both ends.
	var across: float = fposmod(fx if warp_on_top else fy, float(pitch)) / pitch
	var within: float = fposmod(fy if warp_on_top else fx, float(pitch)) / pitch
	var along: float = (posmod(phase, twill) + within) / float(twill)
	var crown: float = 1.0 - pow(2.0 * across - 1.0, 2.0)
	var ends: float = 1.0 - pow(2.0 * along - 1.0, 2.0)
	return Vector2(1.0 if accent else 0.0, crown * 0.7 + ends * 0.3)


## Does this thread carry the accent colour? `block` threads of accent alternate with
## `block` plain; 0 means every thread does, -1 means none do.
func _is_accent(thread: int, block: int) -> bool:
	if block <= 0:
		return block == 0
	return posmod(thread, block * 2) < block


# --- Patterns printed onto plain cloth ------------------------------------
#
# Stripes and checks aren't a colour order in the weave, so they carry no relief of
# their own — the fabric's own weave texture supplies the grain.


func _flat(name: String, cover: PackedFloat32Array) -> void:
	_write(name, cover, PackedFloat32Array())


func _pinstripe() -> PackedFloat32Array:
	# 8 stripes per tile — the reference density; everything else is judged against it.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			cov[y * PAT_SIZE + x] = _band(x, 32.0, 2.0)
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


func _nailhead() -> PackedFloat32Array:
	# The same grid as birdseye with a distinctly bigger dot.
	var cov := _grid()
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			cov[y * PAT_SIZE + x] = _dot(x, y, 16.0, 2.6)
	return cov


# --- Pattern output -------------------------------------------------------


## Packs coverage into R and relief into G (an empty relief writes neutral 0.5), and
## reports mean coverage — how far the pattern shifts the garment towards the accent
## once it's too small on screen to resolve. ClothMaterial.PATTERN_INTENSITY scales it.
func _write(name: String, cover: PackedFloat32Array, relief: PackedFloat32Array) -> void:
	var has_relief := relief.size() == cover.size()
	var relief_mean := 0.0
	if has_relief:
		for i in relief.size():
			relief_mean += relief[i]
		relief_mean /= float(relief.size())

	var img := Image.create(PAT_SIZE, PAT_SIZE, false, Image.FORMAT_RGBA8)
	var total := 0.0
	for y in PAT_SIZE:
		for x in PAT_SIZE:
			var i := y * PAT_SIZE + x
			var c: float = clampf(cover[i], 0.0, 1.0)
			total += c
			var g := 0.5
			if has_relief:
				g = clampf(0.5 + (relief[i] - relief_mean) * RELIEF_AMP, 0.0, 1.0)
			img.set_pixel(x, y, Color(c, g, 0.5, 1.0))
	_save(img, "%s/%s.png" % [PAT_DIR, name])
	print(
		(
			"    %-12s mean coverage %.3f%s"
			% [name, total / (PAT_SIZE * PAT_SIZE), "  (woven)" if has_relief else ""]
		)
	)


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


func _grid() -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(PAT_SIZE * PAT_SIZE)
	return g


# --- Helpers ---------------------------------------------------------------


func _gray(v: float) -> Image:
	var img := Image.create(FAB_SIZE, FAB_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_g(v))
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

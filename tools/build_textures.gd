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
# Tweed neps: how many coloured flecks per tile and their albedo tints (multipliers
# around 1.0, so a nep re-tints the cloth colour instead of painting over it).
const NEP_COUNT := 150
const NEP_COLORS := [
	Color(1.5, 0.9, 0.65),  # rust
	Color(1.45, 1.25, 0.7),  # gold
	Color(0.95, 1.3, 0.85),  # moss
	Color(1.4, 0.75, 0.75),  # burgundy
]

const WEAVES := {
	"houndstooth": {"pitch": 8, "twill": 2, "warp": 4, "weft": 4, "chevron": 0},
	"herringbone": {"pitch": 4, "twill": 2, "warp": 0, "weft": -1, "chevron": 8},
	"sharkskin": {"pitch": 4, "twill": 2, "warp": 1, "weft": 1, "chevron": 0},
}


func _initialize() -> void:
	_ensure(FAB_DIR)
	_ensure(PAT_DIR)

	# --- Fabrics: a heightfield each, written as the grayscale weave (albedo
	# multiplier, unchanged look) plus a baked <name>_n.png normal map so the weave
	# shades with the room's light. Tweed also carries coloured neps in its albedo.
	_fabric("worsted", _fab_worsted(), 8.0)
	_fabric("flannel", _fab_flannel(), 5.0)
	var tweed := _fab_tweed()
	_fabric("tweed", tweed["h"], 14.0, tweed["tint"])
	_fabric("mohair", _fab_mohair(), 3.5)
	_fabric("linen", _fab_linen(), 14.0)

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


## Writes a fabric's grayscale weave PNG from its heightfield (same pixels as the
## old direct drawing), an optional per-pixel albedo tint (tweed's neps), and a
## baked <name>_n.png normal map (Sobel over the tiled height, `amp` = strength).
func _fabric(
	name: String, height: PackedFloat32Array, amp: float, tint := PackedColorArray()
) -> void:
	var img := Image.create(FAB_SIZE, FAB_SIZE, false, Image.FORMAT_RGBA8)
	var has_tint := tint.size() == height.size()
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var i := y * FAB_SIZE + x
			var v := clampf(height[i], 0.0, 1.0)
			var c := _g(v)
			if has_tint:
				c = Color(
					clampf(v * tint[i].r, 0.0, 1.0),
					clampf(v * tint[i].g, 0.0, 1.0),
					clampf(v * tint[i].b, 0.0, 1.0),
					1.0
				)
			img.set_pixel(x, y, c)
	_save(img, FAB_DIR + "/%s.png" % name)
	_bake_normal(height, FAB_SIZE, amp, FAB_DIR + "/%s_n.png" % name)


func _fab_worsted() -> PackedFloat32Array:
	# Fine tight twill: subtle diagonal weave.
	var h := _heights(FAB_SIZE)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var v := 0.5
			if (x + y) % 3 == 0:
				v += 0.06
			if (x - y) % 4 == 0:
				v -= 0.04
			v += (_hash(x, y) - 0.5) * 0.04
			h[y * FAB_SIZE + x] = v
	return h


func _fab_flannel() -> PackedFloat32Array:
	# Soft brushed cloud: low-frequency noise.
	var h := _heights(FAB_SIZE)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var n := _value_noise(x * 0.06, y * 0.06)
			h[y * FAB_SIZE + x] = 0.5 + (n - 0.5) * 0.18
	return h


## Coarse speckle plus sparse coloured neps — the flecks that make tweed tweed.
## The albedo multiplies the cloth colour, so the fleck tints stay harmonious on
## any dye; each nep is also a small bump in the height so the light catches it.
func _fab_tweed() -> Dictionary:
	var h := _heights(FAB_SIZE)
	var tint := PackedColorArray()
	tint.resize(FAB_SIZE * FAB_SIZE)
	tint.fill(Color(1, 1, 1))
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var v := 0.5 + (_hash(x, y) - 0.5) * 0.34
			v += (_value_noise(x * 0.12, y * 0.12) - 0.5) * 0.12
			h[y * FAB_SIZE + x] = v
	for k in NEP_COUNT:
		var cx := _hash(k * 3 + 1, 17) * FAB_SIZE
		var cy := _hash(k * 7 + 5, 91) * FAB_SIZE
		var r := 1.2 + _hash(k, 57) * 2.0
		var col: Color = NEP_COLORS[int(_hash(k, 33) * NEP_COLORS.size()) % NEP_COLORS.size()]
		_stamp_nep(h, tint, cx, cy, r, col)
	return {"h": h, "tint": tint}


func _stamp_nep(
	h: PackedFloat32Array, tint: PackedColorArray, cx: float, cy: float, r: float, col: Color
) -> void:
	var reach := int(ceil(r)) + 1
	for oy in range(-reach, reach + 1):
		for ox in range(-reach, reach + 1):
			var fall := clampf(r - Vector2(ox, oy).length() + 0.5, 0.0, 1.0)
			if fall <= 0.0:
				continue
			var x := posmod(int(cx) + ox, FAB_SIZE)
			var y := posmod(int(cy) + oy, FAB_SIZE)
			var i := y * FAB_SIZE + x
			h[i] += fall * 0.2
			tint[i] = tint[i].lerp(col, fall)


func _fab_mohair() -> PackedFloat32Array:
	# Smooth with a faint vertical sheen.
	var h := _heights(FAB_SIZE)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var sheen: float = sin(float(x) / FAB_SIZE * PI) * 0.08
			h[y * FAB_SIZE + x] = 0.5 + sheen + (_hash(x, y) - 0.5) * 0.03
	return h


func _fab_linen() -> PackedFloat32Array:
	# Open weave: irregular horizontal + vertical slubs.
	var h := _heights(FAB_SIZE)
	for y in FAB_SIZE:
		for x in FAB_SIZE:
			var v := 0.5
			v += sin(float(x) * 0.9) * 0.05
			v += sin(float(y) * 0.9) * 0.05
			v += (_hash(x, y) - 0.5) * 0.08
			h[y * FAB_SIZE + x] = v
	return h


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
	# The same thread relief, baked as a normal map so a woven pattern's threads
	# catch the light (flat printed patterns carry no relief and get none).
	_bake_normal(relief, PAT_SIZE, 3.5, PAT_DIR + "/%s_n.png" % name)


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


func _heights(size: int) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(size * size)
	return h


## Bakes an OpenGL-style tangent-space normal map from a tiled heightfield via a
## wrapped central difference; `amp` scales the slopes (the shader's normal_depth
## scales again on top, so these are just sane per-texture baselines).
func _bake_normal(height: PackedFloat32Array, size: int, amp: float, path: String) -> void:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dx := (
				height[y * size + posmod(x + 1, size)] - height[y * size + posmod(x - 1, size)]
			)
			var dy := (
				height[posmod(y + 1, size) * size + x] - height[posmod(y - 1, size) * size + x]
			)
			var n := Vector3(-dx * amp, dy * amp, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	_save(img, path)


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

extends SceneTree

## Generates a placeholder tileable hair-strand texture at
## assets/textures/hair/strands.png — grayscale strand shading in RGB with a strand
## coverage mask in alpha, so the rig's two-layer hair material can lay strand detail
## (transparent) over the flat base colour. Swap this PNG for real hair art later; the
## material picks it up with no code change.
##   godot --headless --path . --script res://tools/build_hair_texture.gd

const OUT := "res://assets/textures/hair/strands.png"
const W := 256
const H := 256
const STRANDS := 46


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/textures/hair"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260910
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.7, 0.7, 0.7, 0.0))  # transparent gaps: base colour shows through
	for _s in STRANDS:
		var cx := rng.randf() * W
		var width := rng.randf_range(2.5, 6.0)
		var wob := rng.randf_range(4.0, 12.0)  # horizontal sway down the strand
		var phase := rng.randf() * TAU
		var shade := rng.randf_range(0.45, 0.95)  # darker vs lighter strand
		var peak := rng.randf_range(0.45, 0.8)  # strand opacity at its core
		for y in H:
			var t := float(y) / H
			var sway := sin(phase + t * PI * rng.randf_range(1.5, 3.0)) * wob
			var center := cx + sway
			for dx in range(-int(width) - 2, int(width) + 3):
				var x := int(round(center + dx))
				var fall := 1.0 - absf(float(dx)) / (width + 1.0)
				if fall <= 0.0:
					continue
				var a := peak * fall * fall
				var px := ((x % W) + W) % W  # wrap so it tiles horizontally
				var cur := img.get_pixel(px, y)
				if a > cur.a:
					var v: float = lerpf(cur.r, shade, fall)
					img.set_pixel(px, y, Color(v, v, v, a))
	img.save_png(OUT)
	print("build_hair_texture: wrote ", OUT)
	quit(0)

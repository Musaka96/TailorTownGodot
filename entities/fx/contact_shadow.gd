class_name ContactShadow
extends Decal

## A soft dark blob on the ground under a character, so they sit ON the floor instead of
## floating over it — the sun's shadow alone falls off to one side. A Decal, so it lies on
## whatever is underfoot (boards, rugs, the pavement) without a mesh to z-fight.
##   ContactShadow.attach(body)  # once, from the character's _ready

const RADIUS := 0.42
const DEPTH := 0.24
const DARKNESS := 0.8
## Use this, never 0.0, for a decal's upper/lower fade. Godot fades by pow(1 - |y|, fade):
## at 0 a pixel lying exactly on the box's top or bottom face works out pow(0, 0) = NaN,
## and glow blows that one pixel up into a white ball for a frame (the "blinking light"
## the shop-front grime decals gave off across the window glass). This looks the same.
const NO_FADE := 0.001

static var _blob: GradientTexture2D
static var _dot: GradientTexture2D


static func attach(body: Node3D, radius := RADIUS) -> ContactShadow:
	var shadow := ContactShadow.new()
	shadow.size = Vector3(radius * 2.0, DEPTH, radius * 2.0)
	shadow.position = Vector3.ZERO
	body.add_child(shadow)
	return shadow


func _init() -> void:
	texture_albedo = _texture()
	upper_fade = NO_FADE
	lower_fade = NO_FADE
	normal_fade = 0.0


static func _texture() -> GradientTexture2D:
	if _blob == null:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.10, 0.07, 0.05, DARKNESS))
		ramp.set_color(1, Color(0.10, 0.07, 0.05, 0.0))
		ramp.set_offset(0, 0.3)
		_blob = GradientTexture2D.new()
		_blob.gradient = ramp
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 128
		_blob.height = 128
	return _blob


## A plain white soft-edged dot, for anything else that wants one (dust specks).
static func soft_dot() -> GradientTexture2D:
	if _dot == null:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = ramp
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot

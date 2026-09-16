extends Node

## Autoloaded as "Outline". Draws black silhouette outlines around objects as a
## screen-space post-process.
##
## It builds a full-screen quad and parents it to whatever Camera3D is current, so no
## scene needs to reference it — it just applies, like PostFX does. A `spatial` shader is
## required (only those can read the depth buffer), which is why this is a 3D quad rather
## than a CanvasLayer like the retro filter. The two stack fine: outlines are drawn into
## the 3D image, then the retro grade runs over the top.
##
## API: `Outline.profile` to read/tweak the live settings, `set_enabled(on)` / `toggle()`
## to flip it, `set_profile_path(path)` to load a different look.

const SHADER_PATH := "res://materials/outline_postfx.gdshader"
const DEFAULT_PROFILE := "res://data/outline.tres"
## Keeps the quad from ever being frustum-culled.
const CULL_MARGIN := 16384.0

var profile: OutlineProfile

var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _camera: Camera3D


func _ready() -> void:
	_build()
	set_profile_path(DEFAULT_PROFILE)


func _process(_delta: float) -> void:
	_follow_camera()
	_apply()


# --- Public API ------------------------------------------------------------


func set_profile(new_profile: OutlineProfile) -> void:
	profile = new_profile
	_apply()


func set_profile_path(path: String) -> void:
	var loaded: OutlineProfile = null
	if ResourceLoader.exists(path):
		loaded = load(path) as OutlineProfile
	set_profile(loaded if loaded != null else OutlineProfile.make_default())


func set_enabled(on: bool) -> void:
	if profile != null:
		profile.enabled = on


func toggle() -> void:
	if profile != null:
		profile.enabled = not profile.enabled


# --- Internals -------------------------------------------------------------


func _build() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)

	# A 2x2 quad: the shader turns its vertices straight into clip space to cover the view.
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)

	_quad = MeshInstance3D.new()
	_quad.name = "OutlineFX"
	_quad.mesh = quad
	_quad.material_override = _mat
	_quad.extra_cull_margin = CULL_MARGIN
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = false


## Keep the quad parented to whichever camera is current (it changes with the scene).
func _follow_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == _camera:
		return
	_camera = cam
	if _quad.get_parent() != null:
		_quad.get_parent().remove_child(_quad)
	if _camera != null:
		_camera.add_child(_quad)
		_quad.transform = Transform3D.IDENTITY


func _apply() -> void:
	if _quad == null:
		return
	var on := profile != null and profile.enabled and _camera != null
	_quad.visible = on
	if not on:
		return
	_mat.set_shader_parameter("outline_color", profile.outline_color)
	_mat.set_shader_parameter("thickness", profile.thickness)
	_mat.set_shader_parameter("opacity", profile.opacity)
	_mat.set_shader_parameter("depth_threshold", profile.depth_threshold)
	_mat.set_shader_parameter("edge_softness", profile.edge_softness)
	_mat.set_shader_parameter("grazing_guard", profile.grazing_guard)
	_mat.set_shader_parameter("crease_strength", profile.crease_strength)
	_mat.set_shader_parameter("crease_threshold", profile.crease_threshold)
	_mat.set_shader_parameter("fade_start", profile.fade_start)
	_mat.set_shader_parameter("fade_end", profile.fade_end)

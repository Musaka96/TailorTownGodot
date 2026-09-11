extends Node

## Autoloaded as "PostFX". Puts the retro filter on screen: a full-rect ColorRect on
## a high CanvasLayer, above every scene and the HUD, running the screen-reading
## shader (assets/shaders/retro_postfx.gdshader). It loads a PostFxProfile (.tres)
## and pushes its values to the shader every frame, so editing the profile — in the
## inspector while running from the editor, or by swapping profiles — updates the
## look live. No scene needs to reference it; being an autoload it just applies.
##
## API: set_profile_path(path) to load a look, set_profile(profile) to hand one in,
## set_enabled(on) / toggle() to flip it, and `profile` to read/tweak the live one.

const SHADER_PATH := "res://assets/shaders/retro_postfx.gdshader"
## The toon/cel-shaded look is on by default. Edit data/postfx/toon.tres to tune it (band
## count = posterize, ink = outline_strength), or point this at another data/postfx/*.tres
## (e.g. chew.tres) to switch looks.
const DEFAULT_PROFILE := "res://data/postfx/toon.tres"
## Above UI (ui.tscn's CanvasLayer) so the filter covers the HUD too.
const LAYER := 100

var profile: PostFxProfile

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	_build()
	set_profile_path(DEFAULT_PROFILE)


func _process(_delta: float) -> void:
	_apply()


# --- Public API ------------------------------------------------------------


func set_profile(new_profile: PostFxProfile) -> void:
	profile = new_profile
	_apply()


func set_profile_path(path: String) -> void:
	var loaded := load(path) as PostFxProfile
	set_profile(loaded if loaded != null else PostFxProfile.make_default())


func set_enabled(on: bool) -> void:
	if profile != null:
		profile.enabled = on


func toggle() -> void:
	if profile != null:
		profile.enabled = not profile.enabled


# --- Internals -------------------------------------------------------------


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)

	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_layer.add_child(_rect)


func _apply() -> void:
	if _rect == null:
		return
	var on := profile != null and profile.enabled and profile.master_strength > 0.001
	_rect.visible = on
	if not on:
		return
	_mat.set_shader_parameter("master_strength", profile.master_strength)
	_mat.set_shader_parameter("temperature", profile.temperature)
	_mat.set_shader_parameter("tint", profile.tint)
	_mat.set_shader_parameter("brightness", profile.brightness)
	_mat.set_shader_parameter("contrast", profile.contrast)
	_mat.set_shader_parameter("saturation", profile.saturation)
	_mat.set_shader_parameter("film_preset", int(profile.film_preset))
	_mat.set_shader_parameter("film_strength", profile.film_strength)
	_mat.set_shader_parameter("pixel_size", profile.pixelate)
	_mat.set_shader_parameter("posterize_levels", profile.posterize)
	_mat.set_shader_parameter("tilt_shift", profile.tilt_shift)
	_mat.set_shader_parameter("tilt_focus", profile.tilt_focus)
	_mat.set_shader_parameter("tilt_focus_size", profile.tilt_focus_size)
	_mat.set_shader_parameter("outline_strength", profile.outline_strength)
	_mat.set_shader_parameter("scanline_strength", profile.scanline_strength)
	_mat.set_shader_parameter("scanline_count", profile.scanline_count)
	_mat.set_shader_parameter("vignette_strength", profile.vignette_strength)
	_mat.set_shader_parameter("grain_strength", profile.grain_strength)
	_mat.set_shader_parameter("aberration", profile.chromatic_aberration)
	_mat.set_shader_parameter("bloom_strength", profile.bloom_strength)
	_mat.set_shader_parameter("barrel", profile.barrel_distortion)
	_mat.set_shader_parameter("vhs_strength", profile.vhs_wobble)
	_mat.set_shader_parameter("flicker_strength", profile.flicker_strength)

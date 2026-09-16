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
## Press F6 ("cycle_look") to step through every look in data/postfx/ plus "off",
## for side-by-side comparison; the current name flashes on screen.
## Profiles with override_lighting also re-light the 3D scene (PostFxLighting).

const SHADER_PATH := "res://assets/shaders/retro_postfx.gdshader"
const DEFAULT_PROFILE := "res://data/postfx/chew.tres"
## Above UI (ui.tscn's CanvasLayer) so the filter covers the HUD too.
const LAYER := 100
const PROFILE_DIR := "res://data/postfx/"
const TOAST_SECONDS := 1.6

var profile: PostFxProfile

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _lighting := PostFxLighting.new()
var _toast: Label
var _toast_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	set_profile_path(DEFAULT_PROFILE)


func _process(delta: float) -> void:
	_apply()
	_lighting.apply(get_tree(), profile)
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("cycle_look") and event.is_action_pressed("cycle_look"):
		cycle_profile()
		get_viewport().set_input_as_handled()


# --- Public API ------------------------------------------------------------


func set_profile(new_profile: PostFxProfile) -> void:
	profile = new_profile
	_apply()


func set_profile_path(path: String) -> void:
	var loaded := load(path) as PostFxProfile
	set_profile(loaded if loaded != null else PostFxProfile.make_default())


## Step to the next look in data/postfx/ (alphabetical), with "off" after the last.
func cycle_profile() -> void:
	var paths := profile_paths()
	var current := profile.resource_path if profile != null and profile.enabled else ""
	var idx := paths.find(current)
	var next := idx + 1
	if next >= paths.size():
		set_profile(null)
		_show_toast("Look: off")
		return
	set_profile_path(paths[next])
	_show_toast("Look: " + paths[next].get_file().get_basename())


func profile_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for file in ResourceLoader.list_directory(PROFILE_DIR):
		if file.ends_with(".tres") or file.ends_with(".res"):
			out.append(PROFILE_DIR + file)
	out.sort()
	return out


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

	_toast = Label.new()
	_toast.visible = false
	_toast.position = Vector2(16, 12)
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(1, 1, 1))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_left = TOAST_SECONDS


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
	_mat.set_shader_parameter("vibrance", profile.vibrance)
	_mat.set_shader_parameter("lift", profile.lift)
	_mat.set_shader_parameter("gamma", profile.gamma)
	_mat.set_shader_parameter("split_tone", profile.split_tone)
	_mat.set_shader_parameter("shadow_tint", _rgb(profile.shadow_tint))
	_mat.set_shader_parameter("highlight_tint", _rgb(profile.highlight_tint))
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


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

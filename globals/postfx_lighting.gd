class_name PostFxLighting
extends RefCounted

## Applies a PostFxProfile's "Scene Lighting" overrides to the live 3D world: the
## active Environment (whatever WorldEnvironment registered on the root World3D) and
## the scene's main shadow-casting DirectionalLight3D. Originals are snapshotted the
## first time a target is seen and put back whenever the active profile does not
## override lighting, so cycling looks is lossless. Owned and ticked by PostFX.

const ENV_PROPS: Array[StringName] = [
	&"tonemap_mode",
	&"tonemap_exposure",
	&"tonemap_white",
	&"background_color",
	&"ambient_light_color",
	&"ambient_light_energy",
	&"ssao_intensity",
	&"ssao_light_affect",
	&"glow_intensity",
	&"fog_light_color",
	&"fog_density",
	&"adjustment_enabled",
	&"adjustment_contrast",
	&"adjustment_saturation",
]
const SUN_PROPS: Array[StringName] = [&"light_color", &"light_energy", &"shadow_opacity"]

var _env: Environment
var _sun: DirectionalLight3D
var _scene: Node
var _env_orig := {}
var _sun_orig := {}
var _env_applied := {}


func apply(tree: SceneTree, profile: PostFxProfile) -> void:
	_track(tree)
	var on := profile != null and profile.enabled and profile.override_lighting
	if _env != null:
		var want: Dictionary = _env_values(profile) if on else _env_orig
		# Environment setters hit the RenderingServer, so only push on change.
		if want != _env_applied:
			_set_all(_env, want)
			_env_applied = want.duplicate()
	if _sun != null and is_instance_valid(_sun):
		_set_all(_sun, _sun_values(profile) if on else _sun_orig)


func _track(tree: SceneTree) -> void:
	var world := tree.root.find_world_3d()
	var env: Environment = world.environment if world != null else null
	if env != _env:
		_env = env
		_env_orig = _snapshot(env, ENV_PROPS) if env != null else {}
		_env_applied = _env_orig.duplicate()
	var scene := tree.current_scene
	if scene != _scene or (_sun != null and not is_instance_valid(_sun)):
		_scene = scene
		_sun = _find_sun(scene)
		_sun_orig = _snapshot(_sun, SUN_PROPS) if _sun != null else {}


## The key light: the first visible, shadow-casting DirectionalLight3D (falls back to
## any visible one). Hidden placeholder lights are ignored.
func _find_sun(scene: Node) -> DirectionalLight3D:
	if scene == null:
		return null
	var fallback: DirectionalLight3D = null
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		var light := n as DirectionalLight3D
		if not light.is_visible_in_tree():
			continue
		if light.shadow_enabled:
			return light
		if fallback == null:
			fallback = light
	return fallback


func _env_values(p: PostFxProfile) -> Dictionary:
	return {
		&"tonemap_mode": p.tonemap,
		&"tonemap_exposure": p.exposure,
		&"tonemap_white": p.tonemap_white,
		&"background_color": p.background_color,
		&"ambient_light_color": p.ambient_color,
		&"ambient_light_energy": p.ambient_energy,
		&"ssao_intensity": p.ssao_intensity,
		&"ssao_light_affect": p.ssao_light_affect,
		&"glow_intensity": p.glow_intensity,
		&"fog_light_color": p.fog_color,
		&"fog_density": p.fog_density,
		&"adjustment_enabled": true,
		&"adjustment_contrast": p.env_contrast,
		&"adjustment_saturation": p.env_saturation,
	}


func _sun_values(p: PostFxProfile) -> Dictionary:
	return {
		&"light_color": p.sun_color,
		&"light_energy": p.sun_energy,
		&"shadow_opacity": p.shadow_opacity,
	}


static func _snapshot(obj: Object, props: Array[StringName]) -> Dictionary:
	var out := {}
	for prop in props:
		out[prop] = obj.get(prop)
	return out


static func _set_all(obj: Object, values: Dictionary) -> void:
	for prop: StringName in values:
		obj.set(prop, values[prop])

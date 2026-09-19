class_name DustMotes
extends GPUParticles3D

## Dust caught in window light: a handful of tiny warm specks drifting in a small pocket of
## air just inside each shop window the sun comes through — and nowhere else. Fading in and
## out, so they're noticed rather than seen.
##   DustMotes.attach_all(level)  # once the level is built
## Windows are found by name (the town kit's "tailor_shop…wall_window…" meshes); a window
## counts as sunlit when the shadow-casting sun shines in through it.

const WINDOW_HINTS := ["tailor_shop", "wall_window"]
const COUNT := 9
const BOX := Vector3(0.7, 0.5, 0.45)
const INSIDE := 1.1
const HEIGHT := 1.25
const SUNLIT := 0.4
const TINT := Color(1.0, 0.93, 0.76, 0.5)


static func attach_all(level: Node3D) -> void:
	var sun := _sun(level)
	if sun == Vector3.ZERO:
		return
	var windows: Array[AABB] = []
	var centre := Vector3.ZERO
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var nm := String(node.name).to_lower()
		if WINDOW_HINTS.all(func(hint: String) -> bool: return nm.contains(hint)):
			var mesh := node as MeshInstance3D
			var box := mesh.global_transform * mesh.get_aabb()
			windows.append(box)
			centre += box.get_center()
	if windows.is_empty():
		return
	centre /= float(windows.size())
	for box in windows:
		# The wall runs along the window's long side; "in" is across it, toward the shop.
		var across := Vector3.RIGHT if box.size.x < box.size.z else Vector3.BACK
		var inward := across * signf((centre - box.get_center()).dot(across))
		if inward.dot(sun) < SUNLIT:
			continue
		var motes := DustMotes.new()
		level.add_child(motes)
		var at := box.get_center() + inward * INSIDE
		motes.global_position = Vector3(at.x, HEIGHT, at.z)
		if across == Vector3.RIGHT:
			motes.rotation.y = PI * 0.5


## Flat direction the shadow-casting sun shines in (zero if there isn't one).
static func _sun(level: Node) -> Vector3:
	for node in level.find_children("*", "DirectionalLight3D", true, false):
		var light := node as DirectionalLight3D
		if light.shadow_enabled and light.visible:
			var dir := -light.global_transform.basis.z
			dir.y = 0.0
			return dir.normalized()
	return Vector3.ZERO


func _init() -> void:
	amount = COUNT
	lifetime = 8.0
	preprocess = 8.0
	randomness = 1.0
	visibility_aabb = AABB(-BOX * 2.0, BOX * 4.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_material = _drift()
	draw_pass_1 = _speck()


func _drift() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = BOX
	mat.direction = Vector3(0.2, -0.3, 0.1)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.01
	mat.initial_velocity_max = 0.03
	mat.gravity = Vector3(0.0, -0.006, 0.0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.12
	mat.turbulence_noise_scale = 2.5
	mat.turbulence_influence_min = 0.02
	mat.turbulence_influence_max = 0.06
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	# Fade in, hang, fade out.
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray(
		[Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	)
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	mat.color_ramp = ramp
	return mat


func _speck() -> QuadMesh:
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_color = TINT
	look.albedo_texture = ContactShadow.soft_dot()
	look.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.022, 0.022)
	quad.material = look
	return quad

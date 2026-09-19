class_name DustMotes
extends GPUParticles3D

## Dust hanging in the air: a few dozen tiny warm specks drifting slowly around whoever it
## follows, fading in and out so they're noticed rather than seen. Emitted in world space,
## so walking leaves them behind instead of dragging a cloud along.
##   DustMotes.attach(player)

const COUNT := 70
const BOX := Vector3(5.0, 1.1, 4.0)
const HEIGHT := 1.5
const TINT := Color(1.0, 0.93, 0.76, 0.55)


static func attach(body: Node3D) -> DustMotes:
	var motes := DustMotes.new()
	motes.position = Vector3(0.0, HEIGHT, 0.0)
	body.add_child(motes)
	return motes


func _init() -> void:
	amount = COUNT
	lifetime = 9.0
	preprocess = 9.0
	randomness = 1.0
	local_coords = false
	visibility_aabb = AABB(-BOX * 1.5, BOX * 3.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_material = _drift()
	draw_pass_1 = _speck()


func _drift() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = BOX
	mat.direction = Vector3(0.3, -0.2, 0.2)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.01
	mat.initial_velocity_max = 0.05
	mat.gravity = Vector3(0.0, -0.006, 0.0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.12
	mat.turbulence_noise_scale = 2.5
	mat.turbulence_influence_min = 0.02
	mat.turbulence_influence_max = 0.06
	mat.scale_min = 0.5
	mat.scale_max = 1.3
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
	quad.size = Vector2(0.035, 0.035)
	quad.material = look
	return quad

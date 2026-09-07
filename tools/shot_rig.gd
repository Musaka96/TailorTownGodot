extends SceneTree

## Visual check of the CHAR1 character rig: dresses it in a suit, plays an
## animation, auto-frames the camera to whatever scale the mesh imported at, and
## prints the measured world-space height. NOT headless.
##   godot --path . --script res://tools/shot_rig.gd

var _rig: Node3D
var _world: Node3D
var _frames := 0


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(900, 900))
	_world = Node3D.new()
	root.add_child(_world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	_world.add_child(sun)

	# 1 m reference cube (y 0..1) at the left for scale.
	var cube := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	cube.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.4, 0.7, 0.4)
	cube.material_override = cm
	cube.position = Vector3(-1.6, 0.5, 0)
	_world.add_child(cube)

	_rig = load("res://entities/character/character_rig.tscn").instantiate()
	_world.add_child(_rig)
	var mat = load("res://data/materials/navy_worsted_pinstripe.tres")
	_rig.set_palette(Color(0.86, 0.72, 0.60))
	_rig.set_outfit(mat, null, mat)
	var ap: AnimationPlayer = _rig.get_node("AnimationPlayer")
	ap.play("idle")
	ap.seek(0.5, true)

	var cam := Camera3D.new()
	cam.position = Vector3(0.8, 0.9, 3.2)
	cam.look_at_from_position(cam.position, Vector3(0, 0.7, 0), Vector3.UP)
	_world.add_child(cam)
	cam.make_current()

	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 3:
		print(
			"RIG world AABB size=%s center=%s" % [_measure(_rig).size, _measure(_rig).get_center()]
		)
	if _frames < 8:
		return
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png("res://.dev/rig.png")
		print("Saved res://.dev/rig.png")
	quit(0)


func _measure(node: Node) -> AABB:
	# Measure from actual bone world positions — reliable for skinned meshes,
	# unlike MeshInstance3D.get_aabb() which is fooled by node scale.
	var skels := node.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return AABB()
	var skel := skels[0] as Skeleton3D
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in skel.get_bone_count():
		var p: Vector3 = (skel.global_transform * skel.get_bone_global_pose(i)).origin
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo, hi - lo)

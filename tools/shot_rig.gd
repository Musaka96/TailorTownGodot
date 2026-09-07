extends SceneTree

## Quick visual check of the character rig: three recoloured copies, the middle
## one seeked into its walk pose. NOT headless.
##   godot --path . --script res://tools/shot_rig.gd

var _frames := 0


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1000, 700))
	var world := Node3D.new()
	root.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	world.add_child(sun)

	var looks := [
		[Color(0.87, 0.72, 0.60), Color(0.15, 0.12, 0.1), "navy_worsted_pinstripe"],
		[Color(0.80, 0.62, 0.48), Color(0.45, 0.3, 0.15), "brown_tweed_herringbone"],
		[Color(0.9, 0.78, 0.66), Color(0.7, 0.6, 0.3), "blue_worsted_glencheck"],
	]
	for i in looks.size():
		var rig: Node = load("res://entities/character/character_rig.tscn").instantiate()
		world.add_child(rig)
		rig.position = Vector3((i - 1) * 1.1, 0, 0)
		rig.rotation_degrees = Vector3(0, 180, 0)  # face the camera
		var look: Array = looks[i]
		rig.set_palette(look[0], look[1])
		var mat = load("res://data/materials/%s.tres" % look[2])
		rig.set_outfit(mat, mat)
		if i == 1:
			var ap: AnimationPlayer = rig.get_node("AnimationPlayer")
			ap.play("walk")
			ap.seek(0.15, true)
			ap.pause()

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.4)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	world.add_child(cam)
	cam.make_current()

	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 30:
		return
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png("res://.dev/rig.png")
		print("Saved res://.dev/rig.png")
	quit(0)

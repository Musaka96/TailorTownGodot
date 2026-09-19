extends SceneTree

## Renders each shop look on the raw v6 gltf (no main.tscn, roof hidden) so the recolours
## can be reviewed without a human watching the window. NOT headless (needs a
## framebuffer):
##   godot --path . --script res://tools/shot_shop_looks.gd
##
## Saves .dev/looks/<id>.png for every preset in data/shop_looks/.

const SHOP_GLTF := "res://IMPORT/town_kit/export/v6/tailor_shop_v6.gltf"
const OUT_DIR := "res://.dev/looks/"
const SETTLE_FRAMES := 6

var _world: Node3D
var _shop: Node3D
var _roof: Node
var _applier: ShopLookApplier
var _camera_ready := false
var _index := 0
var _frames := 0


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(960, 720))
	_world = Node3D.new()
	root.add_child(_world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.65)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.78, 0.82)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	_world.add_child(sun)

	_shop = load(SHOP_GLTF).instantiate()
	_world.add_child(_shop)

	_roof = _shop.find_child("*_Roof", true, false)
	if _roof != null:
		_roof.visible = false

	_applier = ShopLookApplier.attach(_world)
	if _applier == null or _applier.looks.is_empty():
		push_error("shot_shop_looks: could not attach an applier with looks")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	process_frame.connect(_on_frame)


## Looks-down-from-the-front camera: finds the overall interior bounding box (minus the
## roof) and the door meshes, then sits outside the door, elevated, tilted ~55 degrees
## down toward the box's centre — so the walls/floor/rugs/curtains are all in frame with
## the roof off. Needs global_transform, so it only runs once nodes are inside the tree
## (never true synchronously inside _initialize).
func _frame_camera() -> void:
	var bounds := AABB()
	var first := true
	var door_center := Vector3.ZERO
	var door_count := 0
	for node in _shop.find_children("*", "MeshInstance3D", true, false):
		if _roof != null and (node == _roof or _roof.is_ancestor_of(node)):
			continue
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		bounds = a if first else bounds.merge(a)
		first = false
		var n := String(mi.name)
		if n.contains("wall_door") or n.contains("wall_shop_open"):
			door_center += a.get_center()
			door_count += 1

	var center := bounds.get_center()
	var out_dir := Vector3(0, 0, 1)
	if door_count > 0:
		var to_door := (door_center / door_count) - center
		to_door.y = 0
		if to_door.length() > 0.01:
			out_dir = to_door.normalized()

	print("shot_shop_looks: bounds size=%s center=%s out_dir=%s" % [bounds.size, center, out_dir])

	# ~55 degree downward look: pick a horizontal reach and derive height from tan(55).
	var reach: float = maxf(bounds.size.x, bounds.size.z) * 0.55
	var target := center + Vector3(0, bounds.position.y - center.y, 0) * 0.5
	var eye := target + out_dir * reach + Vector3(0, reach * tan(deg_to_rad(55.0)), 0)

	var cam := Camera3D.new()
	_world.add_child(cam)
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	cam.fov = 70.0
	cam.make_current()
	print("shot_shop_looks: eye=%s target=%s" % [eye, target])


func _on_frame() -> void:
	_frames += 1
	if not _camera_ready:
		_frame_camera()
		_camera_ready = true
		return
	if _frames == 2:
		_applier.apply(_index)
		return  # let the override materials render before capturing
	if _frames < SETTLE_FRAMES:
		return
	var look: ShopLook = _applier.looks[_index]
	var image := get_root().get_texture().get_image()
	if image != null:
		var path := OUT_DIR + String(look.id) + ".png"
		image.save_png(path)
		print("Saved ", path)
	_index += 1
	_frames = 1
	if _index >= _applier.looks.size():
		quit(0)

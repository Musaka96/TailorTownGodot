extends SceneTree

## The live cast, dressed through the game's own path: the player (player.tscn, J1), the
## seven named customers (customer.tscn dressed by CustomerManager._dress with a brief in
## their name, so FaceCast picks the face, hair colour and glasses) and Mr. Hemming as
## the tutorial builds him (CustomerPortrait.configure_look(MentorDialog._look())). NOT
## headless:
##   godot --path . --script res://tools/shot_live_cast.gd
## Writes IMPORT/faces_proc/live_cast.png (git-ignored): per character a close-up of the
## head in the world (portrait size) and the dialogue portrait (CustomerPortrait's own
## view, what the speech bubble shows; the player has none, so a small close-up).

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const MANAGER_SCRIPT := "res://entities/customer/customer_manager.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const PORTRAIT_SCRIPT := "res://ui/customer_portrait.gd"
const MENTOR_SCRIPT := "res://ui/tutorial/mentor_dialog.gd"
const NAMES := [
	"Lord Tewkesbury",
	"Mr. Dimmock",
	"Mr. Pettigrew",
	"Ms. Portobello",
	"Mr. Bellamy",
	"Miss Hartley",
	"Dr. Vance",
]
const OUT_DIR := "res://IMPORT/faces_proc"
const SIZE := Vector2i(700, 700)
const CELL := 360
const SMALL := 200
const LABEL_H := 40
const SPACING := 3.0
const DIST := 2.2
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 35
	_world.add_child(_cam)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var cells := []
	var player: Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.set_physics_process(false)
	_world.add_child(player)
	await _frames(3)
	var prig: Node = player.get_node("Model")
	var face: Resource = prig.get("face_style")
	print("player: %s" % _face_name(face))
	cells.append([await _close_up(prig, CELL), 0, 0, "player (%s)" % _face_name(face)])
	cells.append([await _close_up(prig, SMALL), 1, 0, "player, small"])
	player.queue_free()

	var manager: Node = load(MANAGER_SCRIPT).new()
	var pref_cls: GDScript = load(PREF_SCRIPT)
	var customers := []
	for i in NAMES.size():
		var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
		_world.add_child(cust)
		cust.global_position = Vector3(SPACING * (i + 1), 0.0, 0.0)
		cust.set_physics_process(false)
		cust.preference = pref_cls.random_pref(RandomNumberGenerator.new(), NAMES[i])
		manager.call("_dress", cust)
		customers.append(cust)
	await _frames(3)
	for i in customers.size():
		var cust: Node3D = customers[i]
		var rig: Node = cust.get_node("Rig")
		var label := "%s (%s)" % [NAMES[i], _face_name(rig.get("face_style"))]
		print(
			(
				"%s: face %s, hair #%s, glasses %s %s, head %d"
				% [
					NAMES[i],
					cust.face_style,
					cust.hair_color.to_html(false),
					cust.glasses,
					cust.glasses_color,
					cust.head_index
				]
			)
		)
		var col := ((i + 1) % 3) * 2
		var row := (i + 1) / 3
		cells.append([await _close_up(rig, CELL), col, row, label])
		cells.append([await _portrait(cust, {}), col + 1, row, "%s, dialogue" % NAMES[i]])
	manager.free()

	var mentor: Node = load(MENTOR_SCRIPT).new()
	var look: Dictionary = mentor.call("_look")
	mentor.free()
	print("Mr. Hemming: face %s" % look.get("face_style", ""))
	var mentor_img: Image = await _portrait(null, look)
	cells.append([mentor_img, 4, 2, "Mr. Hemming, dialogue (%s)" % look.get("face_style", "")])
	await _save_grid(cells, 6, 3, "live_cast.png")
	quit(0)


## The rig's head from the front, framed on the head bone, `cell` pixels square.
func _close_up(rig: Node, cell: int) -> Image:
	var blink: Timer = rig.get("_blink")
	if blink != null:
		blink.stop()
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := (rig as Node3D).global_position + Vector3(0, 1.5, 0)
	if skel != null:
		var bone := skel.find_bone("head_2")
		head = skel.global_transform * skel.get_bone_global_pose(bone).origin
	var at := head + Vector3(0, 0.36, 0)
	_cam.look_at_from_position(at + Vector3(0, 0, DIST), at, Vector3.UP)
	await _frames(4)
	var img := _vp.get_texture().get_image()
	var side := int(SIZE.x * 0.8)
	var crop := img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))
	crop.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
	return crop


## The dialogue portrait (CustomerPortrait) for a customer, or for a plain look when
## `cust` is null (the mentor): its own view's image.
func _portrait(cust: Node, look: Dictionary) -> Image:
	var portrait: Control = load(PORTRAIT_SCRIPT).new()
	root.add_child(portrait)
	await _frames(2)
	if cust != null:
		portrait.call("configure", cust)
	else:
		portrait.call("configure_look", look)
	portrait.call("set_live", true)
	var rig: Node = portrait.get("_rig")
	(rig.get("_blink") as Timer).stop()
	rig.call("set_talking", false)
	await _frames(8)
	var view: SubViewport = portrait.get("_view")
	var img := view.get_texture().get_image()
	portrait.queue_free()
	return img


func _face_name(face: Resource) -> String:
	return face.resource_path.get_file().get_basename() if face != null else "none"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cells: Array, cols: int, rows: int, file: String) -> void:
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * rows)
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos := Vector2(int(c[1]) * CELL, int(c[2]) * (CELL + LABEL_H))
		var img: Image = c[0]
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = pos + (Vector2(CELL, CELL) - Vector2(img.get_size())) * 0.5
		board.add_child(tr)
		var lab := Label.new()
		lab.text = c[3]
		lab.position = pos + Vector2(0, CELL)
		lab.size = Vector2(CELL, LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		lab.add_theme_color_override("font_color", INK)
		lab.add_theme_font_size_override("font_size", 14)
		board.add_child(lab)
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(board)
	root.add_child(vp)
	await _frames(4)
	var path := OUT_DIR + "/" + file
	var err := vp.get_texture().get_image().save_png(path)
	vp.queue_free()
	print("Saved %s (%s)" % [path, error_string(err)])

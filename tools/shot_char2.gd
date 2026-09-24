extends SceneTree

## Dev-only side-by-side of the live character (CHARTGEN1, left) and a replacement model
## (CHARTGEN2 from tools/blender/tripo_character.py, right), both driven by the real
## CharacterRig script and animations, dressed in a pinstripe so the fabric grain can be
## judged. NOT headless (it renders):
##   godot --path . --script res://tools/shot_char2.gd
##   godot --path . --script res://tools/shot_char2.gd -- --glb=res://.dev/x.glb --tag=x
## Writes engine_<tag>_<view>.png to IMPORT/CHARREWORK/report/ (git-ignored).
##
## The outfit goes on through the rig's own set_outfit one frame after the rigs enter
## the tree: called earlier, the rig's mesh slots are still empty (they are filled in its
## _ready), so the cloth and the skin tint silently miss. The suit is a pinstripe so the
## grain reads; the shirt is a plain cream poplin, as a shirt would be.
## "rest_back" is the back view in the rest pose (no animation), to tell faceting in the
## mesh from bad weights in the idle pose.

const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const RIG_SCENE := "res://entities/character/character_rig.tscn"
const DEFAULT_GLB := "res://assets/characters/CHARTGEN2.glb"
const OUT_DIR := "res://IMPORT/CHARREWORK/report"
const CLOTH := "res://data/materials/navy_worsted_pinstripe.tres"
const CLOTH_UV_SCALE := 6.0
const SKIN := Color(0.86, 0.72, 0.60)
const SEPARATION := 0.9
const SHIRT_COLOR := Color(0.94, 0.93, 0.89)
const POPLIN := 6  # Enums.Fabric.POPLIN (autoload enums are not resolved in a --script run)
const SOLID := 0  # Enums.Pattern.SOLID
const ORTHO_SIZE := 2.4
const ARM_CHAIN := [["upperarm", "lowerarm"], ["lowerarm", "wrist"]]
const LEG_CHAIN := [["upperleg", "lowerleg"], ["lowerleg", "foot"], ["foot", "toes"]]
# name, animation, time fraction, camera position, look-at target, and optionally:
# which rig to show ("both" / "new" / "old"), orthographic size (0 = perspective), and
# whether to print the pose measurements (sleeve / trouser-leg axes, bone angles)
const SHOTS := [
	["front", "idle", 0.3, Vector3(0.0, 1.1, 5.2), Vector3(0.0, 1.05, 0.0)],
	["back", "idle", 0.3, Vector3(0.0, 1.1, -5.2), Vector3(0.0, 1.05, 0.0)],
	["three_quarter", "idle", 0.3, Vector3(3.4, 1.9, 3.9), Vector3(0.0, 1.0, 0.0)],
	["walk", "walk", 0.25, Vector3(3.6, 1.6, 3.6), Vector3(0.0, 0.95, 0.0)],
	["sleeve", "idle", 0.3, Vector3(1.75, 1.25, 1.0), Vector3(1.35, 0.95, 0.0)],
	["rest_back", "", 0.0, Vector3(0.0, 1.1, -5.2), Vector3(0.0, 1.05, 0.0)],
	["back_close", "idle", 0.3, Vector3(0.9, 0.95, -2.6), Vector3(0.9, 0.85, 0.0)],
	["rest_back_close", "", 0.0, Vector3(0.9, 0.95, -2.6), Vector3(0.9, 0.85, 0.0)],
	# both torsos at one framing, arms down, so the armhole and shoulders compare 1:1
	[
		"torso_front",
		"idle",
		0.3,
		Vector3(0.0, 1.0, 4.0),
		Vector3(0.0, 0.95, 0.0),
		"both",
		0.0,
		true
	],
	["torso_back", "idle", 0.3, Vector3(0.0, 1.0, -4.0), Vector3(0.0, 0.95, 0.0)],
	# the sleeve / body junction of each rig from the front three-quarter
	["junction_new", "idle", 0.3, Vector3(1.75, 1.15, 1.35), Vector3(1.1, 0.95, 0.0)],
	["junction_old", "idle", 0.3, Vector3(-0.05, 1.15, 1.35), Vector3(-0.7, 0.95, 0.0)],
	# orthographic, one rig at a time, for overlays on the owner's reference sheets
	[
		"ortho_idle_front_new",
		"idle",
		0.0,
		Vector3(0.9, 1.124, 6.0),
		Vector3(0.9, 1.124, 0.0),
		"new",
		ORTHO_SIZE,
		true
	],
	[
		"ortho_idle_back_new",
		"idle",
		0.0,
		Vector3(0.9, 1.124, -6.0),
		Vector3(0.9, 1.124, 0.0),
		"new",
		ORTHO_SIZE,
		false
	],
	[
		"ortho_idle_front_old",
		"idle",
		0.0,
		Vector3(-0.9, 1.124, 6.0),
		Vector3(-0.9, 1.124, 0.0),
		"old",
		ORTHO_SIZE,
		false
	],
	[
		"ortho_rest_front_new",
		"",
		0.0,
		Vector3(0.9, 1.124, 6.0),
		Vector3(0.9, 1.124, 0.0),
		"new",
		ORTHO_SIZE,
		false
	],
]

var _rigs: Array[Node3D] = []
var _cam: Camera3D
var _frame := 0
var _shot := 0
var _tag := ""


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1000, 900))
	var glb := DEFAULT_GLB
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glb="):
			glb = arg.trim_prefix("--glb=")
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=") + "_"
	var world := Node3D.new()
	root.add_child(world)
	_add_lights(world)

	var old_rig := (load(RIG_SCENE) as PackedScene).instantiate() as Node3D
	old_rig.position.x = -SEPARATION
	world.add_child(old_rig)
	_rigs.append(old_rig)

	var model := _load_model(glb)
	if model == null:
		push_error("could not load " + glb)
		quit(1)
		return
	var new_rig := _build_rig(model)
	new_rig.position.x = SEPARATION
	world.add_child(new_rig)
	_rigs.append(new_rig)

	_report(new_rig, glb)

	_cam = Camera3D.new()
	_cam.fov = 30.0
	world.add_child(_cam)
	_cam.make_current()
	process_frame.connect(_on_frame)


func _load_model(path: String) -> Node3D:
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			return packed.instantiate() as Node3D
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


## The same wiring as character_rig.tscn, with the model swapped: the rig script finds
## its meshes by name under a child called CHARTGEN1, and the AnimationPlayer's tracks
## are rooted there.
func _build_rig(model: Node3D) -> Node3D:
	var rig := Node3D.new()
	rig.name = "CharacterRig2"
	rig.set_script(load(RIG_SCRIPT))
	model.name = "CHARTGEN1"
	rig.add_child(model)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("../CHARTGEN1")
	rig.add_child(player)
	return rig


func _dress(rig: Node3D) -> void:
	var suit := load(CLOTH) as Resource
	var shirt: Resource = load("res://data/scripts/material_type.gd").new()
	shirt.set("id", &"shot_cream_poplin")
	shirt.set("fabric", POPLIN)
	shirt.set("pattern", SOLID)
	shirt.set("cloth_color", SHIRT_COLOR)
	rig.call("set_palette", SKIN)
	rig.call("set_hair_color", Color(0.25, 0.16, 0.10))
	rig.call("set_outfit", suit, shirt, suit)
	var flats := {
		"shoes": Color(0.16, 0.12, 0.10),
		"buttons": Color(0.75, 0.62, 0.35),
		"tie": Color(0.55, 0.12, 0.14),
		"square": Color(0.92, 0.92, 0.9),
		"left leg": Color(0.16, 0.12, 0.10),
		"right leg": Color(0.16, 0.12, 0.10),
	}
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if flats.has(String(m.name)):
			var flat := StandardMaterial3D.new()
			flat.albedo_color = flats[String(m.name)]
			flat.roughness = 1.0
			m.material_override = flat


func _report(rig: Node3D, glb: String) -> void:
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var names: Array[String] = []
	if skel != null:
		for i in skel.get_bone_count():
			names.append(skel.get_bone_name(i))
	print("%s: %d bones %s" % [glb, names.size(), names])
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		print(
			(
				"  mesh %-8s skin=%s surfaces=%d"
				% [m.name, m.skin != null, m.mesh.get_surface_count() if m.mesh else 0]
			)
		)


func _pose(shot: Array) -> void:
	for rig in _rigs:
		var player := rig.get_node("AnimationPlayer") as AnimationPlayer
		var clip := String(shot[1])
		if clip == "":
			player.stop()
			var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
			if skel != null:
				skel.reset_bone_poses()
			continue
		if not player.has_animation(clip):
			continue
		player.play(clip)
		player.seek(player.get_animation(clip).length * float(shot[2]), true)
		player.pause()
	var who: String = shot[5] if shot.size() > 5 else "both"
	_rigs[0].visible = who != "new"
	_rigs[1].visible = who != "old"
	var ortho: float = shot[6] if shot.size() > 6 else 0.0
	if ortho > 0.0:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = ortho
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.look_at_from_position(shot[3], shot[4], Vector3.UP)


## Where the pose puts the sleeves and trouser legs, from the skinned vertices, and how
## far the clip turns the limb bones: to tell the pose from the weights.
func _measure(shot: Array) -> void:
	print("== pose %s (%s at %.0f%% of the clip)" % [shot[0], shot[1], float(shot[2]) * 100.0])
	for rig in _rigs:
		var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
		var jacket := rig.find_child("jacket", true, false) as MeshInstance3D
		var legs := rig.find_child("legs", true, false) as MeshInstance3D
		if skel == null or jacket == null or legs == null:
			continue
		print("  %s" % ("CHARTGEN1 (owner)" if rig == _rigs[0] else "CHARTGEN2 (new)"))
		# the owner's jacket has no vertices between |x| 0.30 and 0.45 (one long ring)
		var jp := _skinned(jacket, skel)
		for side in [1.0, -1.0]:
			var bone := "lowerarm" + (".l" if side > 0 else ".r")
			print(
				(
					"    sleeve %s off a rigid forearm tube: |x| .45-.70 %s, |x| .30-.45 %s"
					% [
						"+x" if side > 0 else "-x",
						_rigid_gap(jp, skel, bone, side, 0.45, 0.70),
						_rigid_gap(jp, skel, bone, side, 0.30, 0.45),
					]
				)
			)
		var lp := _skinned(legs, skel)
		for side in [1.0, -1.0]:
			var top := _band(lp, 1, side, 0.50, 0.62)
			var knee := _band(lp, 1, side, 0.33, 0.43)
			var hem := _band(lp, 1, side, 0.13, 0.22)
			print(
				(
					(
						"    trouser leg %s: axis %5.1f deg off vertical (front view %+5.1f),"
						+ " bend at the knee %5.1f deg"
					)
					% [
						"+x" if side > 0 else "-x",
						_off_vertical(hem - top),
						_front_tilt(hem - top),
						rad_to_deg((knee - top).angle_to(hem - knee)),
					]
				)
			)
		if rig == _rigs[1]:
			_bone_angles(skel)


## Skeleton-space positions of a skinned mesh in the current pose, each paired with its
## rest position: [[rest, posed], ...].
func _skinned(mi: MeshInstance3D, skel: Skeleton3D) -> Array:
	var out := []
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		mats.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	for surf in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(surf)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / maxi(verts.size(), 1)
		for i in verts.size():
			var p := Vector3.ZERO
			for k in per:
				var w: float = weights[i * per + k]
				if w > 0.0:
					p += (mats[bones[i * per + k]] * verts[i]) * w
			out.append([verts[i], p])
	return out


## Posed centre (bounding box, so dense trims such as cuff buttons do not drag it) of
## the vertices whose REST coordinate `axis` (0 = |x|, 1 = y) lies in [lo, hi] on one
## side (x sign).
func _band(points: Array, axis: int, side: float, lo: float, hi: float) -> Vector3:
	var box := AABB()
	var first := true
	for pair in points:
		var rest: Vector3 = pair[0]
		if rest.x * side <= 0.0:
			continue
		var c: float = absf(rest.x) if axis == 0 else rest.y
		if c >= lo and c <= hi:
			if first:
				box = AABB(pair[1], Vector3.ZERO)
				first = false
			else:
				box = box.expand(pair[1])
	return box.get_center()


## How far (cm, mean / max) the posed vertices with rest |x| in [lo, hi] sit from where
## they would be if they moved rigidly with `bone`: 0 means a rigid tube on that bone.
func _rigid_gap(
	points: Array, skel: Skeleton3D, bone: String, side: float, lo: float, hi: float
) -> String:
	var b := skel.find_bone(bone)
	var move := skel.get_bone_global_pose(b) * skel.get_bone_global_rest(b).affine_inverse()
	var total := 0.0
	var most := 0.0
	var n := 0
	for pair in points:
		var rest: Vector3 = pair[0]
		if rest.x * side <= 0.0 or absf(rest.x) < lo or absf(rest.x) > hi:
			continue
		var gap: float = (move * rest).distance_to(pair[1]) * 100.0
		total += gap
		most = maxf(most, gap)
		n += 1
	if n == 0:
		return "no verts"
	return "%.1f / %.1f cm (%d verts)" % [total / n, most, n]


func _off_vertical(d: Vector3) -> float:
	return rad_to_deg(d.angle_to(Vector3.DOWN))


## Signed lean seen from the front (+ = the lower end is further from the centre line).
func _front_tilt(d: Vector3) -> float:
	return rad_to_deg(atan2(d.x, -d.y))


## How the clip turns each limb bone: its direction off straight down, and how far it
## has turned from the rest pose.
func _bone_angles(skel: Skeleton3D) -> void:
	print("    bones (direction head -> child head): off vertical in the pose | turned from rest")
	for side in [".l", ".r"]:
		for chain in [ARM_CHAIN, LEG_CHAIN]:
			for pair in chain:
				var a := skel.find_bone(String(pair[0]) + side)
				var b := skel.find_bone(String(pair[1]) + side)
				if a < 0 or b < 0:
					continue
				var pose: Vector3 = (
					skel.get_bone_global_pose(b).origin - skel.get_bone_global_pose(a).origin
				)
				var rest: Vector3 = (
					skel.get_bone_global_rest(b).origin - skel.get_bone_global_rest(a).origin
				)
				print(
					(
						"      %-11s %5.1f deg off vertical (front view %+6.1f) | turned %5.1f deg"
						% [
							String(pair[0]) + side,
							_off_vertical(pose),
							_front_tilt(pose),
							rad_to_deg(pose.angle_to(rest)),
						]
					)
				)


func _on_frame() -> void:
	_frame += 1
	if _frame == 2 and _shot == 0:
		_hide_hud(root)
		for rig in _rigs:
			_dress(rig)
			# the rig's AnimationTree owns the skeleton; switch it off to pose by hand
			for tree in rig.find_children("*", "AnimationTree", true, false):
				(tree as AnimationTree).active = false
			var player := rig.get_node("AnimationPlayer") as AnimationPlayer
			print("%s animations: %s" % [rig.name, player.get_animation_list()])
	if _frame == 4:
		_pose(SHOTS[_shot])
	elif _frame == 7 and SHOTS[_shot].size() > 7 and SHOTS[_shot][7]:
		_measure(SHOTS[_shot])
	elif _frame == 10:
		var image := root.get_texture().get_image()
		var path := "%s/engine_%s%s.png" % [OUT_DIR, _tag, SHOTS[_shot][0]]
		if image != null and image.save_png(ProjectSettings.globalize_path(path)) == OK:
			print("Saved " + path)
		_shot += 1
		_frame = 0
		if _shot >= SHOTS.size():
			quit(0)


## The game's autoloads bring their HUD along; the comparison is about the models.
func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		elif child is Control:
			(child as Control).visible = false
		else:
			_hide_hud(child)


func _add_lights(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.76, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 200, 0)
	fill.light_energy = 0.4
	world.add_child(fill)

extends SceneTree

## Dev-only side-by-side of the live character (CHARTGEN1, left) and a replacement model
## (CHARTGEN2 from tools/blender/tripo_character.py, right), both driven by the real
## CharacterRig script and animations, dressed in a pinstripe so the fabric grain can be
## judged. NOT headless (it renders):
##   godot --path . --script res://tools/shot_char2.gd
##   godot --path . --script res://tools/shot_char2.gd -- --glb=res://.dev/x.glb --tag=x
##   godot --path . --script res://tools/shot_char2.gd -- --only=hem_   (shots by prefix)
##   ... -- --only=shoulder_ --arm-drop=45 --tag=basic_45   (arms posed by hand, see below)
## --arm-drop=<deg>: no animation; the skeleton at rest except both upperarms, turned down
## by that many degrees along the calm idle's own rotation (90 = the calm idle's arms).
## "shoulder_" shots go to IMPORT/CHARREWORK/report/shoulder/shoulder_<tag><view>.png.
## --third=<glb>: a third rig beside the two, and each of the three in its own suit (see
## THREE_SUITS); only the "three_" shots run, saved as report/three_<view>.png.
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
const THREE_GAP := 1.35
# --third mode: [suit MaterialType, tie colour] for the owner's rig, the second and the third
const THREE_SUITS := [
	["res://data/materials/navy_worsted_pinstripe.tres", Color(0.55, 0.12, 0.14)],
	["res://data/materials/grey_tweed_herringbone.tres", Color(0.42, 0.07, 0.12)],
	["res://data/materials/charcoal_worsted_solid.tres", Color(0.10, 0.14, 0.30)],
]
const SHIRT_COLOR := Color(0.94, 0.93, 0.89)
const POPLIN := 6  # Enums.Fabric.POPLIN (autoload enums are not resolved in a --script run)
const SOLID := 0  # Enums.Pattern.SOLID
const ORTHO_SIZE := 2.4
const HEM_ORTHO := 0.75
const HEM_GAP := 0.34  # the two rigs stand this far either side of the centre for hem shots
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
	# trouser bottoms, both rigs close together (front/back side by side, side view one
	# behind the other along z), rest and calm idle, plus a wireframe
	[
		"hem_front_rest",
		"",
		0.0,
		Vector3(0.0, 0.3, 4.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		true
	],
	[
		"hem_back_rest",
		"",
		0.0,
		Vector3(0.0, 0.3, -4.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		false
	],
	[
		"hem_side_rest",
		"",
		0.0,
		Vector3(4.0, 0.3, 0.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		false
	],
	[
		"hem_front_wire_rest",
		"",
		0.0,
		Vector3(0.0, 0.3, 4.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		false
	],
	[
		"hem_front_idle",
		"idle",
		0.0,
		Vector3(0.0, 0.3, 4.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		true
	],
	[
		"hem_back_idle",
		"idle",
		0.0,
		Vector3(0.0, 0.3, -4.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		false
	],
	[
		"hem_side_idle",
		"idle",
		0.0,
		Vector3(4.0, 0.3, 0.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		false
	],
	[
		"hem_front_wire_idle",
		"idle",
		0.0,
		Vector3(0.0, 0.3, 4.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		false
	],
	[
		"hem_front_walk",
		"walk",
		0.25,
		Vector3(0.0, 0.3, 4.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		false
	],
	[
		"hem_side_walk",
		"walk",
		0.25,
		Vector3(4.0, 0.3, 0.0),
		Vector3(0.0, 0.3, 0.0),
		"both",
		HEM_ORTHO,
		true
	],
	# shoulder study (new rig only); combine with --arm-drop
	[
		"shoulder_front",
		"",
		0.0,
		Vector3(0.9, 1.05, 3.4),
		Vector3(0.9, 0.95, 0.0),
		"new",
		0.0,
		false
	],
	[
		"shoulder_back",
		"",
		0.0,
		Vector3(0.9, 1.05, -3.4),
		Vector3(0.9, 0.95, 0.0),
		"new",
		0.0,
		false
	],
	[
		"shoulder_closeup",
		"",
		0.0,
		Vector3(1.75, 1.15, 1.35),
		Vector3(1.1, 0.95, 0.0),
		"new",
		0.0,
		false
	],
	# walk-frame close-ups, new rig only; the camera is aimed from the bones (see _aim)
	["hands_walk", "walk", 0.25, Vector3.ZERO, Vector3.ZERO, "new", 0.0, true],
	["rise_walk", "walk", 0.25, Vector3.ZERO, Vector3.ZERO, "new", 0.0, false],
	["knee_walk", "walk", 0.25, Vector3.ZERO, Vector3.ZERO, "new", 0.0, false],
	# --third mode: all three rigs side by side (THREE_GAP apart)
	["three_front", "idle", 0.3, Vector3(0.0, 1.1, 7.2), Vector3(0.0, 1.05, 0.0), "all"],
	["three_back", "idle", 0.3, Vector3(0.0, 1.1, -7.2), Vector3(0.0, 1.05, 0.0), "all"],
	["three_three_quarter", "idle", 0.3, Vector3(4.6, 2.2, 5.6), Vector3(0.0, 1.0, 0.0), "all"],
	["three_walk", "walk", 0.25, Vector3(4.8, 2.0, 5.4), Vector3(0.0, 0.95, 0.0), "all"],
	[
		"three_sleeve",
		"idle",
		0.3,
		Vector3(THREE_GAP + 0.85, 1.25, 1.0),
		Vector3(THREE_GAP + 0.45, 0.95, 0.0),
		"all"
	],
]

var _rigs: Array[Node3D] = []
var _cam: Camera3D
var _frame := 0
var _shot := 0
var _tag := ""
var _only := ""
var _arm_drop := -1.0
var _third := ""


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1000, 900))
	var glb := DEFAULT_GLB
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glb="):
			glb = arg.trim_prefix("--glb=")
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=") + "_"
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg.begins_with("--arm-drop="):
			_arm_drop = float(arg.trim_prefix("--arm-drop="))
		elif arg.begins_with("--third="):
			_third = arg.trim_prefix("--third=")
			_only = "three_"
	RenderingServer.set_debug_generate_wireframes(true)
	# test renders stand in the calm idle (arms straight down); the game keeps the KayKit
	# idle. Must be set before the first rig builds (and caches) the animation library.
	CharacterAnimations.calm_idle = true
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
	if _third != "":
		var third_model := _load_model(_third)
		if third_model == null:
			push_error("could not load " + _third)
			quit(1)
			return
		var third_rig := _build_rig(third_model)
		third_rig.name = "CharacterRig3"
		world.add_child(third_rig)
		_rigs.append(third_rig)
		_report(third_rig, _third)

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
	var suit_path := CLOTH
	var tie := Color(0.55, 0.12, 0.14)
	if _third != "":
		var combo: Array = THREE_SUITS[_rigs.find(rig)]
		suit_path = combo[0]
		tie = combo[1]
	var suit := load(suit_path) as Resource
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
		"tie": tie,
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
	var name := String(shot[0])
	var hem := name.begins_with("hem_")
	var side_view := name.begins_with("hem_side")
	_rigs[0].position = Vector3(
		0.0 if side_view else (-HEM_GAP if hem else -SEPARATION), 0.0, HEM_GAP if side_view else 0.0
	)
	_rigs[1].position = Vector3(
		0.0 if side_view else (HEM_GAP if hem else SEPARATION), 0.0, -HEM_GAP if side_view else 0.0
	)
	if _rigs.size() > 2:
		for k in _rigs.size():
			_rigs[k].position = Vector3((k - 1) * THREE_GAP, 0.0, 0.0)
	root.debug_draw = (
		Viewport.DEBUG_DRAW_WIREFRAME if name.contains("_wire") else Viewport.DEBUG_DRAW_DISABLED
	)
	if _arm_drop >= 0.0:
		for rig in _rigs:
			_drop_arms(rig, _arm_drop)
	var who: String = shot[5] if shot.size() > 5 else "both"
	_rigs[0].visible = who != "new"
	_rigs[1].visible = who != "old"
	for k in range(2, _rigs.size()):
		_rigs[k].visible = who == "all"
	var ortho: float = shot[6] if shot.size() > 6 else 0.0
	if ortho > 0.0:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = ortho
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.look_at_from_position(shot[3], shot[4], Vector3.UP)
	if String(shot[0]) in ["hands_walk", "rise_walk", "knee_walk"]:
		_aim(String(shot[0]))


## Point the camera at the new rig's left hand (hands_walk) or its crotch (rise_walk).
func _aim(name: String) -> void:
	var rig := _rigs[1]
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	if name == "knee_walk":
		# both knees, from the engine_walk camera's direction, closer in
		var kl := skel.get_bone_global_pose(skel.find_bone("lowerleg.l")).origin
		var kr := skel.get_bone_global_pose(skel.find_bone("lowerleg.r")).origin
		var mid := skel.global_transform * ((kl + kr) * 0.5)
		_cam.look_at_from_position(mid + Vector3(0.75, 0.25, 0.75), mid, Vector3.UP)
		return
	if name == "hands_walk":
		var hand := (
			skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hand.l")).origin
		)
		_cam.look_at_from_position(hand + Vector3(0.55, 0.2, 0.75), hand, Vector3.UP)
	else:
		var hips := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hips")).origin
		var crotch := hips + Vector3(0.0, 0.12, 0.0)
		_cam.look_at_from_position(crotch + Vector3(0.1, 0.05, 1.1), crotch, Vector3.UP)


## Rest pose except both upperarms, turned down `deg` degrees along the calm idle's arm
## rotation (CharacterAnimations._calm_rotation), so 90 is exactly the calm idle's arms.
func _drop_arms(rig: Node3D, deg: float) -> void:
	var player := rig.get_node("AnimationPlayer") as AnimationPlayer
	player.stop()
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	skel.reset_bone_poses()
	for side in [".l", ".r"]:
		var bone := skel.find_bone("upperarm" + side)
		var rest := skel.get_bone_rest(bone).basis.get_rotation_quaternion()
		var calm: Quaternion = CharacterAnimations._calm_rotation(skel, bone)
		var turn := calm * rest.inverse()
		skel.set_bone_pose_rotation(bone, Quaternion.IDENTITY.slerp(turn, deg / 90.0) * rest)


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
		print("  %s" % ["CHARTGEN1 (owner)", "CHARTGEN2 (new)", "third rig"][_rigs.find(rig)])
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
		_hem_radii(lp, skel)
		_hands_at_cuffs(rig, skel)
		for part in ["legs", "jacket", "shirt"]:
			var mi := rig.find_child(part, true, false) as MeshInstance3D
			if mi != null:
				_split_gaps(part, _skinned(mi, skel))
		if rig == _rigs[1]:
			_bone_angles(skel)


## The trouser tube per leg at the hem ring, +5, +10 and +20 cm (by REST height), in the
## current pose: half-width across (x), half-depth (z), and where its centre sits.
func _hem_radii(points: Array, skel: Skeleton3D) -> void:
	for side in [1.0, -1.0]:
		var bottom := INF
		for pair in points:
			var rest: Vector3 = pair[0]
			if rest.x * side > 0.0:
				bottom = minf(bottom, rest.y)
		var posed_bottom := INF
		for pair in points:
			var rest: Vector3 = pair[0]
			if rest.x * side > 0.0:
				posed_bottom = minf(posed_bottom, (pair[1] as Vector3).y)
		var row := (
			"    trouser %s hem at %.3f m (rest %.3f):"
			% ["+x" if side > 0 else "-x", posed_bottom, bottom]
		)
		for band in [
			[0.0, 0.012, "ring"], [0.04, 0.06, "+5"], [0.09, 0.11, "+10"], [0.19, 0.21, "+20"]
		]:
			var box := AABB()
			var n := 0
			for pair in points:
				var rest: Vector3 = pair[0]
				if rest.x * side <= 0.0:
					continue
				if rest.y >= bottom + float(band[0]) and rest.y <= bottom + float(band[1]):
					box = AABB(pair[1], Vector3.ZERO) if n == 0 else box.expand(pair[1])
					n += 1
			if n == 0:
				row += "  %s -" % band[2]
			else:
				row += (
					"  %s x%.3f z%.3f c%+.3f"
					% [band[2], box.size.x * 0.5, box.size.z * 0.5, box.get_center().x]
				)
		print(
			row + "  | ring tilt off square to the shin %.1f deg" % _ring_tilt(points, skel, side)
		)


## Angle between the hem ring's plane normal and the lowerleg bone in the current pose:
## 0 when the cuff stays square to the shin.
func _ring_tilt(points: Array, skel: Skeleton3D, side: float) -> float:
	var bottom := INF
	for pair in points:
		if (pair[0] as Vector3).x * side > 0.0:
			bottom = minf(bottom, (pair[0] as Vector3).y)
	var ring: Array[Vector3] = []
	for pair in points:
		var rest: Vector3 = pair[0]
		if rest.x * side > 0.0 and rest.y <= bottom + 0.004:
			ring.append(pair[1])
	if ring.size() < 4:
		return 0.0
	var c := Vector3.ZERO
	for p in ring:
		c += p
	c /= ring.size()
	var cov := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	for p in ring:
		var d := p - c
		cov.x += d * d.x
		cov.y += d * d.y
		cov.z += d * d.z
	# smallest eigenvector = power iteration on (trace * I - cov)
	var tr := cov.x.x + cov.y.y + cov.z.z
	var shifted := Basis(
		Vector3(tr, 0, 0) - cov.x, Vector3(0, tr, 0) - cov.y, Vector3(0, 0, tr) - cov.z
	)
	var n := Vector3(0.1, 1.0, 0.1).normalized()
	for i in 60:
		n = (shifted * n).normalized()
	var a := skel.find_bone("lowerleg" + (".l" if side > 0 else ".r"))
	var b := skel.find_bone("foot" + (".l" if side > 0 else ".r"))
	var shin := skel.get_bone_global_pose(b).origin - skel.get_bone_global_pose(a).origin
	var ang := rad_to_deg(n.angle_to(shin))
	return minf(ang, 180.0 - ang)


## How far each hand ball's centre sits from the shirt cuff and the sleeve end (centres
## of the vertices past |x| 0.60 / 0.66 at rest), at rest and in the current pose.
func _hands_at_cuffs(rig: Node3D, skel: Skeleton3D) -> void:
	var arms := rig.find_child("arms", true, false) as MeshInstance3D
	var shirt := rig.find_child("shirt", true, false) as MeshInstance3D
	var jacket := rig.find_child("jacket", true, false) as MeshInstance3D
	if arms == null or shirt == null or jacket == null:
		return
	var ap := _skinned(arms, skel)
	var sp := _skinned(shirt, skel)
	var jp := _skinned(jacket, skel)
	for side in [1.0, -1.0]:
		var ball := _centre(ap, side, 0.0)
		var cuff := _centre(sp, side, 0.60)
		var sleeve := _centre(jp, side, 0.66)
		var fore := skel.find_bone("lowerarm" + (".l" if side > 0 else ".r"))
		var move := (
			skel.get_bone_global_pose(fore) * skel.get_bone_global_rest(fore).affine_inverse()
		)
		print(
			(
				"    hand %s: ball centre %.1f cm off where a rigid forearm would carry it"
				% ["+x" if side > 0 else "-x", (move * ball[0]).distance_to(ball[1]) * 100.0]
			)
		)
		print(
			(
				(
					"    hand %s: ball to shirt cuff %.3f m (rest %.3f), ball to sleeve end %.3f m"
					+ " (rest %.3f)"
				)
				% [
					"+x" if side > 0 else "-x",
					ball[1].distance_to(cuff[1]),
					ball[0].distance_to(cuff[0]),
					ball[1].distance_to(sleeve[1]),
					ball[0].distance_to(sleeve[0]),
				]
			)
		)


## [rest centre, posed centre] of one side's vertices with rest |x| past `min_x`.
func _centre(points: Array, side: float, min_x: float) -> Array:
	var rest := Vector3.ZERO
	var posed := Vector3.ZERO
	var n := 0
	for pair in points:
		var r: Vector3 = pair[0]
		if r.x * side > 0.0 and absf(r.x) >= min_x:
			rest += r
			posed += pair[1]
			n += 1
	return [rest / maxf(n, 1), posed / maxf(n, 1)]


## Vertices that coincide at rest (a split seam) but part in the pose: the widest gap and
## how many such seams open by more than 1 mm.
func _split_gaps(name: String, points: Array) -> void:
	var groups := {}
	for pair in points:
		var r: Vector3 = pair[0]
		var key := Vector3i(roundi(r.x * 10000.0), roundi(r.y * 10000.0), roundi(r.z * 10000.0))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(pair[1])
	var widest := 0.0
	var opened := 0
	for key in groups:
		var ps: Array = groups[key]
		if ps.size() < 2:
			continue
		var gap := 0.0
		for p in ps:
			gap = maxf(gap, (p as Vector3).distance_to(ps[0]))
		widest = maxf(widest, gap)
		if gap > 0.001:
			opened += 1
	print("    %s split seams: %d open by > 1 mm, widest %.1f cm" % [name, opened, widest * 100.0])


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
	if _frame == 3 and _skip(String(SHOTS[_shot][0])):
		_shot += 1
		_frame = 2
		if _shot >= SHOTS.size():
			quit(0)
		return
	if _frame == 4:
		_pose(SHOTS[_shot])
	elif _frame == 7 and SHOTS[_shot].size() > 7 and SHOTS[_shot][7]:
		_measure(SHOTS[_shot])
	elif _frame == 10:
		var image := root.get_texture().get_image()
		var name := String(SHOTS[_shot][0])
		var bare := (
			name.begins_with("hem_")
			or (_third != "" and name.begins_with("three_"))
			or name in ["hands_walk", "rise_walk", "knee_walk"]
		)
		var prefix := "" if bare else "engine_"
		var path := "%s/%s%s%s.png" % [OUT_DIR, prefix, _tag, name]
		if name.begins_with("shoulder_"):
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(OUT_DIR + "/shoulder")
			)
			path = "%s/shoulder/shoulder_%s%s.png" % [OUT_DIR, _tag, name.trim_prefix("shoulder_")]
		if image != null and image.save_png(ProjectSettings.globalize_path(path)) == OK:
			print("Saved " + path)
		_shot += 1
		_frame = 0
		if _shot >= SHOTS.size():
			quit(0)


## Whether --only (or --third) leaves this shot out. "three_quarter" is the two-rig view,
## not one of the --third shots.
func _skip(name: String) -> bool:
	if _only == "":
		return false
	if _third != "" and name == "three_quarter":
		return true
	return not name.begins_with(_only)


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

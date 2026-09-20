class_name RenovationDirector
extends Node3D

## The scene side of Renovation in grandpa's shop: it turns the autoload's state into what
## the player sees and can walk through. One of these sits in the room scene and drives:
##  - the boards across each doorway (pulled off by hand, or knocked through by builders),
##  - the mess to clear by hand (one pile per cleanup spot) and the dust sheets,
##  - the look of each room's floor, its "(locked)" label and the builders' clutter,
##  - the stations: some MOVE into a room when it opens, others only APPEAR then.
##
## Everything is found by name under the shop shell, so the Blender-built shop only has to
## keep the same names (docs/STORY_AND_RENOVATION.md §6.8). Stations stay in the scene the
## whole time — hidden and switched off until their room is done — so their save paths
## never change.

const INTERACTABLE := preload("res://entities/scripts/interactable.gd")
const WORK_SECONDS := 0.55

const FACE_Z := Basis.IDENTITY
const FACE_PX := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))  # on a west wall
const FACE_NX := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))  # on an east wall

## Doorway boards: room -> the cleanup project that pulls them off ("" = builders' job).
const BOARDS := {
	"workroom": "workroom_boards",
	"cloth": "cloth_boards",
	"nook": "nook_boards",
	"nextdoor": "",
}
## Cleanup projects whose spots are mess piles built into the shell (Spots/<project>).
const MESS_PROJECTS := ["front_sweep", "workroom_clear", "cloth_clear", "nook_clear", "next_clear"]
## The dust-sheet project and the stations sleeping under a sheet.
const SHEETS_PROJECT := "front_sheets"
## (Not the tri-fold mirror: it is 2.5 m tall, and under a sheet it was a white wall
## across the view from the street.)
const SHEETED := ["Worktable", "SewingMachine", "ClothingRack"]
## The sheet over each: [centre, size] in the station's own space, from its model's bounds.
const SHEET_BOX := {
	"Worktable": [Vector3(0.03, 0.63, 0.315), Vector3(1.62, 1.26, 0.99)],
	"SewingMachine": [Vector3(0.065, 0.71, 0.305), Vector3(1.55, 1.42, 0.93)],
	"ClothingRack": [Vector3(0.0, 0.82, 0.0), Vector3(1.72, 1.64, 0.62)],
}
const SHEET_NODE := "DustSheet"
## Stations that move when a room opens: room -> {station: [basis, origin]}.
const MOVES := {
	"workroom":
	{
		"Worktable": [FACE_Z, Vector3(-2.6, 0, -1.45)],
		"SewingMachine": [FACE_Z, Vector3(0.4, 0, -1.45)],
	},
}
## Stations that only exist once a room is done: station -> room.
const APPEAR := {
	"Bookshelf": "workroom",
	"ClothingRack2": "workroom",
	"Shelf2": "cloth",
	"Shelf3": "cloth",
	"Shelf4": "cloth",
	"Mannequin": "nextdoor",
	"ClothingRack3": "nextdoor",
}

## The worktable, the reception desk (the Phone station) and the mirror have no solid
## body of their own; at Mr. Hemming's the kit's partition happens to cover the desk.
## Here they stand free, so they get one: station -> [centre, size] in its own space,
## measured from the models.
const SOLID := {
	"Phone": [Vector3(0.65, 0.5, 0.1), Vector3(2.0, 1.0, 0.7)],
	"Worktable": [Vector3(0.03, 0.45, 0.315), Vector3(1.5, 0.9, 0.87)],
	"Mirror": [Vector3(0.11, 1.0, -0.325), Vector3(2.46, 2.0, 0.59)],
}

## What the greybox floor label says under the room's name, by Renovation.RoomState
## (a finished room has no label). Next door isn't the player's until it is bought.
const LABEL_NOTE: Array[String] = ["(locked)", "(needs clearing)", "(needs the builders)"]

## WEAR: how run-down a room looks, 1 = as found .. 0 = renovated, by Renovation.RoomState.
## The front room is lived in from the first day: it starts shabby rather than ruined and
## each of its own jobs takes some of that away.
const WEAR_BY_STATE: Array[float] = [1.0, 1.0, 0.6, 0.0]
const FRONT_WEAR := 0.75
const FRONT_JOBS := ["front_sheets", "front_sweep", "front_window", "front_lights"]
## Damp runs down a wall that stands full height (the cut-away ones would only show its
## faint foot): room -> [which wall, how many streaks]. A puddle lies where the roof leaks.
const DAMP_WALLS := {
	"front": ["west", 2], "workroom": ["back", 3], "cloth": ["back", 2], "nextdoor": ["back", 2]
}
const PUDDLES := {
	"workroom": Vector2(0.62, 0.45), "cloth": Vector2(0.4, 0.5), "nextdoor": Vector2(0.3, 0.35)
}
const WEAR_LAYER := 2  # render layer of the shop's shell: wear never lands on people
const WEAR_FADE := 0.9  # seconds a room takes to come clean
const GRIME := preload("res://assets/textures/renovation/grime.png")
const DAMP := preload("res://assets/textures/renovation/damp.png")
const PUDDLE := preload("res://assets/textures/renovation/puddle.png")
const PUDDLE_ORM := preload("res://assets/textures/renovation/puddle_orm.png")

## Floor colour by Renovation.RoomState (SHUT, ENTERED, CLEARED, DONE), until the real
## shop swaps this for its wear shader.
const FLOOR_LOOK: Array[Color] = [
	Color(0.30, 0.29, 0.29),
	Color(0.36, 0.35, 0.34),
	Color(0.46, 0.43, 0.40),
	Color(0.62, 0.50, 0.38),
]

@export_node_path("Node3D") var shell_path: NodePath = ^"../GrandpaShell"
## The Blender-built shop (the look). Wear decals are limited to it.
@export_node_path("Node3D") var shop_path: NodePath = ^"../GrandpaShop"

var _shell: Node3D
var _room: Node
var _home := {}  # station name -> its day-1 Transform3D
var _sheets := {}  # station name -> the sheet node over it
var _floor_mats := {}  # room -> its own StandardMaterial3D
var _wear := {}  # room -> its Decals
var _sheets_released := false  # the sheeted stations have been handed back for good


func _ready() -> void:
	_shell = get_node_or_null(shell_path) as Node3D
	_room = get_parent()
	if _shell == null:
		push_warning("RenovationDirector: no shop shell at %s" % shell_path)
		return
	for room: String in MOVES:
		for station: String in MOVES[room]:
			var node := _station(station)
			if node != null:
				_home[station] = node.transform
	_clear_plot_inside()
	_build_solids()
	_build_boards()
	_build_spots()
	_build_sheets()
	_build_wear()
	Renovation.changed.connect(_apply)
	Renovation.project_finished.connect(_on_project_finished)
	_apply()


# --- Applying the state ----------------------------------------------------------


func _apply() -> void:
	if _shell == null:
		return
	for room: String in Renovation.ROOMS:
		if room == "front":
			continue
		var state := Renovation.room_state(room)
		_set_solid(_blocker(room), state < Renovation.RoomState.ENTERED)
		_write_label(room, state)
		_show(_shell.get_node_or_null("Wip_" + room), _room_under_way(room))
		_paint_floor(room, state)
	for project: String in MESS_PROJECTS:
		_apply_spots(project)
	_apply_sheets()
	_apply_stations()
	_apply_wear()


func _apply_spots(project: String) -> void:
	var holder := _shell.get_node_or_null("Spots/" + project)
	if holder == null:
		return
	var gone := int(Renovation.data(project).get("spots", 0))
	if not Renovation.is_done(project):
		gone = Renovation.spots_cleared(project)
	var live := Renovation.available(project)
	var i := 0
	for spot in holder.get_children():
		var there := i >= gone
		_show(spot, there)
		_set_interactable(spot, there and live)
		i += 1


func _apply_sheets() -> void:
	var done := Renovation.is_done(SHEETS_PROJECT)
	if done and _sheets_released:
		return  # handed back already; a reset or an older save un-does it and covers them again
	var gone := SHEETED.size() if done else Renovation.spots_cleared(SHEETS_PROJECT)
	for i in SHEETED.size():
		var station: String = SHEETED[i]
		var covered := i >= gone
		var sheet: Node3D = _sheets.get(station)
		_show(sheet, covered)
		# A station under a sheet can't be used; taking the sheet off wakes it up. The sheet
		# is the station's child, so it is set last: the station-wide switch covers it too.
		_set_interactable(_station(station), not covered)
		_set_interactable(sheet, covered)
	# Once every sheet is off, leave those stations' own switches alone from then on.
	_sheets_released = done


func _apply_stations() -> void:
	for room: String in MOVES:
		var opened := Renovation.room_state(room) == Renovation.RoomState.DONE
		for station: String in MOVES[room]:
			var node := _station(station)
			if node == null:
				continue
			var to: Array = MOVES[room][station]
			node.transform = Transform3D(to[0], to[1]) if opened else _home[station]
	for station: String in APPEAR:
		var there := Renovation.room_state(APPEAR[station]) == Renovation.RoomState.DONE
		_set_station_live(_station(station), there)


## Tell the player: a room coming back is the reward, so it shouldn't happen unnoticed.
## (Loading a save restores the state without finishing anything, so it stays quiet.)
func _on_project_finished(id: String) -> void:
	if UI == null or not UI.has_method("toast"):
		return
	var d := Renovation.data(id)
	var opened := str(d.get("opens", ""))
	if opened != "":
		UI.toast(str(Renovation.ROOMS[opened].get("ready", "A room is ready")))
	elif int(d.get("kind", Renovation.Kind.BUILD)) == Renovation.Kind.BUILD:
		UI.toast("The builders have finished: %s" % str(d.get("name", id)).to_lower())
	else:
		UI.toast("Done: %s" % str(d.get("name", id)).to_lower())


# --- Interacting ---------------------------------------------------------------


## Spots, sheets and boards all forward here through a small proxy (see _Work below).
func work_prompt(project: String, verb: String) -> String:
	if project == "":
		return "The party wall — that's a job for the builders"
	if Renovation.available(project):
		return verb
	if not Renovation.tier_met(project):
		var tier := Renovation.tier_needed(project)
		return "Not yet — earn a name first (%s)" % _tier_name(tier)
	if not Renovation.needs_met(project):
		return "Not yet — %s first" % _first_need(project)
	return ""


func do_work(project: String) -> void:
	if not Renovation.available(project):
		return
	GameState.input_locked = true
	if Sfx != null:
		Sfx.play("cloth_rustle", -2.0, 0.9, 1.1)
	await get_tree().create_timer(WORK_SECONDS).timeout
	GameState.input_locked = false
	if Renovation.clear_spot(project) and Sfx != null:
		Sfx.play("putdown")


# --- Building the hands-on bits ---------------------------------------------------


## TEMPORARY, until the plot is rebuilt for this footprint (docs 6.11, stage D): the plot
## and its edging were laid out around Mr. Hemming's shop, whose wings stand further back, so
## garden beds and props now fall inside grandpa's rooms. Hide the small things whose centre
## lies inside the building (its outline = the shell's own floors); lawns and paving stay.
func _clear_plot_inside() -> void:
	var outline := Rect2()
	for mesh in _shell.get_node("Body").get_children():
		var floor_mesh := mesh as MeshInstance3D
		if floor_mesh == null or not str(floor_mesh.name).begins_with("Floor_"):
			continue
		var box := floor_mesh.global_transform * floor_mesh.get_aabb()
		var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		outline = rect if outline.size == Vector2.ZERO else outline.merge(rect)
	for holder_name: String in ["TailorPlot", "LawnEdging"]:
		var holder := _room.get_node_or_null(holder_name)
		if holder == null:
			continue
		for node in holder.find_children("*", "MeshInstance3D", true, false):
			var prop := node as MeshInstance3D
			var box := prop.global_transform * prop.get_aabb()
			var centre := box.get_center()
			var small := maxf(box.size.x, box.size.z) < 6.0 and box.size.y < 3.0
			if small and outline.has_point(Vector2(centre.x, centre.z)):
				prop.visible = false


func _build_solids() -> void:
	for station: String in SOLID:
		var node := _station(station)
		if node == null or _is_solid(node):
			continue  # not here, or the station has been given a body of its own since
		var body := StaticBody3D.new()
		body.name = "GrandpaBody"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = SOLID[station][1]
		shape.shape = box
		shape.position = SOLID[station][0]
		body.add_child(shape)
		node.add_child(body)  # rides along when the station moves rooms


## `node` already stops the player: it holds a physics body with a live, shaped collider.
func _is_solid(node: Node3D) -> bool:
	for body in node.find_children("*", "PhysicsBody3D", true, false):
		for child in body.get_children():
			var shape := child as CollisionShape3D
			if shape != null and shape.shape != null and not shape.disabled:
				return true
	return false


func _build_boards() -> void:
	for room: String in BOARDS:
		var blocker := _blocker(room)
		if blocker == null:
			continue
		var size := Vector3(1.6, 2.0, 1.6)
		_add_work(blocker, str(BOARDS[room]), "Pull off the boards", size)


func _build_spots() -> void:
	for project: String in MESS_PROJECTS:
		var holder := _shell.get_node_or_null("Spots/" + project)
		if holder == null:
			continue
		for spot in holder.get_children():
			_add_work(spot as Node3D, project, "Clear this away", Vector3(1.5, 1.4, 1.5))


func _build_sheets() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.74, 0.70, 0.62)  # old linen; white blew out in the shop's light
	mat.roughness = 1.0
	for station: String in SHEETED:
		var node := _station(station)
		if node == null:
			continue
		var sheet := MeshInstance3D.new()
		sheet.name = SHEET_NODE
		var box := BoxMesh.new()
		box.size = SHEET_BOX[station][1]
		box.material = mat
		sheet.mesh = box
		sheet.position = SHEET_BOX[station][0]
		node.add_child(sheet)  # the station's own: it goes where the station goes
		var reach: Vector3 = SHEET_BOX[station][1] + Vector3(0.5, 0.2, 0.9)
		_add_work(sheet, SHEETS_PROJECT, "Pull off the dust sheet", reach)
		_sheets[station] = sheet


func _add_work(host: Node3D, project: String, verb: String, size: Vector3) -> void:
	if host == null:
		return
	var proxy := _Work.new()
	proxy.name = "Work"
	proxy.director = self
	proxy.project = project
	proxy.verb = verb
	host.add_child(proxy)
	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(INTERACTABLE)
	area.collision_layer = 4
	area.collision_mask = 0
	area.set("target", proxy)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	host.add_child(area)


# --- Wear ------------------------------------------------------------------------


## 1 = as grandpa left it .. 0 = renovated.
func wear_of(room: String) -> float:
	if room != "front":
		return WEAR_BY_STATE[Renovation.room_state(room)]
	var left := FRONT_WEAR
	for job: String in FRONT_JOBS:
		if Renovation.is_done(job):
			left -= FRONT_WEAR / FRONT_JOBS.size()
	return maxf(left, 0.0)


func _build_wear() -> void:
	var shop := get_node_or_null(shop_path)
	if shop != null:  # the shell of the shop takes the wear; people and furniture don't
		for node in shop.find_children("*", "VisualInstance3D", true, false):
			(node as VisualInstance3D).layers |= WEAR_LAYER
	for room: String in Renovation.ROOMS:
		var floor_mesh := _shell.get_node_or_null("Body/Floor_" + room) as MeshInstance3D
		if floor_mesh == null:
			continue
		var box := floor_mesh.global_transform * floor_mesh.get_aabb()
		var lo := Vector2(box.position.x, box.position.z)
		var span := Vector2(box.size.x, box.size.z)
		var decals: Array[Decal] = []
		var mid := Vector3(lo.x + span.x / 2.0, 0.05, lo.y + span.y / 2.0)
		decals.append(_decal("grime", room, GRIME, mid, Vector3(span.x, 0.5, span.y), Vector3.ZERO))
		if DAMP_WALLS.has(room):
			decals.append_array(_damp(room, lo, span))
		if PUDDLES.has(room):
			var at: Vector2 = lo + span * (PUDDLES[room] as Vector2)
			var wet := _decal(
				"puddle",
				room,
				PUDDLE,
				Vector3(at.x, 0.05, at.y),
				Vector3(2.2, 0.5, 1.8),
				Vector3.ZERO
			)
			wet.texture_orm = PUDDLE_ORM
			decals.append(wet)
		_wear[room] = decals


## Streaks of damp down one wall of `room`: the back wall (low z) or the west wall (low x).
func _damp(room: String, lo: Vector2, span: Vector2) -> Array[Decal]:
	var out: Array[Decal] = []
	var wall := str(DAMP_WALLS[room][0])
	var count := int(DAMP_WALLS[room][1])
	var along := span.x if wall == "back" else span.y
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var at := Vector3(lo.x + along * t, 1.5, lo.y + 0.2)
		var turn := Vector3(90, 0, 0)  # the decal looks at the back wall (-Z)
		if wall == "west":
			at = Vector3(lo.x + 0.2, 1.5, lo.y + along * t)
			turn = Vector3(90, 90, 0)  # ...or at the west wall (-X)
		out.append(_decal("damp%d" % i, room, DAMP, at, Vector3(2.4, 0.8, 3.0), turn))
	return out


func _decal(
	kind: String, room: String, tex: Texture2D, at: Vector3, size: Vector3, turn: Vector3
) -> Decal:
	var decal := Decal.new()
	decal.name = "Wear_%s_%s" % [room, kind]
	decal.texture_albedo = tex
	decal.size = size
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	decal.normal_fade = 0.3
	if get_node_or_null(shop_path) != null:
		decal.cull_mask = WEAR_LAYER
	add_child(decal)
	decal.global_position = at
	decal.rotation_degrees = turn
	decal.albedo_mix = 0.0
	decal.visible = false
	return decal


## Bring every room's wear to where the renovation stands; a room comes clean over a moment.
func _apply_wear() -> void:
	for room: String in _wear:
		var target := wear_of(room)
		for decal: Decal in _wear[room]:
			if is_equal_approx(float(decal.get_meta("wear", -1.0)), target):
				continue
			decal.set_meta("wear", target)
			decal.visible = true
			var fade := create_tween()
			fade.tween_property(decal, "albedo_mix", target, WEAR_FADE)
			if target <= 0.0:
				fade.tween_callback(decal.hide)


# --- Helpers -------------------------------------------------------------------


func _station(station: String) -> Node3D:
	return _room.get_node_or_null(station) as Node3D


func _blocker(room: String) -> Node3D:
	return _shell.get_node_or_null("Blockers/Blocker_" + room) as Node3D


func _room_under_way(room: String) -> bool:
	for id: String in Renovation.all_ids():
		if str(Renovation.data(id).get("room", "")) == room and Renovation.nights_left(id) > 0:
			return true
	return false


func _first_need(project: String) -> String:
	for other: String in Renovation.data(project).get("needs", []):
		if not Renovation.is_done(other):
			return str(Renovation.data(other).get("name", other)).to_lower()
	return "something else"


func _tier_name(tier: int) -> String:
	if Reputation == null or tier >= Reputation.TIERS.size():
		return "tier %d" % tier
	return str(Reputation.TIERS[tier].get("name", "tier %d" % tier))


func _write_label(room: String, state: int) -> void:
	var label := _shell.get_node_or_null("Label_" + room) as Label3D
	if label == null:
		return
	label.visible = state < Renovation.RoomState.DONE
	if not label.visible:
		return
	var note: String = LABEL_NOTE[state]
	if room == "nextdoor" and not Renovation.is_done("next_buy"):
		note = "(not yours)"
	label.text = "%s\n%s" % [str(Renovation.ROOMS[room]["name"]), note]


func _paint_floor(room: String, state: int) -> void:
	var mesh := _shell.get_node_or_null("Body/Floor_" + room) as MeshInstance3D
	if mesh == null:
		return
	if not _floor_mats.has(room):
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.95
		mesh.material_override = mat
		_floor_mats[room] = mat
	(_floor_mats[room] as StandardMaterial3D).albedo_color = FLOOR_LOOK[state]


func _show(node: Node, on: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = on


## Boards across a doorway: seen and solid, or gone.
func _set_solid(node: Node3D, on: bool) -> void:
	if node == null:
		return
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_set_interactable(node, on)


func _set_interactable(node: Node, on: bool) -> void:
	if node == null:
		return
	for area in node.find_children("*", "Area3D", true, false):
		if area is Interactable:
			(area as Interactable).set_enabled(on)


## A station that isn't there yet: unseen, not solid, can't be used (as UpgradeStation).
func _set_station_live(node: Node3D, on: bool) -> void:
	if node == null:
		return
	node.visible = on
	for body in node.find_children("*", "CollisionObject3D", true, false):
		var co := body as CollisionObject3D
		if co is Interactable:
			(co as Interactable).set_enabled(on)
		else:
			co.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## What the Interactable talks to: forwards the prompt and the press to the director.
class _Work:
	extends Node
	var director: RenovationDirector
	var project := ""
	var verb := ""

	func get_interaction_prompt(_actor: Variant) -> String:
		return director.work_prompt(project, verb)

	func interact(_actor: Variant) -> void:
		director.do_work(project)

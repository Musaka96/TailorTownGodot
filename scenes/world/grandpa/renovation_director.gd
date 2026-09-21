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
const MESS_PROJECTS := [
	"front_sweep",
	"front_boards",
	"workroom_clear",
	"cloth_clear",
	"nook_clear",
	"next_clear",
]
## Spots that are boards over a window rather than a heap: they are prised off, not scooped.
const BOARDED_SPOTS := ["front_boards"]
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
## How the drape is built: rings from the floor up, and corners around each ring.
const DRAPE_RINGS := 7
const DRAPE_SIDES := 20
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
const FRONT_JOBS := [
	"front_sheets",
	"front_sweep",
	"front_boards",
	"front_window",
	"front_lights",
	"front_paper",
]
## Damp runs down a wall that stands full height (the cut-away ones would only show its
## faint foot): room -> [which wall, how many streaks]. A puddle lies where the roof leaks.
const DAMP_WALLS := {
	"front": ["west", 2], "workroom": ["back", 3], "cloth": ["back", 2], "nextdoor": ["back", 2]
}
const PUDDLES := {
	"workroom": Vector2(0.62, 0.45), "cloth": Vector2(0.4, 0.5), "nextdoor": Vector2(0.3, 0.35)
}
## A room nobody has opened is dark: a box of shadow filling it, which lifts when the
## boards come off. Inset from the walls so the boards themselves stay lit.
const DARK := Color(0.015, 0.015, 0.02)
const DARK_ALPHA := 0.93
const DARK_INSET := 0.23  # 0.2 put its faces in the door reveals' plane (z-fighting)
const DARK_FADE := 0.7
## The wall between the front room and the nook: fitting out the nook takes it away, so the
## nook becomes part of the shop with no doorway between them.
const NOOK_WALL := "NookWall"
## Until the player buys the tri-fold, the fitting mirror is grandpa's own cheval glass:
## one plain pane on a stand, about a third the width of Mr. Hemming's.
const TRIFOLD_UPGRADE := "mirror_trifold"
const CHEVAL_NODE := "ChevalGlass"
## The memory shelf on the front-room wall: what each keepsake looks like standing on it,
## as [size, colour]. Story.KEEPSAKES picks one of these by name.
const KEEPSAKE_PROPS := {
	"shears": [Vector3(0.05, 0.03, 0.26), Color(0.62, 0.64, 0.68)],
	"thimble": [Vector3(0.05, 0.06, 0.05), Color(0.76, 0.60, 0.26)],
	"photo": [Vector3(0.16, 0.12, 0.02), Color(0.55, 0.42, 0.28)],
	"pencil": [Vector3(0.02, 0.02, 0.18), Color(0.85, 0.72, 0.30)],
	"tin": [Vector3(0.15, 0.08, 0.11), Color(0.68, 0.36, 0.28)],
	"ledger": [Vector3(0.14, 0.05, 0.19), Color(0.36, 0.28, 0.42)],
	"paper": [Vector3(0.17, 0.03, 0.13), Color(0.85, 0.82, 0.70)],
}
## Where it hangs and how long the boards are. The WEST wall of the front room: it stands
## full height and never fades, so the shelf is never left hanging in mid-air the way it
## was on the street front (which is cut away for the camera).
const SHELF_AT := Vector3(-4.18, 1.35, 3.3)
const SHELF_TURN := 90.0
const SHELF_LENGTH := 1.7
const SHELF_VERB := "Grandpa's shelf"
const CHEVAL_SOLID := Vector3(1.0, 1.4, 0.55)
## The front of the shop: grimy and weedy until it is repainted.
const FACADE_JOB := "facade_paint"
## How far out from the front wall the shop's own forecourt reaches. Anything small of the
## plot's standing in there is the shop's dressing, not the street's.
const FORECOURT_DEPTH := 2.3
## The front room keeps its bare walls until the shop is papered.
const PAPER_JOB := "front_paper"
const WEAR_LAYER := 2  # render layer of the shop's shell: wear never lands on people
const WEAR_FADE := 0.9  # seconds a room takes to come clean
const GRIME := preload("res://assets/textures/renovation/grime.png")
const DAMP := preload("res://assets/textures/renovation/damp.png")
const PUDDLE := preload("res://assets/textures/renovation/puddle.png")
const PUDDLE_ORM := preload("res://assets/textures/renovation/puddle_orm.png")
## Two lengths of bare wall (tools/make_wear_textures.py), laid turn and turn about.
const PLASTER: Array[Texture2D] = [
	preload("res://assets/textures/renovation/plaster.png"),
	preload("res://assets/textures/renovation/plaster_b.png"),
]
const PLASTER_LENGTH := 2.0  # metres of wall one length is drawn for — never stretched far
## Bare plaster and damp belong on wall, not on glass: the shop kit builds each wall run
## out of named panels, and only these two have nothing cut out of them. Everything else
## — a window, a door, a shopfront, an archway — is left alone, so no patch of brick ever
## washes across a pane the player is meant to see through.
const SOLID_PANELS := ["wall_plain", "wall_part_v7"]
const PANEL_REACH := 1.0  # how near the room's wall line a panel must stand to count
const PANEL_INSET := 0.04  # keeps a patch off the panel's very edge
const PANEL_JOIN := 0.4  # panels this close run together as one stretch of plaster
const PANEL_MIN := 0.7  # a stretch narrower than this is not worth a patch
const WALL_OFF := 0.3  # how far in from the room's edge a wall patch sits
## From the top of the skirting to just under the wall cap (the walls stand 2.86 m): a
## patch that ran the full 3 m climbed over the cap and showed as brick above the wall.
const WALL_MID := 1.48  # its centre height
const WALL_H := 2.64  # and how far up the wall it reaches
const WALL_DEPTH := 0.7  # how deep it projects (it only has the one wall to find)
const DAMP_WIDE := 2.4  # how broad one streak of damp runs

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
var _dark := {}  # room -> the box of shadow in it
var _facade: Array[Decal] = []  # dirt over the street front
var _panels: Array[AABB] = []  # the shop's blind wall panels, in world space
var _forecourt: Array[MeshInstance3D] = []  # the plot's dressing outside the shop door
var _keepsakes := {}  # keepsake id -> the little thing standing on the shelf
var _sheets_released := false  # the sheeted stations have been handed back for good
## Which sheet comes off next: SHEETED, reordered as the player picks them, so the sheet
## the player pulled is the one that goes.
var _sheet_order: Array = SHEETED.duplicate()
var _working := false  # a job is playing out; another press waits for it
var _fx: RenovationFx


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
	_build_cheval()
	_build_memory_shelf()
	_build_wear()
	_build_dark()
	_build_facade()
	_fx = RenovationFx.new()
	_fx.name = "Fx"
	add_child(_fx)
	Upgrades.changed.connect(_apply)
	Story.changed.connect(_apply_keepsakes)
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
	_apply_dark()
	_apply_facade()
	_apply_nook_wall()
	_apply_mirror()
	_apply_keepsakes()


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
	for i in _sheet_order.size():
		var station: String = _sheet_order[i]
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
## The shelf by the door: how many of his things are on it.
func shelf_prompt() -> String:
	if Story.keepsake_count() == 0:
		return "Grandpa's shelf — nothing on it yet"
	return "Grandpa's shelf (%d)" % Story.keepsake_count()


func work_prompt(project: String, verb: String) -> String:
	if verb == SHELF_VERB:
		return shelf_prompt()
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


## `host` is the thing pressed on (a heap, a sheet, a doorway's boards): it plays out on
## that very one, which then goes (see RenovationFx).
func do_work(project: String, verb := "", host: Node3D = null) -> void:
	if verb == SHELF_VERB:
		if UI != null and UI.story_note != null:
			UI.story_note.open(SHELF_VERB, Story.shelf_text())
		return
	if _working or not Renovation.available(project):
		return
	_working = true
	GameState.input_locked = true
	var kind := _kind_of(project, host)
	var at := _up_next(project, host)
	if host != null and _fx != null:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		await _fx.play(kind, host, player)
	var finished := Renovation.clear_spot(project)
	if _fx != null:
		var opens := kind == RenovationFx.Kind.BOARDS and not project in BOARDED_SPOTS
		_fx.celebrate(at, finished, finished and opens)
		await get_tree().create_timer(RenovationFx.PAYOFF).timeout
	GameState.input_locked = false
	_working = false


func _kind_of(project: String, host: Node3D) -> RenovationFx.Kind:
	if project == SHEETS_PROJECT:
		return RenovationFx.Kind.SHEET
	if project in BOARDED_SPOTS or (host != null and host.get_parent() == _blockers()):
		return RenovationFx.Kind.BOARDS
	return RenovationFx.Kind.PILE


## Line `host` up to be the next to go — the spots and sheets go in order, and this makes
## the one the player picked come next — and say where it stands, for the sparkle.
func _up_next(project: String, host: Node3D) -> Vector3:
	if host == null:
		return global_position
	var next := Renovation.spots_cleared(project)
	if project == SHEETS_PROJECT:
		var station := str(host.get_parent().name)
		if station in _sheet_order and _sheet_order.find(station) >= next:
			_sheet_order.erase(station)
			_sheet_order.insert(next, station)
	elif project in MESS_PROJECTS and host.get_index() >= next:
		host.get_parent().move_child(host, next)
	var box := AABB(host.global_position, Vector3.ZERO)
	for mesh in host.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		box = box.merge(m.global_transform * m.get_aabb())
	return box.get_center()


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
	for prop: MeshInstance3D in _plot_props(outline):
		prop.visible = false


## The plot's small standing things whose centre falls inside `where` (world x/z). Lawns,
## paving and the garden walls are too big to count, and stay where they are.
func _plot_props(where: Rect2) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for holder_name: String in ["TailorPlot", "LawnEdging"]:
		var holder := _room.get_node_or_null(holder_name)
		if holder == null:
			continue
		for node in holder.find_children("*", "MeshInstance3D", true, false):
			var prop := node as MeshInstance3D
			var box := prop.global_transform * prop.get_aabb()
			var centre := box.get_center()
			var small := maxf(box.size.x, box.size.z) < 6.0 and box.size.y < 3.0
			if small and where.has_point(Vector2(centre.x, centre.z)):
				found.append(prop)
	return found


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


## Grandpa's cheval glass, built here rather than in the kit so it always stands exactly
## where the mirror station does: two posts on splayed feet, a pane tilted back a little.
func _build_cheval() -> void:
	var station := _station("Mirror")
	if station == null:
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.20, 0.13)
	wood.roughness = 0.75
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.56, 0.24)
	brass.roughness = 0.35
	brass.metallic = 0.8
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.78, 0.84, 0.86)
	glass.roughness = 0.08
	glass.metallic = 0.65
	var stand := Node3D.new()
	stand.name = CHEVAL_NODE
	station.add_child(stand)
	stand.position = Vector3.ZERO
	var which := 0
	for side: float in [-0.42, 0.42]:
		which += 1
		_part(
			stand,
			"Post%d" % which,
			Vector3(side, 0.74, 0),
			Vector3(0.07, 1.48, 0.07),
			Vector3.ZERO,
			wood
		)
		_part(
			stand,
			"Foot%d" % which,
			Vector3(side, 0.04, 0),
			Vector3(0.11, 0.08, 0.62),
			Vector3.ZERO,
			wood
		)
		var knob := _part(
			stand,
			"Finial%d" % which,
			Vector3(side, 1.5, 0),
			Vector3(0.1, 0.1, 0.1),
			Vector3.ZERO,
			brass
		)
		knob.mesh = SphereMesh.new()
		(knob.mesh as SphereMesh).radius = 0.05
		(knob.mesh as SphereMesh).height = 0.1
		knob.mesh.surface_set_material(0, brass)
	var pane := Node3D.new()
	pane.name = "Pane"
	stand.add_child(pane)
	pane.position = Vector3(0, 0.8, 0.04)
	pane.rotation_degrees = Vector3(-7, 0, 0)  # tilted to catch the customer
	var rail := 0
	for bar: Array in [
		[Vector3(0, 0.52, 0), Vector3(0.82, 0.07, 0.05)],
		[Vector3(0, -0.52, 0), Vector3(0.82, 0.07, 0.05)],
		[Vector3(-0.375, 0, 0), Vector3(0.07, 1.11, 0.05)],
		[Vector3(0.375, 0, 0), Vector3(0.07, 1.11, 0.05)],
	]:
		rail += 1
		_part(pane, "Frame%d" % rail, bar[0], bar[1], Vector3.ZERO, wood)
	_part(pane, "Glass", Vector3(0, 0, 0.01), Vector3(0.7, 1.0, 0.02), Vector3.ZERO, glass)


func _part(
	parent: Node3D, nm: String, at: Vector3, size: Vector3, turn: Vector3, mat: Material
) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = nm
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh.mesh = box
	mesh.position = at
	mesh.rotation_degrees = turn
	parent.add_child(mesh)
	return mesh


## One mirror or the other, never both — and the space it takes up follows it.
func _apply_mirror() -> void:
	var station := _station("Mirror")
	if station == null:
		return
	var stand := station.get_node_or_null(CHEVAL_NODE) as Node3D
	if stand == null:
		return
	var bought := Upgrades.has(TRIFOLD_UPGRADE)
	stand.visible = not bought
	for node in station.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not stand.is_ancestor_of(mesh):
			mesh.visible = bought  # the kit's tri-fold
	var body := station.get_node_or_null("GrandpaBody")
	if body == null:
		return
	for child in body.get_children():
		var shape := child as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		(shape.shape as BoxShape3D).size = SOLID["Mirror"][1] if bought else CHEVAL_SOLID
		shape.position = SOLID["Mirror"][0] if bought else Vector3(0.11, 0.7, -0.1)


## A shelf of plain boards by the door, and on it everything the renovation has turned up.
## The things stand there from the start, unseen, so finding one only has to show it.
func _build_memory_shelf() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.23, 0.15)
	wood.roughness = 0.8
	var shelf := Node3D.new()
	shelf.name = "MemoryShelf"
	add_child(shelf)
	shelf.global_position = SHELF_AT
	shelf.rotation_degrees = Vector3(0, SHELF_TURN, 0)
	_part(shelf, "Board", Vector3.ZERO, Vector3(SHELF_LENGTH, 0.04, 0.22), Vector3.ZERO, wood)
	for side: float in [-1.0, 1.0]:
		_part(
			shelf,
			"Bracket%d" % int(side),
			Vector3(side * (SHELF_LENGTH / 2.0 - 0.08), -0.1, 0.05),
			Vector3(0.04, 0.18, 0.12),
			Vector3.ZERO,
			wood
		)
	var ids: Array = Story.KEEPSAKES.keys()
	var step := SHELF_LENGTH / float(maxi(ids.size(), 1))
	for i in ids.size():
		var id: String = ids[i]
		var prop: Array = KEEPSAKE_PROPS.get(str(Story.KEEPSAKES[id]["prop"]), [])
		if prop.is_empty():
			continue
		var size: Vector3 = prop[0]
		var paint := StandardMaterial3D.new()
		paint.albedo_color = prop[1]
		paint.roughness = 0.6
		var at := Vector3(-SHELF_LENGTH / 2.0 + step * (i + 0.5), 0.02 + size.y / 2.0, 0.0)
		var thing := _part(shelf, "Keepsake_" + id, at, size, Vector3(0, 12.0 * i, 0), paint)
		thing.visible = false
		_keepsakes[id] = thing
	_add_work(shelf, "", SHELF_VERB, Vector3(1.9, 1.0, 1.1))


## What has been found is on the shelf; the rest is not there yet.
func _apply_keepsakes() -> void:
	for id: String in _keepsakes:
		(_keepsakes[id] as Node3D).visible = Story.has_found(id)


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
			if project in BOARDED_SPOTS:  # up on the shop front, reached from the street
				_add_work(spot as Node3D, project, "Pull off the boards", Vector3(2.2, 3.0, 1.8))
			else:
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
		sheet.mesh = _drape(SHEET_BOX[station][1], hash(station))
		sheet.material_override = mat
		sheet.position = SHEET_BOX[station][0] - Vector3(0, SHEET_BOX[station][1].y / 2.0, 0)
		node.add_child(sheet)  # the station's own: it goes where the station goes
		var reach: Vector3 = SHEET_BOX[station][1] + Vector3(0.5, 0.2, 0.9)
		_add_work(sheet, SHEETS_PROJECT, "Pull off the dust sheet", reach)
		_sheets[station] = sheet


## A sheet thrown over something `size` big: rings of a rounded rectangle from the floor up,
## flaring where the cloth pools, pinched in at the top where it lies on the furniture, with
## folds running down it. `salt` makes each sheet hang a little differently.
func _drape(size: Vector3, salt: int) -> ArrayMesh:
	var dice := RandomNumberGenerator.new()
	dice.seed = salt
	var folds := 7 + (absi(salt) % 3)
	var phase := dice.randf_range(0.0, TAU)
	var rings: Array[PackedVector3Array] = []
	for r in DRAPE_RINGS + 1:
		var t := float(r) / float(DRAPE_RINGS)  # 0 at the floor, 1 at the top
		# wide where it pools, drawn in over the top
		var spread := 1.0 + 0.08 * (1.0 - t) - 0.13 * smoothstep(0.72, 1.0, t)
		var y := size.y * t
		if t > 0.995:
			y -= size.y * 0.02  # the top sags a touch
		var ring := PackedVector3Array()
		for i in DRAPE_SIDES:
			var a := TAU * float(i) / float(DRAPE_SIDES)
			var ripple := 1.0 + 0.035 * sin(folds * a + phase) * (0.35 + 0.65 * (1.0 - t))
			var c := cos(a)
			var sn := sin(a)
			# a rounded rectangle, not an ellipse: the cloth still shows the shape underneath
			var x := signf(c) * pow(absf(c), 0.55) * size.x / 2.0 * spread * ripple
			var z := signf(sn) * pow(absf(sn), 0.55) * size.z / 2.0 * spread * ripple
			ring.append(Vector3(x, y, z))
		rings.append(ring)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in DRAPE_RINGS:
		for i in DRAPE_SIDES:
			var j := (i + 1) % DRAPE_SIDES
			var a1 := rings[r][i]
			var b1 := rings[r][j]
			var c1 := rings[r + 1][j]
			var d1 := rings[r + 1][i]
			for v: Vector3 in [a1, b1, c1, a1, c1, d1]:
				tool.add_vertex(v)
	var top := rings[DRAPE_RINGS]
	var middle := Vector3(0, top[0].y + size.y * 0.015, 0)
	for i in DRAPE_SIDES:
		var j := (i + 1) % DRAPE_SIDES
		for v: Vector3 in [top[i], middle, top[j]]:
			tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


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
			# Not the roof tiles: the street front's dirt reaches up to the sign, and the
			# eave hangs out over it.
			if not node.name.contains("_roof_"):
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
		for side in 4:  # the paper has gone: bare plaster, brick showing through
			for bare in _bare_wall(room, side, lo, span):
				bare.set_meta("bare", true)
				decals.append(bare)
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


## One wall of `room` stripped back to the plaster — a patch per blind stretch of it, so
## the windows and the doorway through it stay clear. `side`: 0 back (low z), 1 street
## (high z), 2 west (low x), 3 east (high x).
func _bare_wall(room: String, side: int, lo: Vector2, span: Vector2) -> Array[Decal]:
	var out: Array[Decal] = []
	for run: Vector2 in _solid_spans(side, lo, span):
		# a long stretch takes several lengths side by side, so the bricks keep their size
		var lengths := maxi(1, roundi((run.y - run.x) / PLASTER_LENGTH))
		var each := (run.y - run.x) / lengths
		for n in lengths:
			var mid := run.x + each * (n + 0.5)
			var at := Vector3(mid, WALL_MID, lo.y + WALL_OFF)
			var turn := Vector3(90, 0, 0)
			match side:
				1:
					at.z = lo.y + span.y - WALL_OFF
					turn = Vector3(90, 180, 0)
				2:
					at = Vector3(lo.x + WALL_OFF, WALL_MID, mid)
					turn = Vector3(90, 90, 0)
				3:
					at = Vector3(lo.x + span.x - WALL_OFF, WALL_MID, mid)
					turn = Vector3(90, -90, 0)
			var tex := PLASTER[(out.size() + side) % PLASTER.size()]
			var size := Vector3(each, WALL_DEPTH, WALL_H)
			out.append(_decal("bare%d_%d" % [side, out.size()], room, tex, at, size, turn))
	return out


## Every blind wall panel the shop is built from, in world space. Gathered once — the
## shell does not move, and the wear is rebuilt whenever a job finishes.
func _solid_panels() -> Array[AABB]:
	if not _panels.is_empty():
		return _panels
	var shop := get_node_or_null(shop_path)
	if shop == null:
		return _panels
	for node in shop.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for key: String in SOLID_PANELS:
			if mi.name.contains(key):
				_panels.append(mi.global_transform * mi.get_aabb())
				break
	return _panels


## The stretches of `side`'s wall that are blind panel, as [from, to] along the wall.
func _solid_spans(side: int, lo: Vector2, span: Vector2) -> Array[Vector2]:
	var along_x := side <= 1
	var wall := lo.y if side == 0 else lo.y + span.y
	if side == 2:
		wall = lo.x
	elif side == 3:
		wall = lo.x + span.x
	var from := lo.x if along_x else lo.y
	var to := from + (span.x if along_x else span.y)
	var out: Array[Vector2] = []
	for box: AABB in _solid_panels():
		var across := box.get_center().z if along_x else box.get_center().x
		if absf(across - wall) > PANEL_REACH:
			continue
		var a := maxf(from, (box.position.x if along_x else box.position.z) + PANEL_INSET)
		var b := minf(to, (box.end.x if along_x else box.end.z) - PANEL_INSET)
		if b - a > 0.0:
			out.append(Vector2(a, b))
	return _joined(out)


## Neighbouring panels are one wall to the eye, so their patches are run together — a
## few long stretches of bare plaster broken at the openings, rather than a stripe per
## panel (which reads as a tiling mistake, not as a shop nobody has papered in years).
func _joined(runs: Array[Vector2]) -> Array[Vector2]:
	runs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	for run: Vector2 in runs:
		if not out.is_empty() and run.x - out[-1].y <= PANEL_JOIN:
			out[-1] = Vector2(out[-1].x, maxf(out[-1].y, run.y))
			continue
		out.append(run)
	var wide: Array[Vector2] = []
	for run: Vector2 in out:
		if run.y - run.x >= PANEL_MIN:
			wide.append(run)
	return wide


## Slide a streak along the wall until it sits on blind panel rather than across a
## window. Stays where it is when nothing on that wall is wide enough to take it.
func _onto_panel(at: float, runs: Array[Vector2], wide: float) -> float:
	var best := at
	var nearest := INF
	for run: Vector2 in runs:
		if run.y - run.x < wide:
			continue
		var held := clampf(at, run.x + wide / 2.0, run.y - wide / 2.0)
		if absf(held - at) < nearest:
			nearest = absf(held - at)
			best = held
	return best


## Every room that starts shut gets a box of shadow: from the shop it is a dark hole, and
## whatever is in there stays a surprise until the boards come off.
## The walls have their paper back: the front room when the shop is papered, any other room
## when its own building work is done.
func _papered(room: String) -> bool:
	if room == "front":
		return Renovation.is_done(PAPER_JOB)
	return Renovation.room_state(room) == Renovation.RoomState.DONE


## The street front: years of dirt over the paintwork and the sign, and weeds along the
## plinth, until the front is repainted.
func _build_facade() -> void:
	var front := _shell.get_node_or_null("Body/Floor_front") as MeshInstance3D
	var nook := _shell.get_node_or_null("Body/Floor_nook") as MeshInstance3D
	if front == null or nook == null:
		return
	var box := (front.global_transform * front.get_aabb()).merge(
		nook.global_transform * nook.get_aabb()
	)
	var wide := box.size.x / 3.0
	for i in 3:
		var at := Vector3(
			box.position.x + wide * (i + 0.5), 1.7, box.position.z + box.size.z + 0.45
		)
		var dirt := _decal(
			"facade%d" % i, "front", GRIME, at, Vector3(wide, 1.2, 4.2), Vector3(90, 0, 0)
		)
		dirt.normal_fade = 0.0  # the frontage is one flat face, nothing to fade against
		_facade.append(dirt)
	var out_front := Rect2(box.position.x, box.position.z + box.size.z, box.size.x, FORECOURT_DEPTH)
	_forecourt = _plot_props(out_front)


## Grime lifts, the weeds go, and the flowers come back out, all with the repaint.
func _apply_facade() -> void:
	var done := Renovation.is_done(FACADE_JOB)
	var weeds := _shell.get_node_or_null("Facade")
	if weeds is Node3D:
		(weeds as Node3D).visible = not done
	for prop: MeshInstance3D in _forecourt:
		prop.visible = done
	for dirt: Decal in _facade:
		var target := 0.0 if done else 1.0
		if is_equal_approx(float(dirt.get_meta("wear", -1.0)), target):
			continue
		dirt.set_meta("wear", target)
		dirt.visible = true
		var fade := create_tween()
		fade.tween_property(dirt, "albedo_mix", target, WEAR_FADE)
		if target <= 0.0:
			fade.tween_callback(dirt.hide)


func _build_dark() -> void:
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(DARK, DARK_ALPHA)
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	for room: String in Renovation.ROOMS:
		if room == "front":
			continue
		var floor_mesh := _shell.get_node_or_null("Body/Floor_" + room) as MeshInstance3D
		if floor_mesh == null:
			continue
		var box := floor_mesh.global_transform * floor_mesh.get_aabb()
		var hole := MeshInstance3D.new()
		hole.name = "Dark_" + room
		var cube := BoxMesh.new()
		cube.size = Vector3(box.size.x - DARK_INSET, 2.9, box.size.z - DARK_INSET)
		cube.material = shade
		hole.mesh = cube
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hole)
		hole.global_position = box.get_center() + Vector3(0, 1.45, 0)
		_dark[room] = hole


## Light gets in the moment the boards come off, and never goes back.
func _apply_dark() -> void:
	for room: String in _dark:
		var hole: MeshInstance3D = _dark[room]
		var shut := Renovation.room_state(room) == Renovation.RoomState.SHUT
		if shut == hole.visible:
			continue
		if shut:
			hole.visible = true
			hole.transparency = 0.0
			continue
		var light := create_tween()
		light.tween_property(hole, "transparency", 1.0, DARK_FADE)
		light.tween_callback(hole.hide)


## The nook is fitted out: down comes the wall, and the shop is one room wider.
func _apply_nook_wall() -> void:
	var shop := get_node_or_null(shop_path)
	if shop == null:
		return
	var wall: Node3D = null
	for node in shop.find_children("*" + NOOK_WALL, "Node3D", true, false):
		wall = node as Node3D
	if wall != null:
		wall.visible = Renovation.room_state("nook") != Renovation.RoomState.DONE


## Streaks of damp down one wall of `room`: the back wall (low z) or the west wall (low x).
func _damp(room: String, lo: Vector2, span: Vector2) -> Array[Decal]:
	var out: Array[Decal] = []
	var wall := str(DAMP_WALLS[room][0])
	var count := int(DAMP_WALLS[room][1])
	var along := span.x if wall == "back" else span.y
	var runs := _solid_spans(0 if wall == "back" else 2, lo, span)
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var at := Vector3(_onto_panel(lo.x + along * t, runs, DAMP_WIDE), 1.5, lo.y + 0.2)
		var turn := Vector3(90, 0, 0)  # the decal looks at the back wall (-Z)
		if wall == "west":
			at = Vector3(lo.x + 0.2, 1.5, _onto_panel(lo.y + along * t, runs, DAMP_WIDE))
			turn = Vector3(90, 90, 0)  # ...or at the west wall (-X)
		out.append(_decal("damp%d" % i, room, DAMP, at, Vector3(DAMP_WIDE, 0.8, 3.0), turn))
	return out


func _decal(
	kind: String, room: String, tex: Texture2D, at: Vector3, size: Vector3, turn: Vector3
) -> Decal:
	var decal := Decal.new()
	decal.name = "Wear_%s_%s" % [room, kind]
	decal.texture_albedo = tex
	decal.size = size
	decal.upper_fade = ContactShadow.NO_FADE
	decal.lower_fade = ContactShadow.NO_FADE
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
			if bool(decal.get_meta("bare", false)):
				target = 0.0 if _papered(room) else 0.95
			else:
				target = wear_of(room)
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


func _blockers() -> Node:
	return _shell.get_node_or_null("Blockers")


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
		director.do_work(project, verb, get_parent() as Node3D)

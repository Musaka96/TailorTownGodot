class_name OutdoorCollision
extends Node

## Gives the town kit's street props something to bump into. The kit glTFs (Town,
## TailorPlot, v7 in Hemming's room and v8 in grandpa's) are instanced whole and carry no
## colliders, so the player walked straight through benches, lamps, trees, the plot's
## brick walls and the neighbours' houses. At ready this walks the roots' meshes, matches
## their names, and hangs a StaticBody3D under each match so the body rides the mesh's
## own transform.
##
## Trees get a trunk-thin cylinder (walk under the canopy), lamps a post, round pots and
## pillar boxes a cylinder of their own width, everything else its mesh box. Each
## neighbour's house gets one box round its walls. Ground, paving, lawns, flowers, roofs
## and the plot's gates are left alone.
## A collider switches off while its mesh is hidden (the renovation hides plot props).

## Tree meshes: a trunk cylinder of TRUNK_RADIUS.
const TREES := ["*_tree_round*", "*_tree_tall*", "*_tree_small*", "*_tree_far_*", "*_tree_blossom*"]
## Thin posts: a cylinder of POST_RADIUS.
const POSTS := ["*_street_lamp*"]
## Round things: a cylinder as wide as the mesh's narrower side.
const ROUNDS := ["*_fountain*", "*_pillar_box*", "*_tub_planter*", "*_pot_plant*", "*_pot_topiary*"]
## Everything else that stands: its mesh box.
const BOXES := [
	"*_bench*",
	"*_planter_v6*",
	"*_crate*",
	"*_sign*",
	"*_cafe_set*",
	"*_bicycle*",
	"*_van_*",
	"*_news_stand*",
	"*_flower_barrow*",
	"*_bush*",
	"*_clothes_rack*",
	"*_raised_bed*",
	"*_veg_bed*",
	"*_shed_*",
	"*_water_butt*",
	"*_bolt_bundle*",
	"*_bean_tepee*",
	"*_wall_brick*",
	"*_pier_v6*",
	"*_pier_low*",
	"*_pier_gate*",
]
## A house body in the town kit: every node named like this (bar the props) is one house.
const HOUSE := "v?_*_Body"
## House pieces whose boxes together make its footprint.
const HOUSE_WALL := "*_wall_*"
const TRUNK_RADIUS := 0.3
const POST_RADIUS := 0.2
## Anything flatter than this is ground, not a prop.
const MIN_HEIGHT := 0.15

## The kit roots to search.
@export var roots: Array[NodePath] = []

var _made := 0


func _ready() -> void:
	for path in roots:
		var root := get_node_or_null(path)
		if root != null:
			_walk(root)
	print_verbose("OutdoorCollision: %d colliders" % _made)


func _walk(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		_prop(mesh)
	elif (
		node is Node3D
		and String(node.name).matchn(HOUSE)
		and not String(node.name).contains("props")
	):
		_house(node)
	for child in node.get_children():
		_walk(child)


func _prop(mesh: MeshInstance3D) -> void:
	var box := mesh.get_aabb()
	if box.size.y < MIN_HEIGHT:
		return
	var n := String(mesh.name)
	var shape: Shape3D = null
	if _matches(n, TREES):
		shape = _cylinder(TRUNK_RADIUS, box.size.y)
	elif _matches(n, POSTS):
		shape = _cylinder(POST_RADIUS, box.size.y)
	elif _matches(n, ROUNDS):
		shape = _cylinder(minf(box.size.x, box.size.z) * 0.5, box.size.y)
	elif _matches(n, BOXES):
		var cube := BoxShape3D.new()
		cube.size = box.size
		shape = cube
	if shape != null:
		_attach(mesh, shape, box.get_center(), mesh)


## One box round all of a house's wall pieces, in the house body's own space.
func _house(body: Node3D) -> void:
	var outline := AABB()
	var found := false
	for child in body.get_children():
		var piece := child as MeshInstance3D
		if piece == null or not String(piece.name).matchn(HOUSE_WALL):
			continue
		var box: AABB = piece.transform * piece.get_aabb()
		outline = outline.merge(box) if found else box
		found = true
	if not found or outline.size.y < MIN_HEIGHT:
		return
	var cube := BoxShape3D.new()
	cube.size = outline.size
	_attach(body, cube, outline.get_center(), null)


func _attach(host: Node3D, shape: Shape3D, centre: Vector3, mesh: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.name = "OutdoorBody"
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = centre
	body.add_child(col)
	host.add_child(body)
	_made += 1
	if mesh != null:
		col.disabled = not mesh.is_visible_in_tree()
		mesh.visibility_changed.connect(
			func() -> void: col.set_deferred("disabled", not mesh.is_visible_in_tree())
		)


func _cylinder(radius: float, height: float) -> CylinderShape3D:
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	return cyl


func _matches(n: String, patterns: Array) -> bool:
	for pattern: String in patterns:
		if n.matchn(pattern):
			return true
	return false

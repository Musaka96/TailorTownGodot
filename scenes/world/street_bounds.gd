class_name StreetBounds
extends Node3D

## Keeps the player on grandpa's plot and the pavement in front of it: the road, the
## neighbours' gardens and the far ends of the street are walled off with invisible boxes.
## The ground out there is one big collider (ShopRoom/Street), so without this the player
## walks off across the whole town.
##
## Customers come and go along the pavement at x +/- 22 (Waypoints/StreetWest and East), so
## the ends stand outside that at +/- 24.

## The walkable ground, in the room's space: the plot (its walls), and the pavement strip
## between the plot's front and the kerb.
const PLOT := Rect2(-9.2, -7.6, 25.8, 17.94)  # x, z, width, depth
const PAVEMENT := Rect2(-24.0, 10.34, 48.0, 3.66)
const TALL := 3.0
const THICK := 0.6


func _ready() -> void:
	for seg in _walls():
		_wall(seg[0], seg[1])


## Each wall as [centre (x, z), size (x, z)]: round the pavement, round the plot, and
## across the two gaps beside the plot where its neighbours' gardens begin.
func _walls() -> Array:
	var out: Array = []
	var pave_far := PAVEMENT.position.y + PAVEMENT.size.y
	var plot_far := PLOT.position.x + PLOT.size.x
	var plot_back := PLOT.position.y
	out.append([Vector2(PAVEMENT.get_center().x, pave_far), Vector2(PAVEMENT.size.x, THICK)])
	for x in [PAVEMENT.position.x, PAVEMENT.position.x + PAVEMENT.size.x]:
		out.append([Vector2(x, PAVEMENT.get_center().y), Vector2(THICK, PAVEMENT.size.y)])
	for run: Array in [
		[PAVEMENT.position.x, PLOT.position.x], [plot_far, PAVEMENT.position.x + PAVEMENT.size.x]
	]:
		var wide: float = run[1] - run[0]
		out.append([Vector2((run[0] + run[1]) / 2.0, PAVEMENT.position.y), Vector2(wide, THICK)])
	for x in [PLOT.position.x, plot_far]:
		out.append([Vector2(x, PLOT.get_center().y), Vector2(THICK, PLOT.size.y)])
	out.append([Vector2(PLOT.get_center().x, plot_back), Vector2(PLOT.size.x, THICK)])
	return out


func _wall(at: Vector2, size: Vector2) -> void:
	var body := StaticBody3D.new()
	body.name = "Wall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, TALL, size.y)
	shape.shape = box
	shape.position = Vector3(at.x, TALL / 2.0, at.y)
	body.add_child(shape)
	add_child(body)

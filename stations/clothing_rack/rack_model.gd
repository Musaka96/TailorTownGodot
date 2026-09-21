class_name RackModel
extends RefCounted

## The clothing rack's look: two turned wooden uprights on splayed feet, a low stretcher
## between them, and a brass rail with a ball finial on each end. Simple shapes in the
## shop's wood and brass, built in code (the rack's scene keeps its blocks for collision).
##   add_child(RackModel.build(0.72, 1.55))


static func build(post_x: float, rail_y: float) -> Node3D:
	var wood := _mat(Style.BROWN, 0.0, 0.75)
	var dark := _mat(Style.WALNUT, 0.0, 0.8)
	var brass := _mat(Style.BRASS, 0.55, 0.32)
	var root := Node3D.new()
	root.name = "RackModel"
	for side: float in [-1.0, 1.0]:
		var x := post_x * side
		# The upright, a little thicker at the foot, with a collar where it meets the rail.
		root.add_child(_rod(Vector3(x, 0.06, 0.0), Vector3(x, rail_y, 0.0), 0.032, 0.026, wood))
		root.add_child(_rod(Vector3(x, 0.3, 0.0), Vector3(x, 0.36, 0.0), 0.04, 0.04, dark))
		# The foot: a rounded bar along the rack's depth, with a pad at each end.
		root.add_child(_rod(Vector3(x, 0.035, -0.24), Vector3(x, 0.035, 0.24), 0.03, 0.03, dark))
		for z: float in [-0.24, 0.24]:
			root.add_child(_ball(Vector3(x, 0.035, z), 0.036, dark))
		root.add_child(_ball(Vector3(x, rail_y, 0.0), 0.034, brass))
		root.add_child(_ball(Vector3(x * 1.07, rail_y, 0.0), 0.042, brass))
	var reach := post_x * 1.07
	root.add_child(
		_rod(Vector3(-reach, rail_y, 0.0), Vector3(reach, rail_y, 0.0), 0.017, 0.017, brass)
	)
	root.add_child(
		_rod(Vector3(-post_x, 0.33, 0.0), Vector3(post_x, 0.33, 0.0), 0.018, 0.018, wood)
	)
	return root


static func _rod(a: Vector3, b: Vector3, r_a: float, r_b: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_a
	mesh.top_radius = r_b
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 14
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	var up := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(ref).normalized()
	mi.transform = Transform3D(Basis(x, up, x.cross(up)), (a + b) * 0.5)
	return mi


static func _ball(at: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	return mi


static func _mat(col: Color, metal: float, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metal
	mat.roughness = rough
	return mat

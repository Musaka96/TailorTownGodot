extends SceneTree

## Which wall surfaces PaperWorld reached in grandpa's shop: every surface on the wall
## cutaway shader (paper_on or not) and every wall-named material still not on paper.
## NOT headless:  godot --path . --script res://tools/probe_paper_walls.gd

var _count := 0
var _main: Node


func _initialize() -> void:
	var path := "res://scenes/world/grandpa/main_grandpa.tscn"
	_main = load(path).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(path)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_count += 1
	if _count < 120:
		return
	var sun := _main.find_child("Sun", true, false) as DirectionalLight3D
	if sun != null:
		print("PROBE sun rot=", sun.global_rotation_degrees, " to_sun=", sun.global_basis.z)
	for mi: MeshInstance3D in _main.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null:
				continue
			var p := String(mi.get_path()).replace("/root/Main/", "")
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				var file := (m as ShaderMaterial).shader.resource_path.get_file()
				if file == "wall_cutaway.gdshader":
					var on: Variant = (m as ShaderMaterial).get_shader_parameter("paper_on")
					print("PROBE cutaway paper_on=%s  %s[%d]" % [on, p, s])
				continue
			if m.resource_name.to_lower().contains("wall"):
				print("PROBE unpapered %s '%s'  %s[%d]" % [m.get_class(), m.resource_name, p, s])
	quit()

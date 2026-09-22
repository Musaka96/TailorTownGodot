extends Node

## Content database — autoloaded as "Catalog".
##
## Loads every material (and later garment) definition from res://data/ at boot,
## so any system can look content up by id without hardcoding lists.

const MATERIALS_DIR := "res://data/materials"

## The dress-code rulebook (occasion x style -> acceptable suits). Configurable at
## res://data/dress_code.tres.
var dress_code: DressCode

var _materials: Dictionary = {}  # StringName -> MaterialType
var _materials_ordered: Array[MaterialType] = []


func _ready() -> void:
	_load_materials()
	dress_code = load("res://data/dress_code.tres") as DressCode
	if dress_code == null:
		dress_code = DressCode.new()
		push_warning("Catalog: no dress_code.tres — run tools/build_dress_code.gd")
	print(
		(
			"Catalog: %d materials, %d dress rules."
			% [_materials_ordered.size(), dress_code.rules.size()]
		)
	)


func _load_materials() -> void:
	# ResourceLoader, not DirAccess: in an export the .tres files are converted and
	# only "<name>.tres.remap" stubs remain on disk, which DirAccess lists as-is.
	var files := ResourceLoader.list_directory(MATERIALS_DIR)
	if files.is_empty():
		push_warning("Catalog: no materials in %s" % MATERIALS_DIR)
		return
	for file in files:
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(MATERIALS_DIR.path_join(file))
		var mat := res as MaterialType
		if mat == null:
			push_warning("Catalog: %s is not a MaterialType" % file)
			continue
		_materials[mat.id] = mat
		_materials_ordered.append(mat)
	_materials_ordered.sort_custom(func(a, b): return a.display_name < b.display_name)


func all_materials() -> Array[MaterialType]:
	return _materials_ordered


func get_material(id: StringName) -> MaterialType:
	return _materials.get(id)

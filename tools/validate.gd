extends SceneTree

## Headless project validator — my fast feedback loop.
##
##   godot --headless --path . --script res://tools/validate.gd
##
## Walks res:// and, for every script and scene, tries to load (and instantiate
## scenes) so parse errors, missing resources and broken node references surface
## as a clean PASS/FAIL summary. Exit code is non-zero on any failure, so it
## also works as a CI / pre-commit gate.

const SKIP_DIRS := [".godot", ".git", ".dev", "addons"]

var _errors: Array[String] = []
var _scripts := 0
var _scenes := 0


func _initialize() -> void:
	print("── Validating project ──")
	_scan("res://")

	print("\nChecked %d scripts, %d scenes." % [_scripts, _scenes])
	if _errors.is_empty():
		print("✅ PASS — no problems found.")
		quit(0)
	else:
		print("❌ FAIL — %d problem(s):" % _errors.size())
		for e in _errors:
			print("  • ", e)
		quit(1)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(name):
				_scan(full)
		elif name.ends_with(".gd"):
			_check_script(full)
		elif name.ends_with(".tscn"):
			_check_scene(full)
		name = dir.get_next()
	dir.list_dir_end()


func _check_script(path: String) -> void:
	_scripts += 1
	var res := load(path)
	if res == null:
		_errors.append("Script failed to load: %s" % path)


func _check_scene(path: String) -> void:
	_scenes += 1
	var packed := load(path) as PackedScene
	if packed == null:
		_errors.append("Scene failed to load: %s" % path)
		return
	# Instantiating catches missing ext_resources and bad node setup that a bare
	# load() does not.
	var instance := packed.instantiate()
	if instance == null:
		_errors.append("Scene failed to instantiate: %s" % path)
		return
	instance.free()

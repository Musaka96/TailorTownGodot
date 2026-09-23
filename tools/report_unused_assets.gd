extends SceneTree

## Headless dead-asset finder for res://IMPORT (and res://assets, for Section D).
##
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/report_unused_assets.gd
##
## Builds one dependency graph (ResourceLoader.get_dependencies() plus a regex
## scan of every .gd for "res://..." string literals, so load()/preload() by
## variable and directory constants are not missed) and reuses it for three
## separate reachability questions:
##   - every committed .tscn/.tres/.gd (excluding IMPORT/.godot/addons/tools)
##   - the same, plus everything under tools/** (dev-only)
##   - ONLY the live entry points: run/main_scene + every autoload, expanded
##     transitively (so old committed scenes nothing ever opens don't count)
##
## Read-only: never touches export_presets.cfg, .import files or IMPORT/.

const REPORT_PATH := "res://.dev/unused_assets.txt"
const IMPORT_DIR := "res://IMPORT"
const ASSETS_DIR := "res://assets"
const TOOLS_DIR := "res://tools"
const ROOT_SKIP_DIRS := ["IMPORT", ".godot", "addons", "tools", ".git", ".dev"]
const WALK_SKIP_DIRS := ["IMPORT", ".godot", ".git", ".dev"]
const ROOT_EXTS := ["tscn", "tres", "gd"]

var _project_roots: Array[String] = []  # main_scene + autoloads only ("live" seeds)
var _game_roots: Array[String] = []  # every committed .tscn/.tres/.gd (incl. _project_roots)
var _tools_roots: Array[String] = []  # every .tscn/.tres/.gd under tools/**

var _script_literal_edges: Dictionary = {}  # script path -> Array[String] resolved res:// literals
var _class_name_edges: Dictionary = {}  # script path -> Array[String] global-class-name targets
var _class_paths: Dictionary = {}  # global class_name -> res://path (from the engine's class cache)
var _dynamic_unresolved: Array[Dictionary] = []  # {file, line, snippet, reason}
var _guesses: Array[String] = []  # judgment calls worth flagging back to the human
var _missing: Dictionary = {}  # paths referenced somewhere but absent on disk

var _adj: Dictionary = {}  # res:// path -> Array[String] neighbors (dependency graph)
var _adj_built: Dictionary = {}  # nodes already expanded while building _adj

var _literal_re := RegEx.new()
var _ident_re := RegEx.new()


func _initialize() -> void:
	print("== Scanning for unused res://IMPORT / res://assets files ==")
	_literal_re.compile("[\"'](res://[^\"'\\n]*)[\"']")
	_ident_re.compile("[A-Za-z_][A-Za-z0-9_]*")

	# ResourceLoader.get_dependencies() only sees ext_resource/preload links.
	# GDScript's global `class_name` system lets a script reference another
	# class (as a type hint or a bare `ClassName.static_call()`) with no
	# preload at all — e.g. character_rig.gd calls `Wardrobe.head(i)` without
	# ever preloading wardrobe.gd. Without closing that gap, the "live entry
	# points" walk snaps at the first such reference and everything behind it
	# (wardrobe art, shop-look textures, fonts reached the same way, ...)
	# reads as falsely dead. Build name -> script path from the engine's own
	# global class cache so those edges can be added explicitly.
	for entry in ProjectSettings.get_global_class_list():
		_class_paths[entry.get("class", "")] = entry.get("path", "")

	_guesses.append(
		(
			"Added an edge from every referencing script to any global class_name "
			+ "target found by scanning its identifier tokens (ResourceLoader.get_dependencies() "
			+ "only sees preload/ext_resource links, not bare `ClassName.foo()` or type-hint use)."
		)
	)
	_guesses.append(
		(
			"Added an edge from every .gltf to its same-named .bin sibling "
			+ "(the external glTF buffer is consumed only at import time and never "
			+ "appears in get_dependencies(), so a live .gltf's own .bin would "
			+ "otherwise misreport as unreachable)."
		)
	)

	_collect_project_roots()
	_collect_file_roots()
	_scan_scripts_for_literals("res://")

	# One graph, built from the widest seed set (game + tools), so every
	# reachability question below can be answered by a cheap in-memory BFS.
	_build_graph(_game_roots + _tools_roots)

	var reach_game := _reach_from(_game_roots)
	var reach_all := _reach_from(_game_roots + _tools_roots)
	var reach_live := _reach_from(_project_roots)

	_write_report(reach_game, reach_all, reach_live)
	quit()


# ---------------------------------------------------------------- root set --


func _collect_project_roots() -> void:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	if f == null:
		_guesses.append("Could not open project.godot to read main_scene/autoloads.")
		return
	var text := f.get_as_text()
	f.close()

	var main_re := RegEx.new()
	main_re.compile('run/main_scene="(res://[^"]+)"')
	var m := main_re.search(text)
	if m:
		_project_roots.append(m.get_string(1))
	else:
		_guesses.append("No run/main_scene found in project.godot.")

	var autoload_re := RegEx.new()
	autoload_re.compile('(?m)^\\w+="\\*?(res://[^"]+)"')
	for match in autoload_re.search_all(text):
		_project_roots.append(match.get_string(1))

	_game_roots.append_array(_project_roots)


## Walk res:// (skipping IMPORT/.godot/addons/tools) collecting every
## .tscn/.tres/.gd as a committed-game root; walk tools/** the same way but
## file its results separately (dev-only root set).
func _collect_file_roots() -> void:
	_walk_roots("res://", true)
	_walk_roots(TOOLS_DIR, false)


func _walk_roots(dir_path: String, is_game_side: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if is_game_side:
				if not ROOT_SKIP_DIRS.has(name):
					_walk_roots(full, true)
			else:
				_walk_roots(full, false)
		else:
			var ext := name.get_extension()
			if ROOT_EXTS.has(ext):
				if is_game_side:
					_game_roots.append(full)
				else:
					_tools_roots.append(full)
		name = dir.get_next()
	dir.list_dir_end()


# ------------------------------------------------------- dynamic scanning --


func _scan_scripts_for_literals(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not WALK_SKIP_DIRS.has(name):
				_scan_scripts_for_literals(full)
		elif name.ends_with(".gd"):
			_scan_one_script(full)
		name = dir.get_next()
	dir.list_dir_end()


func _scan_one_script(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()

	var resolved: Array[String] = []
	var lines := text.split("\n")
	for line_no in range(lines.size()):
		var line: String = lines[line_no]
		if line.strip_edges().begins_with("#"):
			continue
		for match in _literal_re.search_all(line):
			var literal: String = match.get_string(1)
			var start: int = match.get_start()
			var end: int = match.get_end()
			var reason := _classify_literal(literal, line, start, end)
			if reason != "":
				(
					_dynamic_unresolved
					. append(
						{
							"file": path,
							"line": line_no + 1,
							"snippet": line.strip_edges(),
							"reason": reason,
						}
					)
				)
			else:
				resolved.append(literal)
	if not resolved.is_empty():
		_script_literal_edges[path] = resolved

	# Global class_name references (see the note in _initialize): scan every
	# identifier token in the file and add an edge for any that name a known
	# global class defined in a different script.
	if not _class_paths.is_empty():
		var seen: Dictionary = {}
		var class_edges: Array[String] = []
		for match in _ident_re.search_all(text):
			var tok := match.get_string()
			if seen.has(tok):
				continue
			seen[tok] = true
			if _class_paths.has(tok):
				var target: String = _class_paths[tok]
				if target != "" and target != path:
					class_edges.append(target)
		if not class_edges.is_empty():
			_class_name_edges[path] = class_edges


## Returns a non-empty reason string if `literal` should be treated as
## dynamic/unresolved instead of a usable graph edge.
func _classify_literal(literal: String, line: String, start: int, end: int) -> String:
	if (
		literal.find("*") != -1
		or literal.find("%s") != -1
		or literal.find("%d") != -1
		or literal.find("{") != -1
		or literal.find("$") != -1
	):
		return "wildcard/format placeholder in literal"
	# Concatenation: a '+' just before the opening quote or just after the
	# closing quote (ignoring whitespace) means the real path is built at
	# runtime and this literal is only a fragment of it.
	var before := start - 1
	while before >= 0 and (line[before] == " " or line[before] == "\t"):
		before -= 1
	if before >= 0 and line[before] == "+":
		return "string concatenation (fragment before)"
	var after := end
	while after < line.length() and (line[after] == " " or line[after] == "\t"):
		after += 1
	if after < line.length() and line[after] == "+":
		return "string concatenation (fragment after)"
	return ""


# ------------------------------------------------------------- the graph --


## Expand every node reachable from `seed_roots`, recording its neighbor list
## in _adj. This is the only place that hits ResourceLoader/disk; every
## reachability question afterward is answered by walking _adj in memory.
func _build_graph(seed_roots: Array[String]) -> void:
	var queue: Array[String] = []
	for r in seed_roots:
		if not _adj_built.has(r):
			_adj_built[r] = true
			queue.append(r)

	var head := 0
	while head < queue.size():
		var path: String = queue[head]
		head += 1
		var neighbors := _neighbors_of(path)
		_adj[path] = neighbors
		for n in neighbors:
			if not _adj_built.has(n):
				_adj_built[n] = true
				queue.append(n)


func _neighbors_of(path: String) -> Array[String]:
	var result: Array[String] = []

	if path.ends_with("/"):
		# Directory constant: best-effort — every file directly inside counts
		# as reachable, since the game likely lists/loads them at runtime
		# instead of declaring each one as a dependency.
		var dir := DirAccess.open(path)
		if dir == null:
			_missing[path] = true
			return result
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir():
				result.append(path.path_join(name))
			name = dir.get_next()
		dir.list_dir_end()
		return result

	if not (FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)):
		_missing[path] = true
		return result

	for dep in ResourceLoader.get_dependencies(path):
		var dep_path := _extract_res_path(dep)
		if dep_path != "":
			result.append(dep_path)

	# A .gltf's external binary buffer is consumed only by the importer (baked
	# into the cached imported mesh) and never appears in get_dependencies(),
	# so a live .gltf's own .bin sibling would otherwise read as unreachable.
	if path.ends_with(".gltf"):
		var bin_path := path.get_basename() + ".bin"
		if FileAccess.file_exists(bin_path):
			result.append(bin_path)

	if _script_literal_edges.has(path):
		for lit in _script_literal_edges[path]:
			result.append(lit)

	if _class_name_edges.has(path):
		for target in _class_name_edges[path]:
			result.append(target)

	return result


## get_dependencies() entries can come back as a bare "res://path" or as
## "res://path::SubResourceHint" (legacy text-resource dependency format), or
## occasionally hint-first. Pull out the res:// segment either way.
func _extract_res_path(dep: String) -> String:
	if dep.begins_with("res://"):
		var idx := dep.find("::")
		if idx == -1:
			return dep
		return dep.substr(0, idx)
	var idx2 := dep.find("res://")
	if idx2 == -1:
		return ""
	return dep.substr(idx2)


## Cheap in-memory BFS over the precomputed graph. Valid for any root list
## that is a subset of what _build_graph was seeded with (or discovered from
## it), which _project_roots / _game_roots / _tools_roots all are.
func _reach_from(roots: Array[String]) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[String] = []
	for r in roots:
		if not visited.has(r):
			visited[r] = true
			queue.append(r)
	var head := 0
	while head < queue.size():
		var path: String = queue[head]
		head += 1
		for n in _adj.get(path, []):
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
	return visited


# --------------------------------------------------------- on-disk listing --


## Every real file under `base_dir` (skips the tiny .import sidecar files,
## which are never themselves a dependency target).
func _list_files_under(base_dir: String) -> Array[String]:
	var out: Array[String] = []
	_list_files_rec(base_dir, out)
	return out


func _list_files_rec(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_list_files_rec(full, out)
		elif not name.ends_with(".import"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size


## Top-level subfolder under a known base dir, e.g. "IMPORT/kaykit".
func _top_folder(path: String, base_dir: String) -> String:
	var base_name := base_dir.get_file()
	var rel := path.substr(base_dir.length() + 1)
	var slash := rel.find("/")
	if slash == -1:
		return base_name + "/(root)"
	return base_name + "/" + rel.substr(0, slash)


## Deeper grouping (up to `depth` path segments past the base dir) so
## versioned folders like IMPORT/town_kit/export/v7 don't all collapse into
## one "IMPORT/town_kit" bucket.
func _folder_group(path: String, base_dir: String, depth: int) -> String:
	var base_name := base_dir.get_file()
	var rel := path.substr(base_dir.length() + 1)
	var parts := rel.split("/")
	var take: int = min(depth, parts.size() - 1)
	if take <= 0:
		return base_name + "/(root)"
	var segs: PackedStringArray = []
	for i in range(take):
		segs.append(parts[i])
	return base_name + "/" + "/".join(segs)


# ---------------------------------------------------------------- report --


func _write_report(reach_game: Dictionary, reach_all: Dictionary, reach_live: Dictionary) -> void:
	var import_files := _list_files_under(IMPORT_DIR)
	var asset_files := _list_files_under(ASSETS_DIR)

	# ---- Sections A/B: IMPORT reachability, committed game vs +tools ----
	var reachable_all: Array[String] = []
	for p in import_files:
		if reach_all.has(p):
			reachable_all.append(p)

	var dev_only: Array[String] = []
	var unreachable: Array[String] = []
	for p in import_files:
		if reach_all.has(p):
			if not reach_game.has(p):
				dev_only.append(p)
		else:
			unreachable.append(p)

	dev_only.sort_custom(func(a, b): return _file_size(a) > _file_size(b))
	unreachable.sort_custom(func(a, b): return _file_size(a) > _file_size(b))

	var total_size := 0
	for p in import_files:
		total_size += _file_size(p)
	var reachable_size := 0
	for p in reachable_all:
		reachable_size += _file_size(p)
	var dev_only_size := 0
	for p in dev_only:
		dev_only_size += _file_size(p)
	var unreachable_size := 0
	for p in unreachable:
		unreachable_size += _file_size(p)

	# ---- Section D: reachable from a committed scene, but not live ----
	var dead_by_old_scenes: Array[String] = []
	for p in import_files:
		if reach_game.has(p) and not reach_live.has(p):
			dead_by_old_scenes.append(p)
	for p in asset_files:
		if reach_game.has(p) and not reach_live.has(p):
			dead_by_old_scenes.append(p)

	# Attribution: only committed roots the live traversal never touched can
	# possibly be the sole reason something in dead_by_old_scenes is alive —
	# anything a live root reaches is by definition already in reach_live.
	var candidate_roots: Array[String] = []
	for r in _game_roots:
		if not reach_live.has(r):
			candidate_roots.append(r)

	var attributed_by: Dictionary = {}  # file -> Array[String] of root paths
	for root in candidate_roots:
		var root_reach := _reach_from([root])
		for p in dead_by_old_scenes:
			if root_reach.has(p):
				if not attributed_by.has(p):
					attributed_by[p] = []
				attributed_by[p].append(root)

	dead_by_old_scenes.sort_custom(func(a, b): return _file_size(a) > _file_size(b))
	var dead_size := 0
	for p in dead_by_old_scenes:
		dead_size += _file_size(p)

	# ---- assemble ----
	var out: PackedStringArray = []
	out.append("TailorTown unused-asset report")
	out.append("Generated by tools/report_unused_assets.gd")
	out.append("")
	out.append("== TOTALS ==")
	out.append("IMPORT on disk:            %s (%d files)" % [_mb(total_size), import_files.size()])
	out.append("Reachable (game+tools):    %s" % _mb(reachable_size))
	out.append("Dev-only (tools/** only):  %s" % _mb(dev_only_size))
	out.append("Unreachable at all:        %s" % _mb(unreachable_size))
	out.append("Reachable from a committed scene/script but NOT from live entry points")
	out.append(
		"(IMPORT + assets, Section D): %s (%d files)" % [_mb(dead_size), dead_by_old_scenes.size()]
	)
	out.append("")
	out.append("Project roots (main_scene+autoloads): %d" % _project_roots.size())
	out.append("Committed game roots (tscn/tres/gd):   %d" % _game_roots.size())
	out.append("Tools roots (tscn/tres/gd):            %d" % _tools_roots.size())
	out.append("Scripts with resolved res:// literals: %d" % _script_literal_edges.size())
	out.append(
		(
			"Global class_name entries known / scripts using one: %d / %d"
			% [_class_paths.size(), _class_name_edges.size()]
		)
	)
	out.append("Missing dependency targets encountered (skipped): %d" % _missing.size())
	out.append("")

	out.append("== SECTION A: res://IMPORT files reachable ONLY from res://tools/** (dev-only) ==")
	_append_section(out, dev_only, IMPORT_DIR, 1)
	out.append("")

	out.append("== SECTION B: res://IMPORT files not reachable at all ==")
	_append_section(out, unreachable, IMPORT_DIR, 1)
	out.append("")

	out.append("== SECTION C: dynamic/unresolved res:// strings found in scripts ==")
	if _dynamic_unresolved.is_empty():
		out.append("(none found)")
	else:
		for d in _dynamic_unresolved:
			out.append("%s:%d [%s] %s" % [d["file"], d["line"], d["reason"], d["snippet"]])
	out.append("")

	out.append("== SECTION D: kept alive only by scenes/scripts the live game never opens ==")
	out.append("(root set = run/main_scene + every autoload, expanded transitively; a file here")
	out.append(" is reachable from SOME committed .tscn/.tres/.gd but not from that live set)")
	if dead_by_old_scenes.is_empty():
		out.append("(none found)")
	else:
		var d_subtotals := {}
		var d_order: Array[String] = []
		for p in dead_by_old_scenes:
			var base: String = IMPORT_DIR if p.begins_with(IMPORT_DIR) else ASSETS_DIR
			var folder := _folder_group(p, base, 3)
			if not d_subtotals.has(folder):
				d_subtotals[folder] = 0
				d_order.append(folder)
			d_subtotals[folder] += _file_size(p)
		out.append("-- folder subtotals (up to 3 path segments) --")
		var d_order_sorted := d_order.duplicate()
		d_order_sorted.sort_custom(func(a, b): return d_subtotals[a] > d_subtotals[b])
		for folder in d_order_sorted:
			out.append("  %s: %s" % [folder, _mb(d_subtotals[folder])])
		out.append("-- files (biggest first) --")
		for p in dead_by_old_scenes:
			var keepers: Array = attributed_by.get(p, [])
			var keeper_str: String
			if keepers.is_empty():
				keeper_str = (
					"(kept alive by a non-scene committed root only reachable via "
					+ "directory-constant/dynamic edges — see NOTES)"
				)
			else:
				keeper_str = ", ".join(keepers)
			out.append("  %s  %s  <- %s" % [_mb(_file_size(p)), p, keeper_str])
	out.append("")

	if not _guesses.is_empty():
		out.append("== NOTES / judgment calls ==")
		for g in _guesses:
			out.append("- " + g)
		out.append("")
	if not _missing.is_empty():
		out.append(
			"== Missing dependency/literal targets (referenced but not found on disk, skipped) =="
		)
		var missing_keys := _missing.keys()
		missing_keys.sort()
		for p in missing_keys:
			out.append("- " + str(p))
		out.append("")

	var report_text := "\n".join(out)
	print(report_text)

	var dir := REPORT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(report_text)
		f.close()
	print("\nWritten to %s" % REPORT_PATH)


func _append_section(
	out: PackedStringArray, files: Array[String], base_dir: String, depth: int
) -> void:
	if files.is_empty():
		out.append("(none)")
		return
	var subtotals := {}
	var order: Array[String] = []
	for p in files:
		var folder := _top_folder(p, base_dir) if depth == 1 else _folder_group(p, base_dir, depth)
		if not subtotals.has(folder):
			subtotals[folder] = 0
			order.append(folder)
		subtotals[folder] += _file_size(p)

	out.append("-- folder subtotals --")
	var order_sorted := order.duplicate()
	order_sorted.sort_custom(func(a, b): return subtotals[a] > subtotals[b])
	for folder in order_sorted:
		out.append("  %s: %s" % [folder, _mb(subtotals[folder])])
	out.append("-- files (biggest first) --")
	for p in files:
		out.append("  %s  %s" % [_mb(_file_size(p)), p])


func _mb(bytes: int) -> String:
	return "%.2f MB" % (bytes / 1048576.0)

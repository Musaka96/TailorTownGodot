class_name PaperWorld
extends Node

## The world in the characters' paper (the owner's pick "G", 2026-09-26; look test in
## tools/shot_paper_world.gd). Every opaque surface of the level is swapped at runtime for
## assets/shaders/paper_world.gdshader: its own colour, softened, laid on one of four world
## papers picked by the material's name (FAMILIES: metal on folded card, wood on kraft,
## walls / cloth / rugs on a crumpled sheet, the rest on coated card). Attached by main.gd.
##
## Left alone: the characters (their own paper face and skin, their cloth; an item they
## carry is still papered), transparent materials (glass, fades), the roof RoofManager
## fades, and shaders this does not know. The wall cutaway keeps its own material and has
## its paper switched on inside (materials/wall_cutaway.gdshader, paper_on), so the fade
## still works.
##
## Other systems keep changing materials (a bolt gets its cloth, F4 recolours the shop, the
## renovation repaints a floor), so a sweep walks every mesh a slice per frame: a surface
## that shows a material that is not paper gets its paper, and a paper whose source changed
## colour or texture in place takes the change. New meshes are papered the frame after they
## enter the tree. F8 (debug builds) turns it all off and back on, to compare.

const SHADER := preload("res://assets/shaders/paper_world.gdshader")
const CUTAWAY_SHADER := "wall_cutaway.gdshader"
const PAPER_SURFACE := "res://data/paper_surfaces/paper_mache.tres"
const PAPER_DIR := "res://assets/textures/paper/"
## Face units per metre (paper_world.gdshaderinc), the painted texture's softening (mip
## bias) and the grain: the owner's pick.
const TILE := 1.25
const FLATTEN := 2.5
const GRAIN := 0.14
## Material name words -> paper; first match wins, anything else is coated card.
const FAMILIES := [
	["folded", ["metal", "gold", "steel", "iron", "brass", "machine", "chrome"]],
	["kraft", ["wood", "walnut", "oak", "pine", "trunk", "post", "floor", "parquet"]],
	[
		"cardboard",
		["wall", "wainscot", "interior", "brick", "roof", "cap", "chimney", "dormer", "cutaway"],
	],
	[
		"crumple",
		[
			"stone",
			"cobble",
			"grass",
			"soil",
			"dirt",
			"rug",
			"drape",
			"curtain",
			"awning",
			"cloth",
			"velvet",
			"linen",
			"trim",
			"shutter",
			"foliage",
			"clover",
			"straw",
			"roll_end",
		],
	],
]
## Per paper (tools/make_paper_tiles.py): texture, scan tiles per face unit (a tile is
## 0.8 m / this), scan normal strength, how much of the scan's light and dark shows.
const PAPERS := {
	"crumple": ["world_crumple", 0.8, 1.0, 0.35],
	"kraft": ["world_kraft", 1.0, 0.7, 0.2],
	"folded": ["world_folded", 2.5, 1.0, 0.4],
	"coated": ["world_coated", 1.0, 1.2, 0.2],
	"cardboard": ["world_cardboard", 1.0, 1.0, 0.5],
}
## How much calmer the paper is on surfaces facing up (floors, paving, table tops): the
## gameplay camera looks down on them from far, and at full strength they read as grain.
const UP_CALM := 0.7
## The paper's creases baked into its colour, so a wall in shade still shows them.
const SHADE := 1.5
## Window glass: see-through and shadowless, so the sun comes in (glass_clear.gdshader).
const GLASS_SHADER := preload("res://assets/shaders/glass_clear.gdshader")
const GLASS_OPACITY := 0.22
## Shaders it knows how to read (their colour, texture, pattern); others stay as they are.
const KNOWN_SHADERS := ["animal_crossing_style", "cloth", "roll_end"]
## Meshes swept per frame.
const SLICE := 160

static var enabled := true

var _root: Node
var _meshes: Array[MeshInstance3D] = []
var _fresh: Array[MeshInstance3D] = []
var _cursor := 0
var _roofs: Array[Node] = []  # the roofs RoofManager fades
var _lenient := {}  # source materials from a roof: papered even while alpha (mid-fade)
var _glass := {}  # the clear glass materials this made
var _papers := {}  # source material id -> paper ShaderMaterial (or null: leave it)
var _source := {}  # paper ShaderMaterial -> its source Material
var _originals := {}  # MeshInstance3D -> {"override": Material, s: Material, ...} before paper
var _cutaways := {}  # cutaway ShaderMaterial -> true
var _textures := {}


static func attach(root: Node) -> PaperWorld:
	var existing := root.get_node_or_null("PaperWorld")
	if existing is PaperWorld:
		return existing
	var pw := PaperWorld.new()
	pw.name = "PaperWorld"
	pw._root = root
	root.add_child(pw)
	return pw


func _ready() -> void:
	if _root == null:
		_root = get_parent()
	for rm in _root.find_children("*", "Node", true, false):
		var sc: Script = rm.get_script()
		if sc != null and sc.resource_path.ends_with("roof_manager.gd"):
			var roof: Variant = rm.get("_roof")
			if roof is Node:
				_roofs.append(roof)
	for n in _root.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)
	get_tree().node_added.connect(_on_node_added)
	if enabled:
		for mi in _meshes:
			_paper_mesh(mi)


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D and _root.is_ancestor_of(node):
		_meshes.append(node as MeshInstance3D)
		_fresh.append(node as MeshInstance3D)


func _process(_delta: float) -> void:
	if not enabled:
		_fresh.clear()
		return
	for mi in _fresh:
		if is_instance_valid(mi):
			_paper_mesh(mi)
	_fresh.clear()
	var n := mini(SLICE, _meshes.size())
	for i in n:
		if _cursor >= _meshes.size():
			_cursor = 0
		var mi := _meshes[_cursor]
		if not is_instance_valid(mi) or not mi.is_inside_tree():
			_meshes.remove_at(_cursor)
			_originals.erase(mi)
			continue
		_paper_mesh(mi)
		_cursor += 1


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		set_enabled(not enabled)
		print("PaperWorld: F8 -> ", "on" if enabled else "off")


## Paper on or off for the whole level (off puts every original material back).
func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		for mi in _meshes:
			if is_instance_valid(mi):
				_paper_mesh(mi)
		return
	for mi: Variant in _originals.keys():
		if not is_instance_valid(mi):
			continue
		var rec: Dictionary = _originals[mi]
		var m := mi as MeshInstance3D
		if rec.has("override"):
			m.material_override = rec["override"]
		for s: Variant in rec.keys():
			if s is int and s < m.get_surface_override_material_count():
				m.set_surface_override_material(s, rec[s])
	_originals.clear()
	for mat: ShaderMaterial in _cutaways.keys():
		mat.set_shader_parameter("paper_on", false)
	_cutaways.clear()


# --- one mesh ------------------------------------------------------------------------------


func _paper_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null or _skipped(mi):
		return
	var roof := _under_roof(mi)
	var over := mi.material_override
	if over != null:
		var p := _paper_or_sync(over, roof)
		if p != null and p != over:
			_remember(mi, "override", over)
			mi.material_override = p
		return
	for s in mi.mesh.get_surface_count():
		var src := mi.get_active_material(s)
		if src == null:
			continue
		var p := _paper_or_sync(src, roof)
		if p != null and p != src:
			_remember(mi, s, mi.get_surface_override_material(s))
			mi.set_surface_override_material(s, p)


func _remember(mi: MeshInstance3D, key: Variant, mat: Material) -> void:
	var rec: Dictionary = _originals.get(mi, {})
	rec[key] = mat
	_originals[mi] = rec


## A mesh of a roof RoofManager fades: its materials go alpha while it fades (the paper
## stays on; the fade itself is the instance transparency, which any material follows).
func _under_roof(mi: Node) -> bool:
	for r in _roofs:
		if is_instance_valid(r) and (r == mi or r.is_ancestor_of(mi)):
			return true
	return false


## Characters keep their own materials. An item a character carries does not count as
## the character.
func _skipped(mi: Node) -> bool:
	var n := mi
	while n != null and n != _root:
		var sc: Script = n.get_script()
		if sc != null:
			var path := sc.resource_path
			if path.contains("entities/items") or path.contains("entities/fx"):
				return false
			if path.ends_with("character_rig.gd"):
				return true
		n = n.get_parent()
	return false


## The paper for `src`: itself when it already is one (after taking any change its source
## made in place), null when it is to be left alone.
func _paper_or_sync(src: Material, roof := false) -> Material:
	if _glass.has(src):
		return null
	if _source.has(src):
		_sync(src as ShaderMaterial)
		return src
	if src is ShaderMaterial and _is_cutaway(src as ShaderMaterial):
		_paper_cutaway(src as ShaderMaterial)
		return null
	var id := src.get_instance_id()
	if not _papers.has(id):
		if roof:
			_lenient[src] = true
		var p := _build(src)
		_papers[id] = p
		if p != null and p.shader == SHADER:
			_source[p] = src
	return _papers[id]


func _is_cutaway(mat: ShaderMaterial) -> bool:
	return mat.shader != null and mat.shader.resource_path.ends_with(CUTAWAY_SHADER)


func _paper_cutaway(mat: ShaderMaterial) -> void:
	if _cutaways.has(mat):
		return
	_cutaways[mat] = true
	_apply_paper(mat, "cardboard")
	mat.set_shader_parameter("paper_flatten", FLATTEN)
	mat.set_shader_parameter("paper_on", true)


# --- building a paper ----------------------------------------------------------------------


## What a material shows: colour, texture, UV scale/offset, vertex colour, a cloth
## pattern, and the words that pick its paper; empty when it is not to be papered.
func _read(src: Material) -> Dictionary:
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and not _lenient.has(src):
			return {}
		if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			return {}
		return {
			"color": b.albedo_color,
			"tex": b.albedo_texture,
			"uv_scale": b.uv1_scale,
			"uv_offset": b.uv1_offset,
			"vcol": b.vertex_color_use_as_albedo,
			"key": b.resource_name.to_lower(),
		}
	if not (src is ShaderMaterial):
		return {}
	var sm := src as ShaderMaterial
	var file := sm.shader.resource_path.get_file() if sm.shader != null else ""
	var known := false
	for k in KNOWN_SHADERS:
		known = known or file.begins_with(k)
	if not known:
		return {}
	var out := {
		"key": sm.resource_name.to_lower() + " " + file,
		"uv_scale": Vector3.ONE,
		"uv_offset": Vector3.ZERO,
		"vcol": false,
		"tex": null
	}
	var col: Variant = sm.get_shader_parameter("cloth_color")
	if col == null:
		col = sm.get_shader_parameter("albedo_color")
	out["color"] = col if col is Color else Color.WHITE
	var tex: Variant = sm.get_shader_parameter("albedo_texture")
	if tex is Texture2D:
		out["tex"] = tex
	var tl: Variant = sm.get_shader_parameter("albedo_tiling")
	if tl is Vector2:
		out["uv_scale"] = Vector3(tl.x, tl.y, 1.0)
	var of: Variant = sm.get_shader_parameter("albedo_offset")
	if of is Vector2:
		out["uv_offset"] = Vector3(of.x, of.y, 0.0)
	var pat: Variant = sm.get_shader_parameter("pattern_tex")
	if pat is Texture2D and file.begins_with("cloth"):
		var uvs: Variant = sm.get_shader_parameter("uv_scale")
		var ps: Variant = sm.get_shader_parameter("pattern_scale")
		var pi: Variant = sm.get_shader_parameter("pattern_intensity")
		var st: Variant = sm.get_shader_parameter("pattern_strength")
		out["pattern"] = pat
		out["pattern_color"] = sm.get_shader_parameter("pattern_color")
		out["pattern_uv"] = (uvs if uvs is float else 2.5) * (ps if ps is float else 1.0)
		out["pattern_mix"] = (pi if pi is float else 1.0) * (st if st is float else 0.85)
	return out


func _build(src: Material) -> ShaderMaterial:
	if src is BaseMaterial3D and src.resource_name.to_lower().contains("glass"):
		return _clear_glass(src as BaseMaterial3D)
	var r := _read(src)
	if r.is_empty():
		return null
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_fill(mat, r)
	mat.set_shader_parameter("flatten", FLATTEN)
	mat.set_shader_parameter("paper_seed", float(_source.size() % 7))
	_apply_paper(mat, _family(r["key"]))
	return mat


func _clear_glass(src: BaseMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	var c := src.albedo_color.lerp(Color.WHITE, 0.4)
	mat.set_shader_parameter("tint", Color(c.r, c.g, c.b))
	mat.set_shader_parameter("opacity", GLASS_OPACITY)
	_glass[mat] = true
	return mat


func _fill(mat: ShaderMaterial, r: Dictionary) -> void:
	mat.set_shader_parameter("albedo_color", r["color"])
	mat.set_shader_parameter("albedo_tex", r["tex"])
	mat.set_shader_parameter("uv1_scale", r["uv_scale"])
	mat.set_shader_parameter("uv1_offset", r["uv_offset"])
	mat.set_shader_parameter("use_vertex_color", r["vcol"])
	if r.has("pattern"):
		mat.set_shader_parameter("pattern_tex", r["pattern"])
		mat.set_shader_parameter("pattern_color", r["pattern_color"])
		mat.set_shader_parameter("pattern_uv", r["pattern_uv"])
		mat.set_shader_parameter("pattern_mix", r["pattern_mix"])
	else:
		mat.set_shader_parameter("pattern_mix", 0.0)


## A source that changed its colour or texture in place (a repainted floor, a turned sign).
func _sync(paper: ShaderMaterial) -> void:
	var src: Material = _source[paper]
	if not is_instance_valid(src):
		return
	var r := _read(src)
	if r.is_empty():
		return
	if (
		paper.get_shader_parameter("albedo_color") != r["color"]
		or paper.get_shader_parameter("albedo_tex") != r["tex"]
	):
		_fill(paper, r)


func _apply_paper(mat: ShaderMaterial, family: String) -> void:
	var look := load(PAPER_SURFACE) as PaperSurface
	if look != null:
		look.apply_to(mat)
	var p: Array = PAPERS[family]
	mat.set_shader_parameter("scan_albedo_tex", _tex(p[0] + "_albedo.jpg"))
	mat.set_shader_parameter("scan_normal_tex", _tex(p[0] + "_normal.jpg"))
	mat.set_shader_parameter("scan_scale", p[1])
	mat.set_shader_parameter("normal_strength", p[2])
	mat.set_shader_parameter("scan_albedo", p[3])
	mat.set_shader_parameter("paper_tile", TILE)
	mat.set_shader_parameter("paper_grain_amount", GRAIN)
	mat.set_shader_parameter("paper_up_calm", UP_CALM)
	mat.set_shader_parameter("paper_shade", SHADE)


func _tex(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load(PAPER_DIR + file)
	return _textures[file]


static func _family(key: String) -> String:
	for f: Array in FAMILIES:
		for word: String in f[1]:
			if key.contains(word):
				return f[0]
	return "coated"

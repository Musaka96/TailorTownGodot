class_name ShopLookApplier
extends Node

## Recolours the shop interior from a data-driven ShopLook (see docs/SHOP_LOOKS.md).
## Walks every MeshInstance3D under the shop and, for each surface whose baked material
## name matches a slot (or its v6 alias), swaps in a shared StandardMaterial3D built from
## the current look. Works on both the v6 and v7 town-kit exports since matching is by
## material name, not node path.
##
## Nothing needs to be placed by hand: ShopLookApplier.attach(root) (called from main.gd,
## next to ShopDoor.attach_all) finds the shop, adds one of these under it with the
## default look list, and applies the saved/current look.

signal look_changed(look: ShopLook)

const DEFAULT_LOOK_DIR := "res://data/shop_looks/"
## Fixed order for the shipped presets (fern_damask is the default → index 0).
## Not simply the alphabetical directory listing, so index 0 stays stable regardless of
## which look files exist on disk.
const DEFAULT_LOOK_ORDER: Array[StringName] = [
	&"fern_damask",
	&"sage_panel",
	&"forest_green",
	&"oxblood",
	&"cream_walnut",
	&"navy_atelier",
	&"plum_damask",
	&"mint_trellis",
	&"olive_fern",
	&"sage_blossom",
	&"chestnut_stripe",
]

## Slot property name -> baked material names that count as that slot (v7 name first,
## v6 alias second). See docs/SHOP_LOOKS.md for the table this mirrors.
const SLOT_ALIASES := {
	"wall": ["InWall", "inwall_sage"],
	"wainscot": ["Wainscot", "inwall_green"],
	"floor": ["Floor", "floor_planks"],
	"rug": ["Rug", "rug_tex_green"],
	"drape": ["Drape", "drape_green"],
}
## Slots only some shop versions have (v7's round and runner rugs): matched the same way,
## but a shop without them is not worth a warning.
const OPTIONAL_SLOT_ALIASES := {
	"rug_round": ["RugRound"],
	"rug_runner": ["RugRunner"],
}

@export var looks: Array[ShopLook] = []
## Explicit path to the shop node; leave empty to auto-find it (see _resolve_shop).
@export var shop_path: NodePath
@export var current: int = 0

var _owned: Dictionary = {}  # StringName -> true
var _material_cache: Dictionary = {}  # "<look id>:<slot>" -> StandardMaterial3D
var _last_matched: Dictionary = {}  # slot name -> true, from the most recent apply()
var _warned: Dictionary = {}  # message -> true, so warnings don't spam every apply


## Add a ShopLookApplier under the shop node (a name starting with "tailor_shop_v")
## found anywhere under `root`, load the default look list and apply the current one.
## Returns the applier, or null (with a warning) if no shop could be found.
## Whether `root` holds a kit shop whose surfaces can be recoloured (the greybox has none).
static func has_shop(root: Node) -> bool:
	return _find_shop(root) != null


static func attach(root: Node) -> ShopLookApplier:
	var shop := _find_shop(root)
	if shop == null:
		push_warning("ShopLookApplier.attach: no 'tailor_shop_v*' node under %s" % root.name)
		return null
	var existing := shop.get_node_or_null("ShopLookApplier")
	if existing is ShopLookApplier:
		return existing
	var applier := ShopLookApplier.new()
	applier.name = "ShopLookApplier"
	applier.looks = _load_default_looks()
	shop.add_child(applier)
	applier._init_owned_defaults()
	applier.apply(applier.current)
	return applier


static func _find_shop(root: Node) -> Node3D:
	var found := root.find_children("tailor_shop_v*", "Node3D", true, false)
	return found[0] if not found.is_empty() else null


static func _load_default_looks() -> Array[ShopLook]:
	var out: Array[ShopLook] = []
	for id in DEFAULT_LOOK_ORDER:
		var path := DEFAULT_LOOK_DIR + String(id) + ".tres"
		if not ResourceLoader.exists(path):
			continue
		var look := load(path) as ShopLook
		if look != null:
			out.append(look)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		get_viewport().set_input_as_handled()
		next()
		var look := get_look()
		print("ShopLookApplier: F4 -> ", look.display_name if look != null else "(none)")


# --- Public API --------------------------------------------------------------


## Apply looks[index] (clamped). Warns once (never crashes) if the shop, the look or a
## slot can't be found.
func apply(index: int) -> void:
	if looks.is_empty():
		_warn_once("ShopLookApplier: no looks configured")
		return
	var i: int = clampi(index, 0, looks.size() - 1)
	var look: ShopLook = looks[i]
	if look == null:
		_warn_once("ShopLookApplier: looks[%d] is null" % i)
		return
	var shop := _resolve_shop()
	if shop == null:
		_warn_once("ShopLookApplier: could not find the shop to recolour")
		return
	var matched: Dictionary = {}
	for node in shop.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh if mi != null else null
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var slot_key := _slot_for_material(mesh.surface_get_material(s))
			if slot_key.is_empty():
				continue
			var slot: ShopLookSlot = look.get(slot_key)
			if slot == null:
				continue
			mi.set_surface_override_material(s, _material_for(look, slot_key, slot))
			matched[slot_key] = true
	for slot_key: String in SLOT_ALIASES:
		if not matched.has(slot_key):
			_warn_once(
				"ShopLookApplier: no surface matched slot '%s' for look '%s'" % [slot_key, look.id]
			)
	current = i
	_last_matched = matched
	look_changed.emit(look)


## Apply the look with this id, if it's in `looks`.
func apply_id(id: StringName) -> void:
	for i in looks.size():
		if looks[i] != null and looks[i].id == id:
			apply(i)
			return
	_warn_once("ShopLookApplier: unknown look id '%s'" % id)


func next() -> void:
	if looks.is_empty():
		return
	apply((current + 1) % looks.size())


func previous() -> void:
	if looks.is_empty():
		return
	apply((current - 1 + looks.size()) % looks.size())


func get_look() -> ShopLook:
	return looks[current] if current >= 0 and current < looks.size() else null


## Slot keys that were actually matched to a surface by the most recent apply() call.
func matched_slots() -> Array:
	return _last_matched.keys()


func is_owned(id: StringName) -> bool:
	return _owned.get(id, false)


func owned_ids() -> Array:
	return _owned.keys()


# --- Save/load (picked up automatically by SaveManager's station scan) -----


func save_state() -> Dictionary:
	var look := get_look()
	return {"current": String(look.id) if look != null else "", "owned": owned_ids()}


func load_state(data: Dictionary) -> void:
	var owned: Array = data.get("owned", [])
	if not owned.is_empty():
		_owned.clear()
		for id: Variant in owned:
			_owned[StringName(str(id))] = true
	var id := StringName(str(data.get("current", "")))
	if id != StringName():
		apply_id(id)


# --- Internals ---------------------------------------------------------------


func _init_owned_defaults() -> void:
	for look in looks:
		if look != null and look.price <= 0 and not _owned.has(look.id):
			_owned[look.id] = true


func _resolve_shop() -> Node3D:
	if shop_path != NodePath():
		var explicit := get_node_or_null(shop_path)
		if explicit is Node3D:
			return explicit
	var parent := get_parent()
	if parent is Node3D and String(parent.name).begins_with("tailor_shop_v"):
		return parent
	var scene_root: Node = get_tree().current_scene if is_inside_tree() else null
	if scene_root == null and is_inside_tree():
		scene_root = get_tree().root
	return _find_shop(scene_root) if scene_root != null else null


static func _slot_for_material(mat: Material) -> String:
	if mat == null:
		return ""
	var name := mat.resource_name
	for table: Dictionary in [SLOT_ALIASES, OPTIONAL_SLOT_ALIASES]:
		for slot_key: String in table:
			var aliases: Array = table[slot_key]
			if aliases.has(name):
				return slot_key
	return ""


func _material_for(look: ShopLook, slot_key: String, slot: ShopLookSlot) -> StandardMaterial3D:
	var cache_key := "%s:%s" % [String(look.id), slot_key]
	var cached: StandardMaterial3D = _material_cache.get(cache_key)
	if cached != null:
		return cached
	var mat := StandardMaterial3D.new()
	mat.resource_name = cache_key
	mat.albedo_texture = slot.albedo_texture
	mat.albedo_color = slot.tint
	if slot.normal_texture != null:
		mat.normal_enabled = true
		mat.normal_texture = slot.normal_texture
		mat.normal_scale = slot.normal_scale
	mat.roughness_texture = slot.roughness_texture
	mat.roughness = slot.roughness
	# The rug's UVs already span the whole (non-tiling) image — never re-tile it.
	var scale: float = 1.0 if slot_key.begins_with("rug") else slot.uv_scale
	mat.uv1_scale = Vector3(scale, scale, 1.0)
	_material_cache[cache_key] = mat
	return mat


func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	push_warning(message)

class_name SaveCodec

## Turns the shop's runtime objects into plain, serialisable dictionaries and back
## again, so SaveManager can write them with FileAccess.store_var. Handles the two
## things that aren't primitives: a MaterialType (cloth) and every carryable world
## item (rolls, cut pieces, garment parts, packaged suits). Kept static and free of
## node/tree state — pure (de)serialisation, shared by SaveManager and the stations.

const ROLL_SCENE := preload("res://entities/items/material_roll.tscn")
const FABRIC_SCENE := preload("res://entities/items/fabric_piece.tscn")
const GARMENT_SCENE := preload("res://entities/items/garment_piece.tscn")
const SUIT_SCENE := preload("res://entities/items/suit.tscn")


# --- MaterialType ----------------------------------------------------------


## A MaterialType (authored .tres or a runtime custom bolt) as a flat dictionary.
static func mat_to(mat: MaterialType) -> Dictionary:
	if mat == null:
		return {}
	return {
		"id": String(mat.id),
		"display_name": mat.display_name,
		"fabric": int(mat.fabric),
		"pattern": int(mat.pattern),
		"cloth_color": mat.cloth_color,
		"pattern_color": mat.pattern_color,
		"weight_gsm": mat.weight_gsm,
		"super_number": mat.super_number,
		"price_per_meter": mat.price_per_meter,
		"roll_length_m": mat.roll_length_m,
	}


static func mat_from(d: Dictionary) -> MaterialType:
	if d.is_empty():
		return null
	var m := MaterialType.new()
	m.id = StringName(str(d.get("id", "")))
	m.display_name = str(d.get("display_name", ""))
	m.fabric = int(d.get("fabric", 0))
	m.pattern = int(d.get("pattern", 0))
	m.cloth_color = d.get("cloth_color", Color(0.5, 0.5, 0.5))
	m.pattern_color = d.get("pattern_color", Color(0.9, 0.9, 0.9))
	m.weight_gsm = int(d.get("weight_gsm", 250))
	m.super_number = int(d.get("super_number", 0))
	m.price_per_meter = int(d.get("price_per_meter", 25))
	m.roll_length_m = float(d.get("roll_length_m", 20.0))
	return m


# --- Carryable items -------------------------------------------------------


## True for any of the four carryable world items.
static func is_item(node: Node) -> bool:
	return node is MaterialRoll or node is FabricPiece or node is GarmentPiece or node is Suit


## Any world item the shop can hold, tagged by "kind" so item_from can rebuild it.
## Returns {} for anything that isn't a known carryable.
static func item_to(node: Node) -> Dictionary:
	if node is MaterialRoll:
		return {"kind": "roll", "material": mat_to(node.material), "remaining": node.remaining_length_m}
	if node is FabricPiece:
		return {"kind": "fabric", "material": mat_to(node.material), "length": node.length_m}
	if node is GarmentPiece:
		return {
			"kind": "garment",
			"material": mat_to(node.material),
			"garment_type": int(node.garment_type),
			"size": int(node.size),
			"style": node.style,
			"quality": node.quality,
			"stage": int(node.stage),
			"order_id": int(node.order_id),
		}
	if node is Suit:
		return {
			"kind": "suit",
			"quality": node.quality,
			"primary_color": node.primary_color,
			"order_id": int(node.order_id),
			"parts": _suit_parts_to(node.parts),
		}
	return {}


## Rebuild a carryable from item_to() data. NOT added to the tree — the caller
## parents/places it (attach_to / place_on) so _ready runs with the values set.
static func item_from(d: Dictionary) -> Node:
	match str(d.get("kind", "")):
		"roll":
			var r: Node = ROLL_SCENE.instantiate()
			r.material = mat_from(d.get("material", {}))
			r.remaining_length_m = float(d.get("remaining", -1.0))
			return r
		"fabric":
			var f: Node = FABRIC_SCENE.instantiate()
			f.material = mat_from(d.get("material", {}))
			f.length_m = float(d.get("length", 1.0))
			return f
		"garment":
			var g: Node = GARMENT_SCENE.instantiate()
			g.material = mat_from(d.get("material", {}))
			g.garment_type = int(d.get("garment_type", 0))
			g.size = int(d.get("size", 1))
			g.style = str(d.get("style", "Classic"))
			g.quality = float(d.get("quality", 1.0))
			g.stage = int(d.get("stage", Enums.Stage.CUT))
			g.order_id = int(d.get("order_id", 0))
			return g
		"suit":
			var s: Node = SUIT_SCENE.instantiate()
			s.quality = float(d.get("quality", 1.0))
			s.primary_color = d.get("primary_color", Color(0.2, 0.2, 0.24))
			s.order_id = int(d.get("order_id", 0))
			s.parts = _suit_parts_from(d.get("parts", {}))
			return s
	return null


# --- Suit parts (a small dict of dicts, GarmentType -> spec) ---------------


static func _suit_parts_to(parts: Dictionary) -> Dictionary:
	var out := {}
	for t: Variant in parts.keys():
		var p: Dictionary = parts[t]
		out[int(t)] = {
			"material": mat_to(p.get("material")),
			"quality": float(p.get("quality", 1.0)),
			"size": int(p.get("size", 1)),
			"style": str(p.get("style", "Classic")),
		}
	return out


static func _suit_parts_from(data: Dictionary) -> Dictionary:
	var out := {}
	for t: Variant in data.keys():
		var p: Dictionary = data[t]
		out[int(t)] = {
			"material": mat_from(p.get("material", {})),
			"quality": float(p.get("quality", 1.0)),
			"size": int(p.get("size", 1)),
			"style": str(p.get("style", "Classic")),
		}
	return out

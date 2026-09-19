class_name ClothStock

## What cloth the shop holds and what its open orders still need — one source of truth for
## the fitting room's "in stock" note and the phone's cloth ledger. Cloth is physical here
## (bolts on shelves and the floor, cut lengths in hand), so stock is a scan of the scene.
##
## A cloth is its fabric + pattern + colour; entries are keyed by key() and look like
##   { fabric, pattern, color, material, have, coming, need, orders: [customer names] }
## with lengths in metres. `coming` is what the phone has on the way.

const COLOR_MATCH := 0.06  # summed RGB distance under which two cloth colours are the same


static func key(fabric: int, pattern: int, color_index: int) -> String:
	return "%d:%d:%d" % [fabric, pattern, color_index]


## True if any bolt or cut length in `scene` is this cloth.
static func has_cloth(scene: Node, fabric: int, pattern: int, color_index: int) -> bool:
	var entry: Dictionary = stock(scene).get(key(fabric, pattern, color_index), {})
	return float(entry.get("have", 0.0)) > 0.0


## Every cloth in the shop, by key: bolts and cut lengths summed, plus anything `phone`
## (a Phone station, optional) has on the way.
static func stock(scene: Node, phone: Node = null) -> Dictionary:
	var out := {}
	if scene == null:
		return out
	for n in scene.find_children("*", "MaterialRoll", true, false):
		var roll := n as MaterialRoll
		if roll != null and not roll.is_empty():
			_add(out, roll.material, "have", roll.remaining_length_m)
	for n in scene.find_children("*", "FabricPiece", true, false):
		var piece := n as FabricPiece
		if piece != null:
			_add(out, piece.material, "have", piece.length_m)
	if phone != null and phone.has_method("pending"):
		for p: Dictionary in phone.pending():
			_add(out, p.get("mat") as MaterialType, "coming", float(p.get("length", 0.0)))
	return out


## `stock()` with what the open orders still need folded in (`need`, `orders`). A part
## stops counting once it is sewn (the order marks it filled) — or already cut and waiting
## on the bench, since its cloth has left the bolt.
static func ledger(scene: Node, phone: Node = null) -> Dictionary:
	var out := stock(scene, phone)
	var cut := _cut_parts(scene)
	for order: SuitOrder in Orders.active:
		for t: int in order.required_types():
			if not order.needs_part(t):
				continue
			var spec: Dictionary = order.design[t]
			var k := key(int(spec["fabric"]), int(spec["pattern"]), int(spec["color"]))
			var waiting := "%s|%d" % [k, t]
			if int(cut.get(waiting, 0)) > 0:
				cut[waiting] = int(cut[waiting]) - 1
				continue
			var entry := _entry(out, order.part_material(t), k)
			entry["need"] = float(entry["need"]) + Pricing.part_meters(t, Enums.Size.M)
			if not (entry["orders"] as Array).has(order.customer_name):
				(entry["orders"] as Array).append(order.customer_name)
	return out


## Parts already cut but not yet sewn, as "key|GarmentType" -> count.
static func _cut_parts(scene: Node) -> Dictionary:
	var out := {}
	if scene == null:
		return out
	for n in scene.find_children("*", "GarmentPiece", true, false):
		var piece := n as GarmentPiece
		if piece == null or piece.order_id != 0 or piece.material == null:
			continue
		var k := "%s|%d" % [_key_of(piece.material), int(piece.garment_type)]
		out[k] = int(out.get(k, 0)) + 1
	return out


static func _add(out: Dictionary, mat: MaterialType, field: String, metres: float) -> void:
	if mat == null or metres <= 0.0:
		return
	var entry := _entry(out, mat, _key_of(mat))
	entry[field] = float(entry[field]) + metres


static func _entry(out: Dictionary, mat: MaterialType, k: String) -> Dictionary:
	if not out.has(k):
		var bits := k.split(":")
		out[k] = {
			"fabric": int(bits[0]),
			"pattern": int(bits[1]),
			"color": int(bits[2]),
			"material": mat,
			"have": 0.0,
			"coming": 0.0,
			"need": 0.0,
			"orders": [],
		}
	return out[k]


static func _key_of(mat: MaterialType) -> String:
	return key(int(mat.fabric), int(mat.pattern), _color_index(mat.cloth_color))


## The palette index of a cloth colour (-1 for a dye that isn't on the palette).
static func _color_index(c: Color) -> int:
	for i in MaterialFactory.color_count():
		var v := MaterialFactory.color_value(i)
		if absf(c.r - v.r) + absf(c.g - v.g) + absf(c.b - v.b) < COLOR_MATCH:
			return i
	return -1

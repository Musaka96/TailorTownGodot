extends Node

## Autoloaded as "Clientele". Remembers the people you've made suits for, so some of them
## come back as REGULARS: same name and face, and a bigger budget the more they trust you
## (loyalty). A fulfilled order earns loyalty; an expired one loses some. The customer
## manager asks pick_regular() when a shopper walks in. See docs/ECONOMY.md.

const MAX_LOYALTY := 5

## Collected suits kept in the town's memory this long (days), for worn_about_town().
const WORN_MEMORY_DAYS := 30

## name -> { look, loyalty, visits, last_day, dislike: { kind, value, known, said },
## owned: [[colour, pattern], ...] }
var _people: Dictionary = {}
## Suits collected and now worn about town: [[jacket colour, day collected], ...]
var _worn: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.order_fulfilled.connect(_on_fulfilled)
	EventBus.order_expired.connect(_on_expired)


## Remember a customer's face when they place an order (keyed by name).
func note_customer(cust: Node) -> void:
	if cust == null or cust.get("preference") == null:
		return
	var nm: String = cust.preference.display_name
	var entry: Dictionary = _people.get(nm, {"loyalty": 0, "visits": 0})
	entry["look"] = {
		"skin": cust.get("skin_color"),
		"head": int(cust.get("head_index")),
		"hair": int(cust.get("hair_index")),
		"hair_color": cust.get("hair_color"),
		"eyes": str(cust.get("eye_color")),
		"glasses": str(cust.get("glasses")),
		"gender": int(cust.get("gender")),
	}
	var frames: Variant = cust.get("glasses_color")  # their glasses' frame colour
	if frames != null:
		entry["look"]["glasses_color"] = str(frames)
	var street: Variant = cust.get("street_index")  # their street clothes
	if street != null:
		entry["look"]["street"] = int(street)
	var dye: Variant = cust.get("street_color")  # the colourway they are dyed in
	if dye != null:
		entry["look"]["street_color"] = int(dye)
	var shoes: Variant = cust.get("shoes")
	if shoes is Dictionary and not (shoes as Dictionary).is_empty():
		entry["look"]["shoes"] = (shoes as Dictionary).duplicate()
	var face: Variant = cust.get("face_style")  # their cut-paper face (FaceCast preset)
	if face != null and str(face) != "":
		entry["look"]["face_style"] = str(face)
	_remember_taste(entry, cust.preference)
	_people[nm] = entry


func has_regulars() -> bool:
	for nm in _people:
		if int(_people[nm].get("visits", 0)) > 0:
			return true
	return false


func is_known(nm: String) -> bool:
	return _people.has(nm)


## 0..MAX_LOYALTY for this name (0 = not a regular yet).
func loyalty(nm: String) -> int:
	return int(_people.get(nm, {}).get("loyalty", 0))


func look(nm: String) -> Dictionary:
	return _people.get(nm, {}).get("look", {})


## Budget multiplier a regular brings (1.0 for strangers).
func budget_mult(nm: String) -> float:
	var c := Config.data
	var step: float = c.loyalty_budget_step if c != null else 0.1
	var top: float = c.loyalty_budget_max if c != null else 0.5
	return 1.0 + minf(loyalty(nm) * step, top)


## A regular who could walk in now (has completed an order, has none open, and didn't
## collect a suit earlier today — nobody's back for another the same day), or "".
func pick_regular() -> String:
	var busy := {}
	for order in Orders.active:
		busy[order.customer_name] = true
	var today: int = Shift.day if Shift != null else 1
	var pool: Array[String] = []
	for nm: String in _people:
		var entry: Dictionary = _people[nm]
		if int(entry.get("last_day", -1)) >= today:
			continue
		if int(entry.get("visits", 0)) > 0 and not busy.has(nm):
			pool.append(nm)
	return pool[_rng.randi() % pool.size()] if not pool.is_empty() else ""


## A small dent in a regular's loyalty (e.g. turned away on a quiet day).
func dent_loyalty(nm: String) -> void:
	if _people.has(nm):
		var entry: Dictionary = _people[nm]
		entry["loyalty"] = maxi(int(entry.get("loyalty", 0)) - 1, 0)


## The dislike a regular keeps from visit to visit: { kind, value, known, said } or {}.
func kept_dislike(nm: String) -> Dictionary:
	return _people.get(nm, {}).get("dislike", {})


## A regular's past suits from you as [colour, pattern].
func wardrobe(nm: String) -> Array:
	return (_people.get(nm, {}).get("owned", []) as Array).duplicate(true)


## Your suits being worn about town: jacket colour -> how many were collected in the
## `window` days before `day` (not counting `day` itself: nobody has seen them yet).
func worn_about_town(day: int, window: int) -> Dictionary:
	var out := {}
	for w: Array in _worn:
		var d := int(w[1])
		if d < day and day - d <= window:
			out[int(w[0])] = int(out.get(int(w[0]), 0)) + 1
	return out


func _on_fulfilled(order: SuitOrder, _payout: int) -> void:
	var entry: Dictionary = _people.get(order.customer_name, {"loyalty": 0, "visits": 0})
	var today: int = Shift.day if Shift != null else 1
	entry["visits"] = int(entry.get("visits", 0)) + 1
	entry["loyalty"] = mini(int(entry.get("loyalty", 0)) + 1, MAX_LOYALTY)
	entry["last_day"] = today
	var jacket: Dictionary = order.design.get(Enums.GarmentType.JACKET, {})
	if not jacket.is_empty():
		var suit := [int(jacket.get("color", 0)), int(jacket.get("pattern", 0))]
		var owned: Array = entry.get("owned", [])
		if not suit in owned:
			owned.append(suit)
		entry["owned"] = owned
		_worn.append([suit[0], today])
		_worn = _worn.filter(func(w: Array) -> bool: return today - int(w[1]) <= WORN_MEMORY_DAYS)
	_people[order.customer_name] = entry


func _on_expired(order: SuitOrder) -> void:
	if _people.has(order.customer_name):
		var entry: Dictionary = _people[order.customer_name]
		entry["loyalty"] = maxi(int(entry.get("loyalty", 0)) - 1, 0)


# --- Save / load -----------------------------------------------------------


func save_state() -> Dictionary:
	return {"people": _people.duplicate(true), "worn": _worn.duplicate(true)}


func restore(d: Variant) -> void:
	var data: Dictionary = d if d is Dictionary else {}
	# Older saves were the people dictionary on its own.
	var people: Variant = data.get("people", data if not data.has("worn") else {})
	_people = (people as Dictionary).duplicate(true) if people is Dictionary else {}
	_worn = (data.get("worn", []) as Array).duplicate(true)
	for nm in _people:  # JSON turns the [colour, pattern] ints into floats
		var entry: Dictionary = _people[nm]
		var owned: Array = []
		for o: Array in entry.get("owned", []):
			owned.append([int(o[0]), int(o[1])])
		entry["owned"] = owned


func reset() -> void:
	_people.clear()
	_worn.clear()


## Keep the first real dislike a customer shows (stated or quiet) for good; a quiet one
## becomes known once they've said it. A town remark is about the town, not them.
func _remember_taste(entry: Dictionary, pref: CustomerPreference) -> void:
	if pref == null:
		return
	var kept: Dictionary = entry.get("dislike", {})
	if kept.is_empty():
		if not pref.quiet_dislike.is_empty():
			kept = pref.quiet_dislike.duplicate()
			kept["known"] = pref.quiet_known
		elif pref.dislikes_color >= 0 and pref.town_worn == 0:
			kept = {"kind": "color", "value": pref.dislikes_color, "known": true, "said": true}
	elif pref.quiet_known and not bool(kept.get("said", false)):
		kept["known"] = true
	entry["dislike"] = kept

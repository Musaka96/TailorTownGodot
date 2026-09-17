extends Node

## Autoloaded as "Clientele". Remembers the people you've made suits for, so some of them
## come back as REGULARS: same name and face, and a bigger budget the more they trust you
## (loyalty). A fulfilled order earns loyalty; an expired one loses some. The customer
## manager asks pick_regular() when a shopper walks in. See docs/ECONOMY.md.

const MAX_LOYALTY := 5

## name -> { look: Dictionary, loyalty: int, visits: int }
var _people: Dictionary = {}
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


## A regular who could walk in now (has completed an order and has none open), or "".
func pick_regular() -> String:
	var busy := {}
	for order in Orders.active:
		busy[order.customer_name] = true
	var pool: Array[String] = []
	for nm: String in _people:
		if int(_people[nm].get("visits", 0)) > 0 and not busy.has(nm):
			pool.append(nm)
	return pool[_rng.randi() % pool.size()] if not pool.is_empty() else ""


## A small dent in a regular's loyalty (e.g. turned away on a quiet day).
func dent_loyalty(nm: String) -> void:
	if _people.has(nm):
		var entry: Dictionary = _people[nm]
		entry["loyalty"] = maxi(int(entry.get("loyalty", 0)) - 1, 0)


func _on_fulfilled(order: SuitOrder, _payout: int) -> void:
	var entry: Dictionary = _people.get(order.customer_name, {"loyalty": 0, "visits": 0})
	entry["visits"] = int(entry.get("visits", 0)) + 1
	entry["loyalty"] = mini(int(entry.get("loyalty", 0)) + 1, MAX_LOYALTY)
	_people[order.customer_name] = entry


func _on_expired(order: SuitOrder) -> void:
	if _people.has(order.customer_name):
		var entry: Dictionary = _people[order.customer_name]
		entry["loyalty"] = maxi(int(entry.get("loyalty", 0)) - 1, 0)


# --- Save / load -----------------------------------------------------------


func save_state() -> Dictionary:
	return _people.duplicate(true)


func restore(d: Variant) -> void:
	_people = (d as Dictionary).duplicate(true) if d is Dictionary else {}


func reset() -> void:
	_people.clear()

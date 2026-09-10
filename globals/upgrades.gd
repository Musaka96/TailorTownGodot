extends Node

## Autoloaded as "Upgrades". Reputation-gated shop progression bought from the phone:
## machine upgrades (faster/unlocked abilities) and premium textile vendors. Purchases
## persist in saves. Everything is data-driven (UPGRADES / VENDORS) so adding more is
## just another entry. Reputation tiers come from the Reputation autoload (0..4).

signal changed

## id -> upgrade. tier = required Reputation.tier(); category groups them in the phone.
const UPGRADES := {
	"cut_sharp":
	{
		"name": "Sharp Scissors",
		"category": "Cutting Table",
		"cost": 120,
		"tier": 1,
		"desc": "Keener shears — hold Shift to cut fast (riskier) at the cutting table.",
	},
	"cut_master":
	{
		"name": "Master Shears",
		"category": "Cutting Table",
		"cost": 320,
		"tier": 2,
		"desc": "Tailor-grade shears glide faster through every cut.",
	},
	"sew_oiled":
	{
		"name": "Oiled Machine",
		"category": "Sewing Machine",
		"cost": 120,
		"tier": 1,
		"desc": "A smooth action — hold Shift to sew fast (tighter timing).",
	},
	"sew_industrial":
	{
		"name": "Industrial Motor",
		"category": "Sewing Machine",
		"cost": 320,
		"tier": 2,
		"desc": "A stronger motor drives the needle quicker on every seam.",
	},
	"rack_hooks":
	{
		"name": "Extra Hooks",
		"category": "Clothing Rack",
		"cost": 140,
		"tier": 1,
		"desc": "More hooks on the rack, so it holds more finished pieces.",
	},
	"bulk_orders":
	{
		"name": "Bulk Orders",
		"category": "Ordering",
		"cost": 220,
		"tier": 2,
		"desc": "Suppliers will cut you much longer bolts of cloth per order.",
	},
}

## Textile suppliers, best fabrics gated behind reputation. Each lists the fabrics
## (Enums.Fabric values) it can supply for the custom maker.
const VENDORS := [
	{
		"name": "Harrow's Haberdashery",
		"tier": 0,
		"fabrics": [0, 1, 5, 6, 7],  # worsted, flannel, cotton, poplin, oxford
	},
	{
		"name": "Northern Mill",
		"tier": 1,
		"fabrics": [0, 1, 2, 4, 5, 6, 7],  # + tweed, linen
	},
	{
		"name": "Savile Silk & Co.",
		"tier": 2,
		"fabrics": [0, 1, 2, 3, 4, 5, 6, 7],  # + mohair blend (all)
		"pattern_dye": true,  # premium: choose the pattern's thread colour
	},
]

const ROLL_LENGTH_BASE := 24.0
const ROLL_LENGTH_BULK := 48.0

var _owned := {}


func has(id: String) -> bool:
	return _owned.get(id, false)


## All upgrade ids in catalogue order.
func all_ids() -> Array:
	return UPGRADES.keys()


func data(id: String) -> Dictionary:
	return UPGRADES.get(id, {})


## Reputation is high enough to buy/own this upgrade.
func tier_met(id: String) -> bool:
	var t: int = Reputation.tier() if Reputation != null else 0
	return t >= int(UPGRADES.get(id, {}).get("tier", 0))


## Buyable right now: not owned, reputation high enough, and affordable.
func can_buy(id: String) -> bool:
	if not UPGRADES.has(id) or has(id) or not tier_met(id):
		return false
	return GameState.can_afford(int(UPGRADES[id]["cost"]))


## Purchase an upgrade (spends money). Returns whether it went through.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	if not GameState.spend(int(UPGRADES[id]["cost"])):
		return false
	_owned[id] = true
	changed.emit()
	return true


# --- Effects ---------------------------------------------------------------


func max_roll_length() -> float:
	return ROLL_LENGTH_BULK if has("bulk_orders") else ROLL_LENGTH_BASE


## Cutting-table cadence multiplier (always-on base speed from the master shears).
func cutting_speed() -> float:
	return 1.3 if has("cut_master") else 1.0


func cutting_sprint() -> bool:
	return has("cut_sharp")


func sewing_speed() -> float:
	return 1.3 if has("sew_industrial") else 1.0


func sewing_sprint() -> bool:
	return has("sew_oiled")


## Extra clothing-rack hooks unlocked by the rack upgrade.
func extra_rack_slots() -> int:
	return 3 if has("rack_hooks") else 0


# --- Vendors ---------------------------------------------------------------


## Vendor entries the shop's current reputation has unlocked (always at least one).
func unlocked_vendors() -> Array:
	var t: int = Reputation.tier() if Reputation != null else 0
	var out: Array = []
	for v in VENDORS:
		if t >= int(v["tier"]):
			out.append(v)
	if out.is_empty():
		out.append(VENDORS[0])
	return out


# --- Save ------------------------------------------------------------------


func save_state() -> Dictionary:
	return _owned.duplicate()


func restore(d: Variant) -> void:
	_owned = (d as Dictionary).duplicate() if d is Dictionary else {}
	changed.emit()


func reset() -> void:
	_owned.clear()
	changed.emit()

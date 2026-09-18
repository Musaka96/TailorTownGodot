extends Node

## Autoloaded as "Upgrades". Reputation-gated shop progression bought from the phone:
## machine upgrades (faster/unlocked abilities) and premium textile vendors. Purchases
## persist in saves. Everything is data-driven (UPGRADES / VENDORS) so adding more is
## just another entry. Reputation tiers come from the Reputation autoload (0..4).
## Prices follow docs/ECONOMY.md: each upgrade costs a few "good days" of profit at the
## tier that unlocks it.

signal changed

## id -> upgrade. tier = required Reputation.tier(); category groups them in the phone.
## Optional "effects" are numbers the games read through mult() (multiplied together over
## everything owned) or bonus() (added up); on/off abilities are just has(id).
const UPGRADES := {
	"cut_weights":
	{
		"name": "Pattern Weights",
		"category": "Cutting Table",
		"cost": 200,
		"tier": 0,
		"desc": "Brass weights hold the cloth flat — it barely pulls at the shears.",
		"effects": {"cut_drift": 0.4},
	},
	"cut_chalk_wheel":
	{
		"name": "Chalk Wheel",
		"category": "Cutting Table",
		"cost": 350,
		"tier": 1,
		"desc": "Crisper chalk, with a mark before every curve and corner.",
	},
	"cut_sharp":
	{
		"name": "Sharp Scissors",
		"category": "Cutting Table",
		"cost": 450,
		"tier": 1,
		"desc": "Keener shears — hold Shift to cut fast (riskier) at the cutting table.",
	},
	"cut_master":
	{
		"name": "Master Shears",
		"category": "Cutting Table",
		"cost": 1400,
		"tier": 2,
		"desc": "Tailor-grade shears: faster cuts and a longer, quicker glide.",
		"effects": {"cut_glide_bonus": 0.5, "cut_glide_build": 2.0},
	},
	"cut_pinking":
	{
		"name": "Pinking Shears",
		"category": "Cutting Table",
		"cost": 900,
		"tier": 2,
		"desc": "A zig-zag edge can't fray, so a cut too wide of the chalk does no harm.",
	},
	"cut_fold":
	{
		"name": "Cut on the Fold",
		"category": "Cutting Table",
		"cost": 1100,
		"tier": 2,
		"desc": "Fold the cloth for shirts and jacket backs: cut half, then unfold it.",
	},
	"cut_rotary":
	{
		"name": "Rotary Cutter & Rule",
		"category": "Cutting Table",
		"cost": 3000,
		"tier": 3,
		"desc": "The rule snaps to the chalk: straight edges roll by themselves.",
	},
	"sew_dial":
	{
		"name": "Speed Dial",
		"category": "Sewing Machine",
		"cost": 200,
		"tier": 0,
		"desc": "The machine slows itself to a safe crawl through the amber marks.",
	},
	"sew_oiled":
	{
		"name": "Oiled Machine",
		"category": "Sewing Machine",
		"cost": 450,
		"tier": 1,
		"desc": "A smooth action: the motor answers the pedal quicker; Shift for top gear.",
		"effects": {"sew_spin": 2.0, "sew_coast": 1.5},
	},
	"sew_guide":
	{
		"name": "Magnetic Seam Guide",
		"category": "Sewing Machine",
		"cost": 400,
		"tier": 1,
		"desc": "A steel edge the cloth rides against — it eases the seam back on its line.",
		"effects": {"sew_drift": 0.5},
	},
	"sew_needle_down":
	{
		"name": "Needle-Down Stop",
		"category": "Sewing Machine",
		"cost": 450,
		"tier": 1,
		"desc": "Let go and it stops dead, needle down — no coasting into pins or corners.",
		"effects": {"sew_coast": 40.0},
	},
	"sew_industrial":
	{
		"name": "Industrial Motor",
		"category": "Sewing Machine",
		"cost": 1400,
		"tier": 2,
		"desc": "A stronger motor drives the needle quicker on every seam.",
		"effects": {"sew_spin": 1.5},
	},
	"sew_walking_foot":
	{
		"name": "Walking Foot",
		"category": "Sewing Machine",
		"cost": 1100,
		"tier": 2,
		"desc": "Feeds both layers evenly — slippery cloth stops wandering off the line.",
		"effects": {"sew_drift": 0.25},
	},
	"sew_knee":
	{
		"name": "Knee Lifter",
		"category": "Sewing Machine",
		"cost": 900,
		"tier": 2,
		"desc": "Lift the foot with your knee: the machine turns corners in a blink.",
		"effects": {"sew_pivot": 0.25},
	},
	"sew_clips":
	{
		"name": "Sewing Clips",
		"category": "Sewing Machine",
		"cost": 800,
		"tier": 2,
		"desc": "Clips instead of pins: sew straight over them at any speed.",
	},
	"sew_roller":
	{
		"name": "Roller Foot",
		"category": "Sewing Machine",
		"cost": 2200,
		"tier": 3,
		"desc": "A foot on rollers: curves barely drag the cloth off the line, even at speed.",
		"effects": {"sew_curve": 0.4},
	},
	"shop_lamp":
	{
		"name": "Workbench Lamp",
		"category": "Workshop",
		"cost": 400,
		"tier": 1,
		"desc": "Good light on the benches — the chalk line is easier to hit.",
		"effects": {"bench_band": 1.15},
	},
	"shop_coffee":
	{
		"name": "Coffee Machine",
		"category": "Workshop",
		"cost": 350,
		"tier": 1,
		"desc": "Two cups a day: each steadies your hands for the next 3 bench jobs.",
	},
	"shop_iron":
	{
		"name": "Pressing Iron",
		"category": "Workshop",
		"cost": 1000,
		"tier": 2,
		"desc": "Press as you sew: every piece pressed on the board gains a little quality.",
	},
	"apprentice":
	{
		"name": "Hire an Apprentice",
		"category": "Staff",
		"cost": 2800,
		"tier": 3,
		"desc":
		(
			"Percy works at his own bench: give him a part of an order and he fetches"
			+ " the cloth, cuts and sews it — and gets better with every job."
		),
	},
	"rack_hooks":
	{
		"name": "Extra Hooks",
		"category": "Clothing Rack",
		"cost": 300,
		"tier": 1,
		"desc": "More hooks on the rack, so it holds more finished pieces.",
	},
	"bulk_orders":
	{
		"name": "Bulk Orders",
		"category": "Ordering",
		"cost": 950,
		"tier": 2,
		"desc": "Suppliers will cut you much longer bolts of cloth per order.",
	},
	"courier":
	{
		"name": "Courier Account",
		"category": "Ordering",
		"cost": 1200,
		"tier": 2,
		"desc": "A bicycle courier brings your cloth within minutes, not hours.",
	},
}

## Textile suppliers, best fabrics gated behind reputation. Each lists the fabrics
## (Enums.Fabric values) it can supply for the custom maker.
const VENDORS := [
	{
		"name": "Harrow's Haberdashery",
		"tier": 0,
		"price_mult": 1.0,
		"fabrics": [0, 1, 5, 6, 7],  # worsted, flannel, cotton, poplin, oxford
	},
	{
		"name": "Northern Mill",
		"tier": 1,
		"price_mult": 1.1,  # a premium mill: +10% per metre
		"fabrics": [0, 1, 2, 4, 5, 6, 7],  # + tweed, linen
	},
	{
		"name": "Savile Silk & Co.",
		"tier": 2,
		"price_mult": 1.2,  # the finest house: +20% per metre
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


## Debug: grant or take away an upgrade for free (the F3 panel's Upgrades list).
func debug_set(id: String, on: bool) -> void:
	if not UPGRADES.has(id):
		return
	if on:
		_owned[id] = true
	else:
		_owned.erase(id)
	changed.emit()


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


## Every owned upgrade's `key` effect multiplied together (1.0 when none has it).
func mult(key: String) -> float:
	var v := 1.0
	for id: String in _owned:
		v *= float(UPGRADES.get(id, {}).get("effects", {}).get(key, 1.0))
	return v


## Every owned upgrade's `key` effect added up (0.0 when none has it).
func bonus(key: String) -> float:
	var v := 0.0
	for id: String in _owned:
		v += float(UPGRADES.get(id, {}).get("effects", {}).get(key, 0.0))
	return v


## In-game hours from ordering cloth to it arriving at the phone.
func delivery_hours() -> float:
	var c: GameConfig = Config.data if Config != null else null
	if has("courier"):
		return c.courier_hours if c != null else 0.25
	return c.delivery_hours if c != null else 2.0


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

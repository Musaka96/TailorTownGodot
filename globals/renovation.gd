extends Node

## Bringing grandpa's shop back, room by room — autoloaded as "Renovation".
##
## Two kinds of work (docs/STORY_AND_RENOVATION.md §3):
##  - CLEANUP is done by hand, in the shop, for free: every project has a few spots to
##    clear (boards to pull off, dust sheets, rubble) and is finished when they all are.
##  - BUILD work is ordered from the phone: it costs money, may need a reputation tier,
##    and the builders take some nights over it. It finishes at dawn (EventBus.day_began).
##
## A locked room goes SHUT -> ENTERED (boards off the door) -> CLEARED (mess gone) -> DONE
## (rebuilt; its stations move in). This autoload only holds the data and the state; the
## scene side (blockers, mess, stations) is RenovationZone, which listens to `changed`.
## Modelled on Upgrades: same gating, same save_state/restore/reset habits.

signal changed
signal project_finished(id: String)

enum Kind { CLEANUP, BUILD }
enum RoomState { SHUT, ENTERED, CLEARED, DONE }

## Rooms in story order. "front" is open from the first morning.
const ROOMS := {
	"front": {"name": "Front room", "tier": 0},
	"workroom": {"name": "Workroom", "tier": 1},
	"cloth": {"name": "Cloth store", "tier": 2},
	"nook": {"name": "Nook", "tier": 3},
	"nextdoor": {"name": "Next door", "tier": 4},
}

## PROVISIONAL costs and nights: they put the projects in the right order of size, but have
## not been balanced in "days of profit" against docs/ECONOMY.md yet.
const PROJECTS := {
	"front_sheets":
	{
		"name": "Pull off the dust sheets",
		"room": "front",
		"kind": Kind.CLEANUP,
		"spots": 3,
		"desc": "Grandpa covered everything before he locked up. See what's underneath.",
		"appeal": 1,
	},
	"front_sweep":
	{
		"name": "Sweep the front room",
		"room": "front",
		"kind": Kind.CLEANUP,
		"spots": 3,
		"needs": ["front_sheets"],
		"desc": "Years of dust and a few dead leaves. A broom does wonders.",
		"appeal": 1,
	},
	"front_window":
	{
		"name": "Reglaze the shop window",
		"room": "front",
		"kind": Kind.BUILD,
		"cost": 150,
		"nights": 1,
		"needs": ["front_sweep"],
		"desc": "Boards off, new glass in. Let the street see you're open.",
		"appeal": 2,
	},
	"front_lights":
	{
		"name": "Fix the wiring and lamps",
		"room": "front",
		"kind": Kind.BUILD,
		"cost": 200,
		"nights": 1,
		"needs": ["front_sweep"],
		"desc": "Half the lamps are dead. A proper light makes a proper shop.",
		"appeal": 2,
	},
	"workroom_boards":
	{
		"name": "Pull the boards off the workroom door",
		"room": "workroom",
		"kind": Kind.CLEANUP,
		"spots": 1,
		"needs": ["front_sweep"],  # the front room is tidied before any other room is begun
		"enters": "workroom",
		"desc": "Nailed shut after the roof went. Time to look inside.",
		"appeal": 0,
	},
	"workroom_clear":
	{
		"name": "Clear the rubble in the workroom",
		"room": "workroom",
		"kind": Kind.CLEANUP,
		"spots": 4,
		"needs": ["workroom_boards"],
		"desc": "Plaster, slates and a bucket that lost the fight. Carry it out.",
		"appeal": 1,
	},
	"workroom_build":
	{
		"name": "Patch the roof, relay the floor",
		"room": "workroom",
		"kind": Kind.BUILD,
		"cost": 900,
		"nights": 2,
		"needs": ["workroom_clear"],
		"opens": "workroom",
		"desc": "A dry, sound room at last. The benches move out of the front room.",
		"appeal": 4,
	},
	"cloth_boards":
	{
		"name": "Pull the boards off the cloth store",
		"room": "cloth",
		"kind": Kind.CLEANUP,
		"spots": 1,
		"needs": ["workroom_build"],
		"enters": "cloth",
		"desc": "It smells of damp in there. Better now than later.",
		"appeal": 0,
	},
	"cloth_clear":
	{
		"name": "Scrub out the cloth store",
		"room": "cloth",
		"kind": Kind.CLEANUP,
		"spots": 3,
		"needs": ["cloth_boards"],
		"desc": "Mouldy crates out, walls scrubbed down.",
		"appeal": 1,
	},
	"cloth_build":
	{
		"name": "Damp-proof and shelve the cloth store",
		"room": "cloth",
		"kind": Kind.BUILD,
		"cost": 1400,
		"nights": 2,
		"needs": ["cloth_clear"],
		"opens": "cloth",
		"desc": "Two long walls of shelving and the delivery door working again.",
		"appeal": 4,
	},
	"nook_boards":
	{
		"name": "Clear the way into the nook",
		"room": "nook",
		"kind": Kind.CLEANUP,
		"spots": 1,
		"needs": ["front_sweep"],
		"enters": "nook",
		"desc": "Somebody stacked the doorway full of crates.",
		"appeal": 0,
	},
	"nook_clear":
	{
		"name": "Empty the nook",
		"room": "nook",
		"kind": Kind.CLEANUP,
		"spots": 3,
		"needs": ["nook_boards"],
		"desc": "Crates, a broken chair, and one very old newspaper.",
		"appeal": 1,
	},
	"nook_build":
	{
		"name": "Fit out the nook",
		"room": "nook",
		"kind": Kind.BUILD,
		"cost": 1800,
		"nights": 2,
		"needs": ["nook_clear"],
		"opens": "nook",
		"desc": "Sockets, a counter and a bit of comfort: room for coffee and pressing.",
		"appeal": 4,
	},
	"next_buy":
	{
		"name": "Buy the unit next door",
		"room": "nextdoor",
		"kind": Kind.BUILD,
		"cost": 6000,
		"nights": 1,
		"needs": ["nook_build"],
		"desc": "It has stood empty as long as grandpa's. The agent will take an offer.",
		"appeal": 2,
	},
	"next_knock":
	{
		"name": "Knock through the party wall",
		"room": "nextdoor",
		"kind": Kind.BUILD,
		"cost": 1500,
		"nights": 2,
		"needs": ["next_buy"],
		"enters": "nextdoor",
		"desc": "One shop out of two. Mind the dust.",
		"appeal": 2,
	},
	"next_clear":
	{
		"name": "Clear out next door",
		"room": "nextdoor",
		"kind": Kind.CLEANUP,
		"spots": 4,
		"needs": ["next_knock"],
		"desc": "Whatever the last tenant sold, they left the boxes.",
		"appeal": 1,
	},
	"next_build":
	{
		"name": "Fit out next door",
		"room": "nextdoor",
		"kind": Kind.BUILD,
		"cost": 3000,
		"nights": 3,
		"needs": ["next_clear"],
		"opens": "nextdoor",
		"desc": "A second workroom and a window on the street for your best work.",
		"appeal": 6,
	},
}

var _done := {}  # project id -> true
var _building := {}  # project id -> nights left
var _spots := {}  # cleanup project id -> spots cleared so far


func _ready() -> void:
	EventBus.day_began.connect(_on_day_began)


# --- Queries -----------------------------------------------------------------


func all_ids() -> Array:
	return PROJECTS.keys()


func data(id: String) -> Dictionary:
	return PROJECTS.get(id, {})


func is_done(id: String) -> bool:
	return _done.has(id)


## Nights until the builders finish `id`; 0 when it isn't under way.
func nights_left(id: String) -> int:
	return int(_building.get(id, 0))


func spots_cleared(id: String) -> int:
	return int(_spots.get(id, 0))


func _kind(id: String) -> int:
	return int(data(id).get("kind", Kind.BUILD))


## The reputation tier a project asks for: its own, or else its room's.
func tier_needed(id: String) -> int:
	var d := data(id)
	if d.has("tier"):
		return int(d["tier"])
	var room: Dictionary = ROOMS.get(str(d.get("room", "")), {})
	return int(room.get("tier", 0))


func tier_met(id: String) -> bool:
	return Reputation == null or Reputation.tier() >= tier_needed(id)


## Every project this one waits for is finished.
func needs_met(id: String) -> bool:
	for other: String in data(id).get("needs", []):
		if not is_done(other):
			return false
	return true


## Open to be worked on now: known, not done or under way, unlocked by tier and by order.
func available(id: String) -> bool:
	if not PROJECTS.has(id) or is_done(id) or _building.has(id):
		return false
	return tier_met(id) and needs_met(id)


## BUILD work the player can order from the phone right now (available and affordable).
func can_order(id: String) -> bool:
	if _kind(id) != Kind.BUILD or not available(id):
		return false
	return GameState.can_afford(int(data(id).get("cost", 0)))


func room_state(room: String) -> int:
	if room == "front":
		return RoomState.DONE
	var entered := false
	var cleared := false
	for id: String in PROJECTS:
		var d: Dictionary = PROJECTS[id]
		if str(d.get("room", "")) != room or not is_done(id):
			continue
		if str(d.get("opens", "")) == room:
			return RoomState.DONE
		if str(d.get("enters", "")) == room:
			entered = true
		elif _kind(id) == Kind.CLEANUP:
			cleared = true
	if entered and cleared:
		return RoomState.CLEARED
	return RoomState.ENTERED if entered else RoomState.SHUT


## How far the shop has come, 0..1 — a shabby shop draws humbler customers, nothing worse.
func appeal() -> float:
	var have := 0
	var total := 0
	for id: String in PROJECTS:
		var pts := int(PROJECTS[id].get("appeal", 0))
		total += pts
		if is_done(id):
			have += pts
	return float(have) / float(total) if total > 0 else 1.0


# --- Doing the work ------------------------------------------------------------


## One spot of a cleanup project cleared by hand; finishes the project on the last one.
func clear_spot(id: String) -> bool:
	if _kind(id) != Kind.CLEANUP or not available(id):
		return false
	var cleared := spots_cleared(id) + 1
	_spots[id] = cleared
	if cleared >= int(data(id).get("spots", 1)):
		_finish(id)
	else:
		changed.emit()
	return true


## Order building work from the phone: pay now, the builders finish after `nights`.
func order(id: String) -> bool:
	if not can_order(id):
		return false
	if not GameState.spend(int(data(id).get("cost", 0))):
		return false
	_building[id] = maxi(int(data(id).get("nights", 1)), 1)
	changed.emit()
	return true


func _on_day_began(_day: int) -> void:
	var finished: Array[String] = []
	for id: String in _building.keys():
		_building[id] = int(_building[id]) - 1
		if int(_building[id]) <= 0:
			finished.append(id)
	for id in finished:
		_finish(id)


func _finish(id: String) -> void:
	_building.erase(id)
	_spots.erase(id)
	_done[id] = true
	changed.emit()
	project_finished.emit(id)


# --- Debug (the F3 panel) ------------------------------------------------------


## The next project in story order that isn't finished, ignoring money and reputation.
func _debug_next() -> String:
	for id: String in PROJECTS:
		if not is_done(id):
			return id
	return ""


## Finish the next unfinished project for free. Returns its id ("" when all are done).
func debug_finish_next() -> String:
	var id := _debug_next()
	if id != "":
		_finish(id)
	return id


func debug_finish_all() -> void:
	for id: String in PROJECTS:
		if not is_done(id):
			_building.erase(id)
			_spots.erase(id)
			_done[id] = true
			project_finished.emit(id)
	changed.emit()


# --- Save ----------------------------------------------------------------------


func save_state() -> Dictionary:
	return {
		"done": _done.keys(),
		"building": _building.duplicate(),
		"spots": _spots.duplicate(),
	}


func restore(d: Variant) -> void:
	_clear()
	if d is Dictionary:
		for id: Variant in (d as Dictionary).get("done", []):
			if PROJECTS.has(str(id)):
				_done[str(id)] = true
		var building: Dictionary = (d as Dictionary).get("building", {})
		for id: Variant in building:
			if PROJECTS.has(str(id)) and not _done.has(str(id)):
				_building[str(id)] = int(building[id])
		var spots: Dictionary = (d as Dictionary).get("spots", {})
		for id: Variant in spots:
			if PROJECTS.has(str(id)) and not _done.has(str(id)):
				_spots[str(id)] = int(spots[id])
	changed.emit()


func reset() -> void:
	_clear()
	changed.emit()


func _clear() -> void:
	_done.clear()
	_building.clear()
	_spots.clear()

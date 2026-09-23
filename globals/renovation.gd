extends Node

## Bringing grandpa's shop back, room by room — autoloaded as "Renovation".
##
## Two kinds of work (docs/STORY_AND_RENOVATION.md §3):
##  - CLEANUP is done by hand, in the shop, for free: every project has a few spots to
##    clear (boards to pull off, dust sheets, rubble) and is finished when they all are.
##  - BUILD work is ordered from the phone and costs money, nothing else. The builders do
##    it on the spot: RenovationDirector plays the job out (camera, dust, hammering, about
##    six seconds) and calls finish_build() under the dust cloud. Where no director is
##    listening (Mr. Hemming's shop, a headless test), the job finishes at once.
##
## A back room stays boarded up (SHUT) until the builders have done it (DONE): its boards,
## its rubble and the rebuild are one builders' job, and the player first walks in when it is
## finished (owner, 2026-09-22). ENTERED and CLEARED are left in RoomState for the scene
## side's lookup tables; no project reaches them any more. This autoload only holds the
## data and the state; the scene side (blockers, mess, stations) is RenovationDirector,
## which listens to `changed`.
## Modelled on Upgrades: same save_state/restore/reset habits. Reputation gates nothing
## here: the shop's income is what paces it (a shabby shop draws humbler customers, and the
## reputation tier still caps what they spend: Pricing.shop_tier_ceiling).

signal changed
signal project_finished(id: String)
## Building work was paid for and the builders are at it now. Whoever handles this owes
## finish_build(id) when the show is over.
signal build_started(id: String)

enum Kind { CLEANUP, BUILD }
enum RoomState { SHUT, ENTERED, CLEARED, DONE }

## Rooms in story order. "front" is open from the first morning.
const ROOMS := {
	"front": {"name": "Front room", "ready": "The front room is ready"},
	"workroom": {"name": "Workroom", "ready": "The workroom is ready: the benches move in"},
	"cloth": {"name": "Cloth store", "ready": "The cloth store is ready"},
	"nook": {"name": "Nook", "ready": "The nook is ready"},
	"nextdoor": {"name": "Workshop", "ready": "The workshop is ready: room for an apprentice"},
}

## Costs in "days of profit" (docs/ECONOMY.md §5): the front room's jobs are about a day
## each for a brand-new shop, each back room a few days at the tier it tends to come at, and
## grandpa's workshop the long saving-up at the end (docs/STORY_AND_RENOVATION.md §6.13).
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
		"desc": "Years of dust and a few dead leaves. A broom does wonders.",
		"appeal": 1,
	},
	"front_boards":
	{
		"name": "Pull the boards off the windows",
		"room": "front",
		"kind": Kind.CLEANUP,
		"spots": 3,
		"desc": "Somebody boarded the shop up years ago. Let the daylight back in.",
		"appeal": 2,
	},
	"yard_rubbish":
	{
		"name": "Clear the rubbish off the forecourt",
		"room": "front",
		"kind": Kind.CLEANUP,
		"spots": 3,
		"desc": "Crates and wet newspaper against the door. Nobody walks into a shop past that.",
		"appeal": 1,
	},
	"yard_weeds":
	{
		"name": "Weed the side garden",
		"room": "front",
		"kind": Kind.CLEANUP,
		"spots": 4,
		"desc": "Docks and thistles up to the knee. The cherry is still under there somewhere.",
		"appeal": 1,
	},
	"front_weeds":
	{
		"name": "Weed the shop front",
		"room": "front",
		"kind": Kind.CLEANUP,
		"spots": 5,
		"desc": "They have come up along the plinth and round the step. Out by the roots.",
		"appeal": 1,
	},
	"front_window":
	{
		"name": "Reglaze the shop window",
		"room": "front",
		"kind": Kind.BUILD,
		"cost": 180,
		"needs": ["front_boards"],
		"desc": "The old panes are cracked and grey with grime. New glass lets the street see in.",
		"appeal": 2,
	},
	"front_lights":
	{
		"name": "Fix the wiring and lamps",
		"room": "front",
		"kind": Kind.BUILD,
		"cost": 220,
		"needs": ["front_sweep"],
		"desc": "Half the lamps are dead. A proper light makes a proper shop.",
		"appeal": 2,
	},
	"front_paper":
	{
		"name": "Paper the shop",
		"room": "front",
		"kind": Kind.BUILD,
		"cost": 380,
		"needs": ["front_lights"],
		"desc": "What is left of the old paper comes off, and the fern goes back up.",
		"appeal": 3,
	},
	"facade_paint":
	{
		"name": "Repaint the front and the sign",
		"room": "front",
		"kind": Kind.BUILD,
		"cost": 560,
		"needs": ["front_window"],
		"desc":
		"Fresh paint from corner to corner, and the sign gone over while they are up there.",
		"appeal": 4,
	},
	"workroom_build":
	{
		"name": "Patch the roof, relay the floor",
		"room": "workroom",
		"kind": Kind.BUILD,
		"cost": 750,
		"needs": ["front_sweep"],  # the front room is tidied before any other room is begun
		"opens": "workroom",
		"desc": "Boards off, rubble out, roof patched, floor relaid. The benches move in there.",
		"appeal": 4,
	},
	"cloth_build":
	{
		"name": "Damp-proof and shelve the cloth store",
		"room": "cloth",
		"kind": Kind.BUILD,
		"cost": 1200,
		"needs": ["workroom_build"],
		"opens": "cloth",
		"desc": "Mouldy crates out, two long walls of shelving in, the delivery door working.",
		"appeal": 4,
	},
	"nook_build":
	{
		"name": "Fit out the nook",
		"room": "nook",
		"kind": Kind.BUILD,
		"cost": 1500,
		"needs": ["front_sweep"],
		"opens": "nook",
		"desc": "Crates out, then sockets and a counter. Room for coffee and pressing.",
		"appeal": 4,
	},
	"next_buy":
	{
		"name": "Make the workshop roof sound",
		"room": "nextdoor",
		"kind": Kind.BUILD,
		"cost": 2400,
		"needs": ["nook_build"],
		"desc": "Grandpa's old workshop, down the side. The felt is off and the rain gets in.",
		"appeal": 2,
	},
	"next_knock":
	{
		"name": "Unbrick the door to the workshop",
		"room": "nextdoor",
		"kind": Kind.BUILD,
		"cost": 900,
		"needs": ["next_buy"],
		"desc": "Grandpa bricked it up the winter the damp came in. Mind the dust.",
		"appeal": 2,
	},
	"next_build":
	{
		"name": "Fit out the workshop",
		"room": "nextdoor",
		"kind": Kind.BUILD,
		"cost": 2600,
		"needs": ["next_knock"],
		"opens": "nextdoor",
		"desc": "Forty years of offcuts out, then a stove and a proper bench for an apprentice.",
		"appeal": 6,
	},
}

var _done := {}  # project id -> true
var _building := {}  # project id -> true while the builders are at it (a few seconds)
var _spots := {}  # cleanup project id -> spots cleared so far

# --- Queries -----------------------------------------------------------------


func all_ids() -> Array:
	return PROJECTS.keys()


func data(id: String) -> Dictionary:
	return PROJECTS.get(id, {})


func is_done(id: String) -> bool:
	return _done.has(id)


## The builders are at `id` right now (the few seconds of the show).
func is_building(id: String) -> bool:
	return _building.has(id)


func spots_cleared(id: String) -> int:
	return int(_spots.get(id, 0))


func _kind(id: String) -> int:
	return int(data(id).get("kind", Kind.BUILD))


## Every project this one waits for is finished.
func needs_met(id: String) -> bool:
	for other: String in data(id).get("needs", []):
		if not is_done(other):
			return false
	return true


## Open to be worked on now: known, not done or under way, and everything before it done.
func available(id: String) -> bool:
	if not PROJECTS.has(id) or is_done(id) or _building.has(id):
		return false
	return needs_met(id)


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
	var share := float(have) / float(total) if total > 0 else 1.0
	# a few upgrades are things a customer sees (the fitting mirror); they count too
	var bought := Upgrades.bonus("appeal") if Upgrades != null else 0.0
	return clampf(share + bought, 0.0, 1.0)


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


## Order building work from the phone: pay now, and the builders get straight to it. With
## nobody to play the job out (no director listening), it is simply done.
func order(id: String) -> bool:
	if not can_order(id):
		return false
	if not GameState.spend(int(data(id).get("cost", 0))):
		return false
	_building[id] = true
	changed.emit()
	if build_started.get_connections().is_empty():
		_finish(id)
	else:
		build_started.emit(id)
	return true


## The builders are done with `id` (the director calls this under its dust cloud).
func finish_build(id: String) -> void:
	if _building.has(id):
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
		"building": _building.keys(),
		"spots": _spots.duplicate(),
	}


func restore(d: Variant) -> void:
	_clear()
	if d is Dictionary:
		for id: Variant in (d as Dictionary).get("done", []):
			if PROJECTS.has(str(id)):
				_done[str(id)] = true
		# Building work saved mid-show (or an older save's builders still out overnight):
		# it was paid for, so it is simply done.
		for id: Variant in (d as Dictionary).get("building", []):
			if PROJECTS.has(str(id)):
				_done[str(id)] = true
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

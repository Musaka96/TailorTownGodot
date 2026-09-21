extends Node

## What to do next, once Mr. Hemming has stopped talking — autoloaded as "Guide".
##
## One goal at a time on the kraft goal tag (GoalTag), from the first morning in grandpa's
## shop to the first city event. No log and no journal: a goal, one to three tick boxes,
## and a moment after the last box is ticked the next goal takes its place.
##
## The chain is data (STEPS, in the manner of Renovation.PROJECTS). Every check names a
## condition key, and _met() answers it from state that is already saved (Renovation, News,
## Reputation, the order book) plus a few flags of its own for things that leave no trace
## ("the sign was flipped once"). So a loaded save shows the right ticks without replaying
## anything, and a step the player has already done is passed over without a word.
##
## Nothing counts at Mr. Hemming's: events are ignored and the tag stays away until the
## player is at grandpa's and the tutorial is over.

const GALA := "event_autumn_gala"
const CAPTION := "Next job"
const EDGE := 20.0  # margin to the screen edge, as the tutorial's tag keeps
const TOP := 96.0  # under the money readout
const POLL := 1.0  # seconds between safety-net looks at the state

## `checks` are [text, condition key]; {n} and {of} in a text are filled from _count().
const STEPS: Array[Dictionary] = [
	{
		"id": "uncover",
		"goal": "Pull off the dust sheets",
		"checks": [["Uncover all three ({n}/{of})", "sheets"]],
	},
	{
		"id": "first_order",
		"goal": "Take your first order",
		"checks":
		[
			["Flip the door sign to open", "opened"],
			["Take a customer's order", "order"],
		],
	},
	{
		"id": "first_suit",
		"goal": "Make the first suit",
		"checks":
		[
			["Hang every sewn part on one rack", "ready"],
			["Hand the suit over", "delivered"],
		],
	},
	{
		"id": "tidy",
		"goal": "Tidy the front room",
		"checks":
		[
			["Sweep the floor", "swept"],
			["Pull the boards off the windows", "boards"],
		],
	},
	{
		"id": "builders",
		"goal": "Get the builders in",
		"checks": [["Ring the builders from the phone", "builders"]],
	},
	{
		"id": "fashion",
		"goal": "Follow the fashion column",
		"checks": [["Hand over a suit in the paper's trend", "fashion"]],
	},
	{
		"id": "name",
		"goal": "Make a name on the Row",
		"checks":
		[
			["Earn {of} reputation ({n}/{of})", "rep"],
			["Hand over {of} suits ({n}/{of})", "suits"],
			["Read the next morning's paper", "season"],
		],
	},
	{
		"id": "gala",
		"goal": "Dress the Autumn Gala",
		"checks":
		[
			["Take an order for the gala", "gala_order"],
			["Hand it over by the gala day", "gala_done"],
		],
	},
]

## Seconds a finished goal stays up, all ticked, before the next one (tests set it to 0).
var next_delay := 1.5

var _step := 0
var _finished := false
var _flags := {}  # things that happened once and leave no other trace
var _suits := 0  # suits handed over at grandpa's
var _shown := -1  # the step on the tag (-1 = none yet)
var _shown_lines := PackedStringArray()
var _advancing := false  # the finished goal is lingering before the next
var _wait := 0.0
var _poll := 0.0
var _layer: CanvasLayer
var _root: Control
var _tag: GoalTag


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.order_created.connect(_on_order_created)
	EventBus.order_ready.connect(_on_order_ready)
	EventBus.order_pieces_ready.connect(_on_order_touched)
	EventBus.order_fulfilled.connect(_on_order_fulfilled)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.day_began.connect(_on_day_began)
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.session_ended.connect(_on_session_ended)
	Renovation.changed.connect(refresh)
	News.season_opened.connect(_on_day_began)


func _process(delta: float) -> void:
	if _finished:
		return
	if _advancing:
		_wait -= delta
		if _wait <= 0.0:
			_next()
	_poll += delta
	if _poll >= POLL:
		_poll = 0.0
		refresh()
	_place()


# --- Queries -----------------------------------------------------------------


## The id of the goal being worked towards ("" once the chain is finished).
func current_id() -> String:
	if _finished or _step >= STEPS.size():
		return ""
	return str(STEPS[_step]["id"])


func is_finished() -> bool:
	return _finished


## Look at the state again: tick what is done, move on when it all is. Steps that are
## already done when they are reached are passed over without being shown.
func refresh() -> void:
	if _finished or _advancing or not _counting():
		return
	_catch_up()
	while _step < STEPS.size() and _step_met(_step):
		if _step == _shown:
			_complete()
			return
		_step += 1
	if _step >= STEPS.size() or _gala_missed():
		_finish()
		return
	_show()


# --- The chain ---------------------------------------------------------------


## The season has opened and the paper is full of the gala: whatever smaller job was
## still on the tag (the fashion column, say) gives way to it.
func _catch_up() -> void:
	if not News.season_open() or current_id() == "gala":
		return
	for i in STEPS.size():
		if str(STEPS[i]["id"]) == "gala" and _step < i:
			_step = i
			_shown = -1


## Nothing done at Mr. Hemming's counts, and nothing while he is still teaching.
func _counting() -> bool:
	if Tutorial != null and Tutorial.is_active():
		return false
	return Locations.current == Locations.GRANDPA


func _step_met(index: int) -> bool:
	for check: Array in STEPS[index]["checks"]:
		if not _met(str(check[1])):
			return false
	return true


## Whether a check's condition holds, read from saved state wherever there is any.
func _met(key: String) -> bool:
	var ok := false
	match key:
		"sheets":
			ok = Renovation.is_done("front_sheets")
		"opened":
			ok = _flags.has("opened") or _met("order")
		"order":
			ok = _flags.has("order") or not Orders.active.is_empty() or _suits_out() > 0
		"ready":
			ok = _flags.has("ready") or _any_order_ready() or _suits_out() > 0
		"delivered":
			ok = _suits_out() >= 1
		"swept":
			ok = Renovation.is_done("front_sweep")
		"boards":
			ok = Renovation.is_done("front_boards")
		"builders":
			ok = _builders_called()
		"fashion":
			ok = _flags.has("fashion")
		"rep", "suits":
			var c := _count(key)
			ok = c.x >= c.y
		"season":
			ok = News.season_open()
		"gala_order":
			ok = _flags.has("gala_order") or _any_event_order()
		"gala_done":
			ok = _flags.has("gala_done")
	return ok


## (so far, needed) for the checks that show a count.
func _count(key: String) -> Vector2i:
	var cfg := Config.data
	match key:
		"sheets":
			var spots := int(Renovation.data("front_sheets").get("spots", 3))
			var n := spots if Renovation.is_done("front_sheets") else 0
			return Vector2i(maxi(n, Renovation.spots_cleared("front_sheets")), spots)
		"rep":
			var need_rep: int = cfg.season_min_reputation if cfg != null else 40
			return Vector2i(Reputation.points, need_rep)
		"suits":
			var need_suits: int = cfg.season_min_suits if cfg != null else 3
			return Vector2i(_suits_out(), need_suits)
	return Vector2i.ZERO


## Suits handed over. The paper keeps the same tally (it opens the season on it), and a
## save from before the Guide has only that one, so take whichever is further on.
func _suits_out() -> int:
	return maxi(_suits, int(News.season_snapshot().get("suits", 0)))


func _any_order_ready() -> bool:
	for order: SuitOrder in Orders.active:
		if order.state == SuitOrder.State.READY:
			return true
	return false


func _any_event_order() -> bool:
	for order: SuitOrder in Orders.active:
		if order.event_id == GALA:
			return true
	return false


## Any building work ordered from the phone, under way or long since finished.
func _builders_called() -> bool:
	for id: String in Renovation.PROJECTS:
		if int(Renovation.data(id).get("kind", -1)) != Renovation.Kind.BUILD:
			continue
		if Renovation.is_done(id) or Renovation.is_building(id):
			return true
	return false


## The gala came and went without the player: there is no later step to wait for.
func _gala_missed() -> bool:
	if current_id() != "gala":
		return false
	var held := News.event_day(GALA)
	return held > 0 and Shift.day > held


func _complete() -> void:
	_tick()
	if next_delay <= 0.0:
		_next()
		return
	_advancing = true
	_wait = next_delay


func _next() -> void:
	_advancing = false
	_step += 1
	_shown = -1
	refresh()


func _finish() -> void:
	_finished = true
	_advancing = false
	_shown = -1
	if _root != null:
		_root.visible = false


# --- The tag -----------------------------------------------------------------


func _lines() -> PackedStringArray:
	var out := PackedStringArray()
	for check: Array in STEPS[_step]["checks"]:
		var c := _count(str(check[1]))
		out.append(str(check[0]).format({"n": mini(c.x, c.y), "of": c.y}))
	return out


## Put the current step on the tag (again, if one of its counts has moved) and tick it.
func _show() -> void:
	_build()
	var lines := _lines()
	if _shown != _step or lines != _shown_lines:
		_shown = _step
		_shown_lines = lines
		_tag.set_goal(CAPTION, str(STEPS[_step]["goal"]), lines)
	_tick()


func _tick() -> void:
	if _tag == null or _shown < 0:
		return
	var checks: Array = STEPS[_shown]["checks"]
	for i in checks.size():
		_tag.set_done(i, _met(str((checks[i] as Array)[1])))


## Out of the way while anything else has the screen, and anywhere but grandpa's.
func _wanted() -> bool:
	if _shown < 0 or not _counting():
		return false
	if UI == null or not UI.visible or UI.busy():
		return false
	if UI.day_transition != null and UI.day_transition.visible:
		return false
	return current_id() != "gala" or News.season_open()


func _place() -> void:
	if _root == null:
		return
	_root.visible = _wanted()
	if not _root.visible:
		return
	var vp := _root.get_viewport_rect().size
	_tag.move_to(Vector2(vp.x - _tag.size.x - EDGE, TOP))


func _build() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 1  # with the HUD: under every menu's dimmer and the tutorial (128)
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = Style.font_body()
	theme.default_font_size = Style.T_BODY
	_root.theme = theme
	_root.visible = false
	_layer.add_child(_root)
	_tag = GoalTag.new()
	_root.add_child(_tag)


# --- Events ------------------------------------------------------------------


func _on_order_created(order: Resource) -> void:
	if not _counting():
		return
	_flags["order"] = true
	var suit := order as SuitOrder
	if suit != null and suit.event_id == GALA:
		_flags["gala_order"] = true
	refresh()


func _on_order_ready(_order: Resource) -> void:
	if not _counting():
		return
	_flags["ready"] = true
	refresh()


func _on_order_touched(_order: Resource) -> void:
	refresh()


func _on_order_fulfilled(order: Resource, _payout: int) -> void:
	if not _counting():
		return
	_suits += 1
	var suit := order as SuitOrder
	if suit != null:
		if News.fashion_matches(suit.design):
			_flags["fashion"] = true
		if suit.event_id == GALA and Shift.day <= News.event_day(GALA):
			_flags["gala_done"] = true
	refresh()


func _on_shift_started(_hour: float) -> void:
	if _counting():
		_flags["opened"] = true
	refresh()


func _on_reputation_changed(_points: int, _tier: int) -> void:
	refresh()


func _on_day_began(_day: int) -> void:
	refresh()


func _on_session_ended() -> void:
	if _root != null:
		_root.visible = false


# --- Debug (the F3 panel) ------------------------------------------------------


## Drop the current goal and take up the next, whatever state the shop is in.
func debug_skip() -> String:
	if _finished:
		return ""
	_next()
	return current_id()


func debug_restart() -> void:
	restore({})


# --- Save ----------------------------------------------------------------------


func save_state() -> Dictionary:
	return {
		"step": current_id(),
		"flags": _flags.duplicate(),
		"suits": _suits,
		"finished": _finished,
	}


## Also the reset: restore({}) starts the chain again from the first goal.
func restore(d: Variant) -> void:
	var saved: Dictionary = d if d is Dictionary else {}
	_flags = {}
	var flags: Variant = saved.get("flags", {})
	if flags is Dictionary:
		for key: Variant in flags as Dictionary:
			_flags[str(key)] = true
	_suits = int(saved.get("suits", 0))
	_finished = bool(saved.get("finished", false))
	_step = 0
	var id := str(saved.get("step", ""))
	for i in STEPS.size():
		if str(STEPS[i]["id"]) == id:
			_step = i
	_shown = -1
	_shown_lines = PackedStringArray()
	_advancing = false
	if _root != null:
		_root.visible = false
	refresh()

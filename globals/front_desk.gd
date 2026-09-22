extends Node

## Autoloaded as "FrontDesk". The customer director: decides WHEN walk-in customers come
## so the shop's workload stays in the cozy zone (see docs/CUSTOMERS.md).
##
## - Estimates how busy you are (load): the work left on open orders against the shift
##   time you have.
## - Plans each day at opening: how many walk-ins, spread over the shift (morning bump,
##   lunch lull, calm close), by stage (opening week → growing → established), plus
##   newspaper event rushes, booked appointments and favours from the rival tailor.
## - Holds arrivals while you're swamped, mid-fitting, just after a handover, or while the
##   "Fully booked" sign is up; guarantees a customer if you're broke with nothing to do.
## - Picks due days you can realistically meet.
## - Handles saying no: appointments ("come back on day X"), referrals to the rival
##   tailor, an honest "I can't make that yet", or a plain no.
## The CustomerManager asks next_arrival() on its arrival tick (every few seconds).

signal changed

const RIVAL_NAME := "Pinch & Pleat"
## Real minutes to cut + sew one part with no upgrades (tuned from the minigame lengths).
const PART_MINUTES := 1.4
## Shift fraction to wait after a suit is handed over before the next walk-in.
const BREATHER := 0.06
## Walk-in windows across the shift (fractions): morning, midday, afternoon.
const WINDOWS := [Vector2(0.05, 0.3), Vector2(0.4, 0.55), Vector2(0.62, 0.86)]
## When the shop opens with an empty order book there is nothing to do but wait, so the
## first walk-in is pulled forward into this window instead of anywhere in the morning one.
const OPENING_BELL := Vector2(0.01, 0.05)
## With nothing left to make, the shop may stand idle this long (shift fraction, about
## half a minute) before the next customer is sent in early; if the day's plan is used up,
## one extra comes, once a day, as long as it isn't nearly closing time.
const IDLE_WAIT := 0.08
const LAST_CALL := 0.8
## Opening week: a second walk-in while the bench has room for it.
const OPENING_ROOM := 0.5
## Load above which nobody new walks in (appointments still come).
const SWAMPED := 1.0
## Load below which a city event sends one more customer than usual.
const EVENT_ROOM := 0.5
## Wallet below which, with no open orders, a customer is guaranteed soon.
const BROKE := 150
## Chance a walk-in is a rush / picky client, by stage (opening, growing, established).
const RUSH_CHANCE := [0.0, 0.15, 0.2]
const PICKY_CHANCE := [0.0, 0.1, 0.15]
const RUSH_BONUS := 0.3
const MAX_APPOINTMENTS_PER_DAY := 2
const HONEST_REP := 2

## The "Fully booked" sign: when up, no walk-ins (appointments and collectors still come).
var booked := false:
	set(v):
		booked = v
		changed.emit()
## Referrals sent to the rival; each one can come back as a favour on a quiet day.
var rival_goodwill := 0
## Booked fittings: { name, day, at, occasion, style, budget, regular, rush, picky }.
var appointments: Array[Dictionary] = []

var _plan: Array[float] = []  # today's walk-in times (shift fraction), ascending
var _plan_day := -1
var _last_handover := -1.0
var _last_arrival := -1.0  # shift fraction the last walk-in was sent in (-1 = none today)
var _idle_bonus_day := -1  # the day the idle extra was used
var _favour_used_day := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.shift_started.connect(func(_h: float) -> void: plan_day())
	EventBus.order_fulfilled.connect(func(_o, _p) -> void: _last_handover = _progress())


# --- Load ------------------------------------------------------------------


## Real minutes of work left on open orders (unmade parts, plus assembly).
func backlog_minutes() -> float:
	var total := 0.0
	for order in Orders.active:
		if order.state != SuitOrder.State.OPEN:
			continue
		for t in order.required_types():
			if not order.is_part_done(t):
				total += _part_minutes()
		total += 0.3  # assembling at the mannequin
	return total


## Minutes to cut + sew one part with the current machine upgrades.
func _part_minutes() -> float:
	var m := PART_MINUTES
	if Upgrades != null and Upgrades.has("cut_master"):
		m -= PART_MINUTES * 0.4 * 0.3
	if Upgrades != null and Upgrades.has("sew_industrial"):
		m -= PART_MINUTES * 0.6 * 0.3
	return m


func _shift_minutes() -> float:
	var fallback: float = DayNight.DEFAULT_SHIFT_SECONDS
	var secs: float = Config.data.shift_real_seconds if Config.data != null else fallback
	return maxf(secs / 60.0, 0.5)


## 0 = idle … 1 = a full two shifts of work queued (above 1 = swamped).
func load_factor() -> float:
	return backlog_minutes() / (_shift_minutes() * 2.0)


## 0 opening week, 1 growing, 2 established.
func stage() -> int:
	var tier: int = Reputation.tier() if Reputation != null else 0
	if tier == 0 and _today() <= 3:
		return 0
	return 1 if tier <= 2 else 2


# --- Planning --------------------------------------------------------------


## Build today's walk-in schedule (called when the shop opens; a mid-day load keeps only
## the arrivals still ahead).
func plan_day() -> void:
	_plan.clear()
	_plan_day = _today()
	_last_handover = -1.0
	_last_arrival = -1.0
	var count := planned_walk_ins()
	var times: Array[float] = []
	for i in count:
		var w: Vector2 = WINDOWS[i % WINDOWS.size()]
		times.append(_rng.randf_range(w.x, w.y))
	times.sort()
	var now := _progress()
	for t in times:
		if t > now:
			_plan.append(t)
	_ring_the_bell(now)
	if _event_extra(load_factor()) and UI != null:
		UI.toast("The paper's buzzing about an event — expect extra customers today!")
	changed.emit()


## Nothing on the books at opening: bring the first walk-in forward so the player isn't
## left standing in an empty shop (day one after skipping the tutorial, especially).
func _ring_the_bell(now: float) -> void:
	if _plan.is_empty() or now > WINDOWS[0].x or not Orders.active.is_empty():
		return
	_plan[0] = minf(_plan[0], _rng.randf_range(OPENING_BELL.x, OPENING_BELL.y))


## How many walk-ins today, by stage, workload and the paper's events.
func planned_walk_ins() -> int:
	var lf := load_factor()
	var count := 1
	match stage():
		0:
			count = 1 + (1 if lf < OPENING_ROOM else 0)
		1:
			count = 1 + (1 if lf < 0.4 else 0)
		2:
			count = 2 + (1 if lf < 0.5 else 0)
	if _event_extra(lf):
		count += 1
	if lf >= SWAMPED:
		count = 0
	return count


## The event brings one more through the door, but only to a shop with room for them:
## a busy bench gets the event's customers in place of the usual ones, not on top.
func _event_extra(lf: float) -> bool:
	return lf < EVENT_ROOM and event_rush_today()


## A newspaper EVENT is on (its bias window covers today).
func event_rush_today() -> bool:
	if News == null:
		return false
	var day := _today()
	for ev in News.upcoming_events(day):
		if News.in_run_up(ev, day):
			return true
	return false


## Called every spawn tick. Returns {} (nobody) or { kind, appointment? } where kind is
## "appointment", "walk_in" or "referral".
func next_arrival() -> Dictionary:
	if _plan_day != _today():
		plan_day()
	var now := _progress()
	var appt := _due_appointment(now)
	if not appt.is_empty():
		appointments.erase(appt)
		changed.emit()
		return {"kind": "appointment", "appointment": appt}
	if not _walk_ins_allowed(now):
		return {}
	var kind := _walk_in_kind(now)
	if kind == "":
		return {}
	_last_arrival = now
	return {"kind": kind}


## A passer-by was talked into coming in (StreetPitch): that uses up one of today's
## planned walk-ins, so pitching brings custom forward rather than adding to it.
func claim_walk_in() -> void:
	if _plan_day != _today():
		plan_day()
	if not _plan.is_empty():
		_plan.remove_at(0)


## Walk-ins are held while the sign is up, a fitting is on screen, just after a handover,
## or while the shop is swamped.
func _walk_ins_allowed(now: float) -> bool:
	if booked or _busy_elsewhere():
		return false
	if _last_handover >= 0.0 and now >= _last_handover and now - _last_handover < BREATHER:
		return false
	return load_factor() < SWAMPED


## "walk_in" (scheduled or the broke safety net), "referral" (the rival's favour) or "".
func _walk_in_kind(now: float) -> String:
	var kind := ""
	if Orders.active.is_empty() and GameState.money < BROKE:
		_plan.clear()  # the safety net replaces today's schedule
		kind = "walk_in"
	elif not _plan.is_empty() and _plan[0] <= now:
		_plan.remove_at(0)
		kind = "walk_in"
	elif _idle_too_long(now):
		# Nothing to make and nobody coming soon: send the next one now rather than leave
		# the player standing in an empty shop (the plan's next walk-in, or today's extra).
		if _plan.is_empty():
			_idle_bonus_day = _today()
		else:
			_plan.remove_at(0)
		kind = "walk_in"
	elif _favour_ready(now):
		_favour_used_day = _today()
		rival_goodwill -= 1
		kind = "referral"
	return kind


## True when the shop has had nothing to make for IDLE_WAIT and someone could come:
## the plan still has a walk-in to bring forward, or today's idle extra is unused.
func _idle_too_long(now: float) -> bool:
	if not _nothing_to_make():
		return false
	var since := now - maxf(maxf(_last_arrival, _last_handover), 0.0)
	if since < IDLE_WAIT:
		return false
	if not _plan.is_empty():
		return true
	return _idle_bonus_day != _today() and now < LAST_CALL


## Every open order is made (waiting to be collected) or there are none: the bench is idle.
func _nothing_to_make() -> bool:
	for order: SuitOrder in Orders.active:
		if order.state == SuitOrder.State.OPEN:
			return false
	return true


## Flavour a fresh walk-in's brief for the current stage: rush orders and picky clients.
func season_brief(pref: CustomerPreference) -> void:
	var st := stage()
	if _rng.randf() < RUSH_CHANCE[st] and load_factor() < 0.6:
		pref.rush = true
	elif _rng.randf() < PICKY_CHANCE[st]:
		pref.picky = true
		pref.budget = int(round(pref.budget * 0.85 / 5.0)) * 5
	pref.roll_taste(_rng)  # last: the brief is final, and the taste picks from what it allows


## A due day the shop can realistically meet for an order of `parts` pieces.
func suggest_due_day(parts: int, rush := false) -> int:
	var today := _today()
	if rush:
		return today + 1
	var shift := _shift_minutes()
	var left_today := (1.0 - _progress()) * shift
	var queue := backlog_minutes() + parts * _part_minutes() + 0.3
	var days := int(ceil(maxf(0.0, queue - left_today) / shift))
	var slack := 2 if stage() == 0 else 1
	return today + clampi(days + slack, 1, 5)


# --- Saying no -------------------------------------------------------------


## The first day a booked fitting fits: after the current backlog clears, and not a day
## that already has MAX_APPOINTMENTS_PER_DAY bookings.
func next_free_day() -> int:
	var day := _today() + maxi(1, int(ceil(backlog_minutes() / _shift_minutes())))
	while _appointments_on(day) >= MAX_APPOINTMENTS_PER_DAY:
		day += 1
	return day


## "Come back on day X": book a fitting for this customer. Returns the day.
func book_appointment(cust: Node) -> int:
	var pref: CustomerPreference = cust.get("preference")
	var day := next_free_day()
	(
		appointments
		. append(
			{
				"name": pref.display_name,
				"day": day,
				"at": _rng.randf_range(0.08, 0.3),
				"occasion": int(pref.occasion),
				"style": int(pref.style),
				"budget": pref.budget,
				"rush": pref.rush,
				"picky": pref.picky,
				"likes": pref.likes_color,
				"dislikes": pref.dislikes_color,
				"quiet": pref.quiet_dislike,
				"quiet_known": pref.quiet_known,
				"town": pref.town_worn,
			}
		)
	)
	if Clientele != null:
		Clientele.note_customer(cust)  # so they come back looking like themselves
	changed.emit()
	return day


## Send the customer to the rival tailor; the favour may come back on a quiet day.
func refer_to_rival(_cust: Node) -> void:
	rival_goodwill += 1
	Reputation.points += 1


## Decline. An honest "I can't make that yet" (the brief needs cloth you can't get, or
## can't fit their budget) earns a little trust; a plain no to a regular on a quiet day
## costs a little of their loyalty. Never money. Returns the reputation change.
func decline(cust: Node) -> int:
	var pref: CustomerPreference = cust.get("preference")
	if pref != null and not brief_feasible(pref):
		Reputation.points += HONEST_REP
		return HONEST_REP
	if pref != null and pref.regular_level > 0 and load_factor() < 0.5 and Clientele != null:
		Clientele.dent_loyalty(pref.display_name)
	return 0


## Can the shop make this brief right now? False when no suit the customer would take
## (the dress code, less their dislikes and suits they already have from you) comes in a
## cloth an unlocked supplier stocks, or even the cheapest of them is over budget.
func brief_feasible(pref: CustomerPreference) -> bool:
	if Catalog == null or Catalog.dress_code == null:
		return true
	if Catalog.dress_code.rule_for(pref.occasion, pref.style) == null:
		return true
	var quote := SuitTaste.cheapest_quote(pref)
	return quote >= 0 and quote <= pref.budget


## Why the brief can't be made (for the greeting bubble), or "".
func infeasible_reason(pref: CustomerPreference) -> String:
	return "" if brief_feasible(pref) else "needs cloth or a price you can't manage yet"


# --- Calendar ----------------------------------------------------------------


## The next `days` shop days: [{ day, due, appointments }] for the order-book calendar.
func calendar(days := 5) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var today := _today()
	for i in days:
		var d := today + i
		var due := 0
		for order in Orders.active:
			if order.due_day == d:
				due += 1
		out.append({"day": d, "due": due, "appointments": _appointments_on(d)})
	return out


# --- Internals -------------------------------------------------------------


func _due_appointment(now: float) -> Dictionary:
	var today := _today()
	for a in appointments:
		if int(a["day"]) < today or (int(a["day"]) == today and float(a["at"]) <= now):
			return a
	return {}


func _appointments_on(day: int) -> int:
	var n := 0
	for a in appointments:
		if int(a["day"]) == day:
			n += 1
	return n


## The rival returns a favour: a quiet afternoon, once a day, if you've sent them work.
func _favour_ready(now: float) -> bool:
	return (
		rival_goodwill > 0
		and _favour_used_day != _today()
		and _plan.is_empty()
		and now > 0.5
		and now < 0.9
		and load_factor() < 0.3
	)


## Don't send someone in while a fitting or greeting is on screen.
func _busy_elsewhere() -> bool:
	if UI == null:
		return false
	return UI.suit_builder.visible or UI.customer_request.visible


func _today() -> int:
	return Shift.day if Shift != null else 1


func _progress() -> float:
	return DayNight.progress() if DayNight != null else 0.0


# --- Save / load -----------------------------------------------------------


func save_state() -> Dictionary:
	return {
		"booked": booked,
		"rival_goodwill": rival_goodwill,
		"appointments": appointments.duplicate(true),
	}


func restore(d: Variant) -> void:
	var data: Dictionary = d if d is Dictionary else {}
	booked = bool(data.get("booked", false))
	rival_goodwill = int(data.get("rival_goodwill", 0))
	appointments.clear()
	for a in data.get("appointments", []):
		appointments.append((a as Dictionary).duplicate())
	_plan_day = -1


func reset() -> void:
	restore({})
	_last_handover = -1.0
	_favour_used_day = -1

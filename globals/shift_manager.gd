extends Node

## Autoloaded as "Shift". Owns the working-day lifecycle on top of DayNight's clock:
## which day it is, what part of it (Phase), and the opening and closing rituals — both
## done by flipping the sign by the door (scenes/world/door_sign.gd).
##
##   MORNING      the day has dawned (EventBus.day_began: the paper lands) but the sign
##                says CLOSED. The clock waits at the opening hour; the benches work, so
##                it's prep time. Flip the sign -> open_shop().
##   OPEN         the clock runs, shoppers and collectors arrive. Flipping the sign now
##                closes early and finishes the day (close_shop(true)).
##   AFTER_HOURS  the closing bell has rung: no new shoppers, the work stations refuse
##                ("labour laws"). Flip the sign to lock up -> close_shop().
##
## Finishing the day plays the UI day-transition and dawns the next morning. Systems ask
## is_open() to gate work/spawns.

enum Phase { MORNING, OPEN, AFTER_HOURS }

const MORNING_HINT_DAYS := 3  # how many mornings remind the player about the sign

var day := 1
var open := true
var phase: int = Phase.OPEN

var _transitioning := false
var _day_start_money := 0
var _dawned_day := 0  # the last day day_began fired for


func _ready() -> void:
	_day_start_money = GameState.money
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.shift_ended.connect(_on_shift_ended)


func is_open() -> bool:
	return open


## True once the closing bell has rung (the benches refuse until tomorrow).
func is_after_hours() -> bool:
	return phase == Phase.AFTER_HOURS


## The wallet balance at the start of today, for the end-of-day "earned" tally.
func day_start_money() -> int:
	return _day_start_money


## Restore that baseline after a mid-day load so the day's earnings read correctly.
func set_day_baseline(amount: int) -> void:
	_day_start_money = amount


## Jump to `to_day` with a clean slate (a new game, or a save being applied): the next
## morning or shift dawns afresh.
func reset_to(to_day: int) -> void:
	day = to_day
	phase = Phase.OPEN
	open = true
	_dawned_day = 0
	_transitioning = false


# --- Day lifecycle ---------------------------------------------------------


## Dawn: the shop is shut, the clock waits, and the day's news arrives.
func begin_morning() -> void:
	phase = Phase.MORNING
	open = false
	_day_start_money = GameState.money
	DayNight.hold_morning()
	_dawn()
	if day <= MORNING_HINT_DAYS and UI != null:
		UI.toast("Take your time — flip the sign by the door when you're ready to open.")


## A save made after the closing bell: the clock stands at closing time, the shop is
## shut, and the sign offers to finish the day. Quiet — the bell already rang that day.
func resume_after_hours() -> void:
	_dawned_day = day  # the morning (and its paper) already happened
	DayNight.hold_evening()
	phase = Phase.AFTER_HOURS
	open = false
	if UI != null and UI.clock != null and UI.clock.has_method("show_closed"):
		UI.clock.show_closed(true)


## The sign was flipped to OPEN: start the clock (shift_started does the rest).
func open_shop() -> void:
	if phase != Phase.MORNING or _transitioning:
		return
	DayNight.start_shift()


## Orders whose customer is still due to call today — closing early sends them home
## until tomorrow (they arrive first thing).
func callers_still_due() -> int:
	var n := 0
	for order: SuitOrder in Orders.active:
		if not order.due_fired and order.due_day <= day:
			n += 1
	return n


## Finish the day: play the transition, then dawn the next morning. After hours this is
## locking up; with `early` it is allowed while the shop is still open.
func close_shop(early := false) -> void:
	if _transitioning or phase == Phase.MORNING:
		return
	if phase == Phase.OPEN:
		if not early:
			return
		DayNight.running = false
		EventBus.shift_ended.emit()  # the usual end-of-shift bookkeeping (autosave, music)
	_transitioning = true
	GameState.input_locked = true
	var earned := GameState.money - _day_start_money
	UI.play_day_transition(day, day + 1, earned, _begin_next_day, _end_transition)


func _begin_next_day() -> void:
	day += 1
	begin_morning()


func _end_transition() -> void:
	_transitioning = false
	GameState.input_locked = false


func _dawn() -> void:
	if _dawned_day == day:
		return
	_dawned_day = day
	EventBus.day_began.emit(day)


func _on_shift_started(_hour: float) -> void:
	# A load or a direct boot starts the clock without a morning — it still dawns first.
	if phase != Phase.MORNING:
		_day_start_money = GameState.money
	_dawn()
	phase = Phase.OPEN
	open = true
	if Pricing.is_market_day(day) and UI != null:
		var off := roundi(Pricing.market_discount() * 100.0)
		UI.toast("Market day! Every supplier's cloth is %d%% off today." % off)


func _on_shift_ended() -> void:
	phase = Phase.AFTER_HOURS
	open = false

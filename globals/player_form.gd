extends Node

## Autoloaded as "PlayerForm". Watches how a playthrough is going and writes it down, so a
## tester can send the owner one plain-text report (pause menu → Playtest Report). It
## only records: nothing here changes the game. See docs/PLAYTEST_REPORT.md.
##
## Four readings, each -1 (easy) … +1 (struggling), over the last few played days:
##   time    – late and lost orders, time swamped vs time with nothing to make
##   craft   – finished piece quality and the share of the quote actually paid
##   money   – how close cash came to the broke line vs how much it grew
##   clients – proposals shown at the mirror per design the customer took
## The weights are first guesses, to be tuned from real reports.

const DIR := "user://playtest"
const WINDOW_DAYS := 3
const MAX_EVENTS := 800
const WRITE_EVERY := 60.0  # seconds of play between automatic report writes
const EASY := -0.4
const HARD := 0.4
const BROKE_LINE := 250.0
const GROWTH_SCALE := 600.0
const COLUMNS := [
	["day", "Day"],
	["open_min", "Open min"],
	["idle_pct", "Idle%"],
	["swamped_pct", "Swamp%"],
	["walk_ins", "Walk-ins"],
	["took", "Took"],
	["booked", "Book"],
	["referred", "Refer"],
	["declined", "Decl"],
	["proposals", "Shown"],
	["yes", "Yes"],
	["collected", "Paid"],
	["late", "Late"],
	["lost", "Lost"],
	["walk_outs", "Walkout"],
	["paid_pct", "Paid%"],
	["quality", "Quality"],
	["cloth_m", "Cloth m"],
	["cloth_cost", "Cloth $"],
	["cash_open", "Cash in"],
	["cash_close", "Cash out"],
	["cash_low", "Low"],
	["rep", "Rep"],
	["fps", "FPS"],
]

## day (int) -> record Dictionary (see _blank_day)
var _days: Dictionary = {}
var _events: PackedStringArray = PackedStringArray()
var _run: Dictionary = {}
var _since_write := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.day_began.connect(_on_day_began)
	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.customer_answered.connect(_on_answered)
	EventBus.design_judged.connect(_on_judged)
	EventBus.order_created.connect(_on_order_created)
	EventBus.order_fulfilled.connect(_on_fulfilled)
	EventBus.order_late.connect(_on_late)
	EventBus.order_expired.connect(_on_expired)
	EventBus.order_placed.connect(_on_cloth_bought)
	EventBus.piece_sewn.connect(_on_sewn)
	EventBus.session_ended.connect(func() -> void: write_report())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		write_report()


func _process(delta: float) -> void:
	if not _in_game():
		return
	var rec := _rec()
	if Tutorial != null and Tutorial.is_active():
		rec["tutorial_s"] = float(rec["tutorial_s"]) + delta
		return
	rec["fps_sum"] = float(rec["fps_sum"]) + Engine.get_frames_per_second()
	rec["fps_n"] = int(rec["fps_n"]) + 1
	rec["cash_low"] = mini(int(rec["cash_low"]), GameState.money)
	if Shift.phase == Shift.Phase.MORNING:
		rec["morning_s"] = float(rec["morning_s"]) + delta
	elif Shift.is_open():
		_sample_open(rec, delta)
	_since_write += delta
	if _since_write >= WRITE_EVERY:
		write_report()


# --- Readings ----------------------------------------------------------------------


## The four readings over the last WINDOW_DAYS played days: { time, craft, money,
## clients } each -1..1, plus the raw figures behind them under "facts".
func readings() -> Dictionary:
	var t := _window_totals()
	var open_s := maxf(float(t["open_s"]), 1.0)
	var due := maxi(int(t["collected"]) + int(t["lost"]), 1)
	var idle := float(t["idle_s"]) / open_s
	var swamped := float(t["swamped_s"]) / open_s
	var time := float(t["late"]) / due + 2.0 * float(t["lost"]) / due + 1.5 * swamped - 1.5 * idle
	var quality := float(t["quality_sum"]) / maxf(float(t["quality_n"]), 1.0)
	var paid := float(t["paid"]) / maxf(float(t["priced"]), 1.0)
	var craft := 0.0
	if float(t["quality_n"]) > 0.0:
		craft += (0.8 - quality) * 3.0
	if float(t["priced"]) > 0.0:
		craft += (0.95 - paid) * 2.0
	var growth := float(t["cash_end"]) - float(t["cash_start"])
	# Plenty of cash alone isn't "easy" (you start with some); growing it is.
	var near_broke := clampf((BROKE_LINE - float(t["cash_low"])) / BROKE_LINE, -0.3, 1.0)
	var money := near_broke - growth / GROWTH_SCALE
	var tries := float(t["proposals"]) / maxf(float(t["yes"]), 1.0)
	var clients := (tries - 1.6) * 1.2 if int(t["yes"]) > 0 else 0.0
	return {
		"time": clampf(time, -1.0, 1.0),
		"craft": clampf(craft, -1.0, 1.0),
		"money": clampf(money, -1.0, 1.0),
		"clients": clampf(clients, -1.0, 1.0),
		"facts":
		{
			"idle": idle,
			"swamped": swamped,
			"late": int(t["late"]),
			"lost": int(t["lost"]),
			"quality": quality,
			"paid": paid,
			"cash_low": int(t["cash_low"]),
			"growth": int(growth),
			"tries": tries,
			"days": int(t["days"]),
		},
	}


## "easy", "about right" or "struggling" for a reading.
static func verdict(value: float) -> String:
	if value <= EASY:
		return "easy"
	if value >= HARD:
		return "struggling"
	return "about right"


# --- The report ----------------------------------------------------------------------


func report_path() -> String:
	return "%s/report_%s.txt" % [DIR, str(_run_info().get("id", "run"))]


## Write the report file and return its path (empty on failure).
func write_report() -> String:
	_since_write = 0.0
	if _days.is_empty() and _events.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(report_path(), FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(report_text())
	f.close()
	return report_path()


## Put the whole report on the clipboard (to paste into a message).
func copy_report() -> void:
	write_report()
	DisplayServer.clipboard_set(report_text())


## Open the folder holding the report files in the OS file manager.
func open_folder() -> void:
	var path := write_report()
	DirAccess.make_dir_recursive_absolute(DIR)
	if path != "":
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path))
	else:
		OS.shell_open(ProjectSettings.globalize_path(DIR))


func report_text() -> String:
	var run := _run_info()
	var lines := PackedStringArray()
	lines.append("TAILORTOWN PLAYTEST REPORT")
	lines.append(
		(
			"Run %s · session %d · written %s"
			% [run.get("id", "?"), int(run.get("sessions", 1)), _now()]
		)
	)
	lines.append(_machine_line())
	lines.append(
		(
			"Now: day %d · $%d cash · %d reputation (tier %d)"
			% [Shift.day, GameState.money, Reputation.points, Reputation.tier()]
		)
	)
	lines.append("")
	lines.append_array(_readings_block())
	lines.append("")
	lines.append("DAY BY DAY")
	lines.append_array(_table(false))
	lines.append("")
	lines.append("WHAT HAPPENED")
	lines.append_array(_events)
	lines.append("")
	lines.append("CSV (paste into a spreadsheet)")
	lines.append_array(_table(true))
	return "\n".join(lines) + "\n"


# --- Save / load -----------------------------------------------------------------


func save_state() -> Dictionary:
	write_report()
	return {"days": _days.duplicate(true), "events": Array(_events), "run": _run.duplicate()}


func restore(d: Variant) -> void:
	var data: Dictionary = d if d is Dictionary else {}
	_days.clear()
	var days: Dictionary = data.get("days", {})
	for k in days:
		_days[int(k)] = days[k]
	_events = PackedStringArray(data.get("events", []))
	_run = (data.get("run", {}) as Dictionary).duplicate()
	if not _run.is_empty():
		_run["sessions"] = int(_run.get("sessions", 1)) + 1
	_log("Session %d: loaded a save" % int(_run_info().get("sessions", 1)))


## A new game: a fresh run with its own report file.
func reset() -> void:
	_days.clear()
	_events = PackedStringArray()
	_run = {}
	_run_info()
	_log("New game")


# --- Listeners -------------------------------------------------------------------


func _on_day_began(day: int) -> void:
	var rec := _rec(day)
	rec["cash_open"] = GameState.money
	rec["cash_low"] = GameState.money
	rec["rep_open"] = Reputation.points
	_log("Day %d begins · $%d · %d reputation" % [day, GameState.money, Reputation.points])


func _on_shift_ended() -> void:
	var rec := _rec()
	rec["cash_close"] = GameState.money
	rec["rep_close"] = Reputation.points
	_log("Shop shut · $%d" % GameState.money)
	write_report()


func _on_answered(choice: String, cust: Node) -> void:
	var rec := _rec()
	rec["walk_ins"] = int(rec["walk_ins"]) + 1
	var key: String = {"take": "took", "book": "booked", "refer": "referred"}.get(
		choice, "declined"
	)
	if choice in ["take", "book", "refer", "decline"]:
		rec[key] = int(rec[key]) + 1
	var pref: CustomerPreference = cust.get("preference")
	if pref == null:
		return
	var who := pref.title()
	var extra := ""
	var taste := pref.taste_short()
	if taste != "":
		extra = " · " + taste.to_lower()
	_log("%s (%s%s): %s" % [who, pref.describe(), extra, _choice_word(choice)])


func _on_judged(suitable: bool, reason: String) -> void:
	var rec := _rec()
	rec["proposals"] = int(rec["proposals"]) + 1
	if suitable:
		rec["yes"] = int(rec["yes"]) + 1
		_log("  mirror: yes")
	else:
		_log("  mirror: no · %s" % reason.trim_prefix("Not quite: "))


func _on_order_created(order: SuitOrder) -> void:
	_log(
		(
			"  order #%d %s · $%d · due day %d · %s"
			% [order.id, order.customer_name, order.price, order.due_day, _suit_words(order)]
		)
	)


func _on_fulfilled(order: SuitOrder, payout: int) -> void:
	var rec := _rec()
	rec["collected"] = int(rec["collected"]) + 1
	rec["paid"] = int(rec["paid"]) + payout
	rec["priced"] = int(rec["priced"]) + order.price
	var when := " (was late)" if order.late else ""
	var who := order.customer_name
	_log("#%d %s collected%s · paid $%d of $%d" % [order.id, who, when, payout, order.price])


func _on_late(order: SuitOrder) -> void:
	var rec := _rec()
	rec["late"] = int(rec["late"]) + 1
	_log("#%d %s came and the suit wasn't ready" % [order.id, order.customer_name])


func _on_expired(order: SuitOrder) -> void:
	var rec := _rec()
	rec["lost"] = int(rec["lost"]) + 1
	var walked := bool(order.get("ignored"))
	if walked:
		rec["walk_outs"] = int(rec["walk_outs"]) + 1
	var why := "walked out, nobody served them" if walked else "order lost"
	_log("#%d %s: %s" % [order.id, order.customer_name, why])


func _on_cloth_bought(material: MaterialType, length: float, cost: int) -> void:
	var rec := _rec()
	rec["cloth_m"] = float(rec["cloth_m"]) + length
	rec["cloth_cost"] = int(rec["cloth_cost"]) + cost
	var what := material.display_name if material != null else "cloth"
	_log("Bought %.0f m %s · $%d" % [length, what, cost])


func _on_sewn(piece: Node) -> void:
	var q: Variant = piece.get("quality") if piece != null else null
	if q == null:
		return
	var rec := _rec()
	rec["quality_sum"] = float(rec["quality_sum"]) + float(q)
	rec["quality_n"] = int(rec["quality_n"]) + 1


# --- Internals -------------------------------------------------------------------


func _in_game() -> bool:
	if Shift == null or GameState.is_paused or get_tree().paused:
		return false
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path != SaveManager.MENU_SCENE


func _sample_open(rec: Dictionary, delta: float) -> void:
	rec["open_s"] = float(rec["open_s"]) + delta
	var making := false
	for order: SuitOrder in Orders.active:
		if order.state == SuitOrder.State.OPEN:
			making = true
			break
	if not making:
		rec["idle_s"] = float(rec["idle_s"]) + delta
	var load := FrontDesk.load_factor()
	rec["peak_load"] = maxf(float(rec["peak_load"]), load)
	if load >= FrontDesk.SWAMPED:
		rec["swamped_s"] = float(rec["swamped_s"]) + delta
	if FrontDesk.booked:
		rec["booked_s"] = float(rec["booked_s"]) + delta


func _rec(day := -1) -> Dictionary:
	if day < 0:
		day = Shift.day if Shift != null else 1
	if not _days.has(day):
		_days[day] = _blank_day(day)
	return _days[day]


func _blank_day(day: int) -> Dictionary:
	return {
		"day": day,
		"open_s": 0.0,
		"morning_s": 0.0,
		"tutorial_s": 0.0,
		"idle_s": 0.0,
		"swamped_s": 0.0,
		"booked_s": 0.0,
		"peak_load": 0.0,
		"walk_ins": 0,
		"took": 0,
		"booked": 0,
		"referred": 0,
		"declined": 0,
		"proposals": 0,
		"yes": 0,
		"collected": 0,
		"late": 0,
		"lost": 0,
		"walk_outs": 0,
		"paid": 0,
		"priced": 0,
		"quality_sum": 0.0,
		"quality_n": 0,
		"cloth_m": 0.0,
		"cloth_cost": 0,
		"cash_open": GameState.money,
		"cash_close": -1,
		"cash_low": GameState.money,
		"rep_open": Reputation.points,
		"rep_close": -1,
		"fps_sum": 0.0,
		"fps_n": 0,
	}


## Sums over the last WINDOW_DAYS days that saw any open-shop time.
func _window_totals() -> Dictionary:
	var played: Array = []
	var keys: Array = _days.keys()
	keys.sort()
	for k in keys:
		if float(_days[k]["open_s"]) > 0.0:
			played.append(_days[k])
	played = played.slice(maxi(played.size() - WINDOW_DAYS, 0))
	var sums := ["open_s", "idle_s", "swamped_s", "late", "lost", "collected", "paid", "priced"]
	sums.append_array(["quality_sum", "quality_n", "proposals", "yes"])
	var t := {"days": played.size(), "cash_low": GameState.money}
	for key: String in sums:
		t[key] = 0.0
	for rec: Dictionary in played:
		for key: String in sums:
			t[key] = float(t[key]) + float(rec[key])
		t["cash_low"] = mini(int(t["cash_low"]), int(rec["cash_low"]))
	t["cash_start"] = int(played[0]["cash_open"]) if not played.is_empty() else GameState.money
	t["cash_end"] = GameState.money
	return t


func _readings_block() -> PackedStringArray:
	var r := readings()
	var f: Dictionary = r["facts"]
	var out := PackedStringArray()
	out.append(
		(
			"HOW IT'S GOING (last %d played day%s · -1 easy … +1 struggling · first guesses)"
			% [int(f["days"]), "" if int(f["days"]) == 1 else "s"]
		)
	)
	var rows := [
		[
			"Time pressure",
			r["time"],
			(
				"%d late, %d lost · swamped %d%% of open time · idle %d%%"
				% [f["late"], f["lost"], roundi(f["swamped"] * 100), roundi(f["idle"] * 100)]
			),
		],
		[
			"Craft",
			r["craft"],
			(
				"piece quality %.2f · paid %d%% of quotes"
				% [f["quality"], roundi(float(f["paid"]) * 100)]
			),
		],
		[
			"Money",
			r["money"],
			"lowest cash $%d · %+d over these days" % [f["cash_low"], f["growth"]],
		],
		["Reading clients", r["clients"], "%.1f designs shown per yes" % f["tries"]],
	]
	for row: Array in rows:
		(
			out
			. append(
				(
					"  %s %s  %s  %s"
					% [
						str(row[0]).rpad(16),
						("%+.2f" % float(row[1])).lpad(5),
						verdict(float(row[1])).rpad(11),
						row[2],
					]
				)
			)
		)
	return out


func _table(csv: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var header := PackedStringArray()
	for c: Array in COLUMNS:
		header.append(str(c[0]) if csv else str(c[1]))
	var rows: Array = [header]
	var keys: Array = _days.keys()
	keys.sort()
	for k in keys:
		var vals := _row_values(_days[k])
		var row := PackedStringArray()
		for c: Array in COLUMNS:
			row.append(str(vals.get(c[0], "")))
		rows.append(row)
	if csv:
		for row: PackedStringArray in rows:
			out.append(",".join(row))
		return out
	for row: PackedStringArray in rows:
		var cells := PackedStringArray()
		for i in row.size():
			var width := maxi(str(COLUMNS[i][1]).length(), 4)
			cells.append(row[i].lpad(width))
		out.append(" ".join(cells))
	return out


func _row_values(rec: Dictionary) -> Dictionary:
	var open_s := maxf(float(rec["open_s"]), 1.0)
	var close := int(rec["cash_close"])
	var rep_close := int(rec["rep_close"])
	var fps_n := maxi(int(rec["fps_n"]), 1)
	var q_n := int(rec["quality_n"])
	var priced := float(rec["priced"])
	var paid_pct: Variant = roundi(float(rec["paid"]) / priced * 100) if priced > 0.0 else "-"
	return {
		"day": rec["day"],
		"open_min": "%.1f" % (float(rec["open_s"]) / 60.0),
		"idle_pct": roundi(float(rec["idle_s"]) / open_s * 100),
		"swamped_pct": roundi(float(rec["swamped_s"]) / open_s * 100),
		"walk_ins": rec["walk_ins"],
		"took": rec["took"],
		"booked": rec["booked"],
		"referred": rec["referred"],
		"declined": rec["declined"],
		"proposals": rec["proposals"],
		"yes": rec["yes"],
		"collected": rec["collected"],
		"late": rec["late"],
		"lost": rec["lost"],
		"walk_outs": rec["walk_outs"],
		"paid_pct": paid_pct,
		"quality": "%.2f" % (float(rec["quality_sum"]) / q_n) if q_n > 0 else "-",
		"cloth_m": "%.0f" % float(rec["cloth_m"]),
		"cloth_cost": rec["cloth_cost"],
		"cash_open": rec["cash_open"],
		"cash_close": close if close >= 0 else GameState.money,
		"cash_low": rec["cash_low"],
		"rep": "%d->%d" % [rec["rep_open"], rep_close if rep_close >= 0 else Reputation.points],
		"fps": roundi(float(rec["fps_sum"]) / fps_n),
	}


func _run_info() -> Dictionary:
	if _run.is_empty():
		var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "_")
		_run = {"id": stamp.substr(0, 15), "started": _now(), "sessions": 1}
	return _run


func _machine_line() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var size := DisplayServer.window_get_size()
	var gpu := RenderingServer.get_video_adapter_name()
	return (
		"Build %s · %s · %s · window %dx%d"
		% [
			version if version != "" else "dev",
			OS.get_name(),
			gpu if gpu != "" else "no GPU name",
			size.x,
			size.y,
		]
	)


func _log(text: String) -> void:
	var clock := DayNight.time_string() if DayNight != null else ""
	var day := Shift.day if Shift != null else 0
	_events.append("D%d %s  %s" % [day, clock, text])
	if _events.size() > MAX_EVENTS:
		_events = _events.slice(_events.size() - MAX_EVENTS)


static func _choice_word(choice: String) -> String:
	match choice:
		"take":
			return "took them on"
		"book":
			return "booked a later day"
		"refer":
			return "sent them to the rival"
		"decline":
			return "turned them away"
	return choice


static func _suit_words(order: SuitOrder) -> String:
	var jacket: Dictionary = order.design.get(Enums.GarmentType.JACKET, {})
	if jacket.is_empty():
		return "?"
	var words := (
		"%s %s %s"
		% [
			MaterialFactory.color_name(int(jacket.get("color", 0))),
			Enums.pattern_name(int(jacket.get("pattern", 0))).to_lower(),
			Enums.fabric_name(int(jacket.get("fabric", 0))).to_lower(),
		]
	)
	var shirt: Dictionary = order.design.get(Enums.GarmentType.SHIRT, {})
	if not shirt.is_empty():
		words += ", %s shirt" % MaterialFactory.color_name(int(shirt.get("color", 10))).to_lower()
	return words


static func _now() -> String:
	return Time.get_datetime_string_from_system().replace("T", " ").substr(0, 16)

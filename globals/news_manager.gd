extends Node

## The daily paper — autoloaded as "News".
##
## Loads every NewsEvent from res://data/news at boot (like Catalog loads
## materials). Each morning (EventBus.day_began) it compiles the day's edition:
## the articles whose day/reputation gates are met and that haven't run yet (unless
## repeatable), ordered so the highest-priority story leads. A FASHION article in
## the edition becomes the running trend (followed orders earn bonus reputation); a
## dated EVENT skews which customers arrive as its day nears. It then emits
## EventBus.newspaper_ready so the HUD can slide the paper up. Read-only content:
## the editor dock and tools/build_news.gd author the .tres files.
##
## "Best suit spotted": orders taken in an event's run-up for its occasion are tagged
## for it (Orders._tag_event). Each one collected in time is judged (judge()); the
## morning after the event the paper leads with the best one that made the cut, and
## the shop gains standing (EventBus.press_mention). If none did, the rival shop gets
## the story instead. An event with a mention_bonus is kinder: any suit of ours worn
## there earns a short society note, and only the great one gets the lead.
##
## The social season: `seasonal` articles (the city events and their follow-ups) count
## their days from the morning the season opens, which is the first morning the shop has
## found its feet (Config season_min_reputation / season_min_suits). Until then there
## are no events, no biased briefs and nothing on the calendar. Ask day_of(), never
## ev.event_day, for the real day an event is held.

signal season_opened(day: int)

const DIR := "res://data/news"
const SPOTTED_KICKER := "SOCIETY · SPOTTED"
const RIVAL_KICKER := "SOCIETY"
const MENTION_KICKER := "SOCIETY · SEEN"
const FILLER_PREFIX := "filler_"  # quiet-day pieces: one a day (see _compile)

var current_edition: Array[NewsEvent] = []
var current_fashion: NewsEvent = null

var _all: Array[NewsEvent] = []
## Article id -> the day it ran. (Old saves stored `true`; that reads as "some earlier day".)
var _seen: Dictionary = {}
var _edition_day := 0
var _rng := RandomNumberGenerator.new()
## Per event id, how the shop's suits fared there so far:
## { entered: int, best: {name, suit, score} (empty until one makes the cut), why: String }.
var _spotted: Dictionary = {}
## The day the social season opened (0 = not yet), and the suits handed over so far.
var _season_start := 0
var _suits_delivered := 0


func _ready() -> void:
	_rng.randomize()
	_load()
	EventBus.day_began.connect(_on_day_began)
	EventBus.order_fulfilled.connect(_on_order_fulfilled)


## Everything in the current edition, lead story first.
func edition() -> Array[NewsEvent]:
	return current_edition


## Reputation bonus for a delivered order that follows the running trend (0 if not).
func fashion_bonus(design: Dictionary) -> int:
	return current_fashion.fashion_bonus if fashion_matches(design) else 0


## True when any piece in `design` uses the trend's pattern or fabric.
func fashion_matches(design: Dictionary) -> bool:
	if current_fashion == null:
		return false
	var pat := current_fashion.fashion_pattern
	var fab := current_fashion.fashion_fabric
	if pat < 0 and fab < 0:
		return false
	for spec: Variant in design.values():
		if not (spec is Dictionary):
			continue
		if pat >= 0 and int(spec.get("pattern", -1)) == pat:
			return true
		if fab >= 0 and int(spec.get("fabric", -1)) == fab:
			return true
	return false


func season_open() -> bool:
	return _season_start > 0


## The real in-game day the city event `ev` is held (0 = not on the calendar yet).
func day_of(ev: NewsEvent) -> int:
	if ev == null or ev.event_day <= 0:
		return 0
	if not ev.seasonal:
		return ev.event_day
	return _season_start + ev.event_day - 1 if _season_start > 0 else 0


## `day` falls in `ev`'s run-up: its bias window, up to and including the event day.
func in_run_up(ev: NewsEvent, day: int) -> bool:
	var held := day_of(ev)
	return held > 0 and day >= held - ev.bias_days and day <= held


## Every EVENT still to come (held on or after `from_day`), soonest first — for the
## paper's social calendar. Empty until the season opens.
func upcoming_events(from_day: int) -> Array[NewsEvent]:
	var out: Array[NewsEvent] = []
	for ev in _all:
		if ev.kind == NewsEvent.Kind.EVENT and day_of(ev) >= maxi(from_day, 1):
			out.append(ev)
	out.sort_custom(func(a: NewsEvent, b: NewsEvent) -> bool: return day_of(a) < day_of(b))
	return out


## A customer brief override for a looming city event: {occasion, style} while an
## EVENT's window covers `day` and the roll passes, else {} (leave the brief random).
func event_bias(day: int, rng: RandomNumberGenerator) -> Dictionary:
	for ev in _all:
		if ev.kind != NewsEvent.Kind.EVENT or not in_run_up(ev, day):
			continue
		if rng.randf() >= ev.bias_chance:
			continue
		var bias := {"occasion": ev.event_occasion}
		if ev.event_style >= 0:
			bias["style"] = ev.event_style
		return bias
	return {}


## The EVENT whose run-up (bias window) covers `day` and wants `occasion`, or null.
func event_for(occasion: int, day: int) -> NewsEvent:
	for ev in _all:
		if ev.kind != NewsEvent.Kind.EVENT or ev.event_occasion != occasion:
			continue
		if in_run_up(ev, day):
			return ev
	return null


## The day the city event `id` is held (0 if unknown, or not on the calendar yet).
func event_day(id: String) -> int:
	return day_of(_event(id))


## An event's name for running text: "the Autumn Charity Gala".
func event_title(id: String) -> String:
	var ev := _event(id)
	if ev == null:
		return "the event"
	return "the " + ev.headline.trim_prefix("The ")


## Would this suit make the society pages? Very nicely made (craft quality AND match to
## the brief at the spotted_* bars) and in style (follows the running trend).
## Returns {ok: bool, why: "" | "craft" | "trend"}.
func judge(order: SuitOrder) -> Dictionary:
	var q_min: float = Config.data.spotted_quality if Config.data != null else 0.85
	var m_min: float = Config.data.spotted_match if Config.data != null else 0.85
	if order.average_quality() < q_min or order.average_match() < m_min:
		return {"ok": false, "why": "craft"}
	if not fashion_matches(order.design):
		return {"ok": false, "why": "trend"}
	return {"ok": true, "why": ""}


## The best-suit tallies for the save file (events not yet reported).
func spotted_snapshot() -> Dictionary:
	return _spotted.duplicate(true)


func restore_spotted(saved: Dictionary) -> void:
	_spotted = saved.duplicate(true)


## The social season's clock for the save file.
func season_snapshot() -> Dictionary:
	return {"start": _season_start, "suits": _suits_delivered}


func restore_season(saved: Dictionary) -> void:
	_season_start = int(saved.get("start", 0))
	_suits_delivered = int(saved.get("suits", 0))


## Restore which articles have already run (from a save). Call before the day
## begins so already-seen, non-repeatable stories don't reappear; the next
## _compile then rebuilds today's edition and trend honouring this history.
func restore_seen(seen: Dictionary) -> void:
	_seen = seen.duplicate()
	_edition_day = 0
	current_edition = []


## The set of article ids that have run, for the save file.
func seen_snapshot() -> Dictionary:
	return _seen.duplicate()


# --- Internals -------------------------------------------------------------


func _load() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return  # No news yet — run tools/build_news.gd.
	for file in dir.get_files():
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var ev := load(DIR.path_join(file)) as NewsEvent
		if ev != null:
			_all.append(ev)


func _on_day_began(_day: int) -> void:
	ensure_edition()
	EventBus.newspaper_ready.emit(_edition_day)


## Make sure today's paper is printed. Safe to call any time: the day hasn't begun yet
## during the tutorial, and a mid-day load starts with no edition — either way today's
## stories are compiled once and kept, never reprinted thinner.
func ensure_edition() -> void:
	var day: int = Shift.day if Shift != null else 1
	if _edition_day == day and not current_edition.is_empty():
		return
	var rep: int = Reputation.points if Reputation != null else 0
	_edition_day = day
	_open_season(day, rep)
	current_edition = _compile(day, rep)
	for ev in current_edition:
		_seen[ev.id] = day
		if ev.kind == NewsEvent.Kind.FASHION:
			current_fashion = ev
	_report_spotted(day)


## The season opens the first morning the shop is on its feet: known on the street, with
## a few suits out of the door. Never at Mr. Hemming's, where nothing counts.
func _open_season(day: int, rep: int) -> void:
	if _season_start > 0 or (Tutorial != null and Tutorial.is_active()):
		return
	var need_rep: int = Config.data.season_min_reputation if Config.data != null else 40
	var need_suits: int = Config.data.season_min_suits if Config.data != null else 3
	if rep < need_rep or _suits_delivered < need_suits:
		return
	_season_start = day
	season_opened.emit(day)


## `day` as `ev` counts it: the plain day, or the day of the season (0 = not open yet).
func _clock(ev: NewsEvent, day: int) -> int:
	if not ev.seasonal:
		return day
	return day - _season_start + 1 if _season_start > 0 else 0


## True when `id` already ran on an earlier day (today's own stories may run again, so
## recompiling the same morning gives the same paper).
func _ran_before(id: String, day: int) -> bool:
	if not _seen.has(id):
		return false
	var when: Variant = _seen[id]
	if typeof(when) == TYPE_INT or typeof(when) == TYPE_FLOAT:
		return int(when) != day
	return true


func _event(id: String) -> NewsEvent:
	for ev in _all:
		if ev.id == id:
			return ev
	return null


# --- Best suit spotted -----------------------------------------------------


## A tagged suit was collected: if it's in time for its event, judge it and keep the
## best entry that made the cut. The client's parting word hints how it will go.
func _on_order_fulfilled(order: SuitOrder, _payout: int) -> void:
	if order == null:
		return
	_suits_delivered += 1
	if order.event_id == "":
		return
	var ev := _event(order.event_id)
	if ev == null:
		return
	var at := event_title(ev.id)
	var today: int = Shift.day if Shift != null else 1
	if today > day_of(ev):
		_toast_later("%s's suit came too late for %s" % [order.customer_name, at])
		return
	var entry: Dictionary = _spotted.get(ev.id, {"entered": 0, "best": {}, "why": ""})
	entry["entered"] = int(entry.get("entered", 0)) + 1
	var score := order.average_quality() * order.average_match()
	var worn := {"name": order.customer_name, "suit": _suit_words(order), "score": score}
	var seen: Dictionary = entry.get("seen", {})
	if seen.is_empty() or score > float(seen.get("score", 0.0)):
		entry["seen"] = worn
	var verdict := judge(order)
	var who := order.customer_name
	if bool(verdict["ok"]):
		var best: Dictionary = entry.get("best", {})
		if best.is_empty() or score > float(best.get("score", 0.0)):
			entry["best"] = worn
		_toast_later("%s wears it to %s. The papers will be watching!" % [who, at])
	else:
		entry["why"] = verdict["why"]
		var short := (
			"not quite fine enough" if verdict["why"] == "craft" else "not quite in fashion"
		)
		if ev.mention_bonus > 0:
			_toast_later("%s wears it to %s. Good for a line in the paper" % [who, at])
		else:
			_toast_later("%s wears it to %s: handsome, but %s for the papers" % [who, at, short])
	_spotted[ev.id] = entry


## The morning after a city event, lead the paper with who wore the best suit there:
## the shop's (and its standing rises), or the rival's if nothing of ours made the cut.
func _report_spotted(day: int) -> void:
	for ev in _all:
		if ev.kind != NewsEvent.Kind.EVENT or day_of(ev) <= 0 or day_of(ev) != day - 1:
			continue
		var key := "spotted_" + ev.id
		if _seen.has(key):
			continue
		_seen[key] = day
		var entry: Dictionary = _spotted.get(ev.id, {})
		_spotted.erase(ev.id)
		var won := not (entry.get("best", {}) as Dictionary).is_empty()
		var seen := not (entry.get("seen", {}) as Dictionary).is_empty()
		var story: NewsEvent
		var bonus := 0
		if won:
			story = _spotted_story(ev, entry)
			bonus = ev.spotted_bonus
		elif seen and ev.mention_bonus > 0:
			story = _mention_story(ev, entry)
			bonus = ev.mention_bonus
		else:
			story = _rival_story(ev, entry)
		story.id = key
		story.priority = 100
		current_edition.push_front(story)
		if bonus > 0:
			EventBus.press_mention.emit(story.headline, bonus)


func _spotted_story(ev: NewsEvent, entry: Dictionary) -> NewsEvent:
	var best: Dictionary = entry["best"]
	var story := NewsEvent.new()
	story.kicker = SPOTTED_KICKER
	story.headline = "Best Suit Spotted at %s" % event_title(ev.id)
	story.body = (
		(
			"Of all the finery on show, one suit had the room talking: %s's %s, cut to "
			+ "the season's fashion by a shop on the Row. By the end of the night half "
			+ "the guests were asking for the tailor's card."
		)
		% [best.get("name", "a guest"), best.get("suit", "suit")]
	)
	return story


## Seen, not crowned: the rival takes the honours, and our suit gets its paragraph.
func _mention_story(ev: NewsEvent, entry: Dictionary) -> NewsEvent:
	var rival: String = FrontDesk.RIVAL_NAME if FrontDesk != null else "Pinch & Pleat"
	var seen: Dictionary = entry["seen"]
	var fault := (
		"The seams want another season's practice"
		if entry.get("why", "") == "craft"
		else "The cut was a season behind the fashion"
	)
	var story := NewsEvent.new()
	story.kicker = MENTION_KICKER
	story.headline = "A New Name Is Seen at %s" % event_title(ev.id)
	story.body = (
		(
			"The honours went to %s, as they generally do. Our correspondent also noted "
			+ "%s's %s, from the newer shop on the Row. %s. Two guests asked who made it."
		)
		% [rival, seen.get("name", "a guest"), seen.get("suit", "suit"), fault]
	)
	return story


func _rival_story(ev: NewsEvent, entry: Dictionary) -> NewsEvent:
	var rival: String = FrontDesk.RIVAL_NAME if FrontDesk != null else "Pinch & Pleat"
	var story := NewsEvent.new()
	story.kicker = RIVAL_KICKER
	if int(entry.get("entered", 0)) <= 0:
		story.headline = "%s Dress %s" % [rival, event_title(ev.id)]
		story.body = (
			(
				"%s dressed half the room, and it did not go unnoticed. The other houses "
				+ "on the Row were nowhere to be seen."
			)
			% rival
		)
		return story
	var fault := (
		"not yet the finished article"
		if entry.get("why", "") == "craft"
		else "a step behind the season's fashion"
	)
	story.headline = "%s Carry the Night at %s" % [rival, event_title(ev.id)]
	story.body = (
		(
			"The honours went to %s, whose tailoring was the talk of the evening. A suit "
			+ "from a newer shop on the Row was spotted too: handsome, our correspondent "
			+ "allows, but %s."
		)
		% [rival, fault]
	)
	return story


## "navy glen check worsted suit": the jacket as a society column would put it.
func _suit_words(order: SuitOrder) -> String:
	var words := order.part_summary(Enums.GarmentType.JACKET)
	if words == "—":
		words = order.part_summary(order.required_types()[0])
	return words.to_lower() + " suit"


func _toast_later(text: String) -> void:
	if UI == null:
		return
	# After Reputation's own "+N reputation" toast for the same collection.
	get_tree().create_timer(2.2).timeout.connect(func() -> void: UI.toast(text))


## The articles that may run today, lead story first.
func _compile(day: int, rep: int) -> Array[NewsEvent]:
	var out: Array[NewsEvent] = []
	var fillers: Array[NewsEvent] = []
	for ev in _all:
		var clock := _clock(ev, day)
		if clock <= 0 or not ev.eligible(clock, rep, _ran_before(ev.id, day)):
			continue
		if ev.id.begins_with(FILLER_PREFIX):
			fillers.append(ev)
		else:
			out.append(ev)
	out.sort_custom(_rank)
	# One quiet-day piece a day, in rotation, at the foot of the page — so there is
	# always a paper, however little is going on.
	if not fillers.is_empty():
		fillers.sort_custom(_rank)
		out.append(fillers[day % fillers.size()])
	return out


## Higher priority leads; weight then a stable-ish random break ties.
func _rank(a: NewsEvent, b: NewsEvent) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	if a.weight != b.weight:
		return a.weight > b.weight
	return a.id < b.id

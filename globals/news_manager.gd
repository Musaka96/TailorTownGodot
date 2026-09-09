extends Node

## The daily paper — autoloaded as "News".
##
## Loads every NewsEvent from res://data/news at boot (like Catalog loads
## materials). Each morning (EventBus.shift_started) it compiles the day's edition:
## the articles whose day/reputation gates are met and that haven't run yet (unless
## repeatable), ordered so the highest-priority story leads. A FASHION article in
## the edition becomes the running trend (followed orders earn bonus reputation); a
## dated EVENT skews which customers arrive as its day nears. It then emits
## EventBus.newspaper_ready so the HUD can slide the paper up. Read-only content:
## the editor dock and tools/build_news.gd author the .tres files.

const DIR := "res://data/news"

var current_edition: Array[NewsEvent] = []
var current_fashion: NewsEvent = null

var _all: Array[NewsEvent] = []
var _seen: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load()
	EventBus.shift_started.connect(_on_shift_started)


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


## Every EVENT still to come (event_day on or after `from_day`), soonest first —
## for the paper's social calendar.
func upcoming_events(from_day: int) -> Array[NewsEvent]:
	var out: Array[NewsEvent] = []
	for ev in _all:
		if ev.kind == NewsEvent.Kind.EVENT and ev.event_day >= from_day:
			out.append(ev)
	out.sort_custom(func(a: NewsEvent, b: NewsEvent) -> bool: return a.event_day < b.event_day)
	return out


## A customer brief override for a looming city event: {occasion, style} while an
## EVENT's window covers `day` and the roll passes, else {} (leave the brief random).
func event_bias(day: int, rng: RandomNumberGenerator) -> Dictionary:
	for ev in _all:
		if ev.kind != NewsEvent.Kind.EVENT or ev.event_day <= 0:
			continue
		if day < ev.event_day - ev.bias_days or day > ev.event_day:
			continue
		if rng.randf() >= ev.bias_chance:
			continue
		var bias := {"occasion": ev.event_occasion}
		if ev.event_style >= 0:
			bias["style"] = ev.event_style
		return bias
	return {}


## Restore which articles have already run (from a save). Call before the day's
## shift_started so already-seen, non-repeatable stories don't reappear; the next
## _compile then rebuilds today's edition and trend honouring this history.
func restore_seen(seen: Dictionary) -> void:
	_seen = seen.duplicate()


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


func _on_shift_started(_start_hour: float) -> void:
	var day: int = Shift.day if Shift != null else 1
	var rep: int = Reputation.points if Reputation != null else 0
	current_edition = _compile(day, rep)
	for ev in current_edition:
		_seen[ev.id] = true
		if ev.kind == NewsEvent.Kind.FASHION:
			current_fashion = ev
	EventBus.newspaper_ready.emit(day)


## The articles that may run today, lead story first.
func _compile(day: int, rep: int) -> Array[NewsEvent]:
	var out: Array[NewsEvent] = []
	for ev in _all:
		if ev.eligible(day, rep, _seen.has(ev.id)):
			out.append(ev)
	out.sort_custom(_rank)
	return out


## Higher priority leads; weight then a stable-ish random break ties.
func _rank(a: NewsEvent, b: NewsEvent) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	if a.weight != b.weight:
		return a.weight > b.weight
	return a.id < b.id

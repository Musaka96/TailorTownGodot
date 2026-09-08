extends SceneTree

## Generates the starter newspaper editions (res://data/news/*.tres). Edit these in
## the News Editor dock afterwards, or add your own; re-run to reset the defaults
## (it overwrites the files it knows, leaves any others alone).
##   godot --headless --path . --script res://tools/build_news.gd
##
## Enum literals are integers here (class_name enums aren't resolved in --script):
##   Kind:     0 Story  1 Fashion  2 Event
##   Pattern:  1 Pinstripe   2 Herringbone   (see Enums.Pattern)
##   Fabric:   2 Tweed        4 Linen        (see Enums.Fabric)
##   Occasion: 3 Party        Style: 3 Fashion

const NEWS_SCRIPT := "res://data/scripts/news_event.gd"
const OUT_DIR := "res://data/news"


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var count := 0
	for ev in _events():
		if ResourceSaver.save(ev, "%s/%s.tres" % [OUT_DIR, ev.id]) == OK:
			count += 1
		else:
			push_error("save failed: " + ev.id)
	print("wrote %d news events to %s" % [count, OUT_DIR])
	quit(0)


func _events() -> Array:
	var out: Array = []

	var opening := _mk("day1_opening", 0, "A New Name Opens on the Row")
	opening.exact_day = 1
	opening.priority = 10
	opening.body = (
		"The Row welcomes a fresh pair of shears this morning. "
		+ "Neighbours wish the new tailor a steady hand and a full order book."
	)
	out.append(opening)

	var trend1 := _mk("day1_fashion", 1, "Pinstripe Returns to Favour")
	trend1.exact_day = 1
	trend1.priority = 5
	trend1.fashion_pattern = 1  # Pinstripe
	trend1.fashion_bonus = 8
	trend1.body = "The smart set is asking for pinstripe again. Work it in and heads will turn."
	out.append(trend1)

	var day2 := _mk("day2_notes", 0, "Cutters Watch the Newcomer")
	day2.exact_day = 2
	day2.priority = 3
	day2.body = "Word of a careful first day travels slowly, but it travels. Keep it up."
	out.append(day2)

	var gala := _mk("event_autumn_gala", 2, "Autumn Charity Gala Announced")
	gala.exact_day = 3
	gala.priority = 7
	gala.event_day = 6
	gala.event_occasion = 3  # Party
	gala.event_style = 3  # Fashion
	gala.bias_days = 2
	gala.bias_chance = 0.6
	gala.body = "The city's gala lands in three days. Expect party briefs — prepare your bold cloth."
	out.append(gala)

	var trend2 := _mk("day4_fashion", 1, "Tweed Warms the City's Shoulders")
	trend2.exact_day = 4
	trend2.priority = 5
	trend2.fashion_fabric = 2  # Tweed
	trend2.fashion_bonus = 8
	trend2.body = "As the air cools, tweed is everywhere. A timely bolt earns a nod of approval."
	out.append(trend2)

	var reputable := _mk("rep_local_name", 0, "Word Travels of a Careful Hand")
	reputable.min_reputation = 120
	reputable.priority = 6
	reputable.body = "Patrons speak warmly of a tailor who measures twice. The bench is getting busy."
	out.append(reputable)

	return out


## A NewsEvent with an id, kind and headline; other fields keep their defaults.
func _mk(id: String, kind: int, headline: String) -> Resource:
	var ev: Resource = load(NEWS_SCRIPT).new()
	ev.id = id
	ev.kind = kind
	ev.headline = headline
	return ev

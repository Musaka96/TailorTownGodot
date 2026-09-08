extends SceneTree

## Generates the starter newspaper editions (res://data/news/*.tres) — roughly ten
## days of city news: opening flavour, rotating fashion trends, one-off happenings,
## and two dated city EVENTS that run across their lead-up (the paper re-announces
## them each morning with escalating copy; the newspaper UI supplies the countdown).
## Edit these in the News Editor dock, or add your own; re-run to reset the defaults.
##   godot --headless --path . --script res://tools/build_news.gd
##
## Enum literals are integers here (class_name enums aren't resolved in --script):
##   Kind:     0 Story  1 Fashion  2 Event
##   Pattern:  1 Pinstripe 2 Herringbone 5 Glen Check   Fabric: 2 Tweed 3 Mohair
##   Occasion: 2 Business 3 Party    Style: 1 Classic 3 Fashion

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
	_stories(out)
	_fashions(out)
	_city_events(out)
	return out


## Lead stories and everyday city happenings, one or more per day across ~10 days.
func _stories(out: Array) -> void:
	_day_story(
		out,
		"day1_opening",
		1,
		10,
		"A New Name Opens on the Row",
		"The Row welcomes a new pair of shears. The neighbours wish it well."
	)
	_day_story(
		out,
		"day2_market",
		2,
		4,
		"Cloth Prices Hold at the Exchange",
		"Bolts are plentiful this week and prices steady — a fine time to stock up."
	)
	_day_story(
		out,
		"day3_rival",
		3,
		4,
		"A Rival Hangs a Shingle Down the Lane",
		"A second tailor sets up nearby. The Row watches to see who cuts the finer coat."
	)
	_day_story(
		out,
		"day4_fog",
		4,
		3,
		"Autumn Fog Settles Over the Rooftops",
		"A thick fog rolls in off the river; the city reaches for warmer cloth."
	)
	_day_story(
		out,
		"day5_theatre",
		5,
		4,
		"Theatre Season Opens to Full Houses",
		"The playhouses light up for the season, and finer coats fill every box."
	)
	_day_story(
		out,
		"day7_gala_after",
		7,
		8,
		"The Gala Dazzles the City",
		"Well-cut guests drew every admiring eye. A good night for a tailor's name."
	)
	_day_story(
		out,
		"day8_wool",
		8,
		4,
		"Fine Northern Wool Reaches the Market",
		"A shipment of soft northern wool arrives at the Exchange in quantity."
	)
	_day_story(
		out,
		"day9_royal",
		9,
		5,
		"Whispers of a Royal Visit",
		"Word spreads of a royal passing through before the season is out."
	)
	# Reputation-gated: appears once you're known, any day.
	var known := _mk("rep_local_name", 0, "Word Travels of a Careful Hand")
	known.min_reputation = 120
	known.priority = 6
	known.body = "Patrons speak warmly of a careful new hand on the Row."
	out.append(known)


## Fashion trends that shift through the run (each sets the running trend).
func _fashions(out: Array) -> void:
	var t1 := _mk("day1_fashion", 1, "Pinstripe Returns to Favour")
	t1.exact_day = 1
	t1.priority = 5
	t1.fashion_pattern = 1  # Pinstripe
	t1.fashion_bonus = 8
	t1.body = "The smart set is asking for pinstripe again — heads will turn."
	out.append(t1)

	var t2 := _mk("day4_fashion", 1, "Tweed Warms the City's Shoulders")
	t2.exact_day = 4
	t2.priority = 5
	t2.fashion_fabric = 2  # Tweed
	t2.fashion_bonus = 8
	t2.body = "As the air cools, tweed warms every shoulder in town."
	out.append(t2)

	var t3 := _mk("day7_fashion", 1, "Herringbone Is the Talk of the Salons")
	t3.exact_day = 7
	t3.priority = 5
	t3.fashion_pattern = 2  # Herringbone
	t3.fashion_bonus = 8
	t3.body = "The salons can speak of nothing but a sharp herringbone this week."
	out.append(t3)


## Dated city events. They run every morning across their lead-up window
## (min_day..event_day, repeatable) and bias which customers arrive as the day nears.
func _city_events(out: Array) -> void:
	var gala := _mk("event_autumn_gala", 2, "The Autumn Charity Gala")
	gala.min_day = 3
	gala.max_day = 6
	gala.repeatable = true
	gala.priority = 7
	gala.event_day = 6
	gala.event_occasion = 3  # Party
	gala.event_style = 3  # Fashion
	gala.bias_days = 3
	gala.bias_chance = 0.6
	gala.body = "The city's charity gala fills every diary — the set will want something bold."
	out.append(gala)

	var guild := _mk("event_guild_review", 2, "The Tailors' Guild Autumn Review")
	guild.min_day = 7
	guild.max_day = 10
	guild.repeatable = true
	guild.priority = 7
	guild.event_day = 10
	guild.event_occasion = 2  # Business
	guild.event_style = 1  # Classic
	guild.bias_days = 3
	guild.bias_chance = 0.6
	guild.body = "The Guild will tour the Row to judge craft and cut; a fine showing lifts a name."
	out.append(guild)


func _day_story(
	out: Array, id: String, day: int, prio: int, headline: String, body: String
) -> void:
	var ev := _mk(id, 0, headline)
	ev.exact_day = day
	ev.priority = prio
	ev.body = body
	out.append(ev)


## A NewsEvent with an id, kind and headline; other fields keep their defaults.
func _mk(id: String, kind: int, headline: String) -> Resource:
	var ev: Resource = load(NEWS_SCRIPT).new()
	ev.id = id
	ev.kind = kind
	ev.headline = headline
	return ev

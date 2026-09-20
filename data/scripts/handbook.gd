class_name Handbook

## Content for the Tailor's Handbook (opened at the bookshelf, or from the fitting
## mirror). Real tailoring knowledge — fabrics, patterns, styles — plus a Dress Codes
## chapter whose guidance is derived live from the configurable Catalog.dress_code so it
## always reflects the rules actually in play.
##
## Voice: Pops's working notes, per docs/WRITING_STYLE_GUIDE.md §3.3. Plain words a
## twelve-year-old reads without stopping, an opinion in every entry, and something the
## player can act on at the mirror.
##
## The Dress Codes chapter gives the rule as a tone phrase first and then names colours
## as examples: "Very dark colours; black or charcoal." The tone teaches the principle,
## the names stop it being ambiguous. It used to hint only ("keep to dark, sombre
## colours"), which was vaguer AND wordier, and for a while it listed every allowed
## colour, which read as a lookup table instead of a man's notes.

# [title, body]  (body supports a little BBCode: [b]…[/b])
const FABRICS := [
	[
		"Worsted Wool",
		"The everyday suit cloth. The wool is combed straight before it is spun, so the "
		+ "yarn comes out smooth and hard and the cloth holds a press.\n\n"
		+ "You will see it graded by a [b]Super[/b] number. Super 100s, 120s, 150s. The "
		+ "higher the number the finer and softer it gets, and the sooner it wears through "
		+ "at the elbow. Super 100s is enough for most people.\n\n"
		+ "Use it for anything. When you cannot decide, this is the answer.",
	],
	[
		"Flannel",
		"Wool with the top side brushed up until the weave goes soft and fuzzy. It does not "
		+ "shine, and it keeps a body warm.\n\n"
		+ "Grey flannel was the office uniform for most of my working life. I have cut "
		+ "hundreds of them and I never once got tired of it.\n\n"
		+ "Autumn and winter. Too hot for July.",
	],
	[
		"Tweed",
		"Scottish hill cloth, made to keep a shepherd dry. The rich took it up for shooting "
		+ "weekends and it has been country wear ever since.\n\n"
		+ "Thick, hairy, warm, rough on the hands. Browns and greens and greys, usually with "
		+ "a herringbone or a check woven into it.\n\n"
		+ "Nobody has ever looked sad in tweed, which is why I would keep it out of a "
		+ "funeral and out of an office.",
	],
	[
		"Mohair Blend",
		"Goat hair spun in with the wool: light, springs back out of a crease, and carries a "
		+ "faint shine.\n\n"
		+ "Summer and evening. The shine is the point of it, so do not put it on somebody "
		+ "who wants to go unnoticed.",
	],
	[
		"Linen",
		"Made from the flax plant. It creases if you look at it, it creases worse after an "
		+ "hour of wearing, and there is nothing to be done about that.\n\n"
		+ "Mrs. Auld came back to complain about the creasing. I had told her at the mirror "
		+ "and I told her again at the door.\n\n"
		+ "Cool as a cellar in August. Tan and natural, nothing darker than sand.",
	],
]

const PATTERNS := [
	[
		"Solid",
		"No pattern at all, which is the safest thing you can put on a body and the one to "
		+ "reach for when the day is a serious one.",
	],
	[
		"Pinstripe",
		"Thin straight lines running up and down a dark cloth, woven in rather than "
		+ "printed. A chalk stripe is the same idea, softer and wider.\n\n"
		+ "Bankers wore it in the twenties and have not stopped since. It makes a person "
		+ "look taller, which is most of why anyone wears it.\n\n"
		+ "I have never cut a brown one and I do not intend to start.",
	],
	[
		"Herringbone",
		"A zig-zag texture laid in rows, like the bones of a fish. That is where the name "
		+ "comes from.\n\n"
		+ "Quiet from a distance and interesting up close, which is a rare combination and "
		+ "the reason you find it in so much tweed. Safe nearly anywhere.",
	],
	[
		"Houndstooth",
		"Broken checks with little points on them, usually black and white. Shepherds in "
		+ "the Scottish Lowlands wove it first.\n\n"
		+ "It shouts. The small version is called puppytooth, and that one can be worn to "
		+ "work without anybody minding.",
	],
	[
		"Windowpane",
		"Lines crossing into large squares, like the panes of a window.\n\n"
		+ "It reads from across a street, which is either the point or the problem. I made "
		+ "one for a bookmaker in 1931 and he was delighted with himself for a year.\n\n"
		+ "One piece of it in a suit. Never two.",
	],
	[
		"Glen Check",
		"Small checks and large checks woven over one another, sometimes with a faint "
		+ "coloured line running through. Some call it Prince of Wales check.\n\n"
		+ "Edward VIII wore it and half the country followed him about. Smart without being "
		+ "stiff.",
	],
	[
		"Birdseye",
		"Tiny dots, each one a speck of the colour underneath showing through.\n\n"
		+ "From across a room it passes for plain, and up close it does not. Good for "
		+ "business, and good for the customer who tells you he dislikes pattern.",
	],
	[
		"Sharkskin",
		"Two colours of yarn woven together so the cloth shifts shade as the wearer turns. "
		+ "Navy and grey, mostly.\n\n"
		+ "It looks expensive. That is the whole idea, and there is no shame in it.",
	],
	[
		"Nailhead",
		"Dots the size of a nail head scattered on plain cloth. A step up from plain, and "
		+ "nobody notices unless they are standing close enough to smell your breakfast.",
	],
]

# [title, body, image]
const STYLES := [
	[
		"Old-School",
		"The way it was cut before the war. Heavy shoulders, a long jacket, dark cloth, and "
		+ "a waistcoat more often than not.\n\n"
		+ "Check and herringbone. Nothing invented after 1930.",
		"res://assets/handbook/styles/oldschool.jpg",
	],
	[
		"Classic",
		"Navy or grey, clean lines, and a pattern you have to look for. It belongs to no "
		+ "particular year, so it never goes out.\n\n"
		+ "When a customer cannot tell you what they want, cut them this.",
		"res://assets/handbook/styles/classic.jpg",
	],
	[
		"Modern",
		"A trimmer cut with fresher colour and a pointed lapel, made to look like this year "
		+ "rather than any other.",
		"res://assets/handbook/styles/modern.jpg",
	],
	[
		"Fashion",
		"Loud on purpose. Big patterns, colours you would not put on a banker, and the "
		+ "jacket need not match the trousers.\n\n"
		+ "This is the one brief where plain cloth will disappoint.",
		"res://assets/handbook/styles/fashion.jpg",
	],
]

# [occasion enum, title, prose]  (the rulebook summary is appended live)
const OCCASIONS := [
	[
		Enums.Occasion.WEDDING,
		"Weddings",
		"You are dressing a guest and not the groom. Nothing that pulls an eye off the "
		+ "couple, and nothing so dark that you are mistaken for the other sort of "
		+ "gathering. Old-School is the only cut I would let go black.",
	],
	[
		Enums.Occasion.FUNERAL,
		"Funerals",
		"Black, or charcoal if they cannot run to black. Nobody at a funeral should be "
		+ "looking at a suit, and it is your job to see that they do not.\n\n"
		+ "The younger houses have started sending people out in deep colours and a bit of "
		+ "texture. The table below says what the family will stand for now. I am only "
		+ "telling you what I would have done.",
	],
	[
		Enums.Occasion.BUSINESS,
		"Business",
		"A plain dark suit is the workhorse of this trade. You will cut more of these than "
		+ "everything else put together.\n\n"
		+ "Navy or charcoal. A quiet texture in the cloth is money without saying so. Keep "
		+ "the pattern small enough that it disappears at ten paces.",
	],
	[
		Enums.Occasion.PARTY,
		"Parties",
		"Here a person may enjoy themselves.\n\n"
		+ "Deeper colours, bigger patterns, cloth with something going on in it. If they "
		+ "ask you for something quiet, give it to them, but do not steer them there.",
	],
]

# Colour families (MaterialFactory palette indices), used to say what a rule is *like*
# before it says what it *is*.
const DARK := [0, 1, 3]  # Navy, Charcoal, Black
const EARTHY := [5, 7, 8, 9]  # Brown, Burgundy, Olive, Forest
const LIGHT := [2, 4]  # Light Grey, Tan
## Patterns that shout (Enums.Pattern indices): Houndstooth, Windowpane, Glen Check.
const BOLD_PATTERNS := [3, 4, 5]
## Patterns you have to look for: Solid, Birdseye, Sharkskin, Nailhead.
const QUIET_PATTERNS := [0, 6, 7, 8]
## Most colours a single line will name before it stops pretending to be a list.
const MAX_EXAMPLES := 3


static func chapters() -> Array:
	return [
		{"name": "Dress Codes", "entries": _dress_entries()},
		{"name": "Fabrics", "entries": _swatch_entries(FABRICS, "fabric")},
		{"name": "Patterns", "entries": _swatch_entries(PATTERNS, "pattern")},
		{"name": "Styles", "entries": _style_entries()},
	]


static func _style_entries() -> Array:
	var out: Array = []
	for e in STYLES:
		out.append({"title": e[0], "body": e[1], "preview": {"image": e[2]}})
	return out


# Fabrics/patterns get a preview swatch; the array index is the Enums index.
static func _swatch_entries(data: Array, kind: String) -> Array:
	var out: Array = []
	for i in data.size():
		out.append({"title": data[i][0], "body": data[i][1], "preview": {kind: i}})
	return out


static func _dress_entries() -> Array:
	var out: Array = []
	for e in OCCASIONS:
		out.append({"title": e[1], "body": "%s\n\n%s" % [e[2], _rule_summary(e[0])], "preview": {}})
	return out


## The rulebook in words: per style, what the colour should be like and which colours
## those are, then how loud the pattern may go, then the shirt and trousers. A colon
## carries each line — this text is generated, so the writing checker never sees it, and
## an em dash per style would put two dozen of them in a chapter on its own.
static func _rule_summary(occasion: int) -> String:
	if Catalog.dress_code == null:
		return ""
	var lines := ["[b]What to make[/b]"]
	for style in range(Enums.Style.size()):
		var rule: DressRule = Catalog.dress_code.rule_for(occasion, style)
		if rule == null:
			continue
		lines.append(
			"[b]%s[/b]: %s %s" % [Enums.style_name(style), _colors(rule), _patterns(rule)]
		)
	lines.append("")
	lines.append("[b]The shirt[/b]: %s" % _shirt_rule(occasion))
	lines.append(
		(
			"[b]The trousers[/b]: the same cloth and colour as the jacket, and either the "
			+ "jacket's pattern or none. A Fashion brief is the exception. There the "
			+ "trousers may be anything."
		)
	)
	lines.append("[b]The cloth[/b]: any of them. No occasion turns a cloth away.")
	return "\n".join(lines)


## "Very dark colours; black or charcoal." — the family first, then the names.
static func _colors(rule: DressRule) -> String:
	var cols: Array = rule.allowed_colors
	if cols.is_empty():
		return "any colour at all."
	var picked := _spread(cols)
	var names: Array[String] = []
	for c: int in picked:
		names.append(MaterialFactory.color_name(c).to_lower())
	if picked.size() < cols.size():
		return "%s, such as %s." % [_family(cols), _list(names)]
	return "%s; %s." % [_family(cols), _list(names)]


## Up to MAX_EXAMPLES colours that between them cover every family the rule allows, so a
## line reading "very dark, or one deep rich colour" never gives three dark examples and
## leaves the player guessing which the deep one was.
static func _spread(cols: Array) -> Array:
	if cols.size() <= MAX_EXAMPLES:
		return cols
	var out: Array = []
	for group: Array in [DARK, EARTHY, LIGHT, [6]]:
		for c: int in cols:
			if c in group and not (c in out):
				out.append(c)
				break
	for c: int in cols:
		if out.size() >= MAX_EXAMPLES:
			break
		if not (c in out):
			out.append(c)
	return out.slice(0, MAX_EXAMPLES)


## How loud the pattern may go. Named outright when the brief demands one, so the player
## is never told "it must have a pattern" without being told which.
static func _patterns(rule: DressRule) -> String:
	var pats: Array = rule.allowed_patterns
	if rule.require_pattern:
		var bold: Array[String] = []
		for p: int in pats:
			if p in BOLD_PATTERNS:
				bold.append(_pattern_word(p))
		if bold.is_empty():
			return "It must carry a pattern; plain cloth will not do."
		return "It must carry a bold pattern: %s." % _list(bold)
	if pats.is_empty():
		return "Any pattern."
	for p: int in pats:
		if p in BOLD_PATTERNS:
			return "A little pattern is welcome."
	var all_quiet := true
	for p: int in pats:
		if not (p in QUIET_PATTERNS):
			all_quiet = false
	if all_quiet:
		return "Keep the pattern so quiet you have to look for it."
	return "Nothing louder than a stripe or a herringbone."


## Which family the allowed colours belong to, said before they are named. Kept short on
## purpose: this is the part the player is meant to remember, and the examples after it
## are what stop it being ambiguous. A rule spanning three families is not summarisable
## in a phrase, so it says so instead of pretending.
static func _family(cols: Array) -> String:
	var dark := _any_in(cols, DARK)
	var earthy := _any_in(cols, EARTHY)
	var light := _any_in(cols, LIGHT)
	var blue := 6 in cols
	var families := int(dark) + int(earthy) + int(light) + int(blue)
	if families >= 3:
		return "A free hand with colour"
	if light and not dark:
		return "Light, warm colours"
	if earthy and not dark:
		return "Deep, rich colours"
	if earthy and dark:
		if _count_in(cols, EARTHY) > _count_in(cols, DARK):
			return "Deep, earthy colours"
		return "Very dark, or one deep rich colour"
	if light and dark:
		return "Dark colours, and grey"
	if blue and dark:
		return "Dark colours, or a true blue"
	return "Very dark colours"


## What the shirt may be for this occasion, from the DressCode tables.
static func _shirt_rule(occasion: int) -> String:
	var cols: Array[String] = []
	for c: int in DressCode.SHIRT_COLORS.get(occasion, []):
		cols.append(MaterialFactory.color_name(c).to_lower())
	var pats: Array[String] = []
	for p: int in DressCode.SHIRT_PATTERNS.get(occasion, []):
		pats.append(_pattern_word(p))
	if cols.is_empty() and pats.is_empty():
		return "anything they like."
	var pale := "pale and sensible; %s" % _list(cols.slice(0, MAX_EXAMPLES))
	if cols.is_empty():
		pale = "any colour"
	if pats.is_empty():
		return "%s. Any pattern." % pale
	return "%s. %s." % [pale, _sentence(_list(pats.slice(0, MAX_EXAMPLES)))]


## "Solid" is the enum's word; "plain" is the one a person uses.
static func _pattern_word(p: int) -> String:
	return "plain" if p == Enums.Pattern.SOLID else Enums.pattern_name(p).to_lower()


static func _any_in(values: Array, group: Array) -> bool:
	for v: int in values:
		if v in group:
			return true
	return false


static func _count_in(values: Array, group: Array) -> int:
	var n := 0
	for v: int in values:
		if v in group:
			n += 1
	return n


## ["a", "b", "c"] -> "a, b or c".
static func _list(names: Array[String]) -> String:
	if names.is_empty():
		return "anything"
	if names.size() == 1:
		return names[0]
	return "%s or %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


static func _sentence(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

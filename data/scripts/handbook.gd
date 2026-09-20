class_name Handbook

## Content for the Tailor's Handbook (opened at the bookshelf). Real-world tailoring
## knowledge — fabrics, patterns, styles — plus a Dress Codes chapter whose guidance is
## derived live from the configurable Catalog.dress_code so it always reflects the rules
## actually in play.
##
## Voice: Pops's working notes, per docs/WRITING_STYLE_GUIDE.md §3.3. Plain words, an
## opinion in every entry, and something the player can act on at the mirror. The Dress
## Codes chapter names the exact colours and patterns the rulebook allows, because a
## handbook that hints ("keep to dark, sombre colours") is both vaguer and wordier than
## one that simply says "navy, charcoal or black".

# [title, body]  (body supports a little BBCode: [b]…[/b])
const FABRICS := [
	[
		"Worsted Wool",
		"The everyday suit cloth. The wool is combed straight before it is spun, so the "
		+ "yarn comes out smooth and hard and the cloth holds a press.\n\n"
		+ "You will see it graded by a [b]Super[/b] number. Super 100s, 120s, 150s. The "
		+ "higher you go the finer and softer it gets, and the sooner it wears through at "
		+ "the elbow. Super 100s does for most people.\n\n"
		+ "Use it for anything. When you cannot decide, this is the answer.",
	],
	[
		"Flannel",
		"Wool with the face brushed up until the weave goes soft and fuzzy. It does not "
		+ "shine and it keeps a man warm.\n\n"
		+ "Grey flannel was the office uniform for most of my working life. I have cut "
		+ "hundreds of them and I never tired of it.\n\n"
		+ "Autumn and winter. Too hot for July.",
	],
	[
		"Tweed",
		"Scottish hill cloth, made to keep a shepherd dry. The gentry took it up for "
		+ "shooting weekends and it has been country wear ever since.\n\n"
		+ "Thick, hairy, warm, rough on the hands. Browns and greens and greys, usually "
		+ "with a herringbone or a check woven into it.\n\n"
		+ "Never for a funeral and never for an office. A cold party, a weekend in the "
		+ "country, and that is the whole list.",
	],
	[
		"Mohair Blend",
		"Goat hair spun in with the wool. Light, springs back out of a crease, and carries "
		+ "a faint shine.\n\n"
		+ "Summer and evening. The shine is the point of it, so do not put it on a man who "
		+ "wants to go unnoticed.",
	],
	[
		"Linen",
		"Flax. It creases if you look at it, it creases worse after an hour of wearing, "
		+ "and that is simply the cloth.\n\n"
		+ "A customer who minds should be told so at the mirror and not at the fitting. "
		+ "Cool as a cellar in August.\n\n"
		+ "Tan and natural. Nothing darker than sand.",
	],
]

const PATTERNS := [
	[
		"Solid",
		"No pattern at all, which is the safest thing you can put on a man and the one to "
		+ "reach for when the day is a serious one.",
	],
	[
		"Pinstripe",
		"Thin straight lines running up and down a dark cloth, woven in rather than "
		+ "printed. A chalk stripe is the same idea, softer and wider.\n\n"
		+ "Bankers wore it in the twenties and have not stopped. It makes a man look "
		+ "taller, and that is most of why anyone wears it.\n\n"
		+ "Navy or charcoal. Not brown.",
	],
	[
		"Herringbone",
		"A zig-zag texture laid in rows, like the bones of a fish. That is where the name "
		+ "comes from.\n\n"
		+ "Quiet from a distance and interesting up close. You find it mostly in tweed and "
		+ "in odd jackets. Safe nearly anywhere.",
	],
	[
		"Houndstooth",
		"Broken checks with little points on them, usually black and white. Shepherds in "
		+ "the Scottish Lowlands wove it first.\n\n"
		+ "It shouts. The small version is called puppytooth, and a man can wear that one "
		+ "to work without anybody minding.",
	],
	[
		"Windowpane",
		"Lines crossing into large squares, like the panes of a window.\n\n"
		+ "It reads from across a street, which is either the point or the problem. One "
		+ "piece of it in a suit. Never two.",
	],
	[
		"Glen Check",
		"Small checks and large checks woven over one another, sometimes with a faint "
		+ "coloured line running through. Also called Prince of Wales check.\n\n"
		+ "Edward VIII wore it and half the country followed him. Smart without being "
		+ "stiff about it.",
	],
	[
		"Birdseye",
		"Tiny dots, each one a speck of the colour underneath showing through.\n\n"
		+ "From across a room it passes for plain. Up close it does not. Good for "
		+ "business, and good for a man who thinks he dislikes pattern.",
	],
	[
		"Sharkskin",
		"Two colours of yarn woven together so the cloth shifts shade as the man turns.\n\n"
		+ "Navy and grey, mostly. It looks expensive, which is the whole idea.",
	],
	[
		"Nailhead",
		"Dots the size of a nail head scattered on a plain ground. A step up from plain, "
		+ "and nobody notices unless they are standing close.",
	],
]

# [title, body, image]
const STYLES := [
	[
		"Old-School",
		"The way it was cut before the war. Heavy shoulders, a full skirt to the jacket, "
		+ "dark cloth, and a waistcoat more often than not.\n\n"
		+ "Check and herringbone. Nothing invented after 1930.",
		"res://assets/handbook/styles/oldschool.jpg",
	],
	[
		"Classic",
		"Navy or grey, clean lines, and a pattern you have to look for. It belongs to no "
		+ "particular year, so it never goes out.\n\n"
		+ "When a customer cannot tell you what he wants, cut him this.",
		"res://assets/handbook/styles/classic.jpg",
	],
	[
		"Modern",
		"A trimmer cut with fresher colour and a pointed lapel, made to look like this "
		+ "year rather than any other.",
		"res://assets/handbook/styles/modern.jpg",
	],
	[
		"Fashion",
		"Loud on purpose. Big patterns, colours you would not put on a banker, and the "
		+ "jacket need not match the trousers.\n\n"
		+ "This is the one brief where a plain cloth will disappoint.",
		"res://assets/handbook/styles/fashion.jpg",
	],
]

# [occasion enum, title, prose]  (the rulebook summary is appended live)
const OCCASIONS := [
	[
		Enums.Occasion.WEDDING,
		"Weddings",
		"You are dressing a guest and not the groom. Nothing that pulls an eye off the "
		+ "couple.\n\n"
		+ "A daytime wedding in summer will take lighter greys, blues and tans. An evening "
		+ "one wants navy or charcoal. Keep black for the grandest sort, after dark.",
	],
	[
		Enums.Occasion.FUNERAL,
		"Funerals",
		"Black. Charcoal if black is beyond them.\n\n"
		+ "Nothing that shines and nothing with a loud check in it. Nobody at a funeral "
		+ "should be looking at a suit, and it is your job to see that they do not.",
	],
	[
		Enums.Occasion.BUSINESS,
		"Business",
		"A plain dark suit is the workhorse of this trade. You will cut more of these than "
		+ "everything else together.\n\n"
		+ "Navy or charcoal. A quiet texture in the cloth is money without saying so. Keep "
		+ "the pattern small enough that it disappears at ten paces.",
	],
	[
		Enums.Occasion.PARTY,
		"Parties",
		"Here a man may enjoy himself.\n\n"
		+ "Deeper colours, bigger patterns, cloth with something going on in it. The "
		+ "evening especially. If he asks you for something quiet, give it to him, but do "
		+ "not steer him there.",
	],
]


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


## The rulebook, in words: for each style, the colours and patterns the jacket may take,
## then the shirt and trouser rules. Named outright rather than hinted at — the player
## has to be able to read this and go straight to the mirror and build the suit.
static func _rule_summary(occasion: int) -> String:
	if Catalog.dress_code == null:
		return ""
	var lines := ["[b]What to make[/b]"]
	for style in range(Enums.Style.size()):
		var rule: DressRule = Catalog.dress_code.rule_for(occasion, style)
		if rule == null:
			continue
		lines.append(
			"[b]%s[/b] — %s. %s" % [Enums.style_name(style), _colors(rule), _patterns(rule)]
		)
	lines.append("")
	lines.append("[b]The shirt[/b] — %s" % _shirt_rule(occasion))
	lines.append(
		(
			"[b]The trousers[/b] — Same cloth and same colour as the jacket. The same "
			+ "pattern as the jacket, or plain. A Fashion brief is the exception: there he "
			+ "may mix them."
		)
	)
	return "\n".join(lines)


## "navy, charcoal or black" — the jacket colours this rule allows.
static func _colors(rule: DressRule) -> String:
	var out: Array[String] = []
	for c: int in rule.allowed_colors:
		out.append(MaterialFactory.color_name(c).to_lower())
	return _sentence(_list(out, "any colour"))


## "Pinstripe, herringbone or plain." plus the warning when the brief demands a pattern.
static func _patterns(rule: DressRule) -> String:
	var out: Array[String] = []
	for p: int in rule.allowed_patterns:
		out.append(_pattern_word(p))
	var s := _sentence(_list(out, "any pattern")) + "."
	if rule.require_pattern:
		s += " A plain cloth will not do here."
	return s


## What the shirt may be for this occasion, from the DressCode tables.
static func _shirt_rule(occasion: int) -> String:
	var cols: Array[String] = []
	for c: int in DressCode.SHIRT_COLORS.get(occasion, []):
		cols.append(MaterialFactory.color_name(c).to_lower())
	var pats: Array[String] = []
	for p: int in DressCode.SHIRT_PATTERNS.get(occasion, []):
		pats.append(_pattern_word(p))
	if cols.is_empty() and pats.is_empty():
		return "Anything he likes."
	return "%s. %s." % [_sentence(_list(cols, "any colour")), _sentence(_list(pats, "any pattern"))]


## "Solid" is the enum's word; "plain" is the one a person uses.
static func _pattern_word(p: int) -> String:
	return "plain" if p == Enums.Pattern.SOLID else Enums.pattern_name(p).to_lower()


## ["a", "b", "c"] -> "a, b or c". An empty list means the rule allows everything.
static func _list(names: Array[String], if_empty: String) -> String:
	if names.is_empty():
		return if_empty
	if names.size() == 1:
		return names[0]
	return "%s or %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


static func _sentence(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

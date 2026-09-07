class_name Handbook

## Content for the Tailor's Handbook (opened at the bookshelf). Real-world
## tailoring knowledge — fabrics, patterns, styles — plus a Dress Codes chapter
## whose guidance is described in plain language, derived live from the
## configurable Catalog.dress_code so it always reflects the rules in play.

# Colour tone buckets (MaterialFactory palette indices).
const LIGHT_COLORS := [2, 4]  # Light Grey, Tan
const MID_COLORS := [6]  # Blue
# Patterns that read as bold / statement-making (Enums.Pattern indices).
const BOLD_PATTERNS := [3, 4, 5]  # Houndstooth, Windowpane, Glen Check

# [title, body]  (body supports a little BBCode: [b]…[/b])
const FABRICS := [
	[
		"Worsted Wool",
		"Wool spun from long fibres that are combed straight ([i]worsted[/i]) before "
		+ "being tightly twisted into a smooth, hard yarn. The result is crisp, durable "
		+ "cloth that holds a sharp press.\n\n"
		+ "Named after Worstead, a village in Norfolk, England, where the technique grew "
		+ "up in the Middle Ages. Fineness is graded by [b]Super[/b] numbers — Super 100s, "
		+ "120s and up — with higher numbers finer, softer and more delicate.\n\n"
		+ "The default suiting cloth: worn year-round, from the boardroom to black tie.",
	],
	[
		"Flannel",
		"A soft wool with a lightly brushed (napped) surface that blurs the weave for a "
		+ "warm, matte look. It can be worsted- or woollen-spun, then teaselled to raise "
		+ "the fuzzy face.\n\n"
		+ "The name likely comes from the Welsh [i]gwlanen[/i]; production centred on Wales "
		+ "from the 17th century. Grey flannel became a 20th-century icon — the uniform of "
		+ "the mid-century professional.\n\n"
		+ "A cool-weather cloth: autumn and winter suits and odd trousers.",
	],
	[
		"Tweed",
		"A rugged, coarse woollen cloth, woven thick and slightly hairy for warmth and "
		+ "weather resistance. The name is thought to come from the Scots [i]tweel[/i] "
		+ "(twill), possibly via the River Tweed.\n\n"
		+ "Born in the Scottish Highlands and Ireland as hard-wearing rural cloth; Harris "
		+ "Tweed is still hand-woven in the Outer Hebrides and legally protected. Victorian "
		+ "gentry adopted it for country estates and sport.\n\n"
		+ "Country and casual, in earthy browns and greens, herringbones and checks — a "
		+ "cold-weather cloth.",
	],
	[
		"Mohair Blend",
		"Fibre from the Angora goat, usually blended with wool. It is crisp and light with "
		+ "a natural sheen, springs back from creases, and breathes well.\n\n"
		+ "Angora goats trace to the Ankara region of Turkey (from which 'Angora' takes its "
		+ "name). Mohair-wool 'tonik' suits were the sharp, shiny look of the 1960s Mods.\n\n"
		+ "Its lustre and light weight make it a favourite for summer suits and for evening "
		+ "and formal wear.",
	],
	[
		"Linen",
		"Woven from the fibres of the flax plant. It is wonderfully cool and breathable, "
		+ "but wrinkles readily — a rumpled charm that is part of the look.\n\n"
		+ "One of the oldest textiles known: linen wrapped the pharaohs of ancient Egypt. "
		+ "Flax is retted, beaten and combed before spinning, a labour-intensive process "
		+ "that long made it prized.\n\n"
		+ "The quintessential hot-weather, casual cloth, at home in tan and natural tones.",
	],
]

const PATTERNS := [
	[
		"Solid",
		"No pattern at all — the most versatile and most formal choice. It lets the "
		+ "cloth's colour and texture speak, and flatters almost any occasion. The safest "
		+ "place to start.",
	],
	[
		"Pinstripe",
		"Thin, evenly spaced vertical lines on a darker ground, woven in (a 'chalk stripe' "
		+ "is softer and wider).\n\n"
		+ "It rose with 1920s finance and the power suits of the 1980s, lending height and "
		+ "authority. Reads formal — best in navy or charcoal.",
	],
	[
		"Herringbone",
		"A broken-twill weave whose diagonal reverses back and forth to form rows of Vs, "
		+ "like a fish's skeleton — hence the name.\n\n"
		+ "An ancient structure found in Roman brickwork and jewellery long before cloth. "
		+ "Subtle and textured; a mainstay of tweeds and jackets.",
	],
	[
		"Houndstooth",
		"Broken checks with sharp, pointed 'teeth', traditionally in black and white. It "
		+ "comes from the woven shepherd's checks of the Scottish Lowlands.\n\n"
		+ "Bold and full of character; the smaller 'puppytooth' is more restrained and "
		+ "easier to wear day to day.",
	],
	[
		"Windowpane",
		"Widely spaced horizontal and vertical lines crossing into large squares, like the "
		+ "panes of a window.\n\n"
		+ "Striking and fashion-forward — it draws the eye, so it is best worn with "
		+ "confidence and in moderation.",
	],
	[
		"Glen Check",
		"Also called Glen plaid or Prince of Wales check: small and large woven checks "
		+ "combined, often with a faint coloured overcheck.\n\n"
		+ "Designed on the Glenurquhart estate in 19th-century Scotland and made famous by "
		+ "Edward VIII. Smart, British and surprisingly versatile.",
	],
	[
		"Birdseye",
		"A tiny dotted texture created by a small repeating weave, each 'eye' a speck of "
		+ "the ground colour.\n\n"
		+ "Near-solid from across a room, with quiet depth up close. Refined and very "
		+ "business-appropriate.",
	],
	[
		"Sharkskin",
		"A weave that alternates two colours of yarn to give a smooth, softly iridescent "
		+ "surface that shifts in the light.\n\n"
		+ "Sleek and modern-classic — think Rat Pack navy and grey suits of the 1960s.",
	],
	[
		"Nailhead",
		"Minute dots like the heads of nails scattered on a solid ground, from a small "
		+ "two-tone weave.\n\n"
		+ "A step more interesting than plain while still reading as near-solid — a quiet, "
		+ "dependable business texture.",
	],
]

# [title, body, image]
const STYLES := [
	[
		"Old-School",
		"Heritage tailoring. Structured shoulders, a fuller, draped cut, sober colour and "
		+ "time-honoured patterns like check and herringbone, often with a waistcoat. Formal "
		+ "and unmistakably traditional — the look of old money and old films.",
		"res://assets/handbook/styles/oldschool.jpg",
	],
	[
		"Classic",
		"The balanced middle ground: clean lines, versatile navy and grey, understated "
		+ "pattern. It borrows from no single era and so never dates — the dependable "
		+ "default of a well-dressed wardrobe.",
		"res://assets/handbook/styles/classic.jpg",
	],
	[
		"Modern",
		"A trimmer, contemporary cut with fresher colour, peak lapels and confident pattern "
		+ "mixing. Sharp and current — made to look of-the-moment.",
		"res://assets/handbook/styles/modern.jpg",
	],
	[
		"Fashion",
		"Expressive and trend-led. Bolder colour, statement patterns like windowpane, and "
		+ "playful touches — a bow tie, an unexpected cloth. Cut to be noticed.",
		"res://assets/handbook/styles/fashion.jpg",
	],
]

# [occasion enum, title, prose]  (plain-language guidance is appended live)
const OCCASIONS := [
	[
		Enums.Occasion.WEDDING,
		"Weddings",
		"Dress to celebrate without upstaging the couple. Daytime and summer weddings "
		+ "welcome lighter greys, blues and tans; evening calls for navy or charcoal. Keep "
		+ "black for the most formal, after-dark affairs.",
	],
	[
		Enums.Occasion.FUNERAL,
		"Funerals",
		"Sombre and respectful above all. Black and charcoal, plain weaves and minimal "
		+ "pattern are the safe tradition. Modern mourning permits deep, muted colours — "
		+ "never anything bright or attention-seeking.",
	],
	[
		Enums.Occasion.BUSINESS,
		"Business",
		"The lounge suit is the workhorse of professional life. Navy and charcoal read as "
		+ "competent and trustworthy; a quiet texture adds authority. Understated wins.",
	],
	[
		Enums.Occasion.PARTY,
		"Parties",
		"Here you have room to express yourself. Richer colours, bolder patterns and "
		+ "textured cloth all come into their own, especially in the evening. Have some fun.",
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


# Plain-language guidance per style, derived from the rule (no exact lists).
static func _rule_summary(occasion: int) -> String:
	if Catalog.dress_code == null:
		return ""
	var lines := ["[b]What works here[/b]"]
	for style in range(Enums.Style.size()):
		var rule: DressRule = Catalog.dress_code.rule_for(occasion, style)
		if rule == null:
			continue
		var tone := _tone_phrase(rule.allowed_colors)
		var pattern := _pattern_phrase(rule)
		lines.append("%s — %s, %s." % [Enums.style_name(style), tone, pattern])
	return "\n".join(lines)


static func _tone_phrase(colors: Array) -> String:
	if colors.is_empty():
		return "colour is open"
	for c in colors:
		if c in LIGHT_COLORS:
			return "lighter, brighter tones are welcome"
	for c in colors:
		if c in MID_COLORS:
			return "rich, mid-depth colour suits it"
	return "keep to dark, sombre colours"


static func _pattern_phrase(rule: DressRule) -> String:
	if rule.require_pattern:
		return "and it wants a bold, statement pattern"
	for p in rule.allowed_patterns:
		if p in BOLD_PATTERNS:
			return "a little pattern is fine"
	return "go easy on pattern — subtle or none"

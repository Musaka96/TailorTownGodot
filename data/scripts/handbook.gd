class_name Handbook

## Content for the Tailor's Handbook (opened at the bookshelf). Real-world
## tailoring knowledge — fabrics, patterns, styles — plus a Dress Codes chapter
## whose "Accepted looks" tables are generated live from the configurable
## Catalog.dress_code, so the book always teaches the rules actually in play.

# [title, body]  (body supports a little BBCode: [b]…[/b])
const FABRICS := [
	[
		"Worsted Wool",
		"Wool spun from long, combed fibres into a smooth, tightly-twisted yarn. The "
		+ "default suiting cloth: crisp, hard-wearing and it holds a press. Fineness is "
		+ "graded by [b]Super[/b] numbers (Super 100s, 120s…) — higher is finer and more "
		+ "delicate. Worn year-round, from business to formal.",
	],
	[
		"Flannel",
		"A soft wool with a lightly brushed, napped surface that hides the weave and gives "
		+ "a warm, matte look. A cool-weather cloth — autumn and winter. Grey flannel is a "
		+ "menswear icon: understated and versatile.",
	],
	[
		"Tweed",
		"A rugged, coarse woollen cloth born in the British Isles. Heavy, textured and "
		+ "warm — country and casual rather than formal. Traditionally woven in herringbone "
		+ "and checks, in earthy browns, greens and greys. A cold-weather favourite.",
	],
	[
		"Mohair Blend",
		"Fibre from the Angora goat, usually blended with wool. Crisp and lightweight with "
		+ "a subtle sheen, it resists wrinkles and breathes well — excellent for summer and "
		+ "for evening or formal wear where a little lustre flatters.",
	],
	[
		"Linen",
		"Woven from flax. Wonderfully cool and breathable, but it creases readily — which "
		+ "is part of its relaxed charm. The quintessential hot-weather, casual cloth, at "
		+ "home in tan and light, natural tones.",
	],
]

const PATTERNS := [
	[
		"Solid",
		"No pattern at all — the most versatile and most formal choice. Lets the "
		+ "cloth's colour and texture speak. Safe for any occasion.",
	],
	[
		"Pinstripe",
		"Thin vertical stripes on a darker ground. Reads formal and authoritative — "
		+ "the banker's and power-suit classic. Best in navy or charcoal.",
	],
	[
		"Herringbone",
		"A broken-twill weave forming a zig-zag like a fish's skeleton. Subtle, "
		+ "textured and versatile; common in jackets and tweeds.",
	],
	[
		"Houndstooth",
		"Broken checks with sharp, jagged points. Bold and full of character. The "
		+ "smaller 'puppytooth' is more restrained and easier to wear.",
	],
	[
		"Windowpane",
		"Widely spaced lines crossing into large squares, like a window frame. "
		+ "Fashion-forward and eye-catching — wear with confidence, in moderation.",
	],
	[
		"Glen Check",
		"Also 'Prince of Wales' check: small and large woven checks together, "
		+ "sometimes with a coloured overcheck. Smart, British and versatile.",
	],
	[
		"Birdseye",
		"A tiny dotted texture from a small repeating weave. Near-solid from a "
		+ "distance, with quiet depth up close. Very business-appropriate.",
	],
	[
		"Sharkskin",
		"A two-toned weave that gives a smooth, softly iridescent sheen. Sleek and "
		+ "modern-classic, usually in navy or grey.",
	],
	[
		"Nailhead",
		"Minute dots like the heads of nails on a solid ground. A refined, almost-"
		+ "solid texture — a step more interesting than plain for business suits.",
	],
]

const STYLES := [
	[
		"Old-School",
		"Heritage tailoring. Structured shoulders, a fuller cut, sober colour and "
		+ "time-honoured patterns like pinstripe and herringbone. Formal and traditional.",
	],
	[
		"Classic",
		"The balanced middle ground: clean lines, versatile navy and grey, understated "
		+ "pattern. Never quite in fashion, so never out of it.",
	],
	[
		"Modern",
		"A trimmer, contemporary cut with fresher colour and subtle texture — sharkskin, "
		+ "glen check. Sharp and current, but still restrained.",
	],
	[
		"Fashion",
		"Expressive and trend-led. Lighter, bolder colour, statement patterns like "
		+ "windowpane and houndstooth, and unexpected cloth. Made to be noticed.",
	],
]

# [occasion enum, title, prose]  (an "Accepted looks" table is appended live)
const OCCASIONS := [
	[
		Enums.Occasion.WEDDING,
		"Weddings",
		"Dress to celebrate without upstaging the couple. Daytime and summer weddings "
		+ "welcome lighter greys, blues and tans; evening calls for navy or charcoal. "
		+ "Keep black for the most formal, after-dark affairs.",
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
		"The lounge suit is the workhorse of professional life. Navy and charcoal read "
		+ "as competent and trustworthy; pinstripe, sharkskin and nailhead add quiet "
		+ "authority. Understated wins.",
	],
	[
		Enums.Occasion.PARTY,
		"Parties",
		"Here you have room to express yourself. Richer colours, bolder patterns and "
		+ "textured cloth all come into their own, especially in the evening. Have fun.",
	],
]


static func chapters() -> Array:
	return [
		{"name": "Dress Codes", "entries": _dress_entries()},
		{"name": "Fabrics", "entries": _entries(FABRICS)},
		{"name": "Patterns", "entries": _entries(PATTERNS)},
		{"name": "Styles", "entries": _entries(STYLES)},
	]


static func _entries(data: Array) -> Array:
	var out: Array = []
	for e in data:
		out.append({"title": e[0], "body": e[1]})
	return out


static func _dress_entries() -> Array:
	var out: Array = []
	for e in OCCASIONS:
		out.append({"title": e[1], "body": "%s\n\n%s" % [e[2], _rule_summary(e[0])]})
	return out


static func _rule_summary(occasion: int) -> String:
	if Catalog.dress_code == null:
		return ""
	var lines := ["[b]Accepted looks[/b]"]
	for style in range(Enums.Style.size()):
		var rule: DressRule = Catalog.dress_code.rule_for(occasion, style)
		if rule == null:
			continue
		var colors := _names(rule.allowed_colors, true)
		var patterns := _names(rule.allowed_patterns, false)
		var extra := "  (needs a bold pattern)" if rule.require_pattern else ""
		lines.append("[b]%s[/b] — %s; %s%s" % [Enums.style_name(style), colors, patterns, extra])
	return "\n".join(lines)


static func _names(indices: Array, is_color: bool) -> String:
	if indices.is_empty():
		return "any"
	var names: Array = []
	for i in indices:
		names.append(MaterialFactory.color_name(i) if is_color else Enums.pattern_name(i))
	return ", ".join(names)

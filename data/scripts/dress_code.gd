class_name DressCode
extends Resource

## The configurable rulebook: one DressRule per (occasion, style). Edit
## res://data/dress_code.tres in the Inspector to tune what suits each brief, or
## regenerate the defaults with tools/build_dress_code.gd.

## Occasion -> style -> [shirt colours, shirt patterns]; an empty list means anything
## goes. Colours are global MaterialFactory indices: 10 white, 11 sky, 12 pink,
## 13 lavender, 14 ecru, 15 mint, 16 butter, 17 pale grey. White is for the sober briefs
## (the old ways, business, mourning); a modern or fashion brief, and any party, wants
## a colour, so the white shirt is a choice and not a default. Shirts are judged in code
## rather than per-rule data since they share one light palette across occasions.
const SHIRTS := {
	Enums.Occasion.WEDDING:
	{
		Enums.Style.OLDSCHOOL: [[10, 14], [Enums.Pattern.SOLID, Enums.Pattern.END_ON_END]],
		Enums.Style.CLASSIC:
		[
			[10, 11, 12, 14],
			[Enums.Pattern.SOLID, Enums.Pattern.BENGAL_STRIPE, Enums.Pattern.END_ON_END],
		],
		Enums.Style.MODERN:
		[
			[11, 12, 13, 15],
			[Enums.Pattern.SOLID, Enums.Pattern.END_ON_END, Enums.Pattern.BENGAL_STRIPE],
		],
		Enums.Style.FASHION: [[12, 13, 15, 16], []],
	},
	Enums.Occasion.FUNERAL:
	{
		Enums.Style.OLDSCHOOL: [[10], [Enums.Pattern.SOLID]],
		Enums.Style.CLASSIC: [[10, 17], [Enums.Pattern.SOLID, Enums.Pattern.END_ON_END]],
		Enums.Style.MODERN: [[10, 17, 11], [Enums.Pattern.SOLID, Enums.Pattern.END_ON_END]],
		Enums.Style.FASHION:
		[
			[17, 13, 11],
			[Enums.Pattern.SOLID, Enums.Pattern.END_ON_END, Enums.Pattern.BENGAL_STRIPE],
		],
	},
	Enums.Occasion.BUSINESS:
	{
		Enums.Style.OLDSCHOOL:
		[
			[10, 11],
			[Enums.Pattern.SOLID, Enums.Pattern.BENGAL_STRIPE, Enums.Pattern.UNIVERSITY_STRIPE],
		],
		Enums.Style.CLASSIC:
		[
			[10, 11, 14, 17],
			[
				Enums.Pattern.SOLID,
				Enums.Pattern.BENGAL_STRIPE,
				Enums.Pattern.UNIVERSITY_STRIPE,
				Enums.Pattern.END_ON_END,
			],
		],
		Enums.Style.MODERN:
		[
			[11, 17, 13],
			[Enums.Pattern.SOLID, Enums.Pattern.END_ON_END, Enums.Pattern.BENGAL_STRIPE],
		],
		Enums.Style.FASHION: [[12, 13, 15, 16], []],
	},
	Enums.Occasion.PARTY:
	{
		Enums.Style.OLDSCHOOL:
		[
			[14, 16, 11],
			[Enums.Pattern.GINGHAM, Enums.Pattern.TATTERSALL, Enums.Pattern.UNIVERSITY_STRIPE],
		],
		Enums.Style.CLASSIC: [[11, 12, 14, 16], []],
		Enums.Style.MODERN: [[12, 13, 15, 11], []],
		Enums.Style.FASHION:
		[
			[12, 13, 15, 16],
			[
				Enums.Pattern.GINGHAM,
				Enums.Pattern.TATTERSALL,
				Enums.Pattern.BENGAL_STRIPE,
				Enums.Pattern.UNIVERSITY_STRIPE,
			],
		],
	},
}

@export var rules: Array[DressRule] = []


## Shirt colours this brief takes (empty = any).
static func shirt_colors(occasion: int, style: int) -> Array:
	return _shirt_entry(occasion, style)[0]


## Shirt patterns this brief takes (empty = any).
static func shirt_patterns(occasion: int, style: int) -> Array:
	return _shirt_entry(occasion, style)[1]


static func _shirt_entry(occasion: int, style: int) -> Array:
	var by_style: Dictionary = SHIRTS.get(occasion, {})
	return by_style.get(style, [[], []])


func rule_for(occasion: int, style: int) -> DressRule:
	for r in rules:
		if int(r.occasion) == occasion and int(r.style) == style:
			return r
	return null


func hint_for(occasion: int, style: int) -> String:
	var r := rule_for(occasion, style)
	return r.hint if r != null else ""


## Judge a whole design against the brief + budget: the jacket must fit the rule for
## this occasion/style, the trousers must read as a matched suit with the jacket, and
## the shirt must be occasion-appropriate. Returns
## { suitable: bool, quote: int, reason: String, reasons: Array[String] }.
func evaluate(occasion: int, style: int, design: Dictionary, budget: int) -> Dictionary:
	var jacket: Dictionary = design.get(Enums.GarmentType.JACKET, {})
	var quote := Pricing.suit_quote(design)
	var rule := rule_for(occasion, style)
	var reasons: Array[String] = []
	if rule == null or jacket.is_empty():
		return {"suitable": false, "quote": quote, "reason": "Hmm…", "reasons": reasons}

	reasons.append_array(_jacket_reasons(rule, occasion, jacket))
	var pants: Dictionary = design.get(Enums.GarmentType.PANTS, {})
	if not pants.is_empty():
		reasons.append_array(_pants_reasons(style, jacket, pants))
	var shirt: Dictionary = design.get(Enums.GarmentType.SHIRT, {})
	if not shirt.is_empty():
		reasons.append_array(_shirt_reasons(occasion, style, shirt))
	if quote > budget:
		reasons.append("it's over my budget")

	var suitable := reasons.is_empty()
	var reason := "This is perfect — I'll take it!" if suitable else "Not quite: " + reasons[0]
	return {"suitable": suitable, "quote": quote, "reason": reason, "reasons": reasons}


## Ways the jacket breaks the brief (empty = fine): colour, required/allowed pattern,
## and cloth, all from the authored DressRule.
func _jacket_reasons(rule: DressRule, occasion: int, jacket: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	var occ := Enums.occasion_name(occasion).to_lower()
	if not _ok(rule.allowed_colors, int(jacket.get("color", -1))):
		var cols: Array[String] = []
		for c: int in rule.allowed_colors:
			cols.append(MaterialFactory.color_name(c).to_lower())
		reasons.append("the jacket colour isn't right for a %s. %s" % [occ, _would_do(cols)])
	var pattern := int(jacket.get("pattern", -1))
	var pats := _pattern_words(rule)
	if rule.require_pattern and pattern == Enums.Pattern.SOLID:
		reasons.append("the jacket needs a bolder pattern. %s" % _would_do(pats))
	elif not _ok(rule.allowed_patterns, pattern):
		reasons.append("not that pattern for the jacket. %s" % _would_do(pats))
	if not _ok(rule.allowed_fabrics, int(jacket.get("fabric", -1))):
		reasons.append("try a different cloth for the jacket")
	return reasons


## "Plain, herringbone or sharkskin would do." — what the customer would take instead,
## so a no always says what a yes looks like.
static func _would_do(names: Array[String]) -> String:
	if names.is_empty():
		return ""
	var said := names[0]
	if names.size() > 1:
		said = "%s or %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]
	return "%s would do." % (said.substr(0, 1).to_upper() + said.substr(1))


static func _pattern_words(rule: DressRule) -> Array[String]:
	var out: Array[String] = []
	for p: int in rule.allowed_patterns:
		if rule.require_pattern and p == Enums.Pattern.SOLID:
			continue
		var word := "plain" if p == Enums.Pattern.SOLID else Enums.pattern_name(p).to_lower()
		out.append(word)
	return out


## The trousers should read as a matched suit with the jacket: the same cloth and
## colour, with a pattern that matches the jacket or stays plain. Fashion briefs are
## the exception — they welcome contrasting jacket/trouser separates, so anything goes.
func _pants_reasons(style: int, jacket: Dictionary, pants: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if style == Enums.Style.FASHION:
		return reasons
	var same_fabric := int(pants.get("fabric", -1)) == int(jacket.get("fabric", -2))
	var same_color := int(pants.get("color", -1)) == int(jacket.get("color", -2))
	if not (same_fabric and same_color):
		reasons.append("the trousers should match the jacket")
		return reasons
	var jp := int(jacket.get("pattern", 0))
	var pp := int(pants.get("pattern", -1))
	if pp != jp and pp != Enums.Pattern.SOLID:
		reasons.append("the trousers' pattern should match the jacket, or stay plain")
	return reasons


## The shirt should suit the brief: a colour and a pattern from its row of SHIRTS. A
## refusal says what would do, like the jacket's.
func _shirt_reasons(occasion: int, style: int, shirt: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	var occ := Enums.occasion_name(occasion).to_lower()
	var cols := shirt_colors(occasion, style)
	var pats := shirt_patterns(occasion, style)
	if not _ok(cols, int(shirt.get("color", -1))):
		var names: Array[String] = []
		for c: int in cols:
			names.append(MaterialFactory.color_name(c).to_lower())
		reasons.append("not that shirt for a %s. %s" % [occ, _would_do(names)])
	if not _ok(pats, int(shirt.get("pattern", -1))):
		var words: Array[String] = []
		for p: int in pats:
			words.append("plain" if p == Enums.Pattern.SOLID else Enums.pattern_name(p).to_lower())
		reasons.append("the shirt wants another pattern. %s" % _would_do(words))
	return reasons


func _ok(allowed: Array, value: int) -> bool:
	return allowed.is_empty() or value in allowed

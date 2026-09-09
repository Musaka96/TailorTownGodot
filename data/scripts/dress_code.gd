class_name DressCode
extends Resource

## The configurable rulebook: one DressRule per (occasion, style). Edit
## res://data/dress_code.tres in the Inspector to tune what suits each brief, or
## regenerate the defaults with tools/build_dress_code.gd.

## Occasion -> acceptable shirt colours (global MaterialFactory indices; the pale
## shirtings are 10..17). Empty means anything goes. Shirts are judged in code (not
## per-rule data) since they share one light palette across occasions.
const SHIRT_COLORS := {
	Enums.Occasion.WEDDING: [10, 11, 12, 13, 14],  # white, sky, pink, lavender, ecru
	Enums.Occasion.FUNERAL: [10, 17],  # white, pale grey
	Enums.Occasion.BUSINESS: [10, 11, 14, 17],  # white, sky, ecru, pale grey
	Enums.Occasion.PARTY: [],  # anything goes
}
## Occasion -> acceptable shirt patterns. Empty means anything goes.
const SHIRT_PATTERNS := {
	Enums.Occasion.WEDDING:
	[
		Enums.Pattern.SOLID,
		Enums.Pattern.BENGAL_STRIPE,
		Enums.Pattern.UNIVERSITY_STRIPE,
		Enums.Pattern.END_ON_END,
	],
	Enums.Occasion.FUNERAL: [Enums.Pattern.SOLID, Enums.Pattern.END_ON_END],
	Enums.Occasion.BUSINESS:
	[
		Enums.Pattern.SOLID,
		Enums.Pattern.BENGAL_STRIPE,
		Enums.Pattern.UNIVERSITY_STRIPE,
		Enums.Pattern.END_ON_END,
	],
	Enums.Occasion.PARTY: [],
}

@export var rules: Array[DressRule] = []


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
		reasons.append_array(_pants_reasons(jacket, pants))
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
		reasons.append("the jacket colour isn't right for a %s" % occ)
	var pattern := int(jacket.get("pattern", -1))
	if rule.require_pattern and pattern == Enums.Pattern.SOLID:
		reasons.append("the jacket needs a bolder pattern")
	elif not _ok(rule.allowed_patterns, pattern):
		reasons.append("that jacket pattern doesn't suit the style")
	if not _ok(rule.allowed_fabrics, int(jacket.get("fabric", -1))):
		reasons.append("try a different cloth for the jacket")
	return reasons


## The trousers should read as a matched suit with the jacket: the same cloth and
## colour, with a pattern that matches the jacket or stays plain.
func _pants_reasons(jacket: Dictionary, pants: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
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


## The shirt should suit the occasion: a light, sensible colour and a pattern that
## isn't too casual. Fashion looks get a free pass to be bold.
func _shirt_reasons(occasion: int, style: int, shirt: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if style == Enums.Style.FASHION:
		return reasons
	var occ := Enums.occasion_name(occasion).to_lower()
	var cols: Array = SHIRT_COLORS.get(occasion, [])
	var pats: Array = SHIRT_PATTERNS.get(occasion, [])
	if not _ok(cols, int(shirt.get("color", -1))):
		reasons.append("that shirt colour is a bit much for a %s" % occ)
	if not _ok(pats, int(shirt.get("pattern", -1))):
		reasons.append("that shirt pattern is too casual for a %s" % occ)
	return reasons


func _ok(allowed: Array, value: int) -> bool:
	return allowed.is_empty() or value in allowed

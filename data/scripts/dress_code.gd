class_name DressCode
extends Resource

## The configurable rulebook: one DressRule per (occasion, style). Edit
## res://data/dress_code.tres in the Inspector to tune what suits each brief, or
## regenerate the defaults with tools/build_dress_code.gd.

@export var rules: Array[DressRule] = []


func rule_for(occasion: int, style: int) -> DressRule:
	for r in rules:
		if int(r.occasion) == occasion and int(r.style) == style:
			return r
	return null


func hint_for(occasion: int, style: int) -> String:
	var r := rule_for(occasion, style)
	return r.hint if r != null else ""


## Judge a design's JACKET against the brief + budget. Returns
## { suitable: bool, quote: int, reason: String, reasons: Array[String] }.
func evaluate(occasion: int, style: int, design: Dictionary, budget: int) -> Dictionary:
	var jacket: Dictionary = design.get(Enums.GarmentType.JACKET, {})
	var quote := Pricing.suit_quote(design)
	var rule := rule_for(occasion, style)
	var reasons: Array[String] = []
	if rule == null or jacket.is_empty():
		return {"suitable": false, "quote": quote, "reason": "Hmm…", "reasons": reasons}

	var color := int(jacket.get("color", -1))
	var pattern := int(jacket.get("pattern", -1))
	var fabric := int(jacket.get("fabric", -1))
	var occasion_word := Enums.occasion_name(occasion).to_lower()

	if not _ok(rule.allowed_colors, color):
		reasons.append("the colour isn't right for a %s" % occasion_word)
	if rule.require_pattern and pattern == Enums.Pattern.SOLID:
		reasons.append("it needs a bolder pattern")
	elif not _ok(rule.allowed_patterns, pattern):
		reasons.append("that pattern doesn't suit the style")
	if not _ok(rule.allowed_fabrics, fabric):
		reasons.append("try a different cloth")
	if quote > budget:
		reasons.append("it's over my budget")

	var suitable := reasons.is_empty()
	var reason := "This is perfect — I'll take it!" if suitable else "Not quite: " + reasons[0]
	return {"suitable": suitable, "quote": quote, "reason": reason, "reasons": reasons}


func _ok(allowed: Array, value: int) -> bool:
	return allowed.is_empty() or value in allowed

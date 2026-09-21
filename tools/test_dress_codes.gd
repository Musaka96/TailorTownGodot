extends SceneTree

## Headless test that the Handbook and the customers agree about every dress code. For
## each occasion × style rule: every pattern the rule allows is named on its Handbook
## line, and a suit built from any allowed colour and pattern (matched trousers, a shirt
## the occasion allows, within budget) is accepted. A refused jacket pattern tells the
## player what would do instead. The playtest: Wedding · Classic read "nothing louder than
## a stripe or a herringbone", but a stripe was refused.
##   godot --headless --path . --script res://tools/test_dress_codes.gd

const JACKET := 2  # Enums.GarmentType.JACKET
const PANTS := 1
const SHIRT := 0

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var catalog: Node = root.get_node("Catalog")
	var code: Resource = catalog.dress_code
	var enums: Variant = load("res://data/scripts/enums.gd")
	var handbook: GDScript = load("res://data/scripts/handbook.gd")
	var dress: GDScript = load("res://data/scripts/dress_code.gd")
	var rules := 0
	var unsaid: Array[String] = []
	var refused: Array[String] = []
	for occasion in 4:
		var summary: String = handbook.call("_rule_summary", occasion).to_lower()
		for style in 4:
			var rule: Resource = code.rule_for(occasion, style)
			if rule == null:
				continue
			rules += 1
			var where := "%s·%s" % [enums.occasion_name(occasion), enums.style_name(style)]
			for p: int in rule.allowed_patterns:
				var word: String = "plain" if p == 0 else enums.pattern_name(p).to_lower()
				if not (rule.require_pattern and p == 0) and not (word in summary):
					unsaid.append("%s %s" % [where, word])
				if rule.require_pattern and p == 0:
					continue
				for c: int in rule.allowed_colors:
					var verdict: Dictionary = code.evaluate(
						occasion, style, _suit(c, p, occasion, style, dress), 100000
					)
					if not verdict["suitable"]:
						refused.append("%s c%d p%d: %s" % [where, c, p, verdict["reason"]])
	_check(rules >= 12, "(setup) %d dress rules" % rules)
	_check(unsaid.is_empty(), "every allowed pattern is named in the Handbook %s" % str(unsaid))
	_check(
		refused.is_empty(), "a suit made to the Handbook is accepted %s" % str(refused.slice(0, 4))
	)

	# Wedding · Classic: a stripe is refused, and the customer says what would do.
	var no: Dictionary = code.evaluate(0, 1, _suit(0, 1, 0, 1, dress), 100000)
	_check(not no["suitable"], "Wedding · Classic turns down a pinstripe")
	_check("herringbone" in str(no["reason"]), "and names what would do: %s" % no["reason"])
	_shirts(code, dress, handbook)
	_tastes(code, dress)
	_finish()


## Every shirt colour and pattern a brief takes is named in its Handbook chapter, and the
## white shirt is no longer a pass everywhere: a modern wedding wants a colour.
func _shirts(code: Resource, dress: GDScript, handbook: GDScript) -> void:
	var unsaid: Array[String] = []
	var white_ok := 0
	for occasion in 4:
		var summary: String = handbook.call("_rule_summary", occasion).to_lower()
		for style in 4:
			for c: int in dress.shirt_colors(occasion, style):
				var name: String = load("res://data/scripts/material_factory.gd").color_name(c)
				if not name.to_lower() in summary:
					unsaid.append("%d·%d %s" % [occasion, style, name])
			if 10 in dress.shirt_colors(occasion, style):
				white_ok += 1
	_check(unsaid.is_empty(), "every shirt colour is named in the Handbook %s" % str(unsaid))
	_check(white_ok <= 8, "a white shirt suits at most half the briefs (%d/16)" % white_ok)
	var suit := _suit(0, 0, 0, 2, dress)
	suit[SHIRT]["color"] = 10
	var no: Dictionary = code.evaluate(0, 2, suit, 100000)
	_check(not no["suitable"], "Wedding · Modern turns down a white shirt")
	_check("sky blue" in str(no["reason"]).to_lower(), "and names one: %s" % no["reason"])


## Colour tastes: a like is always a colour the brief takes, a dislike always leaves one,
## a suit in the disliked colour is refused, and one in the liked colour is noted.
func _tastes(code: Resource, dress: GDScript) -> void:
	var pref_script: GDScript = load("res://data/scripts/customer_preference.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad: Array[String] = []
	var said := 0
	for i in 400:
		var p: Resource = pref_script.new()
		p.occasion = i % 4
		p.style = (i / 4) % 4
		p.budget = 100000
		p.display_name = "Mr. Test%d" % i
		p.roll_taste(rng)
		if p.taste_line() != "":
			said += 1
		var rule: Resource = code.rule_for(p.occasion, p.style)
		var shirt_cols: Array = dress.shirt_colors(p.occasion, p.style)
		for c: int in [p.likes_color, p.dislikes_color]:
			if c < 0:
				continue
			var pool: Array = shirt_cols if c >= 10 else Array(rule.allowed_colors)
			if not c in pool:
				bad.append("%s c%d not in the brief" % [p.display_name, c])
			if c == p.dislikes_color and pool.size() < 2:
				bad.append("%s dislikes the only colour" % p.display_name)
	_check(bad.is_empty(), "tastes stay inside the brief %s" % str(bad.slice(0, 3)))
	_check(said > 150 and said < 330, "a good share voice a colour (%d/400)" % said)

	var fussy: Resource = pref_script.new()
	fussy.occasion = 2
	fussy.style = 1
	fussy.budget = 100000
	fussy.dislikes_color = 0  # navy
	var navy := _suit(0, 0, 2, 1, dress)
	var verdict: Dictionary = fussy.evaluate(navy)
	_check(not verdict["suitable"], "a disliked navy suit is refused")
	_check("navy" in str(verdict["reason"]), "and they say so: %s" % verdict["reason"])
	_check(fussy.evaluate(_suit(1, 0, 2, 1, dress))["suitable"], "charcoal is fine")
	fussy.dislikes_color = -1
	fussy.likes_color = 2  # light grey
	_check(fussy.evaluate(_suit(2, 0, 2, 1, dress))["liked"], "the liked colour is noticed")
	_check(not fussy.evaluate(navy)["liked"], "and navy isn't it")
	_check(fussy.evaluate(navy)["suitable"], "a like is not a must")


## A suit to the letter: the jacket in colour `c` and pattern `p`, matching trousers, and
## the first shirt colour and pattern the brief allows.
func _suit(c: int, p: int, occasion: int, style: int, dress: GDScript) -> Dictionary:
	var jacket := {"fabric": 0, "color": c, "pattern": p, "style_idx": 0}
	var shirt_cols: Array = dress.shirt_colors(occasion, style)
	var shirt_pats: Array = dress.shirt_patterns(occasion, style)
	# An empty list means the occasion takes any shirt.
	var col: int = shirt_cols[0] if not shirt_cols.is_empty() else 0
	var pat: int = shirt_pats[0] if not shirt_pats.is_empty() else 0
	var shirt := {"fabric": 5, "color": col, "pattern": pat, "style_idx": 0}
	return {JACKET: jacket, PANTS: jacket.duplicate(), SHIRT: shirt}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_dress_codes: ALL PASS")
		quit(0)
	else:
		print("test_dress_codes: %d FAILURE(S)" % _failures.size())
		quit(1)

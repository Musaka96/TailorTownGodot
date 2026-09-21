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
						occasion, style, _suit(c, p, occasion, dress), 100000
					)
					if not verdict["suitable"]:
						refused.append("%s c%d p%d: %s" % [where, c, p, verdict["reason"]])
	_check(rules >= 12, "(setup) %d dress rules" % rules)
	_check(unsaid.is_empty(), "every allowed pattern is named in the Handbook %s" % str(unsaid))
	_check(
		refused.is_empty(), "a suit made to the Handbook is accepted %s" % str(refused.slice(0, 4))
	)

	# Wedding · Classic: a stripe is refused, and the customer says what would do.
	var no: Dictionary = code.evaluate(0, 1, _suit(0, 1, 0, dress), 100000)
	_check(not no["suitable"], "Wedding · Classic turns down a pinstripe")
	_check("herringbone" in str(no["reason"]), "and names what would do: %s" % no["reason"])
	_finish()


## A suit to the letter: the jacket in colour `c` and pattern `p`, matching trousers, and
## the first shirt colour and pattern the occasion allows.
func _suit(c: int, p: int, occasion: int, dress: GDScript) -> Dictionary:
	var jacket := {"fabric": 0, "color": c, "pattern": p, "style_idx": 0}
	var shirt_cols: Array = dress.SHIRT_COLORS.get(occasion, [0])
	var shirt_pats: Array = dress.SHIRT_PATTERNS.get(occasion, [0])
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

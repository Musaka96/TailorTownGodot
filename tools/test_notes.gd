extends SceneTree

## Headless test for the mirror's two voices: every objection comes back as a notepad
## note (the tailor's shorthand with the fix) and a spoken line (CustomerLines), parallel
## to `reasons`. For each occasion a deliberately wrong design and a right one are
## judged; the notes line up with the reasons, sit in a known notepad slot, and asking
## twice moves the customer on to another line. Taste objections come first and keep to
## the same shape.
##   godot --headless --path . --script res://tools/test_notes.gd

const JACKET := 2  # Enums.GarmentType.JACKET
const PANTS := 1
const SHIRT := 0
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const LINES_SCRIPT := "res://data/scripts/customer_lines.gd"
const FACTORY_SCRIPT := "res://data/scripts/material_factory.gd"
const PARTS := ["suit", "shirt", "price"]
const SUIT_COLORS := 10  # MaterialFactory.SUIT_COLOR_COUNT
const SHIRT_COLORS := [10, 11, 12, 13, 14, 15, 16, 17]

var _failures: Array[String] = []
var _code: Resource
var _lines: GDScript


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_code = root.get_node("Catalog").dress_code
	_lines = load(LINES_SCRIPT)
	for occasion in 4:
		_occasion(occasion)
	_taste()
	_finish()


func _occasion(occasion: int) -> void:
	var style := 1  # Classic
	var p := _pref(occasion, style)
	var rule: Resource = _code.rule_for(occasion, style)
	var wrong := _wrong_design(rule, occasion, style)
	p.budget = 10
	var first: Dictionary = p.evaluate(wrong)
	var second: Dictionary = p.evaluate(wrong)
	p.budget = 100000
	var where := "occasion %d" % occasion
	_check(not first["suitable"], "%s: the wrong design is refused" % where)
	_shape(first, where + " wrong")
	var kinds: int = _lines.variants(0, occasion)  # Kind.JACKET_COLOR leads
	if kinds > 1:
		var a: String = first["notes"][0]["said"]
		var b: String = second["notes"][0]["said"]
		_check(a != b, "%s: asking twice gets another line (%s / %s)" % [where, a, b])
	for n: Dictionary in first["notes"]:
		print("    [%s] %s  |  %s" % [n["part"], n["note"], n["said"]])
	var right: Dictionary = p.evaluate(_right_design(rule, occasion, style))
	_check(right["suitable"], "%s: the right design is taken (%s)" % [where, right["reasons"]])
	_shape(right, where + " right")
	print("    happy: " + str(right["said_happy"]))
	p.likes_color = int(rule.allowed_colors[0])
	var liked: Dictionary = p.evaluate(_right_design(rule, occasion, style))
	var word := str(load(FACTORY_SCRIPT).color_name(p.likes_color)).to_lower()
	var happy := str(liked["said_happy"])
	_check(word in happy.to_lower(), "%s: a liked yes names the colour (%s)" % [where, happy])


## Stated dislike, a suit they own, a quiet dislike: taste leads, in the same shape.
func _taste() -> void:
	var p := _pref(2, 1)  # Business · Classic: navy, charcoal or light grey
	p.dislikes_color = 0
	p.owned_suits = [[0, 0]]
	p.quiet_dislike = {"kind": "pattern", "value": 0}
	var r: Dictionary = p.evaluate(_suit(0, 0, 10, 0))
	_shape(r, "taste")
	_check(r["notes"].size() >= 3, "three taste notes (%d)" % r["notes"].size())
	if r["notes"].size() >= 3:
		_check(r["notes"][0]["said"] == "Not navy. I did say.", "the dislike keeps its line")
		_check(r["notes"][1]["note"] == "has this one already", "the owned note")
		_check(str(r["notes"][2]["note"]).begins_with("no plain"), "the quiet note")
	for n: Dictionary in r["notes"]:
		print("    [%s] %s  |  %s" % [n["part"], n["note"], n["said"]])
	var q := _pref(2, 1)
	q.dislikes_color = 12  # pink shirt
	var s: Dictionary = q.evaluate(_suit(0, 0, 12, 0))
	_shape(s, "shirt dislike")
	_check(s["notes"][0]["part"] == "shirt", "a shirting dislike goes on the shirt line")


## notes parallel reasons; every note has the three keys, non-empty; parts known.
func _shape(r: Dictionary, where: String) -> void:
	var notes: Array = r.get("notes", [])
	var reasons: Array = r.get("reasons", [])
	_check(
		notes.size() == reasons.size(),
		"%s: %d notes for %d reasons" % [where, notes.size(), reasons.size()]
	)
	_check(str(r.get("said_happy", "")) != "", "%s: said_happy is set" % where)
	for n: Dictionary in notes:
		var ok := true
		for key in ["part", "note", "said"]:
			ok = ok and str(n.get(key, "")) != ""
		_check(ok, "%s: note has part, note and said (%s)" % [where, n])
		_check(str(n.get("part", "")) in PARTS, "%s: part is known (%s)" % [where, n.get("part")])


## A jacket colour outside the rule, plain, odd trousers, the wrong shirt, a tiny budget.
func _wrong_design(rule: Resource, occasion: int, style: int) -> Dictionary:
	var color := 0
	for c in SUIT_COLORS:
		if not c in rule.allowed_colors:
			color = c
			break
	var shirts: Array = _code.shirt_colors(occasion, style)
	var shirt := 10
	for c: int in SHIRT_COLORS:
		if not c in shirts:
			shirt = c
			break
	var d := _suit(color, 0, shirt, 0)
	d[PANTS]["color"] = (color + 1) % SUIT_COLORS
	return d


func _right_design(rule: Resource, occasion: int, style: int) -> Dictionary:
	var pattern := 0
	for pat: int in rule.allowed_patterns:
		if not (rule.require_pattern and pat == 0):
			pattern = pat
			break
	var shirts: Array = _code.shirt_colors(occasion, style)
	var pats: Array = _code.shirt_patterns(occasion, style)
	var shirt := int(shirts[0]) if not shirts.is_empty() else 10
	var shirt_pat := int(pats[0]) if not pats.is_empty() else 0
	return _suit(int(rule.allowed_colors[0]), pattern, shirt, shirt_pat)


func _suit(color: int, pattern: int, shirt: int, shirt_pattern: int) -> Dictionary:
	var suit := {"fabric": 0, "color": color, "pattern": pattern}
	return {
		JACKET: suit.duplicate(),
		PANTS: suit.duplicate(),
		SHIRT: {"fabric": 5, "color": shirt, "pattern": shirt_pattern},
	}


func _pref(occasion: int, style: int) -> Resource:
	var p: Resource = load(PREF_SCRIPT).new()
	p.display_name = "Mr. Test"
	p.occasion = occasion
	p.style = style
	p.budget = 100000
	return p


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("NOTES: all checks passed")
		quit(0)
	else:
		for f in _failures:
			print("  - " + f)
		print("NOTES: %d failed" % _failures.size())
		quit(1)

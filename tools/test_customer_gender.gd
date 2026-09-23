extends SceneTree

## Headless test that a customer's title and body are one decision
## (CustomerPreference.gender): every "Mr." walks in on a man's body, every "Ms." on a
## woman's, a "Dr." on whichever their brief settled; their head fits it; a passer-by
## talked inside is named to fit the body they already have; and an older save that
## paired a "Mr." with a woman's look (or booked an appointment with no gender) still
## comes back as a man.
##   godot --headless --path . --script res://tools/test_customer_gender.gd
## Exit code is non-zero on any failed assertion.

const MALE := 1
const FEMALE := 2
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const WARDROBE_SCRIPT := "res://data/scripts/wardrobe.gd"

var _failures: Array[String] = []
var _manager: Node
## Loaded at run time: the classes lean on autoloads a --script can't see at compile time.
var _pref_cls: GDScript
var _wardrobe: GDScript


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	_manager = get_first_node_in_group("customer_manager")
	_pref_cls = load(PREF_SCRIPT)
	_wardrobe = load(WARDROBE_SCRIPT)
	_walk_ins()
	_pitched()
	_old_save_regular()
	_old_save_appointment()
	var rng := RandomNumberGenerator.new()
	var tut: Resource = root.get_node("Tutorial").tutorial_pref()
	_check(tut.settle_gender(rng) == MALE, "the tutorial's Mr. Pemberton is a man")
	_finish()


## Thirty walk-ins: title, brief and body agree, and the head is one for that body.
func _walk_ins() -> void:
	var bad := PackedStringArray()
	var seen := {}
	for _i in 30:
		var cust: Node = _manager.call("_spawn", Vector3.ZERO, true, {"kind": "walk_in"})
		var why := _mismatch(cust)
		if why != "":
			bad.append(why)
		seen[int(cust.gender)] = true
		cust.free()
	_check(bad.is_empty(), "30 walk-ins: every title matches the body %s" % ", ".join(bad))
	_check(seen.has(MALE) and seen.has(FEMALE), "30 walk-ins include men and women")


## Strollers already have a body; the brief they get when talked inside is named to fit.
func _pitched() -> void:
	var bad := PackedStringArray()
	for _i in 20:
		var cust: Node = _manager.call("_spawn", Vector3.ZERO, false)
		var body := int(cust.gender)
		var pref: Resource = _pref_cls.random_pref(RandomNumberGenerator.new(), "", body)
		cust.preference = pref
		var title: int = _pref_cls.title_gender(pref.display_name)
		if int(pref.gender) != body or (title != 0 and title != body):
			bad.append("%s on %d" % [pref.display_name, body])
		cust.free()
	_check(bad.is_empty(), "a pitched passer-by is named to fit their body %s" % ", ".join(bad))


## A regular saved before the fix as "Mr." with a woman's look comes back a man, with a
## man's head (the same head each visit), and keeps the rest of their colouring.
func _old_save_regular() -> void:
	var clientele: Node = root.get_node("Clientele")
	var look := {
		"skin": Color(0.8, 0.6, 0.5),
		"head": _head_for(FEMALE),
		"hair": _head_for(FEMALE),
		"hair_color": Color.BLACK,
		"eyes": "green",
		"glasses": "",
		"gender": FEMALE,
	}
	clientele.restore({"people": {"Mr. Oldsave": {"look": look, "loyalty": 2, "visits": 1}}})
	var heads := []
	for _i in 2:
		var pref: Resource = _pref_cls.random_pref(RandomNumberGenerator.new(), "Mr. Oldsave")
		var cust: Node = _spawn_with(pref)
		_manager.call("_dress_as", cust, clientele.look("Mr. Oldsave"), "Mr. Oldsave")
		var why := _mismatch(cust)
		_check(why == "" and int(cust.gender) == MALE, "old-save Mr. with a woman's look %s" % why)
		_check(cust.eye_color == "green", "and keeps their eyes")
		heads.append(int(cust.head_index))
		cust.free()
	_check(heads[0] == heads[1], "and the corrected head is the same every visit")
	clientele.reset()


## An appointment booked before the fix has no gender: the title settles it.
func _old_save_appointment() -> void:
	var a := {"name": "Ms. Booked", "occasion": 0, "style": 0, "budget": 400}
	var pref: Resource = _manager.call("_pref_from_appointment", a)
	var cust := _spawn_with(pref)
	_check(int(cust.gender) == FEMALE and _mismatch(cust) == "", "old appointment Ms. is a woman")
	cust.free()


## A customer dressed for `pref` the way _spawn does it.
func _spawn_with(pref: Resource) -> Node:
	var cust: Node = _manager.call("_spawn", Vector3.ZERO, false)
	cust.preference = pref
	_manager.call("_dress", cust)
	return cust


## "" when title, brief and body agree and the head fits the body; else what's wrong.
func _mismatch(cust: Node) -> String:
	var pref: Resource = cust.preference
	var body := int(cust.gender)
	var title: int = _pref_cls.title_gender(pref.display_name)
	if int(pref.gender) != body:
		return "%s: brief %d, body %d" % [pref.display_name, int(pref.gender), body]
	if title != 0 and title != body:
		return "%s on body %d" % [pref.display_name, body]
	var heads: Array = _wardrobe.library().heads
	var i := int(cust.head_index)
	if i < heads.size() and heads[i] != null and not heads[i].fits(body):
		return "%s: head %d is for the other body" % [pref.display_name, i]
	return ""


## Some head index for `gender` (the one a woman's look would have saved).
func _head_for(gender: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return maxi(0, _wardrobe.random_head_index(gender, rng))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_customer_gender: ALL PASS")
		quit(0)
	else:
		print("test_customer_gender: %d FAILURE(S)" % _failures.size())
		quit(1)

extends SceneTree

## Headless test: the tutorial's worktable and sewing steps match the bench games the
## player will actually meet. For every cutting and sewing variant it checks that
##   - the step builds a checklist ending in the right controls,
##   - every key the checklist coaches is one that game really shows in its key prompts
##     (the coach mark finds its target by that label, so a stale key points at nothing),
##   - the games whose controls can't be guessed get a mentor introduction,
##   - the progress flags the checklist ticks on are ones the game reports,
##   - the explanation waits until the cloth is on the bench, not the start of the step,
##   - every station the pin is sent to really exists in the shop.
##   godot --headless --path . --script res://tools/test_tutorial_bench.gd

var _failures: Array[String] = []
var _tutorial: Node
var _config: Resource
var _shop: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 4:
		await process_frame
	_tutorial = root.get_node("Tutorial")
	_config = root.get_node("Config").get("data")
	_shop = load("res://main.tscn").instantiate()
	root.add_child(_shop)
	for _i in 4:
		await process_frame
	var cut_before: int = _config.get("cut_variant")
	var sew_before: int = _config.get("sew_variant")
	for v in 3:
		_cutting(v)
	for v in 2:
		_sewing(v)
	_pacing("worktable", "Worktable")
	_pacing("sew", "SewingMachine")
	_stations_exist()
	_config.set("cut_variant", cut_before)
	_config.set("sew_variant", sew_before)
	_finish()


func _cutting(variant: int) -> void:
	_config.set("cut_variant", variant)
	var game: Node = load("res://ui/cut_variants.gd").create(variant)
	root.add_child(game)
	_idle(game)
	var checks: Array = _tutorial.call("_cut_checks")
	var tag: String = ["steer", "allowance", "strokes"][variant]
	_check(checks.size() >= 3, "cutting %s: a full worktable checklist" % tag)
	_keys_exist(game, checks.slice(2), "cutting %s" % tag)
	var talks: bool = not _tutorial.call("_bench_lines", "worktable").is_empty()
	_check(talks == (variant != 0), "cutting %s: mentor explains it only if needed" % tag)
	_flags_reported(game, checks, "cutting %s" % tag)
	game.queue_free()


func _sewing(variant: int) -> void:
	_config.set("sew_variant", variant)
	var game: Node = load("res://ui/sew_variants.gd").create(variant)
	root.add_child(game)
	_idle(game)
	var checks: Array = _tutorial.call("_sew_checks")
	var tag: String = ["rhythm", "pedal"][variant]
	_check(checks.size() >= 2, "sewing %s: a sewing checklist" % tag)
	_keys_exist(game, checks.slice(2), "sewing %s" % tag)
	var lines: PackedStringArray = _tutorial.call("_bench_lines", "sew")
	_check(lines.is_empty() == (variant == 0), "sewing %s: mentor explains it only if needed" % tag)
	if variant == 1:
		_backstitch(game, checks)
		var said := "".join(lines)
		_check("pedal" in said and "pin" in said, "sewing pedal: mentor covers pedal and pins")
		_check("backstitch" in said, "sewing pedal: mentor covers backstitching")
		_check(checks.size() == 6, "sewing pedal: carry, place, pedal, pins, lock, cut")
	_flags_reported(game, checks, "sewing %s" % tag)
	game.queue_free()


## The backstitch is only pointed at once the needle reaches the end mark, and during the
## tutorial E won't cut the thread until the seam really is locked.
func _backstitch(game: Node, checks: Array) -> void:
	var line: Array = []
	for c: Array in checks:
		if c[1] == "bench:locked":
			line = c
	var flags: Dictionary = _tutorial.get("_flags")
	flags.clear()
	_check(not _tutorial.call("_coach_ready", line), "backstitch: not pointed at mid-seam")
	flags["bench:at_end"] = true
	_check(_tutorial.call("_coach_ready", line), "backstitch: pointed at on the end mark")
	flags.clear()
	var was_active: bool = _tutorial.get("_active")
	_tutorial.set("_active", true)
	_check(game.call("_must_lock"), "backstitch: the tutorial won't cut an unlocked seam")
	var says: String = game.call("_end_situation")
	_check("backstitch" in says and "cut" not in says, "backstitch: the status asks for it")
	(game.get("_locked") as Dictionary)["end"] = true
	_check(not game.call("_must_lock"), "backstitch: once locked, E cuts the thread")
	(game.get("_locked") as Dictionary)["end"] = false
	_tutorial.set("_active", false)
	_check(not game.call("_must_lock"), "backstitch: optional outside the tutorial")
	_tutorial.set("_active", was_active)


## The bench explanation is held back until the cloth is on `station`: nothing when the
## step begins, nothing while the bench is empty, and the introduction the moment it isn't.
func _pacing(step_id: String, station_name: String) -> void:
	_config.set("cut_variant", 1)
	_config.set("sew_variant", 1)
	var steps: Array = _tutorial.get("STEPS")
	var index := -1
	for i in steps.size():
		if steps[i]["id"] == step_id:
			index = i
	var step: Dictionary = steps[index]
	var at_start: PackedStringArray = _tutorial.call("_mentor_lines", step)
	_check(at_start.is_empty(), "%s: nothing is explained as the step begins" % step_id)
	_tutorial.set("_step", index)
	(_tutorial.get("_flags") as Dictionary).clear()
	_tutorial.set("_pending", {})
	var bench: Node = _shop.find_child(station_name, true, false)
	var spoke: bool = _tutorial.call("_brief_on_arrival")
	_check(not spoke, "%s: still quiet while the %s is empty" % [step_id, station_name])
	var cloth := Node3D.new()
	bench.set("_item", cloth)
	spoke = _tutorial.call("_brief_on_arrival")
	var queued: Dictionary = _tutorial.get("_pending")
	_check(spoke and not queued.is_empty(), "%s: explained once it's on the bench" % step_id)
	_tutorial.set("_pending", {})
	spoke = _tutorial.call("_brief_on_arrival")
	_check(not spoke, "%s: and only once" % step_id)
	bench.set("_item", null)
	cloth.free()
	(_tutorial.get("_flags") as Dictionary).clear()
	_tutorial.set("_step", 0)


## Every station a step or checklist line sends the pin to, or waits on, is in the shop —
## a misspelt name would just leave the player with no pin.
func _stations_exist() -> void:
	var named := {}
	for step: Dictionary in _tutorial.get("STEPS"):
		if step.get("point", "") != "":
			named[step["point"]] = true
		var brief: String = step.get("brief", "")
		if brief.begins_with("on:"):
			named[brief.trim_prefix("on:")] = true
	var every: Array = [_tutorial.call("_cut_checks"), _tutorial.call("_sew_checks")]
	for step: Dictionary in _tutorial.get("STEPS"):
		every.append(step.get("checks", []))
	for lines: Array in every:
		for c: Array in lines:
			# "" = no station of its own; "@..." = a person, found at run time.
			if c.size() > 4 and str(c[4]) != "" and not str(c[4]).begins_with("@"):
				named[c[4]] = true
	for station: String in named:
		var found: Node = _shop.find_child(station, true, false)
		_check(found != null, "the shop has a %s for the pin to point at" % station)


## Keep an un-started game from drawing or ticking — its hosts always start() it first,
## and with nothing loaded it has no outline to paint.
func _idle(game: Node) -> void:
	(game as CanvasItem).visible = false
	game.set_process(false)
	game.set_physics_process(false)


## Every coached key in `checks` is one of the labels the game puts on its key prompts.
func _keys_exist(game: Node, checks: Array, label: String) -> void:
	var shown: Array = []
	if game.has_method("_hint_pairs"):
		for pair: Array in game.call("_hint_pairs"):
			shown.append(pair[0])
	else:
		shown = _v1_keys(game)
	for c: Array in checks:
		var key: String = c[2]
		if key != "":
			_check(key in shown, "%s: coached key '%s' is on its prompts %s" % [label, key, shown])


## The v1 games set their prompts inline rather than through _hint_pairs; read them back.
func _v1_keys(game: Node) -> Array:
	if game.has_method("_rebuild_hints"):
		game.call("_rebuild_hints")  # its chrome was built in _ready
	var out: Array = []
	for n in game.find_children("*", "Label", true, false):
		if (n as Label).get_parent() is PanelContainer:
			out.append((n as Label).text)
	return out


## Every "bench:<flag>" the checklist ticks on is a flag the game reports.
func _flags_reported(game: Node, checks: Array, label: String) -> void:
	var flags: Dictionary = game.call("coach_flags")
	for c: Array in checks:
		for cond: String in [c[1], c[5] if c.size() > 5 else ""]:
			if cond.begins_with("bench:"):
				var flag := cond.trim_prefix("bench:")
				_check(flags.has(flag), "%s: the game reports '%s'" % [label, flag])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_tutorial_bench: ALL PASS")
		quit(0)
	else:
		print("test_tutorial_bench: %d FAILURE(S)" % _failures.size())
		quit(1)

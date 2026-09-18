extends SceneTree

## Headless test: the tutorial's worktable and sewing steps match the bench games the
## player will actually meet. For every cutting and sewing variant it checks that
##   - the step builds a checklist ending in the right controls,
##   - every key the checklist coaches is one that game really shows in its key prompts
##     (the coach mark finds its target by that label, so a stale key points at nothing),
##   - the games whose controls can't be guessed get a mentor introduction,
##   - the progress flags the checklist ticks on are ones the game reports.
##   godot --headless --path . --script res://tools/test_tutorial_bench.gd

var _failures: Array[String] = []
var _tutorial: Node
var _config: Resource


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 4:
		await process_frame
	_tutorial = root.get_node("Tutorial")
	_config = root.get_node("Config").get("data")
	var cut_before: int = _config.get("cut_variant")
	var sew_before: int = _config.get("sew_variant")
	for v in 3:
		_cutting(v)
	for v in 2:
		_sewing(v)
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
	_keys_exist(game, checks.slice(1), "sewing %s" % tag)
	var lines: PackedStringArray = _tutorial.call("_bench_lines", "sew")
	_check(lines.is_empty() == (variant == 0), "sewing %s: mentor explains it only if needed" % tag)
	if variant == 1:
		var said := "".join(lines)
		_check("pedal" in said and "pin" in said, "sewing pedal: mentor covers pedal and pins")
		_check("backstitch" in said, "sewing pedal: mentor covers backstitching")
		_check(checks.size() == 5, "sewing pedal: pedal, pins, backstitch, cut thread")
	_flags_reported(game, checks, "sewing %s" % tag)
	game.queue_free()


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
		var cond: String = c[1]
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

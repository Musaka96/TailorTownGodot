extends SceneTree

## Headless test: the morning paper follows the Menus interface size (Settings >
## Interface), whether the slider moves before the paper first opens, while it is open, or
## while it is closed between openings; the scaled spread pivots on its own centre. Puts
## the player's Menus size back afterwards.
##   godot --headless --path . --script res://tools/test_newspaper_scale.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var settings: Node = root.get_node("Settings")
	var ui: Node = root.get_node("UI")
	var paper: Control = ui.get("newspaper")
	var menus := "menus"
	var original: float = settings.call("ui_scale_of", menus)
	var spread: Control = _attached(paper)
	_check(spread != null, "the paper has a control attached to an interface size")
	if spread == null:
		_finish()
		return
	_check(str(spread.get_meta("ui_scale_cat")) == menus, "it follows the Menus size")

	# Before the first open.
	settings.call("set_ui_scale", menus, 1.3)
	paper.call("open")
	await process_frame
	await process_frame
	_check(paper.visible, "paper opened")
	_report(spread, "set before open", 1.3)

	# While open.
	settings.call("set_ui_scale", menus, 0.7)
	await process_frame
	_report(spread, "set while open", 0.7)

	# While closed, then reopened.
	paper.call("close")
	settings.call("set_ui_scale", menus, 1.2)
	paper.call("open")
	await process_frame
	await process_frame
	_report(spread, "set while closed, reopened", 1.2)

	paper.call("close")
	settings.call("set_ui_scale", menus, original)
	_finish()


func _report(spread: Control, label: String, want: float) -> void:
	var centre := spread.size * 0.5
	print(
		(
			"  %s: scale %s pivot %s size %s (centre %s)"
			% [label, spread.scale, spread.pivot_offset, spread.size, centre]
		)
	)
	_check(spread.scale.is_equal_approx(Vector2.ONE * want), "%s: scale %.2f" % [label, want])
	_check(spread.pivot_offset.is_equal_approx(centre), "%s: pivot on the centre" % label)
	_check(spread.size.x > 0.0 and spread.size.y > 0.0, "%s: laid out" % label)


func _attached(node: Node) -> Control:
	for n in node.find_children("*", "Control", true, false):
		if n.has_meta("ui_scale_cat"):
			return n
	return null


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("NEWSPAPER SCALE: all checks passed")
	else:
		print("NEWSPAPER SCALE: %d failure(s): %s" % [_failures.size(), _failures])
	quit(1 if not _failures.is_empty() else 0)

extends SceneTree

## Headless test for pitching the shop to passers-by (StreetPitch): a pitch that lands
## turns the stroller into a walk-in heading for the counter; one that doesn't leaves them
## strolling on, un-pitchable again; and there's no pitching while the shop is full.
##   godot --headless --path . --script res://tools/test_pitch.gd
## Exit code is non-zero on any failed assertion.

var _failures: Array[String] = []
var _manager: Node
var _cfg: Resource


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
	_cfg = root.get_node("Config").data
	_cfg.pitch_cooldown_s = 0.0
	_manager.shopper_chance = 1.0
	var player: Node = current_scene.find_child("Player", true, false)

	# A pitch that fails: they answer, then stroll on — and can't be asked twice.
	_cfg.pitch_base_chance = 0.0
	_cfg.pitch_tier_bonus = 0.0
	var walker := _stroller()
	_check(walker != null, "a passer-by can be pitched to")
	if walker == null:
		_finish()
		return
	_check("Pitch the shop" in walker.get_interaction_prompt(player), "the prompt offers a pitch")
	walker.interact(player)
	_check(walker.get_interaction_prompt(player) == "", "only one pitch per passer-by")
	await create_timer(4.5).timeout
	_check(is_instance_valid(walker) and walker.preference == null, "a no: they stroll on")
	_check(not _manager.busy(), "and the shop's slot stays free")

	# A pitch that lands: they become a walk-in with a brief, holding the service slot.
	_cfg.pitch_base_chance = 1.0
	walker = _stroller()
	walker.interact(player)
	_check(_manager.busy(), "a yes reserves the shop's one service slot at once")
	await create_timer(4.5).timeout
	_check(walker.preference != null, "a yes: they get a brief like any walk-in")
	_check(walker.preference != null and walker.preference.arrival == "pitch", "tagged as pitched")

	# While someone is being served there's no room to pitch for another.
	var other := _stroller()
	_check("not now" in other.get_interaction_prompt(player), "no pitching while the shop is full")
	other.interact(player)
	_check(other.get_interaction_prompt(player) != "", "and the refusal doesn't use them up")
	_finish()


## Send a new stroller down the street and return it.
func _stroller() -> Node:
	var before := get_nodes_in_group("customer")
	_manager.call("_stroll_tick")
	for cust in get_nodes_in_group("customer"):
		if not before.has(cust) and cust.takeover != null:
			return cust
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_pitch: ALL PASS")
		quit(0)
	else:
		print("test_pitch: %d FAILURE(S)" % _failures.size())
		quit(1)

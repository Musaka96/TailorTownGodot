extends SceneTree

## Headless test: the tutorial walks one whole sale, customer first. It drives the real
## order book, rack and customer manager through the tutorial's own hooks and checks that
##   - the steps run greet → design → order cloth → make → rack → collect → wrap-up,
##   - the order taken at the mirror is the one the lesson follows,
##   - the player's part always counts toward it, even in the wrong cloth,
##   - the other parts are waiting on the rack as one set, named right by the mentor,
##   - the player's part joining makes the suit and readies the order (ending the step),
##   - the customer comes back for it, the pin can find them, and handing it over pays.
##   godot --headless --path . --script res://tools/test_tutorial_sale.gd

const JACKET := 2
const SEWN := 3
const CLOTH := "res://data/materials/navy_worsted_solid.tres"
const FLOW := [
	"greet",
	"design",
	"order",
	"store",
	"cut_bolt",
	"worktable",
	"sew",
	"hang",
	"combined",
	"collect",
	"orders",
]

var _failures: Array[String] = []
var _main: Node
var _tut: Node
var _orders: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	for _i in 6:
		await process_frame
	_tut = root.get_node("Tutorial")
	_orders = root.get_node("Orders")
	_orders.active.clear()
	_tut.call("_build")
	_tut.set_process(false)  # drive it step by step; its own ticking would advance it
	_tut.set("_active", true)
	_tut.set("_recipe", _tut.call("_compute_recipe"))

	_flow()
	var order: Resource = _take_order()
	var jacket := _sew_jacket(order)
	var rack := _ready_parts(order)
	_finish_suit(rack, jacket, order)
	await _collect(rack, order)
	_tut.call("abort")
	_finish()


func _flow() -> void:
	var ids: Array = []
	for step: Dictionary in _tut.get("STEPS"):
		ids.append(step["id"])
	_check(ids.slice(0, FLOW.size()) == FLOW, "customer first, then cloth, make, rack, collect")


## The design is confirmed at the mirror: that order is the one the lesson follows.
func _take_order() -> Resource:
	var recipe: Dictionary = _tut.get("_recipe")
	var order: Resource = _orders.create_order("Mr. Tutorial", recipe, 400, Color.WHITE)
	_check(_tut.get("_order") == order, "the order taken at the mirror is the lesson's")
	var said: String = _tut.call("_mentor_lines", _step("order"))[0]
	_check(_tut.call("_cloth_phrase", JACKET) in said, "the phone step names the jacket's cloth")
	return order


## The player sews a jacket in the wrong cloth: it still counts toward the order.
func _sew_jacket(order: Resource) -> Node:
	_goto("sew")
	var jacket: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	jacket.material = load(CLOTH)
	jacket.garment_type = JACKET
	jacket.stage = SEWN
	jacket.quality = 0.8
	_main.add_child(jacket)
	_orders.register_piece(jacket)  # what the machine does; the wrong cloth may not match
	root.get_node("EventBus").piece_sewn.emit(jacket)
	_check(int(jacket.order_id) == order.id, "the player's part counts toward the order")
	_check(float(_tut.get("_done_left")) > 0.0, "and sewing it finishes the sew step")
	return jacket


## The hang step: the shirt and trousers are already on the rack, gathered as one set.
func _ready_parts(order: Resource) -> Node:
	_goto("hang")
	_tut.call("_stage", "hang")
	var rack: Node = _main.find_child("ClothingRack", true, false)
	var hung: Array = rack.stored
	_check(hung.size() == 1 and _is(hung[0], "GarmentSet"), "the other parts wait as one set")
	_check(hung[0].missing() == [JACKET], "waiting for the jacket")
	var said: String = _tut.call("_mentor_lines", _step("hang"))[0]
	_check("shirt and trousers" in said, "Mr. Hemming says what he made")
	_check(order.state == 0, "the order isn't ready before the player's part")
	return rack


## Hanging the player's jacket makes the suit and readies the order — ending the step.
func _finish_suit(rack: Node, jacket: Node, order: Resource) -> void:
	rack.hang(jacket)
	_check(rack.stored.size() == 1 and _is(rack.stored[0], "Suit"), "the jacket makes the suit")
	_check(order.state == 1, "the order is ready")
	_check(float(_tut.get("_done_left")) > 0.0, "and that finishes the hang step")


## The customer comes back; the pin can find them; handing the suit over pays.
func _collect(rack: Node, order: Resource) -> void:
	_goto("collect")
	_check("Mr. Tutorial" in str(_tut.call("_goal_text", _step("collect"))), "the goal names them")
	_tut.call("_stage", "collect")
	for _i in 3:
		await process_frame
	var cust: Node = _tut.call("_collector")
	_check(cust != null, "the customer comes back for the suit")
	if cust == null:
		return
	var player: Node = _main.find_child("Player", true, false)
	var money_before: int = root.get_node("GameState").money
	rack.take(0, player)
	cust.call("_try_collect", player)
	_check(order not in _orders.active, "handing it over completes the order")
	_check(root.get_node("GameState").money > money_before, "and the shop is paid")
	_check(float(_tut.get("_done_left")) > 0.0, "which finishes the collect step")


## Make `id` the current step (its checklist state fresh).
func _goto(id: String) -> void:
	var steps: Array = _tut.get("STEPS")
	for i in steps.size():
		if steps[i]["id"] == id:
			_tut.set("_step", i)
	(_tut.get("_flags") as Dictionary).clear()
	_tut.set("_done_left", 0.0)


func _step(id: String) -> Dictionary:
	for step: Dictionary in _tut.get("STEPS"):
		if step["id"] == id:
			return step
	return {}


func _is(node: Node, kind: String) -> bool:
	var script: Script = node.get_script() if node != null else null
	return script != null and script.get_global_name() == kind


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_tutorial_sale: ALL PASS")
		quit(0)
	else:
		print("test_tutorial_sale: %d FAILURE(S)" % _failures.size())
		quit(1)

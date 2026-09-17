extends Node

## Autoloaded as "Tutorial". A guided first-run walkthrough: on a NEW game the mentor
## (Mr. Hemming, a MentorDialog) offers a tour; if accepted it steps the player through
## ordering cloth, the make pipeline (shelf → worktable → sewing → rack), a customer
## fitting, and a wrap-up on orders, reputation and the handbook.
##
## Two voices:
## - the MENTOR gives the welcome, general know-how and the longer "why" explanations
##   (typed out, with a talking portrait) — the game pauses while he speaks;
## - the GOAL TAG (a swing-ticket checklist, GoalTag) carries each concrete step, ticking
##   its lines live, and sits clear of whatever menu is open. Inside menus a COACH MARK
##   points at the key to press; out in the shop a bobbing hand points at the station.
## Steps complete on EventBus signals, so stations need no tutorial hooks.

## Point the hand at roughly the upper body of a station (metres above its origin).
const POINT_Y := 1.0
const HAND := "👆"
const EDGE := 20.0  # margin between the tag and the screen edge / other UI
const DONE_HOLD := 0.8  # seconds a finished checklist stays up before the next step
const SPOT_PATIENCE := 0.25  # seconds a tag spot must stay covered before the tag moves

## The tutorial customer's fixed, premade brief — the archetypal business suit, so a
## first-timer is walked through a real, sensible combination.
const TUT_OCCASION := Enums.Occasion.BUSINESS
const TUT_STYLE := Enums.Style.CLASSIC
const TUT_BUDGET := 1000

# --- Mentor lines ------------------------------------------------------------

const M_PROMPT := (
	"Ah, a new face on the Row! I'm [b]Mr. Hemming[/b] — forty years behind the shears. "
	+ "Shall I show you how a proper tailor's shop runs?"
)
const M_ORDER := (
	"Splendid. Every suit begins with cloth, and cloth begins with the [b]telephone[/b]. "
	+ "Ring a supplier and have a bolt sent round — any fabric you fancy, for now."
)
const M_MAKE := (
	"A suit is built in pieces. You [b]measure and cut a length[/b] off the bolt, "
	+ "[b]shape it[/b] at the worktable, then [b]stitch it[/b] at the sewing machine."
)
const M_MEASURE := (
	"Mind the [b]length[/b]! Every part takes its own: about [b]2 m[/b] for a jacket, "
	+ "[b]1.4 m[/b] for pants and [b]1.6 m[/b] for a shirt, a touch more for big sizes. "
	+ "Too short and it's useless; too long and the offcut is wasted. Measure twice, cut once!"
)
const M_GREET := (
	"Ah, the bell! Your first customer. Folk walk in with a brief in mind. "
	+ "Greet them kindly and show them to the [b]fitting mirror[/b]."
)
const M_CODE_1 := (
	"Now, the heart of the trade. Every customer has an [b]occasion[/b] — business, a party, "
	+ "a wedding — and a [b]style[/b], classic or otherwise. Together they make a "
	+ "[b]dress code[/b]."
)
const M_CODE_2 := (
	"The code says which [b]cloths[/b], [b]colours[/b] and [b]patterns[/b] are proper. "
	+ "A %s suit wants sober colours and a cloth that works hard; a quiet pinstripe is "
	+ "quite at home. Loud checks at a board meeting? Never."
)
const M_CODE_3 := (
	"Two golden rules: [b]match the trousers to the jacket[/b], and keep the [b]shirt "
	+ "light[/b]. The panel flags what suits the brief, and the [b]Handbook[/b] on the "
	+ "bookshelf lists every code."
)
const M_ORDERS := (
	"Order taken! The customer pops out and comes back to [b]collect[/b] once every part "
	+ "is made. Anything you hang on the rack is matched to open orders by itself, and "
	+ "you're paid on collection."
)
const M_REP := (
	"Do the work well and your [b]reputation[/b] grows — those stars, top left. A good "
	+ "name opens doors: [b]premium suppliers[/b] and new [b]shop upgrades[/b] on the phone."
)
const M_BYE := (
	"That's the lot. Read the [b]Handbook[/b] when you're unsure, and treat yourself to "
	+ "an upgrade when the till allows. The shop is yours — make the Row proud!"
)

# Each step:
#   id; `event` = the EventBus signal that completes it ("" = a mentor-only talk step);
#   `point` = node name to aim the hand at; `match` = item_stored station prefix;
#   `mentor` = lines the mentor says first; `goal` + `checks` = the tag. A check is
#   [text, condition, key, tip]: `condition` ticks it live ("" = only on completion),
#   `key`/`tip` = the coach mark shown while it is the next unticked line.
const STEPS := [
	{
		"id": "order",
		"event": "order_placed",
		"point": "Phone",
		"mentor": [M_ORDER],
		"goal": "Order a bolt of cloth",
		"checks":
		[
			["Open the phone (E)", "seen:phone_order", "", ""],
			["Pick a supplier and fabric", "", "", ""],
			["Place the order", "", "", ""],
		],
	},
	{
		"id": "store",
		"event": "item_stored",
		"match": "Shelf",
		"point": "Shelf",
		"goal": "Shelve the new bolt",
		"checks":
		[
			["Pick up the bolt (E)", "holding:MaterialRoll", "", ""],
			["Store it on a shelf (E)", "", "", ""],
		],
	},
	{
		"id": "cut_bolt",
		"event": "cloth_cut",
		"point": "Shelf",
		"mentor": [M_MAKE, M_MEASURE],
		"goal": "Cut a length of cloth",
		"checks":
		[
			["Open the shelf empty-handed", "seen:shelf_menu", "", ""],
			["Measure enough for a part", "adjusted", "A/D", "Measure the length"],
			["Cut it off the bolt", "", "F", "Cut!"],
		],
	},
	{
		"id": "worktable",
		"event": "piece_cut",
		"point": "Worktable",
		"goal": "Shape it at the worktable",
		"checks":
		[
			["Bring the cloth to the worktable", "seen:worktable_screen", "", ""],
			["Pick a part your cloth covers", "cutting", "E", "Start cutting"],
			["Cut along the dashed line", "", "WASD", "Steer the scissors"],
		],
	},
	{
		"id": "sew",
		"event": "piece_sewn",
		"point": "SewingMachine",
		"goal": "Sew the piece",
		"checks":
		[
			["Take it to the sewing machine", "seen:sewing_screen", "", ""],
			["Stitch on every ring", "", "E / Space", "Stitch on the rings"],
		],
	},
	{
		"id": "hang",
		"event": "item_stored",
		"match": "ClothingRack",
		"point": "ClothingRack",
		"goal": "Hang up the finished part",
		"checks":
		[
			["Pick up the finished part", "holding:GarmentPiece", "", ""],
			["Hang it on the clothing rack (E)", "", "", ""],
		],
	},
	{
		"id": "greet",
		"event": "customer_seated",
		"customer": true,
		"mentor": [M_GREET],
		"goal": "Serve your first customer",
		"checks":
		[
			["Greet them (E)", "seen:customer_request", "", ""],
			["Send them to the mirror", "", "E", "Send to the mirror"],
		],
	},
	{
		"id": "design",
		"event": "design_confirmed",
		"point": "Mirror",
		"mentor": [M_CODE_1, M_CODE_2, M_CODE_3],
		"goal": "",  # filled from the brief (see _goal_text)
		"checks": [],  # filled from the recipe (see _design_checks)
	},
	{"id": "orders", "event": "", "mentor": [M_ORDERS]},
	{"id": "reputation", "event": "", "mentor": [M_REP]},
	{"id": "handbook", "event": "", "point": "Bookshelf", "mentor": [M_BYE]},
]

# Station node-name prefixes gated during a make step (only the step's own is usable).
const STATIONS := [
	"Phone",
	"Shelf",
	"Worktable",
	"SewingMachine",
	"ClothingRack",
	"Mirror",
	"Bookshelf",
	"Mannequin",
	"TrashCan",
]
# Station menus (UI members) the tutorial watches, for "seen:" checks and tag avoidance.
const MENUS := [
	"phone_order",
	"worktable_screen",
	"sewing_screen",
	"suit_builder",
	"shelf_menu",
	"customer_request",
	"handbook",
	"rack_menu",
	"orders_menu",
]

var _active := false
var _step := 0
var _customer: Node = null
var _time := 0.0
var _on_choose := Callable()
var _flags := {}  # condition flags raised during the current step (seen:*, adjusted)
var _done_left := 0.0  # > 0 while a finished checklist lingers before advancing
var _talking := false
var _mentor_was_paused := false
var _pending: Dictionary = {}  # a mentor speech waiting for open menus to close
var _spot_idx := -1  # which placement spot the tag is using (kept while it stays clear)
var _spot_menu: Control = null  # the menu that spot was chosen for
var _spot_blocked := 0.0  # how long the current spot has been covered

## The premade suit the tutorial customer wants (GarmentType -> cloth dict), computed at
## start so the design step can spell out exactly what to make.
var _recipe: Dictionary = {}
## The bolt delivered by the phone this run, so the store step can point right at it.
var _delivered_roll: Node = null

var _layer: CanvasLayer
var _mentor: MentorDialog
var _tag: GoalTag
var _coach: CoachMark
var _hand: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.order_placed.connect(func(_m, _l, _c): _try("order_placed"))
	EventBus.item_stored.connect(func(_i, station): _try("item_stored", station))
	EventBus.cloth_cut.connect(func(_p, _r): _try("cloth_cut"))
	EventBus.piece_cut.connect(func(_p): _try("piece_cut"))
	EventBus.piece_sewn.connect(func(_p): _try("piece_sewn"))
	EventBus.customer_seated.connect(_on_customer_seated)
	EventBus.customer_waiting.connect(func(cust): _customer = cust)
	EventBus.design_confirmed.connect(func(_d): _try("design_confirmed"))
	EventBus.order_delivered.connect(func(roll): _delivered_roll = roll)


## Offer the tutorial (called on a new game): the mentor asks yes/no. `on_choose` runs
## once the player picks either way (so the caller can start the day only after it).
func offer(on_choose := Callable()) -> void:
	if _active:
		return
	_on_choose = on_choose
	_build()
	_speak(PackedStringArray([M_PROMPT]), _on_prompt_answer, "Yes, show me", "No thanks")


func is_active() -> bool:
	return _active


## Screen width a menu should leave free at its left edge for the goal tag (0 when the
## tag isn't up). The suit builder frames the customer to the right of it.
func side_reserve() -> float:
	if not _active or _tag == null or not _tag.visible:
		return 0.0
	return GoalTag.WIDTH + EDGE * 2.0


## True while a make step is running and `target` is a DIFFERENT station than this step's —
## used to lock the player to the current step's station (items/customer are never blocked).
func blocks(target: Node) -> bool:
	if not _active or target == null:
		return false
	var step: Dictionary = STEPS[_step]
	if step.get("event", "") == "":
		return false  # talk steps: roam freely
	var nm := str(target.name)
	var is_station := false
	for s: String in STATIONS:
		if nm.begins_with(s):
			is_station = true
			break
	if not is_station:
		return false
	# Allow the current step's station.
	var want: String = step.get("point", "")
	if want != "" and nm.begins_with(want):
		return false
	# Also allow the PREVIOUS step's station: the piece the player just made (cut, sewn) sits
	# on it, and they must be able to pick it back up to carry it to the next station.
	var prev: String = str(STEPS[_step - 1].get("point", "")) if _step > 0 else ""
	if prev != "" and nm.begins_with(prev):
		return false
	return true


func _on_customer_seated(cust: Node) -> void:
	_customer = cust
	_try("customer_seated")


func _choose_done() -> void:
	if _on_choose.is_valid():
		_on_choose.call()
		_on_choose = Callable()


# --- Flow ------------------------------------------------------------------


func _on_prompt_answer(choice: int) -> void:
	if choice == 0:
		_start()
	else:
		_finish()


func _start() -> void:
	_active = true
	_step = 0
	_recipe = _compute_recipe()  # the exact suit we'll walk the player through making
	# Fold the morning paper away if it's up — the tutorial takes the stage.
	if UI != null and UI.newspaper != null and UI.newspaper.has_method("close"):
		UI.newspaper.close()
	# Unpause so the player can move/interact, but DON'T start the day — no customers or
	# passing time during the tutorial. Stations work via the _shop_closed() exception; the
	# real day begins in _finish().
	get_tree().paused = false
	_apply_step()


func _finish() -> void:
	_active = false
	_pending = {}
	get_tree().paused = false
	_choose_done()  # NOW begin the real day (on completion, or an immediate decline)
	if _layer != null:
		_layer.visible = false


func _try(event: String, station: Node = null) -> void:
	if not _active or _done_left > 0.0:
		return
	var step: Dictionary = STEPS[_step]
	if step.get("event", "") != event:
		return
	if event == "item_stored":
		var want: String = step.get("match", "")
		if want != "" and (station == null or not str(station.name).begins_with(want)):
			return
	# Tick everything and let the finished tag linger a moment before moving on.
	for i in _checks().size():
		_tag.set_done(i, true)
	_coach.clear()
	_done_left = DONE_HOLD


func _advance() -> void:
	_step += 1
	if _step >= STEPS.size():
		_finish()
	else:
		_apply_step()


func _apply_step() -> void:
	var step: Dictionary = STEPS[_step]
	_flags.clear()
	_tag.visible = false
	_coach.clear()
	if step.get("id", "") == "greet" and _customer == null:
		_spawn_customer()
	var lines := _mentor_lines(step)
	if lines.is_empty():
		_show_tag()
	elif step.get("event", "") == "":
		_speak(lines, func(_c: int) -> void: _advance())
	else:
		_speak(lines, func(_c: int) -> void: _show_tag())


## Show the current step's goal tag.
func _show_tag() -> void:
	var items := PackedStringArray()
	for c: Array in _checks():
		items.append(str(c[0]))
	_tag.set_goal(_step_caption(), _goal_text(STEPS[_step]), items)


## "Step 3 of 8", counting only the steps that carry a goal tag.
func _step_caption() -> String:
	var total := 0
	var index := 0
	for i in STEPS.size():
		if str(STEPS[i].get("event", "")) != "":
			total += 1
			if i <= _step:
				index = total
	return "Step %d of %d" % [index, total]


## Poof a customer into the shop for the fitting step (via the customer manager).
func _spawn_customer() -> void:
	var mgr := get_tree().get_first_node_in_group("customer_manager")
	if mgr != null and mgr.has_method("spawn_tutorial_customer"):
		mgr.spawn_tutorial_customer()


func _mentor_lines(step: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in step.get("mentor", []):
		out.append(line % _brief_desc() if line == M_CODE_2 else line)
	return out


func _goal_text(step: Dictionary) -> String:
	if str(step.get("id", "")) == "design":
		return "Design a %s suit" % _brief_desc()
	return str(step.get("goal", ""))


func _checks() -> Array:
	var step: Dictionary = STEPS[_step]
	if str(step.get("id", "")) == "design":
		return _design_checks()
	return step.get("checks", [])


## The fitting checklist: one line per part of the premade recipe, then confirm.
func _design_checks() -> Array:
	var jt := int(Enums.GarmentType.JACKET)
	var pt := int(Enums.GarmentType.PANTS)
	var st := int(Enums.GarmentType.SHIRT)
	return [
		["Jacket: " + _part_desc(jt), "design:%d" % jt, "A/D", "Change the value"],
		["Pants: " + _part_desc(pt), "design:%d" % pt, "W/S", "Pick the next part"],
		["Shirt: " + _part_desc(st), "design:%d" % st, "W/S", "Pick the next part"],
		["Confirm with E", "", "E", "Ask and confirm"],
	]


# --- Mentor ----------------------------------------------------------------


func _speak(pages: PackedStringArray, done: Callable, primary := "Continue", alt := "") -> void:
	_pending = {"pages": pages, "done": done, "primary": primary, "alt": alt}


## Start a queued speech once no station menu is on screen. The game pauses and input is
## locked while the mentor talks, so nothing happens behind his back.
func _start_pending() -> void:
	if _pending.is_empty() or _talking or _open_menu() != null:
		return
	var p := _pending
	_pending = {}
	_talking = true
	_mentor_was_paused = get_tree().paused
	get_tree().paused = true
	GameState.input_locked = true
	_hand.visible = false
	_tag.visible = false
	_mentor.finished.connect(_on_mentor_done.bind(p["done"]), CONNECT_ONE_SHOT)
	_mentor.say(p["pages"], p["primary"], p["alt"])


func _on_mentor_done(choice: int, done: Callable) -> void:
	_talking = false
	get_tree().paused = _mentor_was_paused
	GameState.input_locked = false
	done.call(choice)


# --- Premade recipe --------------------------------------------------------


## A CustomerPreference for the tutorial's fixed brief (used by the CustomerManager when it
## poofs the fitting customer in, so the brief matches the recipe we teach).
func tutorial_pref() -> CustomerPreference:
	var p := CustomerPreference.new()
	p.occasion = TUT_OCCASION
	p.style = TUT_STYLE
	p.budget = TUT_BUDGET
	return p


## The brief label, e.g. "Party · Classic".
func _brief_desc() -> String:
	return "%s · %s" % [Enums.occasion_name(TUT_OCCASION), Enums.style_name(TUT_STYLE)]


## One recipe part described for the bubble, e.g. "Navy · Worsted Wool · Solid".
func _part_desc(garment_type: int) -> String:
	var part: Dictionary = _recipe.get(garment_type, {})
	if part.is_empty():
		return "—"
	return (
		"%s · %s · %s"
		% [
			MaterialFactory.color_name(int(part.get("color", 0))),
			Enums.fabric_name(int(part.get("fabric", 0))),
			Enums.pattern_name(int(part.get("pattern", 0))),
		]
	)


## Build the tutorial's target suit: a matched jacket + trousers plus a light shirt. We
## deliberately pick valid values that DIFFER from the builder's defaults (first of each
## list), so the player has to actually change fabric/colour/pattern to learn the controls.
## Fabrics are limited to what a starting shop can order (unlocked suppliers).
func _compute_recipe() -> Dictionary:
	var jt := int(Enums.GarmentType.JACKET)
	var def_fabric := int(Enums.fabrics_for(jt)[0])
	var def_color := int(MaterialFactory.colors_for(jt)[0])
	var fabric := def_fabric
	var color := def_color
	var pattern := int(Enums.Pattern.SOLID)
	var dc = Catalog.dress_code if Catalog != null else null
	var rule = dc.rule_for(TUT_OCCASION, TUT_STYLE) if dc != null else null
	if rule != null:
		color = _diff_pick(rule.allowed_colors, def_color)
		fabric = _diff_pick(_recipe_fabric_pool(rule), def_fabric)
		pattern = _recipe_pattern(rule)
	var suit_cloth := {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	# Shirts are a light cloth in a pale colour, different again from the suit.
	var shirt := {
		"fabric": int(Enums.Fabric.COTTON),
		"color": _recipe_shirt_color(),
		"pattern": int(Enums.Pattern.SOLID),
		"style_idx": 0,
	}
	return {
		Enums.GarmentType.JACKET: suit_cloth.duplicate(),
		Enums.GarmentType.PANTS: suit_cloth.duplicate(),
		Enums.GarmentType.SHIRT: shirt,
	}


## The first value in `allowed` that ISN'T the builder default, so the player must change
## it. Falls back to the first allowed (or the default if the list is empty).
func _diff_pick(allowed: Array, default_value: int) -> int:
	for v in allowed:
		if int(v) != default_value:
			return int(v)
	return int(allowed[0]) if not allowed.is_empty() else default_value


## Jacket fabrics the brief allows AND a starting shop can order (unlocked suppliers).
func _recipe_fabric_pool(rule) -> Array:
	var supplied := {}
	if Upgrades != null:
		for v in Upgrades.unlocked_vendors():
			for f in v.get("fabrics", []):
				supplied[int(f)] = true
	var base: Array = rule.allowed_fabrics
	if base.is_empty():
		base = Array(Enums.fabrics_for(Enums.GarmentType.JACKET))
	var pool: Array = []
	for f in base:
		if supplied.is_empty() or int(f) in supplied:
			pool.append(int(f))
	return pool


## A bold (non-solid) pattern the brief allows, to teach changing the pattern; else solid.
func _recipe_pattern(rule) -> int:
	var pats: Array = rule.allowed_patterns
	if pats.is_empty():
		pats = Array(Enums.patterns_for(Enums.GarmentType.JACKET))
	for p in pats:
		if int(p) != Enums.Pattern.SOLID:
			return int(p)
	return int(Enums.Pattern.SOLID)


## A pale shirt colour the occasion allows, different from the builder's default shirting.
func _recipe_shirt_color() -> int:
	var def_color := int(MaterialFactory.colors_for(Enums.GarmentType.SHIRT)[0])
	var allowed: Array = DressCode.SHIRT_COLORS.get(TUT_OCCASION, [])
	return _diff_pick(allowed, def_color)


## The item the player is currently carrying (for the store-step pointer), or null.
func _player_held() -> Node:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.get("carry") != null:
		return p.carry.get_held()
	return null


# --- Live update -------------------------------------------------------------


func _process(delta: float) -> void:
	if _layer == null or not _layer.visible:
		return
	_time += delta
	_start_pending()
	if _talking or not _active:
		_hand.visible = false
		_coach.clear()
		return
	if _done_left > 0.0:
		_done_left -= delta
		if _done_left <= 0.0:
			_advance()
		return
	if not _tag.visible:
		return
	_update_checks()
	_place_tag(delta)
	_update_pointers()


func _input(event: InputEvent) -> void:
	# "Set the length" ticks once the player nudges the cut length in the shelf menu.
	if not _active or UI == null or UI.shelf_menu == null or not UI.shelf_menu.visible:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		_flags["adjusted"] = true


func _update_checks() -> void:
	var menu := _open_menu()
	if menu != null:
		_flags["seen:" + _menu_key(menu)] = true
	var checks := _checks()
	for i in checks.size():
		var cond: String = checks[i][1]
		if cond != "" and _met(cond):
			_flags["done:%d" % i] = true  # ticks stay ticked once earned
		_tag.set_done(i, _flags.has("done:%d" % i))


## Whether a check condition currently holds.
func _met(cond: String) -> bool:
	if _flags.has(cond):
		return true
	if cond.begins_with("holding:"):
		var held := _player_held()
		var script: Script = held.get_script() if held != null else null
		return script != null and script.get_global_name() == cond.trim_prefix("holding:")
	if cond.begins_with("design:"):
		return _design_matches(int(cond.trim_prefix("design:")))
	if cond == "cutting":
		var mg: Variant = UI.worktable_screen.get("_minigame") if UI != null else null
		return mg is Control and (mg as Control).is_visible_in_tree()
	return false


## Does the open suit builder's design for `garment_type` match the recipe?
func _design_matches(garment_type: int) -> bool:
	if UI == null or not UI.suit_builder.has_method("current_design"):
		return false
	var want: Dictionary = _recipe.get(garment_type, {})
	var have: Dictionary = UI.suit_builder.current_design().get(garment_type, {})
	if want.is_empty() or have.is_empty():
		return false
	for k in ["fabric", "color", "pattern"]:
		if int(have.get(k, -1)) != int(want.get(k, -2)):
			return false
	return true


## Index of the first unticked checklist line, or -1.
func _next_check() -> int:
	var checks := _checks()
	for i in checks.size():
		if not _flags.has("done:%d" % i):
			return i
	return -1


# --- Placement ---------------------------------------------------------------


## Keep the tag clear of the open menu, the HUD and (at the mirror) the customer: try a
## few calm spots and take the first that overlaps nothing (else the least-covered one).
func _place_tag(delta: float) -> void:
	var vp := _layer.get_viewport().get_visible_rect().size
	var menu := _open_menu()
	var sz := _tag.size
	var busy := _busy_rects(menu)
	var right := vp.x - sz.x - EDGE
	var under_money := 96.0
	var under_rep := 200.0
	var spots: Array[Vector2] = [
		Vector2(right, under_money),
		Vector2(right, (vp.y - sz.y) * 0.5),
		Vector2(right, vp.y - sz.y - EDGE),
		Vector2(EDGE, under_rep),
		Vector2(EDGE, (vp.y - sz.y) * 0.5),
		Vector2(EDGE, vp.y - sz.y - EDGE),
	]
	if menu != null:
		# Beside a centred menu the middle of the margin is the calmest place.
		spots.push_front(Vector2(right, (vp.y - sz.y) * 0.5))
	# Stay put while the current spot is still clear — menus rebuild their contents as you
	# browse, and hopping around on every change reads as the tag "resetting".
	if menu != _spot_menu:
		_spot_menu = menu
		_spot_idx = -1
	# Only give up the current spot once it has been covered for a moment, so one-frame
	# layout glitches (rebuilt cards, re-wrapping labels) never trigger a move.
	if _spot_idx >= 0 and _spot_idx < spots.size():
		if _overlap(Rect2(spots[_spot_idx], sz), busy) <= 0.0:
			_spot_blocked = 0.0
		else:
			_spot_blocked += delta
		if _spot_blocked < SPOT_PATIENCE:
			_tag.move_to(spots[_spot_idx])
			return
	_spot_blocked = 0.0
	var best := 0
	var best_overlap := INF
	for i in spots.size():
		var overlap := _overlap(Rect2(spots[i], sz), busy)
		if overlap < best_overlap:
			best_overlap = overlap
			best = i
		if overlap <= 0.0:
			break
	_spot_idx = best
	_tag.move_to(spots[best])


func _overlap(rect: Rect2, busy: Array[Rect2]) -> float:
	var r := rect.grow(EDGE * 0.5)
	var total := 0.0
	for b in busy:
		if r.intersects(b):
			total += r.intersection(b).get_area()
	return total


## Screen rects the tag must avoid: the open menu's panels, the HUD widgets, and anything
## the menu declares (tutorial_busy_rects).
func _busy_rects(menu: Control) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if UI != null:
		for w in [UI.clock, UI.reputation]:
			if w is Control and (w as Control).is_visible_in_tree():
				out.append((w as Control).get_global_rect())
		for nm in ["_money_panel", "_prompt_bar"]:
			var hud_part: Variant = UI.hud.get(nm)
			if hud_part is Control and (hud_part as Control).is_visible_in_tree():
				out.append((hud_part as Control).get_global_rect())
	if menu == null:
		return out
	# Only the outermost panels: inner cards get rebuilt while browsing and are briefly
	# un-laid-out (or queued for deletion), which would make the tag jump.
	for n in menu.find_children("*", "PanelContainer", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and not c.is_queued_for_deletion() and _outermost(c, menu):
			out.append(c.get_global_rect())
	for n in menu.find_children("*", "TvFrame", true, false):
		out.append((n as Control).get_global_rect())
	if menu.has_method("tutorial_busy_rects"):
		out.append_array(menu.tutorial_busy_rects())
	return out


## True when no PanelContainer sits between `panel` and `menu`.
func _outermost(panel: Control, menu: Control) -> bool:
	var p := panel.get_parent()
	while p != null and p != menu:
		if p is PanelContainer:
			return false
		p = p.get_parent()
	return true


## The station menu currently on screen, or null.
func _open_menu() -> Control:
	if UI == null:
		return null
	for key: String in MENUS:
		var m: Variant = UI.get(key)
		if m is Control and (m as Control).visible:
			return m
	return null


func _menu_key(menu: Control) -> String:
	for key: String in MENUS:
		if UI.get(key) == menu:
			return key
	return ""


# --- Pointers ----------------------------------------------------------------


## Out in the shop the hand bobs over the station; inside a menu a coach mark points at
## the key for the next unticked line (the phone points at its own highlighted card).
func _update_pointers() -> void:
	var menu := _open_menu()
	if menu == null:
		_coach.clear()
		_move_hand(_world_point())
		return
	var step: Dictionary = STEPS[_step]
	if step.get("id", "") == "order" and menu.has_method("tutorial_hint_point"):
		_coach.clear()
		var p: Vector2 = menu.tutorial_hint_point()
		_move_hand(p)
		return
	_hand.visible = false
	var i := _next_check()
	var check: Array = _checks()[i] if i >= 0 else []
	var key: String = check[2] if check.size() > 2 else ""
	var rect := _find_key(menu, key) if key != "" else Rect2()
	if rect.size == Vector2.ZERO:
		_coach.clear()
	else:
		_coach.point_at(rect, str(check[3]))


func _move_hand(pos: Vector2) -> void:
	if pos.x < 0.0:
		_hand.visible = false
		return
	_hand.visible = true
	# Sit just below the target and bob up toward it.
	_hand.position = pos + Vector2(-16, 24 + sin(_time * 6.0) * 6.0)


## The global rect of the visible key-cap labelled `key` inside `menu`.
func _find_key(menu: Control, key: String) -> Rect2:
	for n in menu.find_children("*", "Label", true, false):
		var lbl := n as Label
		if lbl.text == key and lbl.get_parent() is PanelContainer and lbl.is_visible_in_tree():
			return (lbl.get_parent() as Control).get_global_rect()
	return Rect2()


## Screen position of the current step's station, or (-1,-1) if not shown.
func _world_point() -> Vector2:
	var step: Dictionary = STEPS[_step]
	# Store step: point at the bolt the phone just delivered so the player finds it, then
	# (once it's in hand) fall through to the SHELF where it goes.
	if step.get("id", "") == "store" and _delivered_roll != null:
		if is_instance_valid(_delivered_roll) and _delivered_roll != _player_held():
			return _project(_delivered_roll)
	if step.get("customer", false):
		return _project(_customer)
	var name: String = step.get("point", "")
	if name == "":
		return Vector2(-1, -1)
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	return _project(scene.find_child(name, true, false) as Node3D)


## Project a Node3D's upper body to the screen; (-1,-1) if missing or behind the camera.
func _project(node: Node3D) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if node == null or cam == null or not is_instance_valid(node):
		return Vector2(-1, -1)
	var world := node.global_position + Vector3(0, POINT_Y, 0)
	if cam.is_position_behind(world):
		return Vector2(-1, -1)
	return cam.unproject_position(world)


# --- UI --------------------------------------------------------------------


func _build() -> void:
	if _layer != null:
		_layer.visible = true
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128  # above the HUD and open menus so the pointers show on top
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = UI.FONT
	theme.default_font_size = 16
	root.theme = theme
	_layer.add_child(root)

	_tag = GoalTag.new()
	root.add_child(_tag)
	_coach = CoachMark.new()
	root.add_child(_coach)

	_hand = Label.new()
	_hand.text = HAND
	# Fredoka has no emoji glyph — use a system font that carries the colour hand emoji.
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(
		["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"]
	)
	emoji.allow_system_fallback = true
	_hand.add_theme_font_override("font", emoji)
	_hand.add_theme_font_size_override("font_size", 44)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.visible = false
	root.add_child(_hand)

	_mentor = MentorDialog.new()
	root.add_child(_mentor)

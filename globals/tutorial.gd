extends Node

## Autoloaded as "Tutorial". A guided first-run walkthrough: on a NEW game the mentor
## (Mr. Hemming, a MentorDialog) offers a tour; if accepted it walks the player through
## one whole sale. A customer walks in and has a suit designed at the mirror; the player
## orders its cloth on the phone, then makes one part through the pipeline (shelf →
## worktable → sewing machine) while Mr. Hemming runs up the other two. On the rack the
## parts gather into the finished suit, the customer comes back for it, and is paid —
## then a wrap-up on prices, reputation, the paper and the handbook.
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
	"Order taken — that's their ticket, up top. Every suit begins with cloth, and cloth "
	+ "begins with the [b]telephone[/b]: ring a supplier and have a bolt of [b]%s[/b] sent "
	+ "round for the jacket. This first one's [b]on the house[/b]; after that, longer bolts "
	+ "are cheaper per metre."
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
# The bench games have variants (CutVariants / SewVariants); these introduce the ones
# whose controls a first-timer can't guess. Steer and Rhythm need no speech.
const M_CUT_ALLOWANCE := (
	"On the table it goes. Choose a part and its outline is chalked on your cloth: hold "
	+ "[b]Space[/b] and the shears push along it, gliding down the straight runs. The curves "
	+ "are yours to steer with [b]A[/b] and [b]D[/b]. Keep to the chalk — cut inside it and "
	+ "you've nicked the garment."
)
const M_CUT_STROKES := (
	"On the table it goes. Choose a part, then hold [b]Space[/b] to open the shears along "
	+ "the chalk and let go to close them — long, even strokes make the cleanest edge."
)
const M_SEW_PEDAL := (
	"Now the machine. The needle stays put and [b]you guide the cloth[/b]. Line it up on the "
	+ "dotted guide with [b]A[/b] and [b]D[/b], then press the pedal — [b]Space[/b]. Ease off "
	+ "at the [b]amber marks[/b] and stop on a corner to turn the cloth."
)
const M_SEW_PINS := "Pull each [b]pin[/b] with [b]E[/b] before the needle reaches it. "
const M_SEW_LOCK := "At the end mark, hold [b]S[/b] with the pedal to [b]backstitch[/b]. "
const M_SEW_CUT := "Then [b]E[/b] cuts the thread."
const M_GREET := (
	"Splendid — and there's the bell! Your first customer. Folk walk in with a brief in "
	+ "mind. Greet them kindly and show them to the [b]fitting mirror[/b]."
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
const M_STOCK := (
	"And don't fret if a cloth says [b]Not in your shop[/b] — design what the customer "
	+ "wants anyway. Once they've said yes, just [b]order that bolt[/b] on the phone and "
	+ "make the parts from it."
)
const M_PAPER := (
	"Every morning the [b]Tailor's Gazette[/b] lands on the mat. It tells you what's "
	+ "[b]in fashion[/b] (suits in that style earn extra standing) and which [b]events[/b] "
	+ "are coming, so you can stock the right cloth. Press [b]%s[/b] to read it any time."
)
const M_ORDERS := (
	"Paid! The price is the [b]cloth[/b] the parts need plus your [b]craft fee[/b], so any "
	+ "cloth you waste comes out of your own pocket. Most customers come back on their "
	+ "[b]due day[/b] (red ticket = today) and pay on collection; splendid work earns a "
	+ "[b]tip[/b]. Treat people well and they'll come back as [b]regulars[/b]."
)
const M_RACK := (
	"While you were at the machine I ran up the [b]%s[/b] for this order — they're hanging "
	+ "on the [b]rack[/b]. Take your piece over and hang it with them."
)
const M_COMBINE := (
	"See that? Parts made for the same order [b]gather on one hanger[/b], under a ticket "
	+ "saying whose they are and what's still to come — and when the last one joins, it's "
	+ "a [b]finished suit[/b]. Each rack keeps its own, and you can always [b]take a set "
	+ "apart[/b] from the rack."
)
const M_COLLECT := (
	"And here's our customer, right on cue — most come back on their due day, but this one "
	+ "waited. Fetch the suit off the rack and [b]hand it over[/b]."
)
const M_REP := (
	"Do the work well and your [b]reputation[/b] grows — those stars, top left. A good "
	+ "name opens doors: [b]premium suppliers[/b] and new [b]shop upgrades[/b] on the phone."
)
const M_BYE := (
	"That's the lot. Busy? Flip the [b]shop sign[/b] on the phone, or book a customer for "
	+ "another day when you greet them. Read the [b]Handbook[/b] when unsure, and treat "
	+ "yourself to an upgrade when the till allows. Make the Row proud!"
)

## The parts the mentor runs up for the tutorial order are sewn to its design at this
## quality, so the finished suit reads as good but leaves the player's own work to count.
const READY_QUALITY := 0.88
const GARMENT_SCENE := "res://entities/items/garment_piece.tscn"
## How Mr. Hemming names each part.
const SPOKEN_PART := {
	Enums.GarmentType.JACKET: "jacket",
	Enums.GarmentType.SHIRT: "shirt",
	Enums.GarmentType.PANTS: "trousers",
}

# Each step:
#   id; `event` = the EventBus signal that completes it ("" = a mentor-only talk step);
#   `point` = node name to aim the hand at; `match` = item_stored station prefix;
#   `mentor` = lines the mentor says first; `brief` = a condition that, once met, has the
#   mentor explain the bench game (see _bench_lines) — so he talks about it when the cloth
#   is on the bench, not while it's still being carried there; `goal` + `checks` = the
#   tag. A check is [text, condition, key, tip, point?, when?]: `condition` ticks it live
#   ("" = only on completion), `key`/`tip` = the coach mark shown while it is the next
#   unticked line, the optional `point` = the station the pin shows while it is (else the
#   step's `point`), so the pin follows the cloth from bench to bench, and the optional
#   `when` = a condition the coach mark waits for, so it doesn't point at something the
#   player can't do yet (the backstitch, before the needle reaches the end mark).
const STEPS := [
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
		"mentor": [M_CODE_1, M_CODE_2, M_CODE_3, M_STOCK],
		"goal": "",  # filled from the brief (see _goal_text)
		"checks": [],  # filled from the recipe (see _design_checks)
	},
	{
		"id": "order",
		"event": "order_placed",
		"point": "Phone",
		"mentor": [M_ORDER],
		"goal": "Order the jacket's cloth",
		"checks":
		[
			["Open the phone (E)", "seen:phone_order", "", ""],
			["Find the cloth for the jacket", "cloth", "", ""],
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
			["Measure enough for the jacket", "adjusted", "A/D", "Measure the length"],
			["Cut it off the new bolt", "", "F", "Cut!"],
		],
	},
	{
		"id": "worktable",
		"event": "piece_cut",
		"point": "Worktable",
		"brief": "on:Worktable",
		"goal": "Shape it at the worktable",
		"checks": [],  # filled for the worktable's cutting game (see _cut_checks)
	},
	{
		"id": "sew",
		"event": "piece_sewn",
		"point": "SewingMachine",
		"brief": "on:SewingMachine",
		"goal": "Sew the piece",
		"checks": [],  # filled for the machine's sewing game (see _sew_checks)
	},
	{
		"id": "hang",
		"event": "order_ready",
		"point": "ClothingRack",
		"mentor": [M_RACK],
		"goal": "Finish the suit",
		"checks":
		[
			["Take the sewn part off the machine", "holding:GarmentPiece", "", "", "SewingMachine"],
			["Hang it with the others on the rack", "", "", "", "ClothingRack"],
		],
	},
	{"id": "combined", "event": "", "mentor": [M_COMBINE]},
	{
		"id": "collect",
		"event": "order_fulfilled",
		"point": "ClothingRack",
		"mentor": [M_COLLECT],
		"goal": "",  # names the customer (see _goal_text)
		"checks":
		[
			["Take the suit off the rack", "holding:Suit", "E", "Take the suit", "ClothingRack"],
			["Hand it over when they arrive", "", "", "", "@collector"],
		],
	},
	{"id": "orders", "event": "", "mentor": [M_ORDERS]},
	{"id": "reputation", "event": "", "mentor": [M_REP]},
	{"id": "newspaper", "event": "", "mentor": [M_PAPER]},
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
## The tutorial customer's order (a SuitOrder), once it's been taken at the mirror.
var _order: Resource = null
## The parts Mr. Hemming ran up for it (garment types), and the size the player made.
var _prehung: Array[int] = []
var _made_size := Enums.Size.M
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
var _root: Control
var _mentor: MentorDialog
var _tag: GoalTag
var _coach: CoachMark
var _hand: PointerPin  # the dressmaker's-pin marker


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.order_placed.connect(func(_m, _l, _c): _try("order_placed"))
	EventBus.item_stored.connect(func(_i, station): _try("item_stored", station))
	EventBus.cloth_cut.connect(func(_p, _r): _try("cloth_cut"))
	EventBus.piece_cut.connect(func(_p): _try("piece_cut"))
	EventBus.piece_sewn.connect(_on_piece_sewn)
	EventBus.order_created.connect(func(order): _order = order if _active else _order)
	EventBus.order_ready.connect(func(_o): _try("order_ready"))
	EventBus.order_fulfilled.connect(func(_o, _p): _try("order_fulfilled"))
	EventBus.customer_seated.connect(_on_customer_seated)
	EventBus.customer_waiting.connect(func(cust): _customer = cust)
	EventBus.design_confirmed.connect(func(_d): _try("design_confirmed"))
	EventBus.order_delivered.connect(func(roll): _delivered_roll = roll)
	EventBus.session_ended.connect(abort)


## Stop the tutorial without starting the day (leaving the game scene). Everything it
## shows is hidden and its pause/input locks are released; a new game offers it again.
func abort() -> void:
	_active = false
	_pending = {}
	_on_choose = Callable()
	_done_left = 0.0
	_customer = null
	_order = null
	_prehung.clear()
	_delivered_roll = null
	if _talking:
		_talking = false
		GameState.input_locked = false
	if _layer != null:
		if _mentor != null:
			_mentor.hide_dialog()
			for c in _mentor.finished.get_connections():
				_mentor.finished.disconnect(c["callable"])
		_tag.visible = false
		_coach.clear()
		_hand.visible = false
		_layer.visible = false


## Offer the tutorial (called on a new game): the mentor asks yes/no. `on_choose` runs
## once the player picks either way (so the caller can start the day only after it).
func offer(on_choose := Callable()) -> void:
	if _active:
		return
	_on_choose = on_choose
	_build()
	_step = 0
	_flags.clear()
	_speak(PackedStringArray([M_PROMPT]), _on_prompt_answer, "Yes, show me", "No thanks")


func is_active() -> bool:
	return _active


## The first bolt (the tutorial's order step) is on the house.
func first_bolt_free() -> bool:
	return _active and str(STEPS[_step].get("id", "")) == "order"


## Screen width a menu should leave free at its left edge for the goal tag (0 when the
## tag isn't up). The suit builder frames the customer to the right of it.
func side_reserve() -> float:
	if not _active or _tag == null or not _tag.visible:
		return 0.0
	return GoalTag.WIDTH + EDGE * 2.0


## The recipe cloth for one part while the design step runs (so the suit builder can tick
## the rows that are already right), else {}.
func design_target(garment_type: int) -> Dictionary:
	if not _active or str(STEPS[_step].get("id", "")) != "design":
		return {}
	return _recipe.get(garment_type, {})


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
	_stage(str(step.get("id", "")))
	var lines := _mentor_lines(step)
	if lines.is_empty():
		_show_tag()
	elif step.get("event", "") == "":
		_speak(lines, func(_c: int) -> void: _advance())
	else:
		_speak(lines, func(_c: int) -> void: _show_tag())


## Set the scene for a step before it's shown: the customer walks in, the ready parts go
## on the rack, the customer comes back for the suit.
func _stage(step_id: String) -> void:
	match step_id:
		"greet":
			if _customer == null:
				_spawn_customer()
		"hang":
			_hang_ready_parts()
		"collect":
			_call_customer_back()


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
		var text := line
		if line == M_CODE_2:
			text = line % _brief_desc()
		elif line == M_PAPER:
			text = line % _key_name("newspaper")
		elif line == M_ORDER:
			text = line % _cloth_phrase(Enums.GarmentType.JACKET)
		elif line == M_RACK:
			text = line % _parts_phrase(_prehung)
		out.append(text)
	return out


## The part the player sews always counts toward the tutorial's order, even in a cloth that
## doesn't quite match — the lesson mustn't strand them with a part that fits nothing.
func _on_piece_sewn(piece: Node) -> void:
	if _active and _order != null and int(piece.get("order_id")) == 0:
		if _order.needs_part(int(piece.get("garment_type"))):
			Orders.register_piece_for(piece, _order)
	if _active:
		_made_size = int(piece.get("size"))
	_try("piece_sewn")


## The parts Mr. Hemming "ran up" while the player made theirs: every part the order still
## needs, sewn to its design and hung on the rack — where they gather into one set waiting
## for the player's piece.
func _hang_ready_parts() -> void:
	_prehung.clear()
	var rack := _station("ClothingRack")
	if rack == null or _order == null:
		return
	for t: int in _order.required_types():
		if _order.needs_part(t):
			var part := _ready_part(t)
			Orders.register_piece_for(part, _order)
			rack.hang(part)
			_prehung.append(t)


func _ready_part(garment_type: int) -> Node:
	var spec: Dictionary = _order.design.get(garment_type, {})
	var part: Node = load(GARMENT_SCENE).instantiate()
	part.material = MaterialFactory.make(
		int(spec.get("fabric", 0)),
		int(spec.get("pattern", 0)),
		int(spec.get("color", 0)),
		Pricing.part_meters(garment_type, _made_size)
	)
	part.garment_type = garment_type
	part.size = _made_size
	part.stage = Enums.Stage.SEWN
	part.quality = READY_QUALITY
	return part


## The customer comes back for their suit — this once straight away, not on their due day.
## The customer manager sends them in, as it does for any order that falls due.
func _call_customer_back() -> void:
	if _order == null:
		return
	_order.due_fired = true
	EventBus.order_due.emit(_order)


## The customer who has come back for the tutorial's order, once they're in the world.
func _collector() -> Node3D:
	for cust in get_tree().get_nodes_in_group("customer"):
		if _order != null and cust.get("collect_order") == _order:
			return cust as Node3D
	return null


## "charcoal pinstripe flannel" — the recipe's cloth for a part, as the mentor says it.
func _cloth_phrase(garment_type: int) -> String:
	var part: Dictionary = _recipe.get(garment_type, {})
	var words: Array[String] = [MaterialFactory.color_name(int(part.get("color", 0)))]
	var pattern := int(part.get("pattern", 0))
	if pattern != Enums.Pattern.SOLID:
		words.append(Enums.pattern_name(pattern))
	words.append(Enums.fabric_name(int(part.get("fabric", 0))))
	return " ".join(words).to_lower()


## "shirt and trousers" — the parts named the way Mr. Hemming says them.
func _parts_phrase(types: Array[int]) -> String:
	var names: Array[String] = []
	for t in types:
		names.append(str(SPOKEN_PART.get(t, "parts")))
	if names.size() <= 1:
		return "".join(names) if not names.is_empty() else "other parts"
	return ", ".join(names.slice(0, -1)) + " and " + names[-1]


## The mentor's introduction to the worktable or sewing machine game, if it needs one —
## spoken when the step's `brief` condition is first met (the cloth is on the bench). The
## sewing one leaves out pins and backstitching when an upgrade (clips, the auto-lock) has
## taken them off the player's hands.
func _bench_lines(step_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	if step_id == "worktable":
		match CutVariants.current():
			CutVariants.Variant.ALLOWANCE:
				out.append(M_CUT_ALLOWANCE)
			CutVariants.Variant.STROKES:
				out.append(M_CUT_STROKES)
	elif step_id == "sew" and SewVariants.current() == SewVariants.Variant.PEDAL:
		out.append(M_SEW_PEDAL)
		var rest := "" if Upgrades.has("sew_clips") else M_SEW_PINS
		rest += "" if Upgrades.has("sew_autolock") else M_SEW_LOCK
		out.append(rest + M_SEW_CUT)
	return out


## The key currently bound to `action` (e.g. "N"), for mentor lines.
func _key_name(action: String) -> String:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				return (ev as InputEventKey).as_text_physical_keycode()
	return action.to_upper()


func _goal_text(step: Dictionary) -> String:
	if str(step.get("id", "")) == "design":
		return "Design a %s suit" % _brief_desc()
	if str(step.get("id", "")) == "collect" and _order != null:
		return "Hand %s their suit" % _order.customer_name
	return str(step.get("goal", ""))


func _checks() -> Array:
	var step: Dictionary = STEPS[_step]
	match str(step.get("id", "")):
		"design":
			return _design_checks()
		"worktable":
			return _cut_checks()
		"sew":
			return _sew_checks()
	return step.get("checks", [])


## The worktable checklist, for whichever cutting game the worktable runs. The keys match
## that game's own key prompts, so the coach mark lands on them.
func _cut_checks() -> Array:
	var lines: Array = [
		["Put the cloth on the worktable", "on:Worktable", "", "", "Worktable"],
		["Open it and pick a part your cloth covers", "cutting", "E", "Start cutting"],
	]
	match CutVariants.current():
		CutVariants.Variant.ALLOWANCE:
			lines.append(
				["Hold Space / F to push the shears", "bench:started", "Space / F", "Hold to cut"]
			)
			lines.append(["Steer round the curves on the chalk", "", "A / D", "Steer"])
		CutVariants.Variant.STROKES:
			lines.append(
				["Hold Space / F to open, let go to cut", "", "Space / F", "Open, then let go"]
			)
		_:
			lines.append(["Cut along the dashed line", "", "WASD", "Steer the scissors"])
	return lines


## The sewing checklist, for whichever sewing game the machine runs. On Pedal & Aim each
## line ticks as the player actually does it (MinigameScreen.coach_flags), and the pins and
## backstitch lines drop out once an upgrade does that job for them.
func _sew_checks() -> Array:
	var lines: Array = [
		["Take the cut part off the worktable", "holding:GarmentPiece", "", "", "Worktable"],
		["Put it on the sewing machine", "on:SewingMachine", "", "", "SewingMachine"],
	]
	if SewVariants.current() != SewVariants.Variant.PEDAL:
		lines.append(["Stitch on every ring", "", "E / Space", "Stitch on the rings"])
		return lines
	lines.append(["Line up with A / D, then pedal", "bench:started", "Space / F", "Pedal"])
	if not Upgrades.has("sew_clips"):
		lines.append(["Pull each pin before the needle", "bench:pins", "E", "Pull the pin"])
	if not Upgrades.has("sew_autolock"):
		lines.append(
			[
				"Backstitch at the end mark",
				"bench:locked",
				"S + pedal",
				"Lock the seam",
				"",
				"bench:at_end"
			]
		)
	lines.append(["Cut the thread", "", "E", "Cut the thread"])
	return lines


## The fitting checklist: one line per part of the premade recipe, then confirm.
func _design_checks() -> Array:
	var jt := int(Enums.GarmentType.JACKET)
	var pt := int(Enums.GarmentType.PANTS)
	var st := int(Enums.GarmentType.SHIRT)
	# In the builder's own part order, so the coach mark walks down the list with them.
	return [
		["Jacket: " + _part_desc(jt), "design:%d" % jt, "A/D", "Change the value"],
		["Shirt: " + _part_desc(st), "design:%d" % st, "A/D", "Change the value"],
		["Pants: " + _part_desc(pt), "design:%d" % pt, "A/D", "Change the value"],
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
	# The pause menu covers the game: tuck the whole overlay away until it closes.
	_root.visible = not GameState.is_paused
	if GameState.is_paused:
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
	if _brief_on_arrival():
		return
	_place_tag(delta)
	_update_pointers()


## Once the step's `brief` condition is met — the cloth is on the bench — the mentor
## explains the bench game, once. Returns true while he's about to speak.
func _brief_on_arrival() -> bool:
	var step: Dictionary = STEPS[_step]
	var when: String = step.get("brief", "")
	if when == "" or _flags.has("briefed") or not _met(when):
		return false
	_flags["briefed"] = true
	var lines := _bench_lines(str(step.get("id", "")))
	if lines.is_empty():
		return false
	_speak(lines, func(_c: int) -> void: _show_tag())
	return true


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
		var key := "done:%d" % i
		if cond.begins_with("design:") or cond == "cloth":
			# Design lines follow the live design: change a part away and it un-ticks.
			if _met(cond):
				_flags[key] = true
			else:
				_flags.erase(key)
		elif cond != "" and _met(cond):
			_flags[key] = true  # progress ticks stay ticked once earned
		_tag.set_done(i, _flags.has(key))


## Whether a check condition currently holds.
func _met(cond: String) -> bool:
	if _flags.has(cond):
		return true  # "seen:<menu>" and "adjusted" only ever arrive as flags
	var arg := cond.get_slice(":", 1)
	var met := false
	match cond.get_slice(":", 0):
		"holding":
			met = _holding(arg)
		"design":
			met = _design_matches(int(arg))
		"cutting":
			var mg: Variant = UI.worktable_screen.get("_minigame") if UI != null else null
			met = mg is Control and (mg as Control).is_visible_in_tree()
		"bench":
			met = _bench_flag(arg)
		"on":
			met = _loaded(arg)
		"cloth":
			met = _phone_cloth_ok()
	return met


## Whether the phone's order form is set to the jacket's cloth (the order step's line).
func _phone_cloth_ok() -> bool:
	var phone: Variant = UI.get("phone_order") if UI != null else null
	if not (phone is Control and (phone as Control).has_method("tutorial_cloth_ok")):
		return false
	return phone.tutorial_cloth_ok(_recipe.get(Enums.GarmentType.JACKET, {}))


## Whether the player is carrying an item of the given class (e.g. "GarmentPiece").
func _holding(type_name: String) -> bool:
	var held := _player_held()
	var script: Script = held.get_script() if held != null else null
	return script != null and script.get_global_name() == type_name


## Whether the named station has something sitting on it (the worktable, the sewing
## machine — anything answering held_item()).
func _loaded(station_name: String) -> bool:
	var station := _station(station_name)
	return station != null and station.has_method("held_item") and station.held_item() != null


func _station(station_name: String) -> Node3D:
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	return scene.find_child(station_name, true, false) as Node3D


## A progress flag from whichever bench game is on screen — the worktable's or the sewing
## machine's (see MinigameScreen.coach_flags).
func _bench_flag(flag: String) -> bool:
	if UI == null:
		return false
	for host: Control in [UI.worktable_screen, UI.sewing_screen]:
		var mg: Variant = host.get("_minigame")
		if mg is MinigameScreen and (mg as MinigameScreen).is_visible_in_tree():
			return bool((mg as MinigameScreen).coach_flags().get(flag, false))
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
## what to do next — the menu's own pick if it has a tutorial_coach() hook (the right
## row, card or key, with the value to choose), else the key for the next unticked line.
func _update_pointers() -> void:
	var menu := _open_menu()
	if menu == null:
		_coach.clear()
		_move_hand(_world_point())
		return
	_hand.visible = false
	if menu.has_method("tutorial_coach"):
		var hint: Dictionary = menu.tutorial_coach(_coach_goal())
		if not hint.is_empty():
			_coach_hint(menu, hint)
			return
	var i := _next_check()
	var check: Array = _checks()[i] if i >= 0 else []
	var key: String = check[2] if check.size() > 2 and _coach_ready(check) else ""
	var rect := _find_key(menu, key) if key != "" else Rect2()
	if rect.size == Vector2.ZERO:
		_coach.clear()
	else:
		_coach.point_at(rect, str(check[3]))


## What the tutorial wants from the open menu, for its tutorial_coach() hook: the step, the
## whole recipe (the suit builder) and the jacket's cloth (the phone's order).
func _coach_goal() -> Dictionary:
	return {
		"step": str(STEPS[_step].get("id", "")),
		"recipe": _recipe,
		"cloth": _recipe.get(Enums.GarmentType.JACKET, {}),
	}


## Aim the coach mark at what a menu's tutorial_coach() named: {rect} (a row or card, the
## pill beside it when `beside`) or {key} (a key-cap in its hint bar), plus the pill `text`.
func _coach_hint(menu: Control, hint: Dictionary) -> void:
	var rect: Rect2 = hint.get("rect", Rect2())
	if hint.has("key"):
		rect = _find_key(menu, str(hint["key"]))
	if rect.size == Vector2.ZERO:
		return  # a freshly rebuilt row isn't laid out yet: keep last frame's mark
	_coach.point_at(rect, str(hint.get("text", "")), bool(hint.get("beside", false)))


## Whether a line's coach mark may show yet: always, unless it names a `when` condition
## that hasn't come true (see the step format above STEPS).
func _coach_ready(check: Array) -> bool:
	return check.size() < 6 or str(check[5]) == "" or _met(str(check[5]))


func _move_hand(pos: Vector2) -> void:
	if pos.x < 0.0:
		_hand.visible = false
		return
	_hand.point_at(pos)


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
	var target := _line_target()
	if target == "@collector":
		return _project(_collector())
	if target == "":
		target = step.get("point", "")
	if target == "":
		return Vector2(-1, -1)
	return _project(_station(target))


## The station the next unticked line is about, if it names one — so the pin follows the
## cloth: to the worktable, back to it for the cut part, on to the machine.
func _line_target() -> String:
	var i := _next_check()
	if i < 0:
		return ""
	var check: Array = _checks()[i]
	return str(check[4]) if check.size() > 4 else ""


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
	_root = root
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

	_hand = PointerPin.new()
	root.add_child(_hand)

	_mentor = MentorDialog.new()
	root.add_child(_mentor)

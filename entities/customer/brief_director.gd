class_name BriefDirector
extends RefCounted

## Shapes a walk-in's taste after FrontDesk has set the brief (CustomerManager calls
## shape()). In order:
##   1. a regular brings back the dislike they showed before and their past suits;
##   2. a newcomer with no dislike may say no to the colour they keep seeing your suits
##      in about town, or keep a quiet dislike to reveal at the mirror (SuitTaste);
##   3. the cash guard drops a new dislike that would leave you nothing on the shelf and
##      nothing you can afford (keeping GameConfig.taste_cash_reserve in hand);
##   4. in opening week the brief may be nudged toward cloth the shelf lacks but the till
##      can pay for. Never forced: without such a brief the customer stays as they were.
## See docs/CUSTOMERS.md, "Taste".

const NUDGE_TRIES := 24

## The last order was made from cloth already on the shelf (raises the nudge chance).
var _last_from_shelf := false


func _init() -> void:
	EventBus.order_created.connect(_on_order_created)


func shape(
	pref: CustomerPreference, rng: RandomNumberGenerator, regular := "", keep_brief := false
) -> void:
	if pref == null:
		return
	var stock := _stock()
	if regular != "":
		_bring_back(pref, regular)
	var added := _add_dislike(pref, rng, regular)
	if added != "" and not _can_serve(pref, stock):
		_drop(pref, added)
	if keep_brief or not _nudge_open():
		return
	var key := "nudge_after_shelf" if _last_from_shelf else "nudge_chance"
	var chance := float(_cfg(key, 0.35))
	if rng.randf() < chance and SuitTaste.shelf_serves(pref, stock):
		_nudge(pref, rng, regular, stock)


# --- Steps -----------------------------------------------------------------------


## A regular's kept dislike and wardrobe. Their dislike overrides whatever the counter
## roll gave them, but only while the new brief still leaves them something.
func _bring_back(pref: CustomerPreference, regular: String) -> void:
	pref.owned_suits = Clientele.wardrobe(regular)
	if SuitTaste.options(pref).is_empty():
		pref.owned_suits = []  # a brief with nothing new left: let a repeat pass
	var kept := Clientele.kept_dislike(regular)
	if kept.is_empty():
		return
	var dislike := {"kind": str(kept.get("kind", "")), "value": int(kept.get("value", -1))}
	if not SuitTaste.leaves_room(pref, dislike):
		return
	pref.dislikes_color = -1
	pref.town_worn = 0
	if bool(kept.get("said", false)):
		pref.dislikes_color = dislike["value"]
	else:
		pref.quiet_dislike = dislike
		pref.quiet_known = bool(kept.get("known", false))
	if pref.likes_color == pref.dislikes_color:
		pref.likes_color = -1


## A town remark or a quiet dislike for someone with none yet. Returns which was added
## ("town", "quiet") or "".
func _add_dislike(pref: CustomerPreference, rng: RandomNumberGenerator, regular: String) -> String:
	if pref.dislikes_color >= 0 or not pref.quiet_dislike.is_empty():
		return ""
	if regular != "" and not Clientele.kept_dislike(regular).is_empty():
		return ""
	if _town_remark(pref, rng):
		return "town"
	var tier: int = Reputation.tier()
	var chances: Array = Config.data.quiet_dislike_by_tier if Config.data != null else []
	if chances.is_empty() or rng.randf() >= float(chances[clampi(tier, 0, chances.size() - 1)]):
		return ""
	pref.quiet_dislike = SuitTaste.roll_quiet(pref, rng, tier)
	pref.quiet_known = false
	return "quiet" if not pref.quiet_dislike.is_empty() else ""


## "I keep seeing your navy about town": the colour most worn in the last few days, once
## there are enough of them, if the brief leaves another colour.
func _town_remark(pref: CustomerPreference, rng: RandomNumberGenerator) -> bool:
	var window := int(_cfg("town_window_days", 5))
	var worn := Clientele.worn_about_town(Shift.day, window)
	var color := -1
	var count := 0
	for c: int in worn:
		if int(worn[c]) > count:
			color = c
			count = int(worn[c])
	if count < int(_cfg("town_min_worn", 2)) or not color in SuitTaste.brief_colors(pref):
		return false
	if not SuitTaste.leaves_room(pref, {"kind": "color", "value": color}):
		return false
	var step := float(_cfg("town_step", 0.2))
	if rng.randf() >= minf((count - 1) * step, float(_cfg("town_cap", 0.5))):
		return false
	pref.dislikes_color = color
	pref.town_worn = count
	if pref.likes_color == color:
		pref.likes_color = -1
	return true


func _drop(pref: CustomerPreference, added: String) -> void:
	if added == "town":
		pref.dislikes_color = -1
		pref.town_worn = 0
	else:
		pref.quiet_dislike = {}
		pref.quiet_known = false


## Reroll the occasion and style (and the taste that goes with them) until the shelf
## can't serve it but a cut you can afford can. Otherwise put everything back.
func _nudge(
	pref: CustomerPreference, rng: RandomNumberGenerator, regular: String, stock: Dictionary
) -> void:
	var before := _snapshot(pref)
	for _i in NUDGE_TRIES:
		pref.occasion = rng.randi() % Enums.Occasion.size()
		pref.style = rng.randi() % Enums.Style.size()
		pref.roll_taste(rng)
		pref.quiet_dislike = {}
		pref.quiet_known = false
		pref.town_worn = 0
		if regular != "":
			_bring_back(pref, regular)
		_add_dislike(pref, rng, regular)
		if SuitTaste.shelf_serves(pref, stock) or not FrontDesk.brief_feasible(pref):
			continue
		var cut := SuitTaste.cheapest_cut(pref)
		if cut >= 0 and cut <= GameState.money - int(_cfg("taste_cash_reserve", 100)):
			return
	_restore(pref, before)


# --- Helpers ---------------------------------------------------------------------


## Can the shop serve this brief: from the shelf, or with a cut the till can pay for?
func _can_serve(pref: CustomerPreference, stock: Dictionary) -> bool:
	if SuitTaste.shelf_serves(pref, stock):
		return true
	var cut := SuitTaste.cheapest_cut(pref)
	return cut >= 0 and cut <= GameState.money - int(_cfg("taste_cash_reserve", 100))


func _nudge_open() -> bool:
	if Reputation.tier() > 0 or (Tutorial != null and Tutorial.is_active()):
		return false
	return Shift.day <= int(_cfg("nudge_days", 3))


static func _scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null


func _stock() -> Dictionary:
	var scene := _scene()
	return ClothStock.stock(scene) if scene != null else {}


func _on_order_created(order: SuitOrder) -> void:
	var jacket: Dictionary = order.design.get(Enums.GarmentType.JACKET, {})
	var scene := _scene()
	if jacket.is_empty() or scene == null:
		return
	_last_from_shelf = (
		ClothStock
		. has_cloth(
			scene,
			int(jacket.get("fabric", 0)),
			int(jacket.get("pattern", 0)),
			int(jacket.get("color", 0)),
		)
	)


static func _snapshot(pref: CustomerPreference) -> Dictionary:
	return {
		"occasion": pref.occasion,
		"style": pref.style,
		"likes": pref.likes_color,
		"dislikes": pref.dislikes_color,
		"quiet": pref.quiet_dislike.duplicate(),
		"known": pref.quiet_known,
		"town": pref.town_worn,
		"owned": pref.owned_suits.duplicate(true),
	}


static func _restore(pref: CustomerPreference, s: Dictionary) -> void:
	pref.occasion = s["occasion"]
	pref.style = s["style"]
	pref.likes_color = s["likes"]
	pref.dislikes_color = s["dislikes"]
	pref.quiet_dislike = s["quiet"]
	pref.quiet_known = s["known"]
	pref.town_worn = s["town"]
	pref.owned_suits = s["owned"]


static func _cfg(key: String, fallback: Variant) -> Variant:
	if Config == null or Config.data == null:
		return fallback
	var v: Variant = Config.data.get(key)
	return fallback if v == null else v

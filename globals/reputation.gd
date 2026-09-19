extends Node

## The shop's standing on the Row — autoloaded as "Reputation".
##
## You start unknown. Every collected order adds points scaled by how well it met
## the brief and how cleanly it was made, with a bonus when the customer is truly
## delighted (great match AND great craft) and another when the suit follows the
## current fashion trend (News.current_fashion). Missing a deadline costs standing.
## Points map to named tiers that later gate which customers and content unlock.
##
## State persists across days (it's an autoload, above the scene tree), resets on a fresh
## run, and is captured/restored by SaveManager.

## Cumulative point thresholds and their rank names, low to high.
const TIERS := [
	{"at": 0, "name": "Unknown"},
	{"at": 40, "name": "Apprentice of the Row"},
	{"at": 120, "name": "Local Name"},
	{"at": 260, "name": "City Favourite"},
	{"at": 480, "name": "Master of the Row"},
]

## Decorations can raise reputation gains by at most this much (+50%).
const DECOR_CAP := 0.5

## Points awarded/lost. Setter clamps at 0 and announces changes for the HUD.
var points: int = 0:
	set(value):
		points = maxi(value, 0)
		EventBus.reputation_changed.emit(points, tier())


func _ready() -> void:
	EventBus.order_fulfilled.connect(_on_order_fulfilled)
	EventBus.order_expired.connect(_on_order_expired)
	EventBus.order_late.connect(_on_order_late)
	EventBus.press_mention.connect(_on_press_mention)


## Extra share of reputation gained thanks to the shop's decorations (ShopDecoration
## nodes in the current scene), capped at DECOR_CAP.
func decor_bonus() -> float:
	var total := 0.0
	for node in get_tree().get_nodes_in_group(ShopDecoration.GROUP):
		if node is ShopDecoration and (node as ShopDecoration).is_visible_in_tree():
			total += (node as ShopDecoration).reputation_bonus
	return minf(total, DECOR_CAP)


## Current rank index (0..TIERS.size()-1).
func tier() -> int:
	var idx := 0
	for i in TIERS.size():
		if points >= int(TIERS[i]["at"]):
			idx = i
	return idx


func tier_name() -> String:
	return str(TIERS[tier()]["name"])


## 0..1 progress from the current tier's threshold toward the next (1.0 at the top).
func tier_progress() -> float:
	var i := tier()
	if i >= TIERS.size() - 1:
		return 1.0
	var lo := int(TIERS[i]["at"])
	var hi := int(TIERS[i + 1]["at"])
	if hi <= lo:
		return 1.0
	return clampf(float(points - lo) / float(hi - lo), 0.0, 1.0)


func _on_order_fulfilled(order: SuitOrder, _payout: int) -> void:
	if order == null:
		return
	var match_avg := order.average_match()
	var quality := order.average_quality()
	var gain := 5 + int(round(match_avg * quality * 15.0))
	var loved := match_avg >= 0.85 and quality >= 0.85
	if loved:
		gain += 10
	var following := News != null and News.fashion_matches(order.design)
	if following:
		gain += News.fashion_bonus(order.design)
	gain = int(round(gain * (1.0 + decor_bonus())))
	points += gain
	_toast(gain, loved, following)


## The paper praised the shop (best suit spotted at a city event).
func _on_press_mention(_headline: String, reputation: int) -> void:
	if reputation <= 0:
		return
	points += reputation
	if UI != null:
		UI.toast("+%d reputation: you made the papers!" % reputation)


func _on_order_expired(_order: SuitOrder) -> void:
	points -= Config.data.expired_rep_loss if Config.data != null else 12


func _on_order_late(_order: SuitOrder) -> void:
	points -= Config.data.late_rep_loss if Config.data != null else 6


func _toast(gain: int, loved: bool, following: bool) -> void:
	if UI == null:
		return
	var note := "+%d reputation" % gain
	if loved:
		note += " — they loved it!"
	elif following:
		note += " — right on trend"
	UI.toast(note)

class_name StreetPitch
extends Node

## Lets the player drum up business on the street: every passer-by can be pitched to,
## once. The player calls out a (quirky) line, the passer-by stops to answer, and now and
## then it works — they turn for the door as a walk-in (CustomerManager.invite_in).
## Otherwise they shrug it off and stroll on. Added to strollers by the manager
## (StreetPitch.attach) and takes over their interaction, like CustomerWait.
##
## The odds grow with the shop's reputation (GameConfig.pitch_*). It can't conjure more
## work than the shop can take: no pitching while someone is being served, the Fully
## Booked sign is up, or the order book is swamped — and a win uses up one of the day's
## planned walk-ins (FrontDesk.claim_walk_in), so it brings custom forward, not extra.

const PITCHES := [
	"Psst — your elbows deserve better sleeves!",
	"Sir! Madam! That coat is a cry for help!",
	"Suits! Fresh suits! Still warm from the iron!",
	"One fitting and your mother will finally be proud!",
	"You walk like someone who needs a waistcoat!",
	"Trousers that fit — it's not a myth, step inside!",
	"I can see your ankles from here. Let me help.",
	"Free compliments with every jacket.",
	"You, yes you — born to wear pinstripes!",
	"My tape measure has been asking about you.",
	"Lapels so sharp you'll need a licence!",
	"Be honest: when were you last properly measured?",
]
const YES := [
	"...You know what? Go on, then.",
	"Ha! All right, you've talked me into it.",
	"I DO have a wedding coming up...",
	"My mother would like that. Lead the way!",
	"Well, since you ask so nicely.",
	"Pinstripes, you say? Show me.",
]
const NO := [
	"Do I LOOK like I wear suits?",
	"Not today, thank you!",
	"I'm late for the tram!",
	"My ankles are none of your business.",
	"Maybe when I'm rich.",
	"I only came out for bread.",
	"Nice try, tailor.",
]
const REPLY_AFTER := 1.5  # seconds the player's line hangs before the answer
const LINGER := 2.0  # ...and the answer, before they move on

static var _next_pitch_at := 0.0

## Where the stroll carries on to if the pitch fails.
var resume_to := Vector3.ZERO

var _cust: Customer
var _used := false


static func attach(cust: Customer, stroll_to: Vector3) -> StreetPitch:
	var pitch := StreetPitch.new()
	pitch.name = "StreetPitch"
	pitch.resume_to = stroll_to
	pitch._cust = cust
	cust.add_child(pitch)
	return pitch


## The chance a pitch lands right now: a base plus a little per reputation tier.
static func chance() -> float:
	var cfg := Config.data
	var base: float = cfg.pitch_base_chance if cfg != null else 0.3
	var per_tier: float = cfg.pitch_tier_bonus if cfg != null else 0.06
	var tier: int = Reputation.tier() if Reputation != null else 0
	return clampf(base + per_tier * tier, 0.0, 0.9)


func _ready() -> void:
	_cust.takeover = self
	(_cust.get_node("Interactable") as Interactable).set_enabled(true)


# --- Interaction (the Customer forwards these while we hold `takeover`) ----


func get_interaction_prompt(_actor) -> String:
	if _used or _now() < _next_pitch_at:
		return ""
	if _shop_full():
		return "Pitch the shop (not now — you've no room for another customer)"
	return "Pitch the shop to this passer-by"


func interact(actor) -> void:
	if _used or _now() < _next_pitch_at:
		return
	if _shop_full():
		Sfx.play("error")
		return
	_used = true
	var cfg := Config.data
	_next_pitch_at = _now() + (cfg.pitch_cooldown_s if cfg != null else 4.0)
	_pitch(actor as Node3D)


func _pitch(player: Node3D) -> void:
	var manager := _cust.manager
	# Reserve the shop's service slot now, so nobody else walks in while they decide.
	var won: bool = randf() < StreetPitch.chance() and manager != null
	won = won and bool(manager.hold_for(_cust))
	_stop_and_face(player)
	if player != null:
		WorldBubble.say(player, PITCHES.pick_random(), REPLY_AFTER - 0.3)  # gone as they answer
	Sfx.play_single("mentor_blip", -8.0, 1.1, 1.3)
	await get_tree().create_timer(REPLY_AFTER).timeout
	if not is_instance_valid(_cust):
		return
	var reply: String = YES.pick_random() if won else NO.pick_random()
	WorldBubble.say(_cust, reply, LINGER + 0.4)
	_cust.set_talking(true)
	_cust.react(Customer.REACT_LIKE if won else Customer.REACT_DISLIKE)
	Sfx.play("happy" if won else "unhappy", -6.0)
	await get_tree().create_timer(LINGER).timeout
	if not is_instance_valid(_cust):
		return
	_cust.set_talking(false)
	_cust.react(Customer.REACT_NEUTRAL)
	_release()
	if won:
		UI.pop_above_player("New customer!", "Your pitch worked")
		manager.invite_in(_cust)
	else:
		_cust.walk([resume_to], _cust.despawn)


func _stop_and_face(player: Node3D) -> void:
	var yaw := NAN
	if player != null:
		var to := player.global_position - _cust.global_position
		yaw = atan2(to.x, to.z)
	_cust.walk([], Callable(), yaw)


func _shop_full() -> bool:
	var manager := _cust.manager
	if manager == null or bool(manager.busy()) or not Shift.is_open():
		return true
	if FrontDesk == null:
		return false
	return FrontDesk.booked or FrontDesk.load_factor() >= FrontDesk.SWAMPED


## Hand the customer's interaction back (it's off until the manager gives them a mode).
func _release() -> void:
	if _cust.takeover == self:
		_cust.takeover = null
	(_cust.get_node("Interactable") as Interactable).set_enabled(false)
	queue_free()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

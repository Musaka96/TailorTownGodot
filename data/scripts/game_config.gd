class_name GameConfig
extends Resource

## Central tunables for the game — edit res://data/game_config.tres in the
## inspector to balance economy and minigame difficulty without touching code.

@export_group("Economy")
## See docs/ECONOMY.md for the pillars these numbers serve.
@export var starting_money: int = 500
## A new game starts with two bolts on a shelf: a suiting (jacket + pants) and a shirting.
@export var starter_suit_m: float = 8.0
@export var starter_shirt_m: float = 5.0
## Per-metre base cloth price, indexed by Enums.Fabric
## (worsted, flannel, tweed, mohair, linen, cotton, poplin, oxford).
@export var fabric_price_per_m: Array[int] = [20, 22, 18, 30, 16, 12, 16, 18]
## Per-metre pattern surcharge, indexed by Enums.Pattern (solid, pinstripe, herringbone,
## houndstooth, windowpane, glen, birdseye, sharkskin, nailhead, bengal, university,
## gingham, tattersall, end-on-end).
@export var pattern_surcharge_per_m: Array[int] = [0, 6, 5, 6, 5, 7, 6, 5, 5, 4, 4, 5, 6, 3]

@export_subgroup("Suit price (cloth + craft)")
## Craft fee per part at size M, before the reputation multiplier.
@export var craft_fee_jacket: int = 90
@export var craft_fee_pants: int = 50
@export var craft_fee_shirt: int = 40
## Craft fee multiplier per reputation tier (Unknown … Master).
@export var craft_mult_by_tier: Array[float] = [1.0, 1.15, 1.3, 1.5, 1.75]
## The tailor's handling margin on the cloth the suit needs (0.1 = +10%).
@export var cloth_handling: float = 0.1

@export_subgroup("Customers")
## Budget range (the most they'll pay) per reputation tier.
@export var budget_min_by_tier: Array[int] = [300, 350, 420, 500, 600]
@export var budget_max_by_tier: Array[int] = [450, 550, 650, 800, 950]
## Chance a shopper is one of your regulars (once you have some).
@export var regular_chance: float = 0.35
## Each completed order raises that regular's budget by this much (capped).
@export var loyalty_budget_step: float = 0.1
@export var loyalty_budget_max: float = 0.5

@export_subgroup("Payout")
## Match×quality at or above this pays the full price ("good enough").
@export var full_pay_at: float = 0.6
## Below this, pay falls off steeply (between the two it eases from 60% to 100%).
@export var low_pay_at: float = 0.4
## Match×quality at or above this earns a tip, growing to `tip_max` at a perfect 1.0.
@export var tip_from: float = 0.9
@export var tip_max: float = 0.25
## A late suit (collected the day after its due day) pays this share, and costs standing.
@export var late_pay: float = 0.75
@export var late_rep_loss: int = 6
@export var expired_rep_loss: int = 12
## A customer who calls for a suit that isn't ready waits this long (seconds) to be
## spoken to before walking out; regulars are more patient.
@export var collector_patience_s: float = 45.0
@export var regular_patience_mult: float = 1.5
## Apologise and a stranger agrees to call again tomorrow this often (a regular always
## does, and holds no grudge). Never past a city event's day, and only once per order.
@export var reschedule_chance: float = 0.6
## Standing lost when the order is lost all the same — after an apology, or (on top of
## expired_rep_loss) when the customer was left standing until they walked out.
@export var apologised_rep_loss: int = 6
@export var ignored_rep_loss: int = 6
## A coffee offered to a customer. Greeted with one, they add up to this share of the
## price to the bill when they collect (scaled by how good the cup was) and the gesture
## earns a little standing. Kept waiting with one, their patience starts over and drains
## at this rate, and a stranger is this much likelier to agree to call tomorrow.
@export var coffee_tip_share: float = 0.06
@export var coffee_rep: int = 2
@export var coffee_patience_drain: float = 0.5
@export var coffee_goodwill: float = 0.25
## "Best suit spotted": a suit worn to a city event makes the paper only when both its
## craft quality and its match to the brief reach these, AND it follows the trend.
## Otherwise the rival shop gets the story.
@export var spotted_quality: float = 0.85
@export var spotted_match: float = 0.85

@export_subgroup("Cloth ordering")
@export var roll_min_m: float = 2.0
@export var roll_step_m: float = 1.0
## Per-metre discount for long bolts (planning ahead is cheaper).
@export var bulk_10m_discount: float = 0.1
@export var bulk_20m_discount: float = 0.2
## Every Nth day is market day: all cloth is discounted.
@export var market_day_every: int = 5
@export var market_discount: float = 0.25
## When you're broke, the phone lets one bolt up to this price go on account (0% interest,
## repaid automatically from your next collection).
@export var account_limit: int = 120
## In-game hours from ordering a bolt on the phone to it arriving (the Courier Account
## upgrade uses the shorter one). Orders that would land after closing come next morning.
@export var delivery_hours: float = 2.0
@export var courier_hours: float = 0.25

@export_group("Workshop")
## Pressing Iron: quality a piece gains from a clean press (half of it with one scorch,
## none with two — never past 100%), and what a press scorched three times costs it.
@export var press_bonus_best: float = 0.08
@export var press_scorch_penalty: float = 0.05
## Coffee Machine: cups the pot makes a day, and bench games of focus from a well-made cup
## (a perfect one gives coffee_jobs_perfect more, a weak one only coffee_weak_share of
## them). The Espresso Machine adds to cups and jobs through its upgrade effects.
@export var coffee_cups: int = 2
@export var coffee_jobs: int = 3
@export var coffee_jobs_perfect: int = 1
@export var coffee_weak_share: float = 0.6
## While focused: the bench games' bands are this much wider and cloth drift halves.
@export var focus_band: float = 1.2

@export_group("Apprentice")
## Shop-time seconds he takes to cut (and again to sew) a part: green → seasoned.
@export var apprentice_step_seconds_start: float = 40.0
@export var apprentice_step_seconds_master: float = 15.0
## Quality of each step (cut, sew), green → seasoned; the two multiply like yours.
@export var apprentice_quality_start: float = 0.8
@export var apprentice_quality_master: float = 0.95
## Jobs of a kind before he's ~63% of the way from green to seasoned (1 − e^−n/this).
@export var apprentice_learn_jobs: float = 8.0

@export_group("Orders")
## Deadline range in shop days (the customer returns on that day's shift).
@export var deadline_min_days: int = 1
@export var deadline_max_days: int = 4

@export_group("Day / Night")
## In-game hour the shift opens at (24h clock).
@export var shift_start_hour: float = 8.0
## In-game hour the shift closes at; the closing bell rings here.
@export var shift_end_hour: float = 17.0
## Real seconds for the whole shift (open → close) to play out.
@export var shift_real_seconds: float = 300.0

@export_group("Cutting minigame")
@export var cut_lead_seconds: float = 1.6  ## "get ready" pause before cutting starts
@export var cut_seconds: float = 15.0  ## time to cut the whole shape when aligned
@export var cut_tolerance_deg: float = 26.0  ## how far off the line still cuts cleanly
@export var cut_max_mistakes: int = 3
## Which cutting game the worktable runs (the F3 debug panel can flip it live).
@export_enum("Steer (v1)", "Seam allowance (v2)", "Strokes (v3)") var cut_variant: int = 1
## v2/v3 zones, in shape units (1 unit ≈ 40 cm): on the chalk, the seam allowance
## outside it, and how far inside the line you can stray before it's a nick.
@export var cut_band_perfect: float = 0.015
@export var cut_band_good: float = 0.05
@export var cut_band_nick: float = 0.02
@export var cut2_seconds: float = 12.0  ## v2: whole outline at full push, no glide
@export var cut2_glide: float = 1.8  ## v2: speed multiplier gliding a straight on the line
@export var cut2_turn_deg: float = 170.0  ## v2: how fast the shears turn at full lock
@export var cut3_max_stroke: float = 0.45  ## v3: longest stroke (shape units)
@export var cut3_min_stroke: float = 0.04  ## v3: a quick tap's snip
@export var cut3_charge_seconds: float = 0.9  ## v3: time to open the blades fully
@export var cut3_short_stroke: float = 0.12  ## v3: snips shorter than this chew the edge

@export_group("Sewing minigame")
@export var sew_lead_seconds: float = 1.6  ## "get ready" pause before the needle moves
@export var sew_stitches: int = 9
@export var sew_cross_seconds: float = 7.5  ## time for the needle to cross the seam
@export var sew_good_window: float = 0.05  ## timing window (seam fraction) for a stitch
@export var sew_perfect_window: float = 0.025
@export var sew_max_mistakes: int = 3
## Which sewing game the machine runs (the F3 debug panel can flip it live).
@export_enum("Rhythm (v1)", "Pedal & Guide (v2)") var sew_variant: int = 1
@export var sew2_top_speed: float = 0.36  ## v2: cloth feed at full pedal (units/s)
@export var sew2_spin_seconds: float = 1.0  ## v2: motor 0 → full on the base machine
@export var sew2_coast_seconds: float = 0.35  ## v2: motor full → 0 after letting go
@export var sew2_turn_sewing_deg: float = 50.0  ## v2: turning the cloth while sewing (°/s)
@export var sew2_turn_still_deg: float = 80.0  ## v2: turning it about a stopped needle

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
@export_enum("Steer (v1)", "Seam allowance (v2)", "Strokes (v3)") var cut_variant: int = 0
## v2/v3 zones, in shape units (1 unit ≈ 40 cm): on the chalk, the seam allowance
## outside it, and how far inside the line you can stray before it's a nick.
@export var cut_band_perfect: float = 0.015
@export var cut_band_good: float = 0.05
@export var cut_band_nick: float = 0.02
@export var cut2_seconds: float = 18.0  ## v2: time for the whole outline at full push
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

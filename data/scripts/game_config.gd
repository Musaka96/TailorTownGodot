class_name GameConfig
extends Resource

## Central tunables for the game — edit res://data/game_config.tres in the
## inspector to balance economy and minigame difficulty without touching code.

@export_group("Economy")
@export var starting_money: int = 500
## Per-metre base cloth price, indexed by Enums.Fabric
## (worsted, flannel, tweed, mohair, linen).
@export var fabric_price_per_m: Array[int] = [20, 22, 18, 30, 16]
## Per-metre pattern surcharge, indexed by Enums.Pattern
## (solid, pinstripe, herringbone, houndstooth, windowpane, glen, birdseye, sharkskin, nailhead).
@export var pattern_surcharge_per_m: Array[int] = [0, 6, 5, 6, 5, 7, 6, 5, 5]
## A finished suit sells for this multiple of the cloth it used (used from the
## customer/selling phase).
@export var sell_markup: float = 2.4

@export_group("Cutting minigame")
@export var cut_lead_seconds: float = 1.6        ## "get ready" pause before cutting starts
@export var cut_seconds: float = 15.0            ## time to cut the whole shape when aligned
@export var cut_tolerance_deg: float = 26.0      ## how far off the line still cuts cleanly
@export var cut_max_mistakes: int = 3

@export_group("Sewing minigame")
@export var sew_lead_seconds: float = 1.6        ## "get ready" pause before the needle moves
@export var sew_stitches: int = 9
@export var sew_cross_seconds: float = 7.5       ## time for the needle to cross the seam
@export var sew_good_window: float = 0.05        ## timing window (seam fraction) for a stitch
@export var sew_perfect_window: float = 0.025
@export var sew_max_mistakes: int = 3

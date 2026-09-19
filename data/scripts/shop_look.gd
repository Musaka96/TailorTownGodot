class_name ShopLook
extends Resource

## A cosmetic interior preset for the shop (see docs/SHOP_LOOKS.md): recolours the
## upper wall, wainscot panelling, floor, rugs and curtains by matching the imported
## gltf's baked material names — ShopLookApplier does the matching and builds the actual
## materials. Authored as .tres in data/shop_looks/ (see tools/build_shop_looks.gd).
##
## price/reputation_required follow the same pricing language as globals/upgrades.gd, so
## these are ready to slot into a future cosmetic-upgrade menu (not wired up yet).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 0 = owned from the start (free).
@export var price: int = 0
## Reputation.tier() points needed before it can be bought (see globals/reputation.gd).
@export var reputation_required: int = 0

@export_group("Slots")
@export var wall: ShopLookSlot
@export var wainscot: ShopLookSlot
@export var floor: ShopLookSlot
@export var rug: ShopLookSlot
## Round and runner rugs have their own images, so one design is never stretched across
## three shapes. Only the v7 shop has these surfaces.
@export var rug_round: ShopLookSlot
@export var rug_runner: ShopLookSlot
@export var drape: ShopLookSlot

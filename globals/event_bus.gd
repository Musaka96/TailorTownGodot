extends Node

## Global signal hub — autoloaded as "EventBus".
##
## Systems emit and listen here instead of referencing each other directly, which
## keeps stations, UI, economy and customers decoupled and independently testable.
## Add signals as phases need them; keep it to *signals only*, no logic/state.

# --- Phase 1: interaction & carry ---
signal item_picked_up(item: Node)
signal item_dropped(item: Node)
signal item_stored(item: Node, station: Node)
signal item_taken(item: Node, station: Node)

## Current interaction prompt for the HUD ("" = nothing in range).
signal interaction_prompt_changed(text: String)

# --- Economy / ordering ---
signal money_changed(balance: int)
signal order_placed(material: MaterialType, length: float, cost: int)
signal order_delivered(roll: Node)

# --- Cutting ---
signal cloth_cut(piece: Node, source_roll: Node)
signal piece_cut(piece: Node)  # a garment part was cut at the worktable
signal piece_sewn(piece: Node)  # a garment part was sewn at the machine

# --- Assembly ---
signal suit_packaged(suit: Node)

# --- Customer / design ---
signal design_confirmed(design: Dictionary)

# --- Customers, storefront & orders ---
## A shopper has entered and is waiting to be greeted.
signal customer_waiting(customer: Node)
## A greeted customer has been sent to the fitting mirror.
signal customer_seated(customer: Node)
## The player answered a walk-in's greeting: "take", "book", "refer" or "decline".
signal customer_answered(choice: String, customer: Node)
## A design was shown to the customer at the mirror; `reason` is their first objection.
signal design_judged(suitable: bool, reason: String)
## A customer approved a design and left; an order now exists to make it.
signal order_created(order: Resource)
## A made piece was checked off against an order (garment_type of Enums.GarmentType).
signal order_part_filled(order: Resource, garment_type: int)
## Every piece of an order has been made — it now needs assembling into a suit at the
## mannequin before it can be collected.
signal order_pieces_ready(order: Resource)
## The suit was assembled at the mannequin; the order now waits for the customer to collect.
signal order_ready(order: Resource)
## An order's deadline arrived — the customer is on their way back to collect it.
signal order_due(order: Resource)
## The running game scene is being left or replaced (to the main menu, a load, or a new
## game). Systems holding per-session UI/state (tutorial, open menus) shut down cleanly.
signal session_ended
## The order book was wiped/rebuilt (new game, load) — views should drop their old entries.
signal orders_cleared
## The customer came on the due day but the suit wasn't ready — they'll return tomorrow.
signal order_late(order: Resource)
## Cloth bought on account (owed > 0) or settled (owed == 0).
signal account_changed(owed: int)
## The customer collected a finished order and paid `payout`.
signal order_fulfilled(order: Resource, payout: int)
## An order's deadline passed without it being finished; it was lost.
signal order_expired(order: Resource)

# --- Day / night shift ---
## A new day dawned (the morning, before the sign is flipped): the paper lands, the pot is
## refilled. Always fires before that day's shift_started.
signal day_began(day: int)
## The shop opened for the day at `start_hour` — the player flipped the door sign.
signal shift_started(start_hour: float)
## The shift reached its end hour (night); the closing bell rings.
signal shift_ended

# --- Reputation & news ---
## The shop's standing changed; `tier` is the current rank index.
signal reputation_changed(points: int, tier: int)
## A fresh edition of the paper is ready for the given day (auto-opens the HUD paper).
signal newspaper_ready(day: int)
## The paper ran a story praising the shop (e.g. best suit spotted at a city event);
## Reputation adds `reputation` points and the HUD toasts it.
signal press_mention(headline: String, reputation: int)

# --- Workshop ---
## Coffee focus changed: `jobs` bench games left with steadier hands (0 = none).
signal focus_changed(jobs: int)

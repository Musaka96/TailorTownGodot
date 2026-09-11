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
## A customer approved a design and left; an order now exists to make it.
signal order_created(order: Resource)
## A made piece was checked off against an order (garment_type of Enums.GarmentType).
signal order_part_filled(order: Resource, garment_type: int)
## Every piece of an order is checked off; it now waits for the customer to collect.
signal order_ready(order: Resource)
## An order's deadline arrived — the customer is on their way back to collect it.
signal order_due(order: Resource)
## The customer collected a finished order and paid `payout`.
signal order_fulfilled(order: Resource, payout: int)
## An order's deadline passed without it being finished; it was lost.
signal order_expired(order: Resource)
## A customer left the shop (served or gave up).
signal customer_left(customer: Node)

# --- Day / night shift ---
## A new work shift began at `start_hour` (midday).
signal shift_started(start_hour: float)
## The shift reached its end hour (night); the closing bell rings.
signal shift_ended

# --- Reputation & news ---
## The shop's standing changed; `tier` is the current rank index.
signal reputation_changed(points: int, tier: int)
## A fresh edition of the paper is ready for the given day (auto-opens the HUD paper).
signal newspaper_ready(day: int)

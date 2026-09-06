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

# --- Economy (used from Phase 2) ---
signal money_changed(balance: int)

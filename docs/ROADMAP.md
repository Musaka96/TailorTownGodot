# TailorTown — Roadmap & Feature Readiness

Upcoming systems the owner has flagged, each with **what already supports it** and
**what to build first**, so a future session can start without re-deriving the
architecture. Ordered roughly easiest → hardest. (Assessed 2026-09-11 against the
current code; the SaveManager capability-scan groundwork mentioned below is
**already done** — new stateful stations are saved automatically.)

---

## A. Coffee station — sit, drink, timed "caffeinated" buff (better suit quality)

**Idea:** a coffee spot in the shop; sit and drink to gain a timed focus buff that
raises the quality of pieces you craft while it's active.

**Supports it now:**
- Adding a station is trivial (the `Interactable` + `get_interaction_prompt`/
  `interact` pattern; make it a hand-owned scene under `stations/coffee/`).
- Quality already flows piece → suit: set at `worktable.gd finish_cut`, multiplied
  at `sewing_machine.gd finish_sew`, averaged at `mannequin.gd _package`. A buff is
  a clean post-multiplier at those two `finish_*` points.

**Build first:**
- There is **no global "active buffs / player status" concept.** Add a small
  `Buffs` (or `PlayerStatus`) autoload that tracks timed effects and emits
  EventBus signals (`buff_started/ended`) for the HUD. Read it in `finish_cut`/
  `finish_sew` (e.g. `quality *= Buffs.quality_multiplier()`).
- Decide save behaviour: a timed buff should snapshot **remaining seconds**.
  SaveManager captures autoload state explicitly (money/rep/upgrades/clock) — add a
  `Buffs.save_state()`/`restore()` and one line in `capture()`/`_apply_pending()`.
- A **"sit/drink" animation** is new: `character_rig` currently blends only
  locomotion + carry + wave/accept one-shots. Add a sit pose/clip to
  `data/animations` and a rig state, or fake it (snap to a seated marker + idle).
- Effort: **Low-Med.** Mostly additive; the buff autoload is the real new seam.

## B. "Best suit spotted" newspaper announcement + bonus reputation

**Idea:** when you make a good-enough suit during a relevant city event, the next
paper runs a "best suit spotted" story that promotes the shop and grants extra rep.

**Supports it now:** most of the wiring exists.
- `News` already runs a daily fashion trend + city events with day/occasion/style
  and biases customer briefs (`event_bias`).
- `Reputation._on_order_fulfilled` already grants a fashion bonus
  (`News.fashion_bonus`) — the fulfil path is exactly the right hook.
- `NewsEvent` already carries the event metadata; the paper renders from `News`.

**Build first:**
- `News` today has `event_bias` (spawning) and `fashion_matches` (pattern trend)
  but **no "is an event live right now AND does this suit clear a quality bar"**
  query. Add `NewsEvent` fields (announcement text, quality threshold) and a
  method like `News.event_reward(order, day) -> {rep, headline}`.
- Grant the bonus at the fulfil hook (extend `reputation.gd _on_order_fulfilled`),
  and **queue a headline** for the next edition (News compiles editions on
  `shift_started`) so it appears in the morning paper. Emit a new EventBus signal
  (e.g. `press_mention`) so the HUD can toast it.
- Effort: **Low-Med.** Extends existing seams; no refactor.

## C. Design catalog — save a design as a named preset; pick a variant at the mirror

**Idea:** save a suit design under a name; when designing at the mirror, load a
premade variant from the catalog instead of building from scratch.

**Supports it now:** **well positioned.**
- The design dict shape is already canonical and reused everywhere:
  `{ GarmentType(int) → { fabric, color, pattern, style_idx } }` (see
  `ui/suit_builder.gd`, stored verbatim in `SuitOrder.design`,
  `order_manager.create_order`). A preset is literally that dict + a name.

**Build first:**
- A small persistent store: a `DesignCatalog` autoload (or a `.tres`) with
  `save(name, design)` / `list()` / `get(name)`. Decide global (one file) vs
  per-save (probably global, like a pattern book).
- UI in `suit_builder.gd` to (1) list presets and load one into `_design` then
  re-run `_refresh` + `_apply_to_customer`, and (2) a "save this design" action.
- If presets persist across runs, add a `DesignCatalog.save_state`/`restore`
  (autoload state, like Upgrades) — or write its own `.tres` under `user://`.
- Effort: **Low-Med.** Mostly additive; reuses the design-dict format.

## D. Shop personalization — swappable furniture, walls, floors, carpets

**Idea:** customize the shop's appearance (furniture, walls, floor, carpets).
Asset-heavy (owner supplies models).

**Supports it now:**
- The rig already proves runtime mesh/material swapping (`character_rig` wardrobe),
  and materials are data-driven `.tres` — the same approach fits furnishings.

**Build first:**
- Scenes are **hand-owned with stations placed as fixed nodes** — there is no
  "slot"/placement layer. Add **named anchor/slot nodes** in the room scene
  (e.g. `Furnishings/FloorSlot`, `WallSlot_*`) and a **data-driven furnishing
  catalog** (`Resource`: id, category, mesh/material, price).
- A **placement/apply system** that instantiates the chosen furnishing at each
  slot, plus a purchase flow (reuse the `Upgrades.can_buy` gating pattern).
- **Persistence:** the chosen furnishings must be saved. SaveManager captures
  autoload state + station `save_state` — add a furnishings section (a `Decor`
  autoload with `save_state`, or per-slot `save_state` nodes).
- Feeds directly into **E** (each location has its own furnishings).
- Effort: **Med-High** (biggest asset + systems lift after E).

## E. New shop location — reputation-gated, costs money, moves to a new region

**Idea:** once reputation is high enough, buy and move to a new shop in a new
region (far future).

**Supports it now:**
- Reputation tiers (`reputation.gd`) and gated purchasing (`Upgrades` pattern)
  already exist. Scenes are hand-owned `.tscn`, so a second room is authorable.

**Build first — this is the biggest refactor:**
- **SaveManager assumes one world.** `MAIN_SCENE` is a single const, `_shop_room`
  / `_capture_loose` assume one `ShopRoom`, and stations are captured by scanning
  "the current scene." Multi-location needs: a **current-location** field in the
  save, **per-location contents** (not one flat `stations`/`loose` blob), and a
  **scene-swap that isn't the load-a-save path**.
- **CustomerManager** hardwires storefront markers from one scene — each location
  needs its own markers, or a per-location config resource.
- A **purchase-a-location transaction** (new money sink) + a `Location`/world-state
  layer that the save, spawner, and scene loader all read.
- Plan the `Location` abstraction **before** attempting this; it also subsumes D
  (per-location furnishings). Effort: **High.**

---

## Suggested groundwork order

1. **B** and **C** are the cheapest wins that extend existing seams — do these first.
2. **A** introduces the reusable `Buffs`/status autoload (useful beyond coffee).
3. **D** introduces the furnishing catalog + slot layer + a `Decor` save section.
4. **E** last: design a `Location`/world-state layer that folds in D's per-location
   furnishings and generalises SaveManager away from a single `main.tscn`/`ShopRoom`.

The one structural investment that pays off across A/D/E is keeping **all new
stateful things save-discoverable** — stations already are (capability scan);
apply the same "explicit `save_state` + one line in `capture()`" habit to new
autoloads (`Buffs`, `Decor`, `Location`).

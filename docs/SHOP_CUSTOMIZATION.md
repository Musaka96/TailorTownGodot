# Shop customization: plan

Unlockable finishes for the shop's walls, wainscot, floor, rugs and curtains, bought from the
phone, previewed live, and worth a little reputation. This is Roadmap item **D** for surfaces;
furniture and decor spots come after. Status: **planned, not built** (2026-09-19).

## Decisions (owner, 2026-09-19)

| Question | Decision |
|---|---|
| Whole looks or surface by surface? | **Mix and match, plus sets.** Every surface is bought on its own; the looks stay as curated sets with a small matched-set bonus. |
| How does a change appear? | **Live preview from a sky overview of the shop.** Confirming a change plays working sounds and a burst of dust and smoke in the shop, thick enough to cover the actual texture switch. |
| Does decoration matter? | **Yes, a small reputation bonus** through the existing decoration hook, capped. |
| Different finishes per room? | **Later.** Whole shop first; per-room slots are a second pass. |

## What already exists

- **Looks system** (`docs/SHOP_LOOKS.md`): `ShopLook` / `ShopLookSlot` resources, `ShopLookApplier`
  recolours seven material slots on the shop (`InWall`, `Wainscot`, `Floor`, `Rug`, `RugRound`,
  `RugRunner`, `Drape`), eleven looks, F4 debug cycling, saves through `SaveManager`.
- **Buying pattern:** `globals/upgrades.gd` (`can_buy`, `buy`, `tier_met`, `save_state`) and the
  phone's Shop Upgrades screen (`ui/phone_order.gd`).
- **Meaning hook:** `ShopDecoration` + `Reputation.decor_bonus()` (sum of bonuses, cap +50%).
  `ECONOMY.md` names decoration as the missing late-game sink, at $60-1,500 and 0.3-2% each.
- **Reputation tiers:** 0 / 40 / 120 / 260 / 480 points.

## 1. Data: finishes and sets

- `ShopFinish` (Resource, replaces the role of `ShopLookSlot` as a catalogue item):
  `id`, `category` (WALL, WAINSCOT, FLOOR, RUG, DRAPE), `display_name`, `description`, `price`,
  `tier` (reputation tier needed), `charm` (reputation bonus share, e.g. 0.01), `unlock`
  (`"shop"` by default, or a special source, see 4), and the material data the slot has today
  (texture set, tint, uv scale, roughness, normal scale). A RUG finish is a colour family and
  carries all three rug images.
- `ShopLook` becomes a **set**: a name plus one finish id per category. Owning every finish in a
  set and wearing them together gives the matched-set bonus.
- `Decor` autoload, modelled on `Upgrades`: catalogue loaded from `data/shop_finishes/*.tres`,
  `owned`, `equipped` per category, `can_buy(id)`, `buy(id)`, `equip(id)`, `buy_set(id)`,
  `charm_total()`, signals `changed` / `equipped_changed`, `save_state` / `restore` / `reset`.
  `ShopLookApplier` stops owning state and simply listens to `Decor`.
- Migration: `tools/build_shop_looks.gd` becomes `tools/build_shop_finishes.gd` and splits the
  eleven looks into about 6 wall finishes, 8 wainscot colours, 3 floors, 8 rug families and 8
  curtain colours, then writes the eleven sets. Old saves that stored a look id equip that set.
- Free from the start: the five Fern Damask finishes and the Sage & Panel ones.

## 2. The decorator: buying and previewing

- A **Decorator** entry on the phone, next to Shop Upgrades.
- **Sky overview:** opening it lifts the camera to a fixed overview of the whole shop (roof
  already fades through `RoofManager`), game time paused like the other phone screens.
- Category tabs, then a swatch list. Each row: swatch, name, price or OWNED or the reputation
  rank it needs. Moving the selection **previews the finish live** in the shop behind the panel.
  Leaving without confirming restores what was equipped.
- Confirm = buy (if needed) and equip. Owned finishes swap for free, forever.
- A Sets tab lists the curated sets: one press previews the whole set, shows the total for the
  pieces not yet owned, and buys them together.
- Swatch icons are rendered by a tool (`tools/shot_finish_swatches.gd`), not painted by hand.
- UI rules: `UI_STYLE_GUIDE.md`, the `check_ui.gd` gate, and the fixed-panel rule (only the panel
  is a fixed size; content stacks and scrolls).

## 3. The change itself: the refit moment

Previewing is instant and silent. **Confirming** plays a short refit (about 1.5 s):

1. Dust and smoke puffs burst across the affected surfaces (floor-wide for floors, along the
   walls for wallpaper, a puff per rug), thick enough to hide the surface.
2. Working sounds: hammering, sawing, a roller, cloth being shaken out, per category. Generate
   them locally (see the ComfyUI audio recipe) and route through the existing audio buses.
3. The material swaps while the smoke is at its thickest, then it clears on the new finish.
4. Optional later: a Gazette line the next morning when a whole set is completed.

Implementation: one `RefitFX` scene (GPUParticles3D emitters sized from the shop's interior box,
one shared puff texture, an AudioStreamPlayer) driven by `ShopLookApplier` with a callback at the
cover point. Keep particle counts modest; the shop is already a heavy scene.

## 4. Unlocking and meaning

- **Base rule:** price plus reputation tier, exactly like upgrades. Indicative prices: paint and
  plain panelling $60-150, wallpapers $200-450, floors $300-600, rugs $80-250, curtains $60-200,
  so a full fancy set lands around $900-1,500 (the ECONOMY.md range).
- **Special sources** (a handful, for surprise): a market-day stall that sells rugs, a regular who
  gifts a finish after several happy orders, a press mention unlocking a "featured" wallpaper.
- **Reputation:** `Reputation.decor_bonus()` also adds `Decor.charm_total()`; still capped at
  +50%. Charm 0.3-2% per finish, rising with price. Matched set: +2%. "Freshly decorated": +3%
  for three days after any confirmed change, so redecorating is a repeatable sink.
- No finish is strictly best: charm follows price tier, and the set bonus rewards coherence over
  piling up the most expensive pieces.

## 5. Build order

| Phase | What | Size |
|---|---|---|
| 1 | `ShopFinish`, sets, `Decor` autoload, save/restore, applier listens to `Decor`, builder + tests | M |
| 2 | Decorator phone screen, sky overview camera, live preview, buy / equip, swatch tool | M-L |
| 3 | Refit FX (particles + sounds), charm into reputation, set and fresh bonuses, tests | M |
| 4 | Special unlock sources, Gazette line, more finishes | S-M |
| 5 | Per-room finishes (kit gets `InWall_Shop` / `InWall_Work` style slots), exterior colours (door, awning, shutters already are slots), decor spots with alternatives | L |

Each phase ships with a headless test in `tools/` and in-engine screenshots.

## Open questions for later

- Should customers react to a look (a line of dialogue, a preference)? Not planned for v1.
- Should the new-location feature (Roadmap E) reset or carry over owned finishes? Carry over.

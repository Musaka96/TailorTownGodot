# TailorTown — Project State

**Snapshot date:** 2026-09-11 · **Engine:** Godot 4.7.2 (Forward+, Jolt, D3D12) ·
**Status:** playable vertical-slice demo (full craft-and-sell loop + tutorial).

This is the source-of-truth "where are we" document. `docs/GAME_DESIGN.md` is the
*original* design/plan (still useful for intent, but describes an earlier target);
this file describes what is **actually implemented**.

---

## 1. What the game is

A top-down 3D bespoke-tailoring shop sim. You physically walk the shop (WASD /
gamepad, camera-relative), **carry one item at a time**, and move cloth through a
crafting pipeline at fixed stations. Customers arrive with an **occasion + style**
brief and a **budget**, sit at the mirror, and you design a suit for them; a
confirmed design becomes a deadlined **order**. You craft the matching pieces,
assemble a suit, and fulfil the order for money and **reputation**. Days are timed
shifts you open and close.

## 2. The core loop (all implemented)

```
Phone (order cloth $) → bolt delivered → Shelf (store; cut a length → FabricPiece)
→ Worktable (pick type/size/style + CUTTING minigame → GarmentPiece[CUT])
→ Sewing machine (SEWING minigame → GarmentPiece[SEWN])
→ Clothing rack (hang finished pieces) → Mannequin (assemble → Suit)
Customer at Mirror → suit builder (design to brief within budget) → Order created
Suit vs open orders → matched pieces paid on collection → money + reputation
```

Reputation unlocks premium fabric suppliers and shop upgrades (bought at the
phone). A newspaper each morning sets a fashion trend and can bias customer
briefs. The whole thing saves/loads and has a guided first-run tutorial.

## 3. Runtime architecture

### Autoloads (`project.godot [autoload]`, in load order)

| Name | File | Role |
|---|---|---|
| **EventBus** | `globals/event_bus.gd` | Pure signal hub — the decoupling backbone (see §4). |
| **Sfx** | `globals/sfx.gd` | Sound manager: one-shot pool, named loops, music, auto-wired to EventBus. |
| **Config** | `globals/config.gd` | Loads `data/game_config.tres` (`GameConfig`) — all tunables. |
| **GameState** | `globals/game_state.gd` | `money`, `is_paused`, `input_locked`; top-level pause/quit input. |
| **Catalog** | `globals/catalog.gd` | Content DB: all `MaterialType` + the `DressCode` rulebook. |
| **Orders** | `globals/order_manager.gd` | Order lifecycle: create / submit (per-piece match) / collect / expire; deadlines. |
| **Reputation** | `globals/reputation.gd` | Points + 5 tiers; gains on fulfil (incl. fashion bonus), loses on expire. |
| **Upgrades** | `globals/upgrades.gd` | Reputation-gated machine upgrades + fabric vendors, bought at the phone. |
| **News** | `globals/news_manager.gd` | Daily paper: fashion trend + city events; biases customer briefs. |
| **UI** | `ui/ui.tscn` (`ui/ui.gd`) | Root of in-game UI; `open_*` entry points; builds several screens in code. |
| **PostFX** | `globals/postfx.gd` | Full-screen retro shader driven by a `PostFxProfile`. |
| **Settings** | `globals/settings.gd` | Player options → `user://settings.cfg` (audio, display, key rebinds). |
| **Shift** | `globals/shift_manager.gd` | Working-day lifecycle; "lock up shop" door; `is_open()` gates work/spawns. |
| **DayNight** | `globals/day_night.gd` | Shift clock + sun sweep; `start_shift`/`shift_ended`. Does NOT auto-start at boot. |
| **SaveManager** | `globals/save_manager.gd` | Save/load orchestrator; boot flow; autosave on `shift_ended`. |
| **Tutorial** | `globals/tutorial.gd` | Data-driven first-run walkthrough (hand pointer, EventBus-driven steps). |
| **Debug** | `globals/debug_menu.gd` | F3 in-game console (money, customers, orders, shift) — debug builds only. |
| **McpBridgeGame** | `mcp_bridge_game.gd` | TCP tooling bridge (screenshot / tree / click) on 127.0.0.1:9501. |

Autoload order is deliberate: EventBus first; Config before GameState (reads
`Config.data`); Reputation before Upgrades/News (they read it); SaveManager/
Tutorial last. `UI` is referenced by Tutorial/Reputation but always null-guarded.

### Entities (`entities/`)

- **Player** (`scenes/player/player.gd`, `Player`, CharacterBody3D): camera-relative
  movement + sprint, Jolt gravity/jump, drives the rig's locomotion/carry anim,
  points `CarrySlot` at the rig's hand bone.
- **Carry / interaction** (`entities/player/`): `CarrySlot` (holds one item),
  `interaction_controller.gd` (nearest-`Interactable` picker + brass outline;
  respects `Tutorial.blocks` and `GameState.input_locked`),
  `entities/scripts/interactable.gd` (`Interactable`, generic Area3D trigger).
- **Carried items** (`entities/items/`), all Node3D with a common carry interface:
  `MaterialRoll` (bolt, `remaining_length_m`) → `FabricPiece` (cut cloth) →
  `GarmentPiece` (`garment_type`/`size`/`style`/`quality`/`stage` CUT→SEWN) →
  `Suit` (`parts` dict + avg `quality`).
- **Customer** (`entities/customer/customer.gd`, `Customer`): waypoint walker
  (no navmesh), modes NONE/GREET/MIRROR/COLLECT, drives its rig, reacts.
- **CustomerManager** (`entities/customer/customer_manager.gd`): pedestrian spawn
  timer, one shopper served at a time, storefront markers via NodePaths, returning
  collectors, `spawn_tutorial_customer()` poof.
- **CharacterRig** (`entities/character/character_rig.gd`, shared by player &
  customers): skinned KayKit-derived rig, AnimationTree blends (idle/walk/carry +
  one-shots), modular wardrobe (head/hair/top/bottom mesh swap with bone remap),
  2D sprite faces on the `head_2` bone (blink/talk/expressions + head-wobble).
  Built by `tools/build_character.gd` — **the only scene builder still used.**

### Stations (`stations/`)

| Station | Accepts | Produces | Emits | Opens |
|---|---|---|---|---|
| Phone | — | `MaterialRoll` at delivery spot | `order_delivered` | order/upgrades menu |
| Shelf | `MaterialRoll` | `FabricPiece` (on cut) | `item_stored/taken`, `cloth_cut` | shelf browse menu |
| Worktable | `FabricPiece` | `GarmentPiece[CUT]` | `piece_cut` | config + cutting minigame |
| SewingMachine | `GarmentPiece[CUT]` | `GarmentPiece[SEWN]` | `piece_sewn` | sewing minigame |
| ClothingRack | `GarmentPiece`/`Suit` | storage | `item_stored/taken` | rack browse menu |
| Mannequin | 3× SEWN pieces | `Suit` → `Orders.submit` | `suit_packaged` | — (direct) |
| Mirror | (customer) | order (via builder) | — | suit builder |
| Bookshelf | — | — | — | handbook |
| TrashCan | any item | destroys it | — | — (poof) |

Stations gate on `UI._shop_closed()` (refuse at night, except during the tutorial).
Stateful stations implement `save_state`/`load_state` (Shelf, ClothingRack,
Mannequin, Worktable, SewingMachine) and are persisted automatically.

### UI (`ui/`)

`ui/ui.gd` (autoload **UI**) is the hub. Some screens are scene children of
`ui/ui.tscn` (phone_order, worktable_screen, sewing_screen, suit_builder,
customer_request, handbook, hud, shelf_menu, orders_panel); others are built in
code in `ui.gd._ready` (orders_menu, clock, reputation widget, newspaper,
pause_menu, rack_menu, day_transition). The **3D main menu**
(`scenes/menu/main_menu.tscn` + `ui/main_menu.gd`) is the boot scene.

Theme = a single **Style** kit (`ui/style.gd`, six `MenuSkin`s), helper classes
`MenuKit`/`AtelierFrame`/`MaterialSwatch`, enforced by `tools/check_ui.gd`. See
`docs/UI_STYLE_GUIDE.md`. Minigames: `ui/cutting_minigame.gd`, `ui/sew_minigame.gd`.

### Data layer (`data/`)

Resource/helper classes in `data/scripts/`: `Enums`, `MaterialType`,
`MaterialFactory`, `Pricing`, `DressCode`/`DressRule` (order-matching rulebook),
`CustomerPreference`, `SuitOrder` (per-part match: fabric .4 / pattern .3 / colour
.3; `payout = price × avg_match × avg_quality`), `GameConfig`, `SaveCodec`,
`Handbook`, `NewsEvent`, `PostFxProfile`, `ClothMaterial`, and the character-data
classes (`FaceLayout`, `FaceProfiles`, `Wardrobe`/`WardrobeLibrary`/`WardrobePart`,
`CharAnims`/`CharacterAnimations`). Authored `.tres` content lives in
`data/materials/` (12 bolts), `data/dress_code.tres`, `data/game_config.tres`,
`data/news/`, `data/postfx/`, `data/wardrobe/`, `data/animations/`,
`data/face_layout.tres`, `data/face_profiles.tres`.

## 4. EventBus signals

Emitted: `item_picked_up/dropped/stored/taken`, `interaction_prompt_changed`,
`money_changed`, `order_placed/delivered`, `cloth_cut`, `piece_cut`, `piece_sewn`,
`suit_packaged` (no listeners — informational), `design_confirmed`,
`customer_waiting/seated`, `order_created/part_filled/ready/due/fulfilled/expired`,
`shift_started/ended`, `reputation_changed`, `newspaper_ready`. The customer
departure flow uses `Customer.departed` directly (not an EventBus signal).

## 5. Save system

`SaveCodec` serialises `MaterialType` + the four carryables to plain dicts.
`SaveManager.capture()` snapshots money, day, reputation, upgrades, clock progress,
day-start money, seen news, the order book, every station with `save_state`, loose
items under `ShopRoom`, and the carried item. Files: `user://saves/slot_<n>.sav`
(3 numbered + `auto`), binary `store_var`, `VERSION = 1`. Autosaves on
`shift_ended`. **Boot flow:** `scenes/menu/main_menu.tscn` →
`SaveManager.new_game()`/`load_from(slot)` → `change_scene_to_file(main.tscn)` →
`main.gd._ready` → `SaveManager.notify_game_ready()` (applies a load, or on "new"
offers the Tutorial then starts day 1). DayNight intentionally does not auto-start
at boot, so the day-1 newspaper never fires behind the menu.

## 6. Tooling (`tools/`)

Headless builders write committed content: `build_config`, `build_content`
(materials), `build_dress_code`, `build_news`, `build_postfx`,
`build_cloth_materials`, `build_textures`, `build_hair_texture`, `build_faces`,
`build_animations`, `build_wardrobe`, `build_audio`, `build_input`. Scene builders
still in use: **`build_character.gd`** (character rig from the KayKit import) and
**`build_dev.gd`** (`scenes/dev/dev_shop.tscn` sandbox — nests hand-owned scenes as
instances, safe). `build_main_menu.gd` authored the 3D menu once (now hand-edited).
Verifiers: `validate.gd` (loads every script/scene), `check_ui.gd` (style guide).
Smoke tests: `test_phase1..6`, `test_save`, `test_shift`, `test_news`,
`test_wardrobe`. Screenshot tools need a GPU (no `--headless`): `screenshot.gd`,
`shot_rig/ui/menu/phone/worktable/sewing/mirror/closeup.gd`.

> **The `build_phase1.gd` all-scene generator is GONE.** All game scenes are
> hand-owned and edited in the Godot editor. Do not recreate a scene generator or
> bulk-regenerate `.tscn`. (The dev skill doc's "rebuild order" still lists
> build_phase1 — that is stale; ignore it.)

## 7. Known issues / accepted debt

Fixed in the 2026-09-11 code-health pass: sewing-machine save gap, `Orders.submit`
destroying unmatched pieces, `CarrySlot.take_item` silent no-op, stale
`test_phase5`, dead `customer_left` signal, per-frame sun re-drive.

Still open (low priority, noted for future work):

- **Accepted cross-manager refs** (read-only lookups, not signal traffic):
  Reputation→News, CustomerManager→News/Shift/Tutorial, Upgrades→Reputation/
  GameState, Orders→Config/GameState. Fine, but it's the coupling the rulebook
  warns about.
- **Untyped Variant vars** in `ui/suit_builder.gd` (`_mirror/_actor/_customer/
  _pref/_rig`) — should be typed.
- **`character_rig.gd` is large** (~900 lines): skeleton + face + wobble + wardrobe.
  Single most likely future god-object; consider splitting the 2D-face subsystem.
- **CustomerManager marker NodePaths**: if the map is re-laid, the mirror/greet/
  door/street markers must be re-pointed or spawning silently no-ops (positions
  resolve to `Vector3.ZERO`).
- **Reference-only enums**: `ItemKind`, `Stage.FABRIC_PART/CONFIGURED`, and several
  styling enums (`Lapel`, `Fit`, …) are declared but unused by the live flow.
- **Two legacy tools**: `build_menu.gd` (code-only menu, superseded by the 3D menu)
  and `build_project.gd` (original one-shot generator) look obsolete.

## 8. Repo hygiene TODO (untracked; owner should decide)

- `data/face_profiles.tres` is **game-referenced data** but untracked — a fresh
  clone loses per-head face tuning. Commit it once the face work settles.
- Untracked `.uid` files (`head_wobble.gd.uid`, `upgrades.gd.uid`,
  `minigame_canvas.gd.uid`, `rack_menu.gd.uid`, `cloth_outline.gdshader.uid`) —
  commit for import stability across machines.
- Stray/duplicate assets to clean when convenient: `assets/characters/CHARTGEN1 -
  Copy.*`, `assets/characters/parts/KOSA+GLAVA-*-TEST*` extra basecolor variants,
  and the bulk `assets/models/FromUnreal/` + `assets/textures/random/` dirs (repo
  convention: bulk imports live under the git-ignored `IMPORT/`). *Left alone for
  now since active model work is in progress.*

## 9. Verification status (2026-09-11)

`gdlint`: pass · `validate.gd`: pass (133 scripts, 24 scenes) · `test_phase5`,
`test_phase6`, `test_save`, `test_shift`, `test_news`: pass.

# TailorTown — Story, Renovation & Progression Plan

Proposed 2026-09-20. Status: **plan, owner decisions mostly in** (see §9). Nothing here is
built yet. This doc subsumes ROADMAP item **E** (new location) and pulls **D** (shop
personalization) forward, because the story needs both.

## 1. The premise

Your grandfather was a tailor. He retired years ago and his little shop has stood shut
ever since. One day you decide to reopen it. You can't sew, so you go to the best tailor
you know of, **Mr. Hemming** on the Row, and ask him to teach you. He does (the
tutorial, in *his* premium shop). Then you go home, unlock grandpa's door, and find dust
sheets, a dripping ceiling and two rooms you can't even get into. The game is the climb
from there: same core loop (order → cut → sew → rack → collect), but the shop you run it
in is something you **earn back room by room**.

Why this works for the game we already have:

- The current v7 shop is *too nice* to start in. It becomes Hemming's shop, and it now
  doubles as **the promise**: the player spends 15 minutes in the shop they will one day
  deserve.
- Every existing progression system (reputation tiers, `Upgrades`, vendors, shop looks,
  coffee/ironing/apprentice stations) gets a **physical home** in a renovated room
  instead of being a line in a phone list.
- Hemming's line "a new face on the Row" already implies a premium street. Grandpa's shop
  is in the ordinary town. The Row is the long-term aspiration.

### Suggested backstory glue (cheap, makes everything click)

- **Hemming was grandpa's apprentice** forty years ago. That is why a master tailor
  teaches a stranger for free: "I owe that man my hands." It also lets Hemming tell
  grandpa stories without grandpa being on screen.
- **Grandpa is alive**, retired to the coast. He writes letters. This keeps the tone cozy
  (ECONOMY pillar: "cozy, never a trap"), gives us a reactive narrator, and sets up the
  ending: he comes back to see the finished shop and you make *his* suit.
- The shop has **no canonical name yet** (`SHOP_NAME` constant). The story supplies it:
  the faded sign carries grandpa's name; repainting the sign is a renovation step where
  the player may **name the shop** themselves.

## 2. How the story is told (beyond the tutorial)

Rule: no cutscene-heavy storytelling. The story rides on systems that already exist, in
small doses, and most of it is *found* while renovating.

| Channel | What it carries | Built on |
|---|---|---|
| **Prologue** (30–40 s, skippable) | 4–5 still panels in the key-art style: the shuttered shop, the letter + key from grandpa, you knocking on Hemming's door | new tiny `ui/story_panels.gd`; art via the image pipeline (UI_STYLE_GUIDE §7.1 rules) |
| **Hemming's tutorial copy** | Rewritten `M_*` lines: he knows who you are, drops 2–3 grandpa anecdotes, sends you off with grandpa's old shears he kept | `globals/tutorial.gd` consts only |
| **Grandpa's letters** | Arrive with the morning paper at milestones (first sale, each room opened, rep tiers, event win). Reactive: he comments on what you actually did. Some carry a gift (a bolt, a pattern, a keepsake) | newspaper delivery flow + a letter panel in the paper skin |
| **Keepsakes** (the main one) | Every renovation **uncovers something**: a tin of photos under the rotten floor, customers' measurements pencilled on the wall behind the wallpaper, his treadle machine under a dust sheet, the old order ledger. Each goes on a **memory shelf / framed on the wall**, so the shop visibly fills with family history | `Renovation` project → `keepsake` id; small prop scenes; inspect = one paragraph |
| **Old regulars** | Some customers knew him: "Your grandfather made my wedding suit." One-line memories in the customer bubble; they become early regulars | `Clientele` autoload + customer bubble |
| **Newspaper** | Day 1 small item: "Old tailor's shop to reopen"; later headlines on facade restoration, rival Pinch & Pleat sneering, etc. | `News` editions |
| **Hemming check-ins** | He phones/visits when a new room opens and teaches *that room's* station then (ironing, coffee, apprentice bench). The first-run tutorial shrinks to the core loop; advanced lessons arrive just in time | `MentorDialog` queue, `Tutorial` STEPS split into chapters |
| **Handbook** | Reframed as **grandpa's old notebook**: same content, handwritten margin notes | handbook copy/skin |
| **Finale** | At top tier with the shop restored, grandpa visits as a customer. You make his suit. Last letter + a photo of the two of you on the wall. Game continues after | scripted customer via `Customer.takeover` |

Existing upgrades get re-themed for free: `cut_sharp` = *sharpen grandpa's shears*,
`sew_oiled` = *oil grandpa's seized-up machine*, `sew_industrial` = finally replacing it
(and the old one moves to the memory shelf).

## 3. Progression structure

| Chapter | Where | Rep tier | What the player does |
|---|---|---|---|
| 0 Prologue | panels | – | letter, key, decision |
| 1 Apprenticeship | Hemming's shop (v7), locked in | – | today's tutorial, core loop only |
| 2 Dust sheets | grandpa's shop, **front room only** | 0 | hands-on cleanup, first customers (neighbours, modest briefs), fix sign / window / lights |
| 3 A dry roof | + **workroom** | 1 | roof patched, rotten floor relaid, benches move out of the cramped front room |
| 4 Proper stock | + **cloth store** | 2 | damp store rebuilt → bigger shelving, bulk orders, delivery door; front room refit unlocks **shop looks** |
| 5 Comforts | + **nook** | 3 | coffee / pressing corner; facade repaint + name the sign |
| 6 Knock-through | + **neighbouring unit** | 4 | expansion: apprentice bench, display window/mannequin; grandpa's visit |

Tier thresholds and prices must be set in "days of profit" per ECONOMY.md once the
projects exist; the table above is only the order.

### Two kinds of work

1. **Cleanup — hands-on, free, costs day time.** Sweep rubble, pull dust sheets, tear
   boards off a window, scrub mould, empty the drip bucket. Hold-E interactions with a
   progress ring (later maybe a tiny minigame per the comfort-minigame host). Gives the
   player something cozy to do in the quiet early days when customers are few, and makes
   progress possible at $0.
2. **Building work — phone, money + reputation tier + days.** Roof, floors, plaster,
   wiring, glazing, knocking through. New phone hub card **Builders** next to *Order
   Textiles* / *Shop Upgrades*. Work takes 1–3 nights; the room is tarped meanwhile; it
   completes on `shift_started` with the already-planned **dust-and-sound refit moment**
   (SHOP_CUSTOMIZATION.md) and a short camera pan to the reveal.

A room usually needs *cleanup first, then building work*, so the two interleave.

### Does damage affect gameplay?

Recommended: **yes, softly, framed as things getting better** (rewards over penalties).

- **Shop appeal**: each repair raises an appeal score that feeds the existing
  `ShopDecoration` → reputation hook and the customer tier ceiling. A shabby shop simply
  attracts humbler briefs; it never loses you money.
- **No lights** → the door sign flips to closed at dusk (shorter open phase). Fixing the
  wiring gives the full day. This is also natural early-game pacing.
- **Leak** → on rainy days a bucket fills; empty it or the puddle spreads (cosmetic +
  slightly slower walking through it). Never damages cloth.
- **Boarded window** → dark room; glazing it brings the sunbeams and dust motes we
  already have. Pure reward.

## 4. Where the two shops live

- **Grandpa's shop goes on the existing town plot**, replacing the v7 shop there. The
  town, street life, customers' pavement waypoints, main-menu camera and west square all
  stay. The kit is already `Plan`-driven with `YARD` reserved for growth. A shabby shop in
  a pretty street reads instantly, and restoring the facade "completes" the street.
- **Hemming's shop = the v7 shop moved into a new small diorama**, "the Row". The player
  is locked in, and the game camera looks north at ~55°, so only this needs to exist: a
  pavement strip and a slice of road in front, two premium facades each side (stone, black
  paint, brass), a rear garden wall and the backs of a rear row. Roughly a tenth of the
  town's triangles. Nothing across the road (same reasoning as the town).

## 5. Generating grandpa's shop (Blender kit "v8")

New script `IMPORT/town_kit/build_v8_grandpa.py`, importing the v7/v6 chain like every
version so far (old versions untouched).

**Layout** (smaller and humbler than v7; obeys the camera rule: only front-to-back full
walls, left-right dividers stay waist-high or have wide openings):

```
        [ yard ]
  +---------+-------+ . . . . . . .
  | work-   | cloth |  neighbour  .
  | room    | store |  unit       .   <- chapter 6, bought later
  +--  --+--+--  ---+  (vacant)   .
  | front room  nook|             .
  +----[door]-------+ . . . . . . .
        street
```

**Exports** (split, shared origin, stable names, as v6 taught us):
`grandpa_shell`, then per room `room_<id>_before` and `room_<id>_after` dressing sets,
plus `grandpa_facade_before/after`. Per-room material slots from day one
(`InWall_front`, `Floor_work`, …) so shop looks can finally go per-room.

**Damage vocabulary** — new kit pieces, all chunky and *charming*, never grim (owner
rule: cute and simple):

- `dmg_rubble_{s,m,l}` (bricks + plaster chunks), `dmg_plank_loose`, missing-board floor
  holes with a plant growing through
- `dmg_boards_window`, `dmg_boards_door`, `dmg_tarp`, builder's trestle + paint pots for
  "work in progress"
- `dmg_dust_sheet_*` — sheet-draped silhouettes of furniture. Cheapest, most readable
  "abandoned" signal there is, and pulling one off is a lovely reveal
- `dmg_bucket` + `dmg_puddle`, cobweb corner fans, a mouse hole, a bird's nest in the
  broken pane, stacked old crates
- Exterior: slipped roof tiles + tarp patch, faded sign, flaking paint, weeds at the
  plinth, one cracked pane

**The leaking roof must read on floor and walls.** The roof is hidden in play, so the
leak is told by: a drip particle from the wall-cap height, a rippling puddle, a bucket
with a *plink* (Stable Audio pipeline), and dark water-streak stains running down the
wall. The hole itself only shows on the exterior (menu / street views).

**Damaged and wet surfaces — do it in a shader, not in baked textures.** One Godot
"wear" shader layer on the room slots with a per-room `damage` uniform (0..1) and a mask
(vertex colour / a mask texture baked by Blender): darkens and desaturates albedo, adds a
stain tint, and for wet areas **drops roughness** (wet = dark + glossy). Advantages:

- renovation can **animate** from ruined to clean (a wipe across the room at the reveal);
- "cleaned but not repaired" is just `damage = 0.5`, no third texture set;
- no new diffusion sets, which the owner found too busy last time.

On top of it: a handful of **Decals** (cracks, exposed lath patch, peeling-paper edge,
mould bloom, streaks), drawn procedurally like the rugs/wallpapers (`_src/make_*.py`).
Grandpa's walls should be a **faded version of Fern Damask**, so the player can later
restore "his" wallpaper as a look. Watch the outline pass: decals/puddles are transparent,
so re-check them against the ALPHA-only outline rule.

Locked rooms stay **visible through the cut-away** (unlit, dusty, rubble in view). Seeing
the mess every day is the motivation.

## 6. Systems to build

### 6.1 Location layer (the part of ROADMAP E we actually need)

The scary part of E was *per-location saved contents*. We can dodge it: **Hemming's shop
is never saved.** The tutorial is one sitting (or restarts), so the save stays
single-world. Needed:

- `Location` resource (`data/locations/*.tres`): id, scene path, flags (customers on,
  day cycle on, saving allowed, doors locked), starting stock.
- `SaveManager.MAIN_SCENE` const → `Locations.current().scene`; save stores the location
  id (always `grandpa_shop` in practice; pause-menu save is disabled at Hemming's).
- Split `main.tscn` into a shared **gameplay rig** (player, camera, managers, UI hooks)
  and a **world** scene, so both locations reuse the rig. `main.tscn` carries the owner's
  uncommitted work, so this split is done *with* the owner, not under them.
- Storefront/pavement markers, `RoofManager.interior_extents` and collisions are
  authored per world scene (they already live in the scene).
- The ~40 tools/tests that reference `main.tscn` keep working if `main.tscn` stays the
  grandpa-shop entry scene; Hemming's gets a new `main_hemming.tscn`.

### 6.2 `Renovation` autoload (modelled on `Upgrades`)

- Data: `data/renovations/*.tres` — id, room, kind (cleanup / build / room), cost, tier,
  nights, `requires[]`, `keepsake`, appeal, effect flags.
- State: not_started / cleaned / in_progress(nights left) / done. `save_state()` /
  `restore()` + one line in `SaveManager.capture()` and `_reset_autoloads()`.
- Scene side: a `RenovationZone` node per room with `Before` / `WorkInProgress` / `After`
  child groups, a door blocker (boards + collision + prompt "Boarded up — call the
  builders"), and the room's `damage` shader value. Stations of a locked room live under
  `After`, so the capability-scan save keeps working untouched.
- `Upgrades` entries that are stations gain `requires_room` (coffee machine → nook, etc.).
- Signals on EventBus: `renovation_started / finished / keepsake_found`.
- Phone: `Screen.BUILDERS`, reusing the Shop Upgrades list grouped by room.
- Test: `tools/test_renovation.gd` (gating, nights tick, save round-trip, blocker off).

### 6.3 Tutorial rework

- Runs in the `hemming_shop` location; front door refuses ("Not before you can sew a
  straight seam."). Scripted customers only, as now.
- Optional but strong: **Hemming as a body in the room** at the second bench (he already
  "runs up the other two parts" invisibly) using the character parts system.
- STEPS split into chapters: `core` (first run) and per-room lessons fired by
  `renovation_finished`.
- "Skip the tour" still plays the prologue and lands at grandpa's door.
- The **goal tag becomes the light quest tracker** for chapter 2+ ("Pull off the dust
  sheets 0/4 · Sweep the floor · Turn the sign").
- Known: `test_session` / `test_tutorial_sale` already fail on a Nil `.visible` at
  tutorial.gd:~916 — fix that first, before moving anything.

### 6.4 Story delivery bits

`story_panels.gd` (prologue), a letter panel in the newspaper flow, `Keepsake` prop +
inspect text + memory shelf, regulars' memory lines in `Clientele`, a few `News` items.
All small and independent; can land in any order after 6.1–6.2.

## 6.5 Station plan per room (owner-approved 2026-09-20, layout A)

Room sizes (on the town kit's 2 m grid since 2026-09-20, see 6.11): **front room 8x6 m**,
nook 4x6, workroom 8x4, cloth store 4x4, neighbouring unit 6x10. Two earlier footprints
came first: the sketch's 6x5 front room was too small once the real station footprints
were measured (the phone *is* the 2 m reception desk, and its origin sits at the desk's
left end; the tri-fold mirror is 2.46 m wide), so it grew to 7x5.5; then the kit's grid
made it 8x6. Yard behind stays free (keeps a later garden room possible). The footprint
lives in one place: `tools/build_grandpa_greybox.gd`; station positions in
`tools/make_grandpa_room.py` and `RenovationDirector.MOVES`.

| Stage | Stations |
|---|---|
| **Day 1, front room only** | counter (phone + grandpa's notebook on it), **basic mirror**, one small cloth shelf, cutting table, grandpa's treadle sewing machine, one clothing rack, bin. The full loop works; only capacity and comfort are missing |
| **Workroom** | cutting table + sewing machine move here (full-size table), second rack, bin. Front room becomes reception: bookshelf, memory shelf |
| **Cloth store** | two long shelf walls, delivery door (Bulk Orders, premium suppliers) |
| **Nook** | coffee machine, ironing board (`Upgrades` entries gain `requires_room`) |
| **Fitting corner** | see below |
| **Next door** | apprentice bench (+ the apprentice's own machine), rack, street-window mannequins |

### The mirror is its own upgrade line

1. **Basic mirror** (day 1): grandpa's spotted old cheval glass leaning in the front room.
   Does the whole measure/design job, nothing more.
2. **Better mirror** (phone upgrade): proper tri-fold. Effect to be designed with the
   suit-builder (ideas: design catalog presets from ROADMAP C live here, a small
   measuring-accuracy or customer-satisfaction bonus).
3. **Fitting corner** (renovation project): a dedicated corner carved out for fittings —
   platform, tri-fold mirror, stool, rug, drape. Counts toward shop appeal; natural home
   for the design catalog. Placement: on the front room's left wall or the front of the
   neighbouring unit, decided in greybox. Keep it a *corner with a low/open side*, not a
   walled booth (camera rule, and the owner rejected a curtained booth in v3).

### Circulation rule (owner requirement)

Cramped must never mean stuck. Player capsule radius is 0.34 m, customers similar.

- The customer route **door -> counter -> mirror -> door** keeps a clear aisle of
  **>= 1.2 m** (player and customer can pass each other).
- Every other station keeps **>= 0.9 m** of free floor on its working side.
- A customer standing at the counter or the mirror must not block the player's way to
  any station (no single-file dead ends behind a waiting customer).
- Checked at every stage, not just day 1: a greybox test (`tools/test_shop_clearance.gd`)
  parks a customer at each waiting spot and path-tests the player to every station, for
  each renovation state. Re-run whenever furniture footprints or room sizes change.
- If the 6x5 front room cannot meet this with all seven day-1 stations, **grow the room**
  (6.5x5.5) before dropping a station.

## 6.6 What the greybox taught us (feeds the Blender v8 brief)

- **Dollhouse cut-away.** The game camera is a perspective camera, so in a small shop not
  only left-right walls hide floor: *inner* front-to-back walls lean across the side rooms
  too. In the greybox every inner wall and the street front keep only their bottom 1.1 m;
  everything above it lives in the `Roof` group that `RoofManager` fades while the player
  is inside. Outer side walls and the back wall stay whole (they lean away / sit behind).
  v8 must export its walls split the same way (`_Body` low part, `_Roof` upper part).
- **Locked rooms stay in view** through the cut-away: dark floor, rubble, boards across
  the doorway (`Blockers/Blocker_<room>`, one StaticBody each, freed by a renovation).
- **Door sign**: a shop with its own doorway places a `DoorSignSpot` marker.
- **The v7 plot garden pokes into the front-left corner** of grandpa's footprint (the v7
  wings were set back). Cosmetic, greybox only; v8 rebuilds the plot for the new footprint.
- **The day-1 mirror is still the big tri-fold.** The basic cheval mirror is a v8 asset.

## 6.7 Status

- **M1 (2026-09-20, branch `story-renovation`)**: `Locations` autoload; a new game opens at
  Mr. Hemming's (`main.tscn`, no saving, door barred for the player), then the curtain
  falls and rises on grandpa's greybox shop (`scenes/world/grandpa/`), which is the saved
  world; saves carry `location`; old saves (no key) still open in `main.tscn`.
  Tools: `tools/build_grandpa_greybox.gd` (shell), `tools/make_grandpa_room.py` (one-time
  room converter), `tools/shot_grandpa.gd`, `tools/test_locations.gd`.
- **M2 (2026-09-20)**: the renovation loop, on the greybox.
  - `Renovation` autoload (`globals/renovation.gd`, modelled on `Upgrades`, saved with the
    game): 17 projects over 5 rooms. **Cleanup** is done by hand, spot by spot, for free;
    **build** work is ordered, paid for, gated by reputation tier and finished by the builders
    overnight (`EventBus.day_began`). A locked room goes shut -> entered (boards off) ->
    cleared (mess out) -> done (rebuilt, stations in). **All costs and nights are
    provisional** - they order the projects by size but are not balanced in days of profit.
  - `RenovationDirector` (`scenes/world/grandpa/renovation_director.gd`) is the scene side:
    boards, a mess pile per cleanup spot, dust sheets over three stations (which sleep until
    uncovered), the builders' clutter, floor and label by room state. Stations of later
    rooms sit in the scene from the first day, hidden and switched off, so **save paths
    never change**; when a room is done they appear, and the worktable and sewing machine
    move from the front room into the workroom.
  - Coffee machine, ironing board and apprentice bench wait for their room as well as their
    upgrade (`UpgradeStation.room`), and can't be bought before the room exists
    (`Upgrades.ROOM_OF`; only in grandpa's shop, so Hemming's and old saves are unchanged).
  - Tests: `test_renovation` (gating, money, nights, scene effects, save round trip),
    `test_shop_clearance` (below), `test_locations`. GIF of the whole procedure:
    `docs/media/renovation.gif` (`tools/shot_renovation_gif.gd` +
    `tools/make_renovation_gif.py`).
- **Playable loop (2026-09-20)**: the phone's **Builders** card (grandpa's shop only) orders
  building work, so the renovation can be played through without debug tools; the **F3
  panel** has a Renovation section (finish next job, builders finish tonight, renovate
  everything, open a room with everything it depends on, a per-project checklist, reset);
  a finished job is announced with a toast. **A shabby shop draws humbler customers**:
  the budget band follows the lower of the reputation tier and the tier the shop is fit
  to receive (`Pricing.shop_tier_ceiling`, `GameConfig.appeal_for_budget_tier`,
  provisional; tier 0 is always welcome, so day 1 is unchanged). Mr. Hemming's welcome and
  send-off now fit the story (that he was grandpa's apprentice is still to be confirmed by
  the owner). The front room must be tidied before any other room is begun.
- **Stage A of 6.11 done**: the greybox stands on the kit's 2 m grid; every station
  re-placed; `test_shop_clearance` passes 270 checks over seven stages.
- **Not in git**: the town, the plot and Mr. Hemming's shop are referenced from
  `IMPORT/town_kit/export/v7/`, and `/IMPORT/` is ignored, so a fresh clone has none of
  them. Grandpa's room scene depends on the same files; the v8 shop will follow the same
  convention.
- **Stage B done - the look**: `IMPORT/town_kit/build_v8_grandpa.py` (not in git, like the
  rest of the kit; ~40 s, writes only `export/v8/`) builds grandpa's building as a front
  block and a lower back block - two modest roofs meeting in a valley over the workroom -
  and next door as a separate house in another colour, from the kit's own wall pieces:
  shop windows, the double door, arched inner doorways, wainscot, skirting, curtains, a named
  plank floor per room, door leaves in a `Doors` group (so `ShopDoor` swings them for
  customers). **Cut-away**: every inner wall, the street front and the party wall are
  bisected at 1.1 m (`split()`); the upper halves go to the roof group with the caps,
  cornices and curtains above them, and `RoofManager` fades the lot. The cut is filled
  dark, which reads like the kit's wall caps. **Hybrid on purpose**: Blender is the look
  only; collision, boards, mess and builders' clutter still come from the tested Godot-side
  shell (`SHOW_SHELL := false` leaves its own walls, roof and labels out).
- **Stage C, first pass - damage**: per-room wear as Decals whose strength follows the
  renovation (`RenovationDirector.wear_of`): a grey film of grime on the floor, damp down a
  full-height wall, a wet glossy puddle under the leak; shut/entered 1.0, cleared 0.6, done 0;
  the front room starts at 0.75 and each of its jobs takes a quarter away. Limited to the
  shop's shell by render layer 2, so it never lands on people. Procedural textures:
  `tools/make_wear_textures.py` -> `assets/textures/renovation/`. The mess is seeded heaps of
  brick, plaster and slate, dust mounds with dead leaves, planks nailed across the doorways
  (all below the cut), a low run of bricks across the party wall, a trestle, ladder, tarp and
  paint pots for the builders. The third dust sheet covers the rack, not the 2.5 m mirror.
- **Checked as a shop**: a customer called in grandpa's walks in from the street through
  the new door (which swings open) to the counter.
- **Still placeholder**: dust sheets are linen-coloured boxes (want draped meshes); the
  day-1 mirror is still Mr. Hemming's tri-fold (want grandpa's plain cheval glass); the
  cornice band came out navy, not terracotta; next door wears the same wallpaper as
  grandpa's (interior slots are global, not per building or room); the plot is still Mr.
  Hemming's (stage D) with its props hidden where they fall inside the building; a blossom
  tree overhangs next door's corner. All costs, nights and appeal thresholds are provisional.
- Not started: the story pieces of section 2 beyond Mr. Hemming's words (prologue panels,
  grandpa's letters, keepsakes, old regulars, headlines), naming the shop, the fitting
  corner and the mirror upgrade line, Mr. Hemming as a body in his shop, his Row diorama.

## 6.8 Names the Blender-built shop must keep

`RenovationDirector` finds everything by name under the shop shell (`shell_path`, today
`GrandpaShell`). v8 can look like anything as long as these exist:

| Node (under the shell) | What it is | Driven by |
|---|---|---|
| `Blockers/Blocker_<room>` | boards across a doorway: a body with a collider + its mesh. Rooms: `workroom`, `cloth`, `nook`, `nextdoor` (the party wall) | hidden + collision off once the room is entered |
| `Spots/<cleanup project>/Spot<i>` | one mess pile per spot; children are the visuals. Projects: `front_sweep`, `workroom_clear`, `cloth_clear`, `nook_clear`, `next_clear` (spot counts in `Renovation.PROJECTS`) | hidden one by one as they are cleared |
| `Wip_<room>` | the builders' clutter (trestle, tarp, pots) | shown while a build job of that room is under way |
| `Body/Floor_<room>` | the room's floor mesh (`front`, `workroom`, `cloth`, `nook`, `nextdoor`) | greybox: recoloured by state. v8: replace `_paint_floor` with the wear shader's `damage` value |
| `Label_<room>` | greybox floor label | drop it in v8 |
| `Roof` | roof + the upper part of every cut-away wall | `RoofManager` fades it while the player is inside |

Dust sheets are made by the director over the stations named in `SHEETED`; v8 should
supply real sheet meshes (draped silhouettes) and the director should use those instead.

## 6.9 What the clearance test found

`tools/test_shop_clearance.gd` flood-fills the floor with a player-sized body against the
real colliders, at seven renovation stages. It checks: every station that is there can be
walked up to from its front; shut rooms are really shut; the street door is reachable;
nothing is cut off with customers standing at the counter and the mirror; **every station
is reachable along corridors at least 0.9 m wide**; and the customer's route keeps a
**1.2 m aisle** from the door to the counter and to the mirror. Run it with `-- verbose`
for an ASCII map of each stage. It caught three things no screenshot had shown:

- **Three stations have no solid body of their own**: the worktable, the reception desk
  (the Phone station) and the mirror can be walked through. At Mr. Hemming's the kit's
  partition happens to stand where the desk is. In grandpa's shop the director gives them
  a body (`SOLID`, sizes measured from the models). *Owner's call*: giving `worktable.tscn`,
  `phone.tscn` and `mirror.tscn` a body of their own would fix Hemming's shop too - those
  scenes are hand-owned, so it was left alone.
- **The tri-fold mirror is 2.46 m wide.** Set diagonally it walled off a third of the front
  room together with the desk; it now stands flat on the east wall. The day-1 basic mirror
  (a v8 asset) is the real answer.
- The **window mannequin** stood 0.7 m from the glass; moved back so one can walk round it.
- The desk is not centred on the Phone station's origin (it runs x -0.35..1.65 from it).

## 6.10 Open questions for the owner

1. **The nook is the corridor to next door.** The party wall only touches the nook and the
   cloth store, so the knock-through opens off the nook: front room -> nook -> next door.
   It passes the 0.9 m rule with the coffee machine and ironing board in, but the comfort
   corner becomes a passage. Alternatives: knock through from the cloth store instead
   (work side to work side), or swap nook and cloth store. Left as drawn for now.
2. **Next door is nearly empty** (one bench, one rack, one mannequin in ~50 m2). What else
   belongs there - a second cutting table, a fitting corner, a bigger display?
3. **Give the three body-less stations a body in their own scenes?** (6.9)
4. **Reputation tiers gate rooms** (workroom tier 1 ... next door tier 4) and costs are
   placeholders - both need a balance pass against `docs/ECONOMY.md`.

## 6.11 The Blender v8 brief (read before building the real shop)

**The kit is a 2 m module kit.** `build_v7.PlanB` asserts every room dimension is a multiple
of 2 m; walls are runs of 2 m `wall_<kind>` pieces (`wall_part_v7` inside, `wall_part_arch_v7`
for a doorway), textures bake 2 m per UV tile. The first greybox footprint (7x5.5, 3x5.5,
7x5, 3x5, 5x10.5) is off that grid almost everywhere, so **the footprint moves onto the grid
first** - in the greybox, where it is cheap and `test_shop_clearance` re-proves it.

On-grid footprint (kit coordinates, street at -Y; Godot = kit x + 0.65, z = 8.34 - kit y):

| Room | Kit x | Kit y | Size | Was |
|---|---|---|---|---|
| Front room | -5..3 | 0..6 | 8x6 | 7x5.5 |
| Nook | 3..7 | 0..6 | 4x6 | 3x5.5 |
| Workroom | -5..3 | 6..10 | 8x4 | 7x5 |
| Cloth store | 3..7 | 6..10 | 4x4 | 3x5 |
| Next door | 7..13 | 0..10 | 6x10 | 5x10.5 |

Own building 12x10 = 120 m2, about two thirds of Mr. Hemming's v7 shop (~180 m2): still the
smaller, humbler shop. A flush front (no stepped-out centre) on kit y = 0, which is where the
v7 door stood, so the town's path to the door still arrives at a door (kit x = 0). The west
wall stays where the greybox has it. The v7 plot (kit x -10..14) has room for all 18 m.

How a kit shop is put together (so v8 can follow it): a list of `(piece, Matrix, colors[,
group[, node name]])`; groups become `<root>_Body / _Roof / _Interior / _Doors`
(`part_group`); the optional node name is how v8 can emit exactly the names of 6.8. Shells
come from `K.townhouse(W, D, 1, front_rows, skip=..., open_sides=..., interior=True)`, then
pieces are swapped (`V6.V6_RENAME`, the strict `_i5` wall pieces that do not z-fight).

**The kit has no cut-away walls.** Its walls are whole pieces 3 m high. 6.6 needs every inner
wall and the street front to keep only the bottom 1.1 m while the player is inside. Do it
generically: build a wall piece, duplicate it, bisect at z = 1.1 (`bmesh.ops.bisect_plane`),
register `<piece>_lo` (group Body) and `<piece>_hi` (group Roof). Windows get sliced near
their sills, which reads as a low wall with a sill. Check UV/normal baking on the halves.

Stages, each leaving the game playable:

- **A.** Move the greybox to the grid (consts in `tools/build_grandpa_greybox.gd`, station
  tables in `tools/make_grandpa_room.py` and `RenovationDirector.MOVES`, room centres in
  `tools/test_shop_clearance.gd`); re-run clearance, renovation, locations.
- **B.** v8 shell for that footprint from existing kit pieces + the generic split; export
  `grandpa_shop_v8.gltf`; show it in the room scene. **Hybrid on purpose:** the gameplay
  nodes of 6.8 keep coming from the Godot-side builder (tested), with its wall/floor meshes
  hidden - Blender supplies the look only, so nothing that works can break.
- **C.** Damage: rubble, boards, draped sheets, bucket and puddle, cobwebs as kit pieces under
  the same node names; the per-room wear shader (`damage` 0..1, wet = dark + glossy) in place
  of `_paint_floor`; procedural decals. The basic cheval mirror.
- **D.** The plot rebuilt for the footprint (the v7 garden pokes into the front-left corner).

## 7. Build order

| # | Milestone | Proves |
|---|---|---|
| M0 | Owner decisions (§9), names, story bible paragraph per chapter | – |
| M1 | Location layer + tutorial at "Hemming's", **greybox** grandpa shop | new game → prologue stub → Hemming → arrive at grandpa's, save/load OK |
| M2 | `Renovation` system on the greybox (zones, blockers, Builders card, nights, save, test) | the whole loop is fun before any art exists |
| M3 | Blender v8: shell, rooms before/after, damage pieces, wear shader, decals; the Row diorama | the look; in-engine screenshots for review |
| M4 | Story delivery: panels, Hemming copy, letters, keepsakes, regulars, headlines | the story lands |
| M5 | Balance pass (prices in days-of-profit, tier gates), knock-through expansion, grandpa's visit | the long game |

Greybox first on purpose: the renovation loop's feel (how much cleanup, how many nights,
how fast rooms open) should be tuned before spending Blender time on rooms whose size may
change.

## 8. Risks

- **`main.tscn` split** touches owner-owned scenes with uncommitted work. Do it together.
- **Starting poorer must still be fun.** The cramped front room needs the full loop in it
  on day 1 (counter, one bench, treadle machine, small shelf, one rack). Restriction should
  come from *capacity and comfort*, never from missing a core step.
- **Art volume**: before/after for ~5 rooms + facade. The wear shader and dust sheets keep
  this affordable; resist unique damaged meshes per room.
- **Tone**: abandoned can drift gloomy. Keep warm light, plants, the bird's nest, funny
  finds.

## 9. Owner decisions (answered 2026-09-20)

1. **Grandpa is alive**, writes letters, visits at the end. ✔
2. **Hybrid renovation**: hands-on cleanup *and* phone builders. ✔
3. **Grandpa's shop on the existing town plot; Hemming's v7 shop in a small new "Row"
   diorama.** ✔
4. **No damage mechanics.** Damage is visual + room gating only. The single gameplay
   effect of a shabby shop is **humbler customers** (appeal → customer tier ceiling). This
   overrides §3 "Does damage affect gameplay?": no closing at dusk, no bucket chore, no
   puddle slowdown. The bucket, drips and puddles stay as set dressing.
5. **Expansion: layout A** (knock through sideways into the neighbouring unit), yard kept
   free so a garden room stays possible. Station plan approved, see §6.5. ✔
6. **Names: cute.** Proposal, awaiting a yes: grandpa **Barnaby "Pops" Thimble**; the shop
   **The Little Thimble** (faded on the old sign; the player may rename it at the sign
   repaint); the town **Buttonbrook**; Hemming's street stays **the Row**. Alternatives:
   Bobbin / Button for the family name, "Thimble & Thread" for the shop.
7. **Hemming is a physical character** in his shop (character parts system), standing at
   the second bench; the portrait dialog stays for his speech. ✔

Work happens on the `story-renovation` branch.

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
5. **Expansion direction: open.** Three layouts were shown (A knock through sideways,
   B into the yard, C sideways first then a glazed garden room). Recommendation: **A now,
   shaped so C stays possible** (keep the yard free behind the workroom).
6. **Names: cute.** Proposal, awaiting a yes: grandpa **Barnaby "Pops" Thimble**; the shop
   **The Little Thimble** (faded on the old sign; the player may rename it at the sign
   repaint); the town **Buttonbrook**; Hemming's street stays **the Row**. Alternatives:
   Bobbin / Button for the family name, "Thimble & Thread" for the shop.
7. **Hemming is a physical character** in his shop (character parts system), standing at
   the second bench; the portrait dialog stays for his speech. ✔

Work happens on the `story-renovation` branch.

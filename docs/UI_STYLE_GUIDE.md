# TailorTown UI Style Guide

The look-and-feel bible for every in-game menu, HUD element and prompt. It is not
Animal Crossing — it borrows AC's *warmth and playfulness* and retargets it to a
**bespoke Savile Row tailoring shop**. Every screen should feel like a real
surface in that shop: an order pad, a leather-bound handbook, a bolt of cloth, a
fitting mirror.

This guide is **enforceable**: `tools/check_ui.gd` scans the UI scripts against the
rules marked **[CHECK]** and fails the build if they are broken. A future "UI
rater" agent judges the softer rules (marked **[JUDGE]**) from screenshots against
this same checklist.

---

## 1. Identity

**Savile Row atelier.** Warm walnut and cream paper, brass hardware, deep forest
and burgundy accents, tailor's-chalk marks and measuring-tape edges. Sophisticated
but cozy — a craftsperson's workshop, not a sterile app.

Guiding feelings: *hand-made, tactile, unhurried, precise.* Prefer paper, cloth,
thread, brass and chalk over glass, glow and gradients.

---

## 2. Tokens (single source of truth: `ui/style.gd`)

Never hard-code a colour, radius or spacing value in a menu. Pull it from `Style`.
**[CHECK]** No `Color(...)` / `Color("...")` literals in `ui/*.gd` except inside
`ui/style.gd` itself and the drawn primitives (`material_swatch`, `clock_widget`,
`atelier_frame`, `day_transition`).

### Palette

| Token         | Hex       | Use                                    |
|---------------|-----------|----------------------------------------|
| `WALNUT`/`INK`| `#4a3826` | Primary text, dark wood, outlines      |
| `INK_SOFT`    | `#8a745a` | Secondary text, captions               |
| `CREAM`       | `#f4ead2` | Panel paper (default)                  |
| `PAPER`       | `#efe3c8` | Kraft pattern-paper (warmer surfaces)  |
| `CARD`        | `#fbf5e6` | List cards                             |
| `CARD_SELECTED`|`#fffaf0` | Selected card                          |
| `BRASS`       | `#c9a24a` | Primary accent — hardware, highlights  |
| `FOREST`      | `#2f5d3e` | Positive / good / "in progress"        |
| `BURGUNDY`    | `#7a3b3b` | Rich accent / reading / danger-warm    |
| `CHALK`       | `#eef2f4` | Chalk marks, stitch lines on dark      |
| `STEEL`       | `#bcc3c9` | Blades, pin shafts, needles            |
| `STEEL_DARK`  | `#70797f` | Steel in shadow, blade outlines        |
| `AMBER`       | `#e6a63c` | Warning                                |
| `CLAY`        | `#d76b5a` | Low / danger                           |

State colour is **never the only signal** — always pair with a word or icon.
`Style.fill_color(fraction)` returns FOREST → AMBER → CLAY.

### Spacing — 8px grid

`S1=4  S2=8  S3=16  S4=24`. **[CHECK]** No raw pixel separations/margins in
`ui/*.gd`; use `Style.S*`.

### Radii & frame

Panels `radius 20`, cards `radius 12–14`, key-caps `radius 6`. Panels get the
**atelier frame** (§5): a stitched inner border + chalk corner ticks in the menu's
accent, over a paper base.

### Type — Fredoka, applied via the shared theme

| Role            | Size | Colour     | Weight |
|-----------------|------|------------|--------|
| Screen title    | 26   | `WALNUT`   | bold   |
| Section header  | 18   | accent     | bold   |
| Body / value    | 17–19| `WALNUT`   | –      |
| Caption / sub   | 15   | `INK_SOFT` | –      |
| Hint / key-cap  | 14–15| see §4     | –      |

Bold is a real weight (`Style.bold_font()`, an embolden of Fredoka), used for
titles, headers and emphasised words — **[JUDGE]** every screen has a clear bold
title and at least one bolded key term; body copy is not a flat wall of one weight.

---

## 3. Frames must not stretch  **[CHECK]**

A menu's outer panel has a **fixed size** — it must not grow or shrink as its
contents change (mode toggles, list length, tab switches). Different groupings and
arrangements inside are encouraged; the *silhouette* stays put.

Rule: every menu panel sets **both** `custom_minimum_size.x > 0` **and** `.y > 0`
(from `Style.FRAME_*` presets), and inner variable-length regions live in a
`ScrollContainer` or a fixed-cell grid — never a container that resizes the panel.

Frame presets in `Style`: `FRAME_SMALL (560×360)`, `FRAME_WIDE (820×520)`,
`FRAME_TALL (640×560)`, `FRAME_FULL` (staged full-screen, §6).

---

## 4. Text, hints and prompts

- **Info / hints get a background for readability.** Any persistent on-screen text
  over the game world (hints, status, tooltips) sits on a translucent rounded bar,
  never bare on the 3D scene. Use `Style.hint_bar(...)` / `Style.info_badge(...)`.
  **[CHECK]** No menu sets a `Hint` label's `text` to a raw string that contains a
  key name; hints are built with `Style.hint_bar()`.
- **Actions name their key as a key-cap.** Every actionable prompt shows the
  binding as a rounded key-cap (`Style.keycap("E")`) followed by the verb
  ("`E` Order", "`Esc` Close"). One consistent cap style everywhere.
- **Emphasis via bold, not colour-only.** Bold the key term; don't rely on a hue a
  colour-blind player can't separate.

---

## 5. Per-menu skins — same controls, different surface  **[JUDGE]**

Controls and navigation are **identical** across menus (W/S select, A/D change,
`E`/`interact` confirm, `Esc` close). What changes is the *surface* — each screen
is its own object, differing on **four** axes, not just accent:

- **Paper colour** — the panel background is not always cream.
- **Background pattern** — a faint watermark (`AtelierFrame.Pattern`) drawn over
  the *whole* panel, on top of the item cards, so the screen reads as one textured
  sheet. Fabric swatches carry `z_index = 1` so the real cloth preview stays above
  the pattern and clean.
- **Silhouette** — per-corner radii (round pad vs. squared book-spine vs. arched
  mirror vs. boxy board).
- **Shape accent** — a solid detail (`AtelierFrame.Shape`) in the **top-right or
  edges only** (see §4-collision below).

| Menu / screen        | `MenuSkin`| Paper         | Accent    | Pattern      | Silhouette          | Shape  |
|----------------------|-----------|---------------|-----------|--------------|---------------------|--------|
| Phone order          | `ORDER`   | `CREAM`       | `BRASS`   | `PINSTRIPE`  | round               | `CLIP` |
| Handbook             | `BOOK`    | `PAPER`       | `BURGUNDY`| `RULES`      | squared spine side  | `BOOK` |
| Shelf browse         | `SHELF`   | `PAPER_COOL`  | `FOREST`  | `HERRINGBONE`| round               | `FOLD` |
| Suit builder / mirror| `MIRROR`  | `PAPER_MIRROR`| `BRASS`   | none         | arched top          | none   |
| Worktable / sewing   | `WORK`    | `MAT`         | `WALNUT`  | `GRID`       | boxy                | `TAPE` |
| Orders board         | `ORDERS`  | `CORK`        | `BURGUNDY`| `CORK`       | boxy                | `PIN`  |

Add a menu → add its row here and a `case` to `Style.apply_skin()`, then the menu
calls `Style.apply_skin(panel, Style.MenuSkin.X)` (one line — it sets paper,
silhouette, margins and the frame). **[CHECK]** Every menu panel uses
`Style.apply_skin(...)`, not the generic `Style.panel()`.

**The craft minigames are one bench.** Cutting and sewing both wear `WORK` and share
their whole chrome (`ui/minigame_screen.gd`): the scrim, the panel, the title row with
its slip pins, the job's swing ticket, the play surface, the status line and the key
prompts. What differs is the *surface they paint* — a cutting mat with a pinned paper
pattern, versus a machine bed with a strip of cloth under the needle — and the frame,
because a garment shape needs height (`FRAME_TALL`) where a seam needs width
(`FRAME_WIDE`). A new minigame extends `MinigameScreen` rather than rebuilding chrome;
`check_ui.gd` knows about that base (`CHROME_BASE`) and still checks the rest.

**Dialogs are not panels.** A character *speaking* to the player (e.g. the greeting
brief) uses a small **speech bubble** — a compact cream rounded panel with a
downward tail (`ui/speech_tail.gd`) and light key-cap prompts, not the full atelier
frame. These are `EXEMPT` in the checker.

**Collision rule [JUDGE]:** the screen title lives top-left, so solid shape
accents are tucked hard into the top-right or edges, never top-left; the pattern
stays a faint watermark and fabric swatches sit above it. No solid decoration or
label may overlap a label. Verify by screenshot for every migrated menu.

---

## 6. Staging — put the player in the scene  **[JUDGE]**

AC never just floats a box on a frozen world; it *poses* the player and frames the
moment. For interactions with a subject (the mirror, a customer, a station), the
menu should sit to one side and the camera should frame the player + subject on the
other, rather than dimming everything. `FRAME_FULL` menus own the whole screen and
supply their own staging. This is aspirational for existing menus and required for
new subject-facing ones (mirror first).

---

## 7. Generated art

Art is always **optional**: every surface that can take a texture paints its own
fallback from the palette, so a missing file only costs the texture, never the screen.
Generated PNGs live in `assets/textures/ui/`.

### 7.1 Writing the prompts — keeping the "AI look" out

Image models have a house style: smooth gradients, a soft glow, a centre-lit vignette,
plastic surfaces and perfect symmetry. It reads as generic instantly and it fights this
game's hand-made identity. Every prompt written for TailorTown therefore:

1. **Names a real medium and tool**, never a render. "Flat gouache on toned paper",
   "screen-printed in three inks", "coloured pencil on kraft" — not "digital art",
   "3D render", "concept art".
2. **Bans the render gloss explicitly.** A standing negative list, in the prompt body:
   *no gradients, no glow, no bloom, no rim light, no lens blur, no depth of field, no
   vignette, no drop shadow, no specular highlights, no floating particles.*
3. **Never uses quality-inflation words.** `4k`, `8k`, `masterpiece`, `hyperdetailed`,
   `photorealistic`, `trending on ArtStation`, `Unreal Engine`, `octane` all push the
   smooth plastic look. Leave them out.
4. **States the lighting.** For a tiling texture: *"flat, even, frontal light with no
   single light source"* — the centre-lit falloff is the clearest AI tell in a tile.
5. **Gives the palette as a closed set of hex values** ("five colours only: …"). Open
   palettes drift pastel-rainbow.
6. **Asks for honest irregularity, in moderation.** Two or three imperfection cues —
   *"lines drawn by hand, slightly uneven", "one small scuff", "threads not perfectly
   parallel"* — and no more; a fourth makes the model degrade the image on purpose.
7. **Orders the prompt** surface → subject → details → constraints, and puts the
   constraints last as their own sentences (the OpenAI image guide's structure).
8. **Ends with the exclusions**: *no text, no watermark, no signature, no border, no
   frame, no perspective, no horizon, no people.*

Tiling textures add: *"the left edge continues into the right edge and the top into the
bottom; no feature is cut off at an edge without continuing on the opposite one."*
Cut-outs add either a transparent background (gpt-image-2 renders real alpha when asked
for an isolated subject on a transparent background) or, as a fallback, *"everything
around it is flat pure green #00FF00 with no gradient, shadow, glow or fringing"* for
keying.

### 7.2 The stage curtain

`ui/loading_curtain.gd` draws the velvet curtain over every scene swap. It takes three
textures, and paints its own fallback from the palette for any that are missing, so the
game always has a curtain:

| File (in `assets/textures/ui/`) | What it is |
|---|---|
| `curtain_panel.png` | The LEFT half, mirrored for the right and stretched to half the screen. Solid fabric to the top/left/right edges; the bottom ~4% is the scalloped hem, with alpha below it (`ART_HEM_SHARE` must match). |
| `curtain_trim.png` | The braid down each leading edge. Tiled down its length, drawn at `TRIM_SHARE` of the screen height so it reads the same at any resolution. Must tile top-to-bottom. |
| `curtain_valance.png` | The pelmet. Tiled across the screen at `VALANCE_SHARE` of its height; rides down with the curtain and flies out as it opens. Must tile left-to-right. |

The art is generated from the prompts below, dropped in `IMPORT/curtain` (git-ignored) on a
flat green background — image models will not give reliable transparency — and turned into
the textures by `tools/prep_curtain_art.py`, which keys the green, crops, and makes the two
strips tile. It prints the panel's hem share; check it still matches `ART_HEM_SHARE`.

<details>
<summary>Generation prompts (ChatGPT image)</summary>

**1. Panel** — portrait 1024x1536

> A single left-hand theatre curtain panel of deep burgundy velvet, seen flat-on from the
> front, filling the entire image edge to edge. Hand-painted stylised game art for a cosy
> storybook tailor-shop game: soft cel shading, warm painterly texture, gentle rim light, no
> photorealism, no black outlines. Roughly seven tall vertical pleats running the full height
> — wide dark folds with narrower lit crests — with the folds varying slightly in width so the
> drape looks natural rather than a repeating pattern. Colour: rich burgundy #7A3B3B, folds
> deepening to a near-black plum #2E1616, crests catching a warm highlight up to #9A5555.
> Slightly darker along the top edge as if shaded under a rail, and darker again down the
> right-hand edge where this panel meets its twin. The bottom 12% of the image is a scalloped
> gathered hem: the fabric ends in soft arches that hang down between the pleats. Everything
> below that hem is flat pure green #00FF00 with no gradient, shadow, glow or fringing. The
> fabric itself must run all the way to the left, right and top edges with no border and no
> background showing. No gold trim, no tassels, no rope, no fringe, no pelmet, no rings, no
> rail, no text, no watermark, no perspective, no floor, no stage, no people.

**2. Braid** — portrait 1024x1536

> A single vertical length of ornate gold bullion braid — the decorative binding sewn down the
> leading edge of a theatre curtain — running perfectly straight from the very top of the image
> to the very bottom, centred, about one tenth of the image width. Hand-painted stylised game
> art, soft cel shading, warm painterly, cosy storybook tailor-shop game, no photorealism.
> Antique brass gold #C9A24A with darker recesses #8A6A2A and bright highlights #E8CE86. A
> regular repeating twist along its length, identical from top to bottom with no change in
> scale, thickness or lighting, and the pattern cut at exactly the same point at the top and
> bottom edges so stacked copies join seamlessly. Everything around the braid is flat pure
> green #00FF00 with no gradient, shadow or glow. No tassels, no fringe, no curtain, no fabric,
> no text, no watermark, no perspective.

**3. Valance** — landscape 1536x1024

> A horizontal swagged pelmet (valance) of deep burgundy velvet hanging across the top of a
> theatre curtain, seen flat-on from the front. Hand-painted stylised game art for a cosy
> storybook tailor-shop game: soft cel shading, warm painterly texture, no photorealism, no
> black outlines. The velvet fills the top of the image edge to edge and drapes into four
> identical shallow swags, each gathered upward at its sides and dipping in the middle, with
> soft radiating folds. A row of short gold bullion fringe hangs from the lower edge of each
> swag. Burgundy #7A3B3B deepening to #2E1616 in the folds, crests to #9A5555; fringe in
> antique brass gold #C9A24A with darker recesses #8A6A2A. Critical: the left and right edges
> of the image must both fall at exactly the same point in a swag — the highest gathered point
> — so copies placed side by side form a continuous run with no visible seam. Everything below
> the fringe is flat pure green #00FF00 with no gradient, shadow or glow. No curtain panels, no
> rail, no rings, no rope, no tassels, no text, no watermark, no perspective, no room.

</details>

### 7.3 Craft-minigame surfaces

Three tiling textures the cutting and sewing screens use if they are present. All three
are drawn **tiled at their own pixel size**, so author them at the scale they should
read at on screen, and all three must tile seamlessly in both directions.

| File (in `assets/textures/ui/`) | What it is |
|---|---|
| `cutting_mat.png` | 512x512. The cutting mat's surface, grid included — when it is present the drawn grid is skipped (the ruler ticks along the canvas edges are still drawn, since those can't tile). |
| `machine_bed.png` | 512x512. The sewing machine's deck. The needle plate, feed dogs, arm and spool stay drawn on top of it. |
| `cloth_weave.png` | 256x256. A near-white linen weave, **multiplied by the customer's cloth colour**, so it must be light and neutral — no colour of its own. |

<details>
<summary>Generation prompts (ChatGPT image)</summary>

**1. Cutting mat** — square 1024x1024, used at 512

> A seamless tiling texture of a tailor's cutting mat, seen straight down from above,
> filling the whole image edge to edge. Flat gouache on toned paper, painted by hand for
> a cosy storybook tailoring game. Warm tan ground #DCCFB0 with a printed measuring grid
> in a slightly darker tan #CBBB97: thin lines forming squares about one thirty-second of
> the image wide, and a marginally heavier line every fourth square. The grid lines are
> drawn by hand and very slightly uneven, not ruled by a machine. Two or three faint
> healed scalpel scuffs cross the mat at shallow angles in #C6B48E, well away from the
> edges. Five colours only. Flat, even, frontal light with no single light source and no
> falloff anywhere in the image. No gradients, no glow, no bloom, no rim light, no lens
> blur, no depth of field, no vignette, no drop shadow, no specular highlights, no
> floating particles, no cloth, no tools, no pattern pieces. The left edge continues into
> the right edge and the top into the bottom; no feature is cut off at an edge without
> continuing on the opposite one. No text, no numbers, no watermark, no signature, no
> border, no frame, no perspective, no horizon, no people.

**2. Machine bed** — square 1024x1024, used at 512

> A seamless tiling texture of the flat deck of an old sewing machine, seen straight down
> from above, filling the whole image edge to edge. Flat gouache on toned paper, painted
> by hand for a cosy storybook tailoring game. Dark warm walnut-brown japanned metal
> #4A3826 with a finer grain in #3B2C1E running the full width in one direction only.
> Two or three small honest marks: a shallow scratch, a worn patch rubbed slightly
> lighter to #5A4632. Four colours only. Flat, even, frontal light with no single light
> source and no falloff anywhere in the image. No gradients, no glow, no bloom, no rim
> light, no lens blur, no depth of field, no vignette, no drop shadow, no specular
> highlights, no reflections, no floating particles, no needle, no presser foot, no
> plate, no screws, no decals, no cloth. The left edge continues into the right edge and
> the top into the bottom; no feature is cut off at an edge without continuing on the
> opposite one. No text, no watermark, no signature, no border, no frame, no perspective,
> no horizon, no people.

**3. Cloth weave** — square 1024x1024, used at 256

> A seamless tiling texture of plain-woven linen seen straight down from above, filling
> the whole image edge to edge, painted almost white so it can be tinted any colour
> afterwards. Flat gouache on paper, painted by hand for a cosy storybook tailoring game.
> Off-white ground #FAF6EE with the warp and weft threads picked out in #EFE8DA and
> #E4DCCB, crossing at right angles, about one hundred and twenty threads across the
> image. The threads are not perfectly parallel and their spacing varies very slightly,
> the way real cloth does. Three colours only, all of them near-white — no hue, no tint,
> nothing saturated anywhere in the image. Flat, even, frontal light with no single light
> source and no falloff anywhere in the image. No gradients, no glow, no bloom, no rim
> light, no lens blur, no depth of field, no vignette, no drop shadow, no specular
> highlights, no fraying, no hem, no seam, no stitching, no pattern, no print. The left
> edge continues into the right edge and the top into the bottom; no feature is cut off
> at an edge without continuing on the opposite one. No text, no watermark, no signature,
> no border, no frame, no perspective, no horizon, no people.

</details>

## 8. Compliance

- **[CHECK]** rules → `tools/check_ui.gd` (headless, part of the dev loop). Run:
  `godot --headless --path . --script res://tools/check_ui.gd`. Report in
  `.dev/ui_check.log`; non-zero exit on any violation. Screens that aren't modal
  panels (minigame hosts, HUD strips) are listed `EXEMPT`. A legitimate non-styling
  `Color()` literal (e.g. a skin/hair data fallback) is allowed by adding a
  `# ui-check-ignore` marker on that line.
- **[JUDGE]** rules → screenshot each changed menu (`tools/screenshot.gd`) and
  rate against §2 (type hierarchy), §4 (prompts/emphasis), §5 (distinct surface),
  §6 (staging). This is the checklist a dedicated UI-rater agent uses.

**Definition of done for any UI change:** `check_ui.gd` passes, `gdlint` clean,
a screenshot exists, and the change is consistent with the skin table (§5).

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
- **Background pattern** — a faint full-area watermark (`AtelierFrame.Pattern`).
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

**Collision rule [JUDGE]:** the screen title lives top-left, so solid shape
accents go top-right or along edges, never top-left; background patterns stay
faint watermarks. No decoration or label may overlap another label. Verify by
screenshot for every migrated menu.

---

## 6. Staging — put the player in the scene  **[JUDGE]**

AC never just floats a box on a frozen world; it *poses* the player and frames the
moment. For interactions with a subject (the mirror, a customer, a station), the
menu should sit to one side and the camera should frame the player + subject on the
other, rather than dimming everything. `FRAME_FULL` menus own the whole screen and
supply their own staging. This is aspirational for existing menus and required for
new subject-facing ones (mirror first).

---

## 7. Compliance

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

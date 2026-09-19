# UI Overhaul Plan — type, titles, and the front door

Status: **proposed** (2026-09-19). Companion to `docs/UI_STYLE_GUIDE.md`; when a phase
lands, its rules move into the style guide and this file shrinks.

The atelier identity (paper, brass, stitching, craft objects) stays exactly as it is. This
pass is about **typography and placement** — the things that currently make good surfaces
read as "simple".

---

## 1. What is actually wrong (audit, 2026-09-19)

1. **The whole game is set in Fredoka *Light*.** `assets/fonts/Fredoka.ttf` is a variable
   font (`wght` 300–700, `wdth` 75–125). Nothing selects an instance, so Godot renders the
   default: weight 300. `Style.bold_font()` is `variation_embolden = 0.4` on top of Light —
   a smeared fake, not the real 600/700 cut that is sitting in the file.
2. **No type scale.** 17 distinct font sizes (10 → 46) across `ui/`, ~130 literals, zero
   named constants — including inside `style.gd`.
3. **Screen titles drifted.** Five sizes (22/24/26/40/46), four colour conventions (accent,
   accent darkened, WALNUT, INK), one centred (pause) vs the rest left. Only 4 of 10 titled
   menus call `Style.title_label()`; the rest re-type the same three lines.
4. **Titles are low-contrast and unanchored.** Brass on cream (phone, mirror) is the weakest
   text on the screen when it should be the strongest. No rule, no kicker, no consistent
   subtitle slot — the title just floats above whatever comes next (budget line, badges,
   tape measure, calendar, tabs…).
5. **Hierarchy inside panels is flat.** Row label and row value are nearly the same weight
   and size (17/18). The most important number on a screen is often caption text — e.g. the
   mirror's `Cloth $96 + Craft $180 = Quote $276` is 14pt soft ink. Money is bold in the
   HUD, plain in the ticket strip, plain on the orders board.
6. **`Style.header()` exists and almost nobody uses it** (settings + phone only), and it
   defaults to BRASS regardless of the host skin.
7. **Main menu:** the wordmark is a 40pt Label in the body font, left-aligned above centred
   buttons; the sign covers ~40% of a lovely town shot; no version, no key prompts, no
   "last save" info; an unstyled default `HSeparator`. Title colour is authored three times
   (builder BRASS → `.tscn` BRASS → runtime WALNUT).
8. **Plumbing:** no project-wide Theme (`ui.gd` hand-assigns a runtime theme to 9 nodes;
   `day_transition` is missed), `newspaper.gd` runs its own font factory, `coach_mark` and
   `mentor_dialog` hand-rebuild `key_pill` 1pt bigger, dead font sizes in `ui.tscn`.
9. **Tooling:** `check_ui.gd` has no typography rule and never sees 8 UI files.
   `shot_ui.gd` is **broken** — it boots `run/main_scene`, which is now the main menu, so
   every capture is the title screen.

---

## 2. Decisions to make first

| # | Decision | Recommendation |
|---|----------|----------------|
| A | Add a **display face** for the wordmark + screen titles? | **Yes — Fraunces** (OFL, variable: weight, optical size, and a `SOFT` axis that rounds the serifs). A soft old-style serif says "tailor's fascia lettering" and sits comfortably next to Fredoka's round forms. Used for: wordmark, screen titles, day card, newspaper masthead. *Never* for body, rows, values or prompts. Fallback if it feels too formal in-game: keep Fredoka 700 for titles and use Fraunces for the wordmark only. |
| B | Wordmark: **type-set in code** or **generated art**? | **Code first** (`ui/craft/wordmark.gd`): it is resolution-proof, themable, and animatable (thread draws itself on boot). Art can replace it later via the usual optional-texture hook (§7 of the style guide). |
| C | Main-menu layout: keep the **hanging sign as the whole menu**, or split **fascia sign (wordmark) + slim menu column**? | **Split.** The sign becomes what a sign is — the shop's name — and shrinks; the buttons become a narrow stack of sewn labels under it. Frees the town view. |
| D | Title colour rule | **Always INK/WALNUT** for the title text; the skin accent moves to the *kicker* and the *rule* under the title. Fixes contrast and ends the four-conventions drift in one move. |

---

## 3. The type system (Phase 1 target)

### Fonts — real variable instances, built once in `Style`

| Token | Face | Axes | Use |
|-------|------|------|-----|
| `Style.font_body()` | Fredoka | wght 450 | default everywhere (was 300) |
| `Style.font_medium()` | Fredoka | wght 550 | row values, card names, buttons |
| `Style.font_bold()` | Fredoka | wght 650 | headers, money, key terms, pills |
| `Style.font_caps()` | Fredoka | wght 600, wdth 90, glyph spacing +2 | kickers / small caps labels |
| `Style.font_display()` | Fraunces | wght 700, SOFT 100, opsz high | wordmark, screen titles, day card |

`bold_font()` stays as an alias of `font_bold()` so nothing breaks. Exact weights get tuned
by eye in a specimen shot (Phase 0) — these are starting values.

### Scale — seven steps, named, nothing else allowed

| Token | px | Role |
|-------|----|------|
| `T_MICRO` | 12 | badges, folio, tape numerals |
| `T_CAPTION` | 14 | sub-lines, hints, kickers, pills |
| `T_BODY` | 16 | body copy, row labels |
| `T_VALUE` | 18 | row values, buttons, section headers |
| `T_NAME` | 21 | card / item names |
| `T_TITLE` | 28 | screen titles |
| `T_HERO` | 46 | day card, wordmark base |

Maps the current 17 sizes onto 7 (10/11→12, 13/15→14, 17→16, 19/20→18 or 21, 22/24/26→28
or 21). The newspaper keeps a private sub-scale but built from `Style` fonts.

### Project-wide theme

Generate `data/ui/atelier_theme.tres` (from a small builder tool) and set it as
`gui/theme/custom` in `project.godot`. Default font = `font_body`, default size = `T_BODY`,
plus type variations `Title`, `Header`, `Kicker`, `Caption`, `Value`. Delete the manual
nine-node assignment in `ui.gd`. Every Control — main menu, day card, debug panels — gets
the right font for free.

---

## 4. The title block (Phase 2 target)

One component, `Style.title_block(title, opts)`, used by **every** panel:

```
  ORDER PAD                      ← kicker: T_CAPTION, font_caps, skin accent   (optional)
  Harrow's Haberdashery          ← title: T_TITLE, font_display, INK
  ━━━━━━━╸ ─ ─ ─ ─ ─ ─ ─ ─ ─     ← rule: short solid accent bar + running stitch to the edge
  Budget $500        ·  3 rolls  ← meta row: T_CAPTION, INK_SOFT, values in font_bold (optional)
```

- Left-aligned in panels (top-left is reserved for it — style guide §5 collision rule
  already says so). Centred only on *cards* (sign, day card, goal tag, gazette).
- The **kicker** carries the surface's identity ("ORDER PAD", "FITTING ROOM", "THE BENCH",
  "HANDBOOK") so the title itself can be the *specific* thing: the supplier, the customer's
  name, the garment. Today those fight for one line (`Order · Harrow's Haberdashery`).
- The **meta row** is the one sanctioned home for what currently gets wedged under titles:
  budget, roll count, client badges, slips/pips in minigames.
- `right` slot for things that must share the row (minigame slips + pips).
- Extra top padding per skin so the title clears the spiral binding / book spine / arch.

`Style.header()` gets the same treatment at small scale — `T_VALUE` bold, accent, with a
hairline stitch running to the panel edge — and takes the skin accent from the panel
instead of defaulting to BRASS.

---

## 5. Hierarchy inside panels (Phase 3 target)

Shared builders so every menu says the same thing the same way:

- **`Style.field_row(label, value)`** — label `T_CAPTION` caps-ish INK_SOFT, value
  `T_VALUE` `font_medium` INK. One definition replaces the 17/18 vs 18/19 variants in
  phone / mirror / worktable. Selected row: value goes `font_bold`.
- **`Style.money(amount, size)`** — always `font_bold`, tabular figures, FOREST for income /
  INK for prices / CLAY for can't-afford. Retire `LEAF`. HUD, ticket strip, orders board,
  phone and mirror all use it.
- **`Style.total_bar(parts, total)`** — the quote/price summary as a proper footer block:
  small parts on the left (`Cloth $96 + Craft $180`), the total large and bold on the right
  (`Quote $276`), a stitched rule above. Mirror, phone order form, worktable.
- **Footer anchoring** — hint pills pin to the panel bottom with a consistent `S3` gap and a
  hairline above; the scroll region above absorbs slack. Kills the floating gap in the
  mirror panel (rows end at 60%, pills sit at 85%).
- **Bold rule, written down:** bold = *the thing you came to read* — names, money, due
  dates, the selected value, one key term per sentence of body copy. Never whole paragraphs,
  never row labels.
- **Card names** unify at `T_NAME` `font_medium`; sub-lines `T_CAPTION`.

---

## 6. Main menu (Phase 4 target)

**Layout**

```
 ┌─ chains ─┐
 │  T A I L O R                                  ← fascia sign: walnut board, gold-leaf
 │    T O W N  ~~~~~~~⟶ needle                    Fraunces wordmark, thread flourish
 │  BESPOKE TAILORING · ON THE ROW │              tracked small caps
 └────────────────────────────────┘
   ┌ New Game ┐                                   ← slim column of sewn labels (~280px),
   ┌ Continue ┐  Day 12 · $1,840 · ★★☆            hung from the sign on short threads;
   ┌ Load     ┐                                   Continue shows the latest save inline
   ┌ Settings ┐
   ┌ Quit     ┐
                                   [town, unobstructed — ~70% of the frame]

 v0.x.y                          W/S Select   E Choose   Esc Back        ← footer
```

- **Wordmark** (`ui/craft/wordmark.gd`, drawn): two-line lockup in `font_display`, gold-leaf
  treatment = BRASS fill + RIM_DARK lower-right edge + a thin CHALK top-left highlight (flat
  shapes, no gradients — consistent with §7.1). A running-stitch underline that ends in a
  threaded needle. Tracked small-caps tagline underneath.
- **Boot animation:** sign drops in on its chains and settles (existing sway), the thread
  underline *sews itself* left→right, then the button labels pop in staggered (existing
  `Craft.pop_in`). ~1.2s total, skippable by any input.
- **Buttons:** `MenuKit.button` to `font_medium` `T_VALUE`; focused label slides 6px right
  with a brass pin marker rather than only changing fill. Narrower (280) so the column
  reads as labels, not a form.
- **Sub-pages** (Load / Settings) keep the fascia but swap the wordmark for a normal
  `title_block` on the cream plate — camera already eases to a different viewpoint.
- **Save slots:** two-line rows — `Slot 2` bold + `Day 12 · $1,840 · ★★☆ · 09-19 21:14`
  caption — instead of one long dotted string.
- **Footer:** version string bottom-left, `Style.hint_bar` bottom-centre (the menu is the
  only screen with no key prompts today).
- **Cleanup:** single source for title colour/text (builder only; drop the runtime
  override), replace the default `HSeparator` with the stitched rule, rebuild the scene via
  `build_main_menu.gd` so the `.tscn` stops baking stale copies of Style values.
- **Pause menu** inherits all of it (same `SignBoard` + `MenuKit`), with "Paused" as a
  `title_block`, and the day / money / time as its meta row.

---

## 7. Phases

Each phase ends with: `check_ui` green, gdlint clean, before/after shots, commit + push.

| Phase | Work | Size | Visible change |
|-------|------|------|----------------|
| **0 — Tooling** | Fix `shot_ui.gd` (load `main.tscn` explicitly; add mirror, rack, apprentice, pause, settings, main-menu targets; document worktable/customer). Add `tools/shot_type_specimen.gd` — one sheet showing every font token × scale step on each paper colour. Capture a "before" set. | S | none |
| **1 — Type foundation** | Real Fredoka instances; add Fraunces; `T_*` scale; `atelier_theme.tres` + `gui/theme/custom`; remove the `ui.gd` manual theme plumbing; `bold_font()` aliased. Tune weights on the specimen sheet. | M | **Large** — every label in the game gets heavier and crisper at once. Needs your eyes before going further. |
| **2 — Title block** | `Style.title_block` + upgraded `Style.header`; migrate all 10 titled menus + `MinigameScreen`; kicker names per skin; per-skin top padding; day card + gazette masthead onto `font_display`. | M | Large |
| **3 — Inner hierarchy** | `field_row`, `money`, `total_bar`, footer anchoring; sweep ~130 size literals onto `T_*`; unify card names; fold `coach_mark` / `mentor_dialog` pills back into `Style.key_pill`; newspaper onto `Style` fonts; retire `LEAF`; delete dead `ui.tscn` sizes. Menu by menu: phone → mirror → worktable → orders → shelf/rack → apprentice → HUD strips. | L | Medium per menu, cumulative |
| **4 — Main menu** | Wordmark, split layout, boot animation, slot rows, footer, pause-menu parity, builder cleanup. | M | **The showpiece** |
| **5 — Guardrails** | `check_ui.gd` typography rules: no numeric `font_size` literal outside `style.gd` (must be `Style.T_*`); titled menus must call `title_block`; no `FontVariation.new()` outside `style.gd`; bring the 8 unchecked files into MIGRATED/EXEMPT. Rewrite style guide §2 *Type* + add §4.1 *Title block* and the bold rule. | S | none — stops it drifting again |

**Order rationale:** Phase 1 is the cheapest big win and changes text metrics everywhere,
so it must land before anyone fine-tunes placement. Phase 4 can be pulled forward to right
after Phase 1 if you want the showpiece early — it only depends on the fonts.

## 8. Risks

- **Heavier text is wider.** Real 450/650 weights run ~4–8% wider than Light; fixed-frame
  panels with tight rows (mirror part rows, order tickets, goal tag) may clip or wrap.
  Mitigation: `wdth 95` on `font_medium`/`font_bold` if needed, and the specimen + per-menu
  shots in Phase 1.
- **Fraunces could read too "editorial"** against the chunky 3D. That is what decision A's
  fallback is for; the specimen sheet settles it before any menu is touched.
- **Tutorial coach marks** point at rows by position — re-verify the tutorial shots after
  Phase 2/3 move things.
- **Main-menu scene is builder-generated but hand-editable** — confirm nothing was
  hand-tweaked in `main_menu.tscn` (it is currently modified in git) before re-running
  `build_main_menu.gd`.

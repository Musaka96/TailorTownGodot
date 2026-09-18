# Research — a new cutting minigame

Written 2026-09-18. v1 is preserved at git tag **`cutting-v1-steer`** (`ui/cutting_minigame.gd`).

## Why v1 feels bad

v1: the cut auto-travels the outline; you aim the scissors with WASD/stick and the cut
only advances while the blades are within 26° of the edge.

1. **WASD has 8 directions, the edges don't.** The jittered silhouettes give every edge
   an arbitrary angle, so on keyboard you are *never* pointing along the line, only
   "near enough". It reads as imprecise even when it's counting.
2. **The corner deadlock.** The cut stops dead whenever you're misaligned. At a
   corner the eye says "I'm there, turn", but the cursor is still a few pixels short on
   the old edge. Turning early = misaligned = the cursor stops = it never reaches the
   corner. You have to turn *back* to finish the last pixels. That's the "stuck" report.
3. **2D aiming is the wrong input for keyboard parity.** A stick gives 360°, keys give
   8. Any design built on free 2D aiming will always feel better on one device.

## Principles for keyboard ↔ controller parity

- **Use 1D axes and buttons, not 2D aim.** Left/right (A/D ↔ stick X) and a hold/tap
  button (Space/E ↔ A) feel near-identical on both. Keyboard axes get a short
  ramp (tap = small nudge, hold = accelerate) so they approximate a stick.
- **Turn the cloth, not the wrist.** Real cutters walk round the table / rotate the
  work so they always cut the same way. If the cut always heads *up the screen*,
  "left" and "right" never flip meaning.
- **Never gate progress on precision.** Being off the line should cost quality, not
  stop the cut. Stopping is what created the corner trap.
- **Corners are automatic (or a bonus), never a wall.**
- **Don't make it rhythm.** Sewing already is a timing-tap game; cutting should
  feel like *steering / judgement*, so the two stations don't blur.

## Genre references (what we'd borrow)

| Game | Mechanic | Takeaway |
|---|---|---|
| Cooking Mama / Trauma Center | trace dotted lines with stylus / pointer | the fantasy; but pointer-based, doesn't port to keys |
| Papa's ___ria (Flipline) | every station scored as a %, rarely 100 | generous floor, visible headroom, per-step breakdown at the end |
| Stardew Valley fishing | one button keeps a bar inside a moving zone | 1-input "stay in the band" tracking works on any device |
| Mario Kart smart steering | assist keeps you on track | assist can raise the floor without touching the ceiling |
| Racing/lane games on keyboard | digital left/right with accel ramp | 1D tracking is fine on keys; 2D isn't |
| Golf 3-click swing / power meters | hold & release to set strength | judgement input, identical on every device |
| Real tailoring | long strokes on straights, short snips on curves; cut on the seam allowance side; rotate the work | authentic mechanics that happen to be controller-friendly |

## Propositions

### A. "Seam Allowance" — steer the line, cloth turns for you  ⭐ recommended

- The cloth rotates so the cut **always runs up the screen**. Hold **Cut** (Space/E ↔ A)
  to advance; release to pause. Steer **left/right** only (A/D ↔ stick X).
- Straight edges are relaxing; the skill is in the **curves** — armhole, neckline,
  crotch curve, lapel — where the line sweeps sideways and you have to follow it.
- At a corner the scissors stop, the blades open, and the cloth **pivots** by itself
  (optional: a "pivot" press prompt for a small bonus). Nothing can get stuck.
- **Three zones, asymmetric** (this is the leeway):
  - *On the chalk* (thin band) → **Perfect**
  - *Outside, within the seam allowance* (wide band) → **Good**. Safe, forgiving.
  - *Inside the line* → you're cutting into the garment: a **nick**. Sustained = a slip.
  - Far outside → "rough", wasted cloth, but not a slip.
  The safe side is obvious and wide, so a new player hugs the outside and finishes;
  a good player rides the chalk.
- **Fabric matters** (ties into premium suppliers): silk drifts sideways, tweed is
  steady, stripes/checks need the pattern matched → harder but pricier.
- Shift sprint upgrade still fits: faster cut, the curves come at you faster.

Keyboard vs controller: same inputs, same feel — this is the strongest parity option.

### B. "Long Strokes & Snips" — one-button judgement

- The scissors sit on the line. **Hold** to open the blades wider (a charge),
  **release** to close = one stroke. Stroke length = how wide you opened.
- A stroke goes **straight along the current tangent**. On a straight edge a long
  stroke is perfect and fast; on a curve a long stroke overshoots and leaves the line.
- Short snips are always safe but leave a **jagged, chewed edge** (small quality cost)
  — exactly what happens with real shears.
- Easy: snip-snip-snip all the way → finishes, ~75%. Mastery: long strokes on the
  straights, measured strokes on curves, few jags → 100%. A "par" stroke count per
  piece gives a golf-like target.

One button, so parity is perfect. Risk: charge/release is close-ish to sewing's timing
feel — mitigated because there's no tempo, you take your time.

### C. "Lay the Marker" — layout puzzle before the cut (add-on, not a replacement)

- Place the pattern pieces on the cloth before cutting: grid-snapped moves
  (WASD/d-pad), rotate with Q/E ↔ bumpers, grain line must run with the selvedge
  (so only 0°/180°).
- Easy: an "auto-lay" button gives a valid, slightly wasteful layout. Extra good: a
  tight layout **saves cloth** → leftover scrap / refund (feeds docs/ECONOMY.md).
- Most effort (needs real multi-piece shapes). Best as a later upgrade stage.

### D. "Fold & Cut" — garnish for A or B

- Many pieces are cut on the fold: fold the cloth, cut half the outline, then an
  **unfold reveal** of the full symmetric piece. Halves cut length, adds a great
  "ta-da" moment. Cheap once A or B exists.

### E. Rotary cutter + ruler — alt tool / upgrade

- Place a ruler (snaps to chalk marks), then hold to roll the cutter and keep the
  pressure needle in a green band (Stardew-style). Straight lines only, so less
  bespoke-feeling; could be a "Rotary Cutter" upgrade that makes straight pieces fast.

### (0. Patch v1 instead)

If we wanted to keep v1: a corner grace window (either edge's tangent counts within
N px of a vertex), never stop the cursor (slow it instead), and aim magnetism toward
the line. Fixes the stuck bug, but not the 8-direction feel.

## Where the difficulty should sit

Targets (matches the Papa's-style "generous floor, visible ceiling"):

| Player | Should get |
|---|---|
| First try, no idea | finishes, ~65–75% quality, almost never ruins it |
| Paying attention | 80–90% |
| Skilled, riding the line | 95%+ |
| Flawless | 100% + a "Clean Cut" stamp |

Scoring sketch for A (per sample along the cut length):
`perfect = 1.0, good = 0.8, rough = 0.4, nick = 0.2` (as built); quality = average − 0.1 per
slip. Ruin only after 3 sustained nicks (deliberately hard to hit by accident).
Staying in the wide band the whole way = 80% → the floor is easy, the last 20% is
where the skill lives. Show an end-of-cut breakdown ("Perfect 62% · Good 35% · Nicks 1").

Knobs (all into `GameConfig`, like v1's `cut_*`): band widths, cut speed, keyboard
ramp, fabric drift per textile, and a "Steady hand" assist that widens the bands.

## Switching between versions

Both versions keep the same contract — `start(garment_type, title)` and
`finished(success, quality)` — so `worktable_screen.gd` picks one by a
`GameConfig.cut_variant` setting. v1 stays in the codebase as-is.

## Built (2026-09-18)

A (v2) and B (v3) are in, alongside v1:

- `ui/cut_bench.gd` — shared base (`CutBench`): curved garment outlines, the customer's
  cloth + pattern on the mat, seam-allowance band, zone scoring, shears.
- `ui/cut_allowance_minigame.gd` — v2 "Seam Allowance" (steer + hold, cloth turns; glides
  1.8× on straights held on the line; base outline 12 s).
- `ui/cut_strokes_minigame.gd` — v3 "Long Strokes & Snips" (one button, ghost stroke).
- `ui/cut_variants.gd` — factory; `GameConfig.cut_variant` picks what the worktable runs.
- F3 debug panel → **Cutting minigame**: try v1/v2/v3 on a random bolt, pick the piece,
  and switch what the worktable uses (live, not saved).

v3 simulated (5 runs each): snipping everything ≈ 0.81; expert ≈ 1.00; "good enough"
strokes ≈ 0.93–0.98; always-max strokes 0.85–0.97 on shirt/trousers (mostly straight),
but slips on the jacket's rounded front.

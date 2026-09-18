# Research — a more machine-like sewing minigame

Written 2026-09-18, after cutting v2 ("Seam Allowance") landed well. The current game
(`ui/sew_minigame.gd`) is kept as-is; anything new goes in beside it with a variant
switch, the same way cutting did (`CutVariants`).

## What's off about the current one

The current game is rhythm: the needle bar runs across a still strip of cloth, and you
tap as it reaches each marked point. It's fun, but it's not how a machine works:

1. **On a real machine the needle stays put and the cloth moves.** The machine feeds
   the cloth toward you with its feed dogs; your hands only *guide* it.
2. **You don't press once per stitch.** The foot pedal sets the speed, and the machine
   makes the stitches. The skill is controlling speed and guiding the cloth.
3. **You keep the seam straight with the seam guide**: engraved lines on the throat
   plate (1.5 cm / 5/8"). You keep the cloth's raw edge on the line, not the needle
   on a mark.

## What real machine sewing involves (every step is a mechanic)

| Real step | What it becomes in the game |
|---|---|
| Foot pedal: gentle = slow, floored = fast | analog speed: pad trigger, or Space with motor spin-up |
| Guide the cloth edge along the seam guide | steer left/right (same input as cutting v2) |
| Slow down for curves | curves are hard at speed, easy slow |
| Corner: stop with the needle *down* exactly at the corner, lift the foot, turn the cloth, drop the foot | stop on the mark with the pedal, then press Pivot |
| Backstitch a few stitches at the start and end to lock the seam | hold Reverse briefly at each end |
| Pull each pin out before the needle reaches it | tap to pull pins as they come in |
| Heavy cloth labours if you race it; slippery cloth wanders | fabric changes max speed and drift |
| Topstitching (lapels, pockets) shows, so it must be dead straight | tighter bands on some seams |

## Propositions

### A. "Pedal & Guide" (recommended)

The machine is fixed at the centre of the screen and the cloth feeds down past the
needle, like cutting v2 but *you* aren't the thing moving.

- **Pedal** (hold Space/F, or RT on the pad): the motor spins up while held and runs
  down when released. On a pad, the trigger is analog, so a half-press is half speed.
  Keyboard gets the same ramp, so tapping works like feathering the pedal.
- **Guide** (A/D or the stick): push the cloth left/right to keep its edge on the seam
  guide. Same zones as cutting: on the line = Perfect, near = Good, wandering =
  Rough. Wandering into the fold = a slip.
- **Stitch evenness:** the stitches appear under the needle, spaced by speed. Jerking
  the pedal on and off leaves uneven stitches. Holding it smooth leaves even ones.
- **Corners:** a chalk mark says where to turn. Ease off and stop with the needle on
  the mark, then press **Pivot** (E / X). The foot lifts, the cloth turns, and the foot drops.
  Stopping short or overshooting leaves a rounded or crooked corner (quality cost,
  not a slip). This is a *pedal-control* skill, so it doesn't feel like cutting.
- **Pins:** pins lie across the seam. Tap **Pull** before the needle gets there. Sewing
  over one = a bent-needle slip. Slow sewing gives lots of time, fast sewing doesn't.
- **Backstitch (optional polish):** at the start and end, hold **Reverse** (Q / LB) for
  a moment. A locked seam gets a small bonus. Skipping it costs only a little.

**How it differs from cutting v2:** cutting is on/off with steering. Sewing is about
*speed control*, with steering as the second hand. Corners and pins are about stopping
and reacting, not steering.

**Where the difficulty sits:**

| Player | Does | Gets |
|---|---|---|
| New | light pedal, slow and steady, pulls pins in time, roughly on the line | ~75–80% |
| Attentive | steady speed, stays on the guide, stops near the corners | 85–90% |
| Skilled | fast on straights, eases into curves and corners, pivots on the mark, backstitches | 95–100% |

Speed is *not* scored directly. It's the risk you choose: faster means less reaction
time for pins, curves and corners. The Oiled Machine upgrade (Shift) raises top speed.
The Industrial Motor upgrade raises top speed and spins up faster.

**Parity:** trigger vs. held key with a motor ramp. Tapping Space ≈ feathering RT.
Everything else is one axis plus buttons.

### B. "Hand Wheel": keep the rhythm, make it a machine

A cheaper change to the current game, if we want sewing to stay rhythm-based:
- The cloth moves and the needle stays still (flip the current view).
- The pedal sets tempo instead of a fixed crossing time, so you choose your own speed.
- Taps become **pins to pull** and **corners to pivot** rather than every stitch.
- Keeps most of the current code, but it's still a timing game at heart.

### C. Seam types as variety (add-on for A or B)

- **Straight seam** (trouser outseam): speed run.
- **Curved seam** (armhole, crotch): feathering the pedal.
- **Set-in sleeve / easing:** the top layer is slightly longer. Hold **Ease** to push
  the extra in evenly (a gentle second input).
- **Topstitch** (lapel edge): half the band width, shows on the finished suit.
- Each garment part gets its own seam from the list, so the shirt, trousers and
  jacket each sew differently.

### D. Machine care (small events)

- **Bobbin runs out** on a long seam: a short "rewind" prompt. It's rare, and a
  Bobbin-Winder upgrade removes it.
- **Thread tension** dial per fabric: a pre-seam choice (light / medium / heavy).
  Pick wrong = puckering (quality, not a slip). It teaches fabrics, and the handbook
  can explain it.

## Suggested build order

1. A, core: fixed needle, feeding cloth, pedal with motor ramp, guide, zones,
   pivot corners. Reuse `CutBench`-style geometry (outline, normals, zones, trail).
2. Pins (the reaction layer).
3. Backstitch plus the seam types from C.
4. D if the station still wants more texture.

Same switch as cutting: `SewVariants` + `GameConfig.sew_variant` + the F3 panel's
"Try" buttons on a random cloth.

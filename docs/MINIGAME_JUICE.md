# TailorTown — Minigame "juice": ideas for rewarding a line done really well

> Suggestions only — nothing here is built yet. Pick what you like and it becomes a task.
> Written after the 2026-09-19 playtest ("add more dopamine for when you do a line real nice").

## Where we are
The benches already punish well and *describe* well, but they barely **celebrate**:

- The only shared "feel" hook is negative: `MinigameScreen._slip_feedback()` rocks the
  panel on a slip. There is no positive twin.
- Cutting colours the trail by zone and prints a verdict word in the status line at the
  end ("Flawless" / "Fine work"…). Sewing prints one fixed sentence. Pressing prints nothing.
- The best existing reward loop is v2's **glide** (clean straight → the shears speed up and
  a glide loop fades in). It works because it is *continuous, audible and earned*. Most
  ideas below copy that recipe.
- No 2D particles, no score popups, no streaks, no camera or panel "pop" on success.

Everything a reward needs is already computed and thrown away:

| Game | Per-moment accuracy already available | Hook |
|---|---|---|
| Cutting v2/v3 | zone per step / per stroke (PERFECT…NICK), length in each zone | `CutBench._record(zone, length, score)`, `_zone_len` |
| Sewing v1 | per-stitch grade array | `SewMinigame._judge`, `_try_stitch()` |
| Sewing v2 | zone per frame (same enum as cutting) | `SewPedalMinigame` → `_record` |
| Pressing | each wrinkle flattened, scorches | `PressMinigame` wrinkle loop |
| Coffee | per-beat grade (Perfect / Good / Off) | `CoffeeBench._grade()` |

## Tier 1 — cheap, high impact (a day or two, all five games at once)

1. **`_good_feedback(level)` on `MinigameScreen`** — the missing twin of `_slip_feedback()`:
   a tiny scale "breathe" of the panel (`Craft.bump`), a soft chime, and an optional word.
   Every idea below calls it, so all benches celebrate the same way.
2. **Perfect streak + rising pitch.** Count consecutive PERFECT steps/strokes/stitches.
   Each one ticks a soft note whose pitch climbs a scale (`Sfx.play(key, db, pitch, pitch)`
   already takes pitch) — 8 notes up, then it sparkles and holds. Breaking the streak
   drops the pitch back with a gentle "aw", not a buzzer. This is the single biggest win:
   it turns "doing it right" into a little tune you don't want to break.
3. **Streak chip.** A small stitched badge by the slip pins: `×6 Perfect`. It bumps on
   every increment, turns brass at 5, forest at 10. Shown only while a streak is alive.
4. **Rubber-stamp verdict.** At the end, the verdict isn't status text — it *stamps* onto
   the piece: "FLAWLESS" / "FINE WORK" slams in at an angle with a thunk (`pin_in`, low
   pitch), ink slightly uneven, tiny panel rock. One shared `VERDICTS` table for every game
   (today only cutting has one).
5. **Hand-drawn sparks on perfects.** No particle system needed: `MinigameCanvas` is a
   draw surface, so a perfect stroke/stitch spawns 5–7 short thread-coloured dashes that
   fly out and fade over 0.3 s (a tiny array of `{pos, vel, life}` painted in
   `_paint_overlay`). In cutting they're cloth-coloured snips; in sewing, thread loops; in
   pressing, little steam puffs; in coffee, crema dots.

## Tier 2 — the "one more go" layer

6. **The tally card.** After the stamp, a small card counts up what you did: bars for
   Perfect / Good / Rough fill left-to-right with ticking sounds, then the quality % rolls
   up like a till, then coins ping if it beat your best. 1.5 s, skippable. (Cutting already
   tracks `_zone_len` and never shows it.)
7. **Personal bests per garment.** "Best jacket cut: 94%". Beat it → a little ribbon pins
   itself to the card and Mr. Hemming-style blip. Stored in the save; costs nothing in
   balance, adds a reason to care about a routine shirt.
8. **Clean-run bonus.** Finish with zero slips → "Clean hands" seal and +1 reputation or a
   few dollars' tip on that order. Small, but it makes the *whole run* matter, not just the
   average.
9. **Glide everywhere.** Give sewing v2 and pressing the v2-cutting treatment: sustained
   accuracy makes the tool visibly and audibly *sing* (machine hum smooths out, the iron
   leaves a bright clean wake). Flow state as feedback.
10. **Trail shimmer.** The perfect portions of a cut line / seam get a moving highlight
    that runs along them once when the piece is finished — your good work literally
    shines before the reveal.

## Tier 3 — nice if there's time

11. **Gamepad rumble**: a light tick per perfect, a soft double-pulse on the stamp, the
    existing rock on a slip. (`Input.start_joy_vibration`.)
12. **Customer sees it.** A Flawless piece makes the waiting customer's portrait beam /
    clap at pickup ("Would you look at that stitching!") — ties bench skill to the
    characters, which is where the cozy payoff lives.
13. **Combo-driven focus.** A 10-streak briefly widens the perfect band (a 2 s "in the
    zone" glow) — success breeds success. Needs care so it doesn't trivialise v2.
14. **Near-miss grace note.** Just outside PERFECT plays a slightly flat note instead of
    nothing — you *hear* how close you were, which is what makes people lean in.
15. **Newspaper shout-out.** A day with 3+ Flawless pieces gets a filler line in the next
    Gazette ("Remarkably Neat Work Seen on the Row").

## Things to avoid
- **Screen shake / big flashes** — wrong tone for a cozy tailor shop; the panel "breathe"
  and the stamp are as loud as it should get.
- **Punishing streak breaks** — the streak resets quietly. Losing the tune is the penalty.
- **Rewards that only show at the end** — the moment-to-moment tick (idea 2) matters more
  than any results screen.
- **Colour as the only signal** — pair every colour change with a sound or a word
  (style guide rule).

## Suggested order
2 + 1 (streak tune, shared hook) → 4 (stamp) → 5 (sparks) → 3 (chip) → 6 (tally) → 7/8.
Ideas 1–5 touch `minigame_screen.gd`, `cut_bench.gd`, `sew_minigame.gd`,
`sew_pedal_minigame.gd`, `press_minigame.gd`, `coffee_bench.gd` and one new sound builder
(`tools/build_juice_audio.gd`: a soft mallet note + the stamp thunk).

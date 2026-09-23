# Sound list, provenance and the audit (2026-09-23)

Every sound the game plays goes through the `Sfx` autoload (`globals/sfx.gd`): a
name → file map (`LIB`), a pool of one-shot players, named loops and the music
player. Gameplay moments are wired on `EventBus` inside `Sfx._connect_events()`;
UI moments call `Sfx.play("name")` directly.

Press **F7** in a debug build for the Sound Review panel: every sound below with
a Play button, a 1–5 rating and a note. Ratings save to
`user://playtest/sound_ratings.json`; "Copy report" puts a markdown table on the
clipboard.

## How the sounds were made (four generations)

| Gen | When | Technique | Files | Tell-tale |
|---|---|---|---|---|
| 1 | 2026-09-07/08 | Sample-library one-shots dropped in by hand (no script in the repo) | door_chime, coins, happy, unhappy, phone_order, pin_in, pin_out, fabric_unroll, drawer, chalk, tape, snip, scissors_run, sew_machine, sew_machine_loop, menu_open, page_turn, error, stitch | 48 kHz stereo; wildly uneven loudness (tape peaks at −29 dB, fabric_unroll at −0.6 dB); up to 1.5 s of trailing silence; very bright |
| 2 | 2026-09-08 | Stable Audio Open 1.0 on the local GPU, trimmed and normalised by hand | new_order_ping, order_complete, day_start, day_end, ambience_loop, ui_*, footsteps, pickup, putdown, cloth_rustle (the last four groups were replaced the same day, see gen 2b) | 44.1 kHz; realistic foley; abrupt tails (the file ends while still −23 dB loud, so it clicks) |
| 2b | 2026-09-08 | Python "cute plink" synth (sine + octave, exp decay), not in the repo | ui_move, ui_confirm, ui_cancel, footstep_wood_1-3, footstep_rug, pickup, putdown | 44.1 kHz mono, peak −0.9 dB, no end fade (tail at −16 dB: a click on every step) |
| 3 | 2026-09-18 → 22 | **GDScript sound design**: `tools/audio_synth.gd` + one `build_*_audio.gd` per group, deterministic seeds | curtain_*, scissors_glide_loop, sew_stitch_*, sew_tap, steam_hiss, coffee_pour, iron_glide_loop, scorch, grinder_loop, tamp, pour_loop, juice_*, reno_scoop/tumble/whip/creak/clatter/tick/done/open, reno_poof, sign_* | 44.1 kHz mono, every file peaks at −1.4 dB, 1 ms/6 ms end fades, layered voices, filtered noise, notes on a scale |
| 3b | 2026-09-22 | Stable Audio Open, three takes per sound auditioned, best kept (`.dev/reno_audio_alts/`) | reno_knock, reno_hammer, reno_saw, reno_drill, reno_roller, reno_reveal | −3 dB peak, clean fades |

**2026-09-23 rebuild (after the first F7 review, `SFX_REVIEW_2026-09-23.md`):**
every sound rated below 4 moved to generation 3. New builders
`tools/build_world_audio.gd` (new_order_ping, footsteps, door_open/close,
cloth_rustle, error, happy, phone_order, tape) and `tools/build_mentor_audio.gd`
(mentor_blip_1-5, a mumble instead of a beep); retuned recipes in the cut,
sewing, comfort, juice, renovation, curtain and menu builders (scissors_glide,
sew_stitch_good, pour_loop, juice_stamp, reno_tick, reno_open, curtain_*,
sign_drop/hoist). Every sibling those builders also make stayed byte-identical.
Still gen 1/2 and awaiting a rating: door_chime, day_start, day_end,
ambience_loop, and the 4-rated samples (coins, pins, drawer, chalk, snip,
scissors_run, page_turn, order_complete, unhappy).

Why generation 3 sounds better, in one paragraph: it is *designed*, not
*found*. Each sound is a few named voices (a filtered noise band for cloth or
air, a sine "knock" for wood, a mallet tone with an octave shimmer for sparkle)
placed in time on purpose, with envelopes that never end mid-sample, all
normalised to the same peak and rendered at the same rate. The gen 1 and gen 2
files are whatever a library or the model gave back: different loudness per
file, real-world brightness (bells and coins sit at 5–10 kHz, which is exactly
where ears hurt), and hand-trims that stop while the sound is still ringing.
Nothing about the game changed between the two; the recipe did.

## Measured trouble (from `python tools/audit_audio.py`)

Bright = share of energy above 4 kHz. Cut = level in the last 5 ms (anything
above about −40 dB clicks when it stops).

| Sound | Fires when | Problem | Numbers |
|---|---|---|---|
| new_order_ping | the customer is sent back for their suit (`order_due`) | 2 s long, most of it above 5 kHz, chopped off | bright 0.57, cut −23 dB |
| door_chime | customer arrives at the desk (`customer_waiting`), and a delivery box lands | a real bell, 95 % of its energy 2–10 kHz; fires right after the ping | bright 0.46, 48 kHz stereo |
| coins | payment on fulfilment | sizzle: 91 % of its energy above 4 kHz | bright 0.91 |
| snip, scissors_run, chalk | cutting bench, worktable menu | same sizzle; scissors_run and chalk are also nearly inaudible | bright 0.92 / 0.87 / 0.80, peaks −8 / −11 / −26 dB |
| order_complete | suit finished | sub-thump plus bell, chopped off | 61 % below 100 Hz, cut −28 dB |
| ambience_loop | from boot | 98 % of its energy is below 100 Hz: a rumble, not a room | 5 MB for 30 s |
| pickup, putdown, ui_move/confirm/cancel, footsteps | every step and menu move | no end fade, so each one clicks off; pickup and putdown are also squashed (crest 8 dB) | cut −16 … −21 dB |
| tape, stitch, chalk, phone_order | menus, hand stitch, phone | far quieter than everything else | peaks −29 / −17 / −26 / −14 dB |
| drawer, pin_out, stitch, phone_order, menu_open | | 0.8–1.6 s of trailing silence (wasted pool voices, late-feeling loops) | trail 934 / 1366 / 1558 / 846 / 787 ms |
| complete, ruined, slip | nothing | orphans from the retired `build_audio.gd`, not in `LIB` | 22 kHz |

Every gen 3 file measured clean: same peak, no clipping, no clicks, brightness
under 0.2 except the deliberate sparkle in `sign_sew` and `scorch`.

## Plan

1. **Rate first.** F7, play everything, rate 1–5, note "harsh / loud / quiet /
   wrong / boring". Copy the report into the next session. The ratings decide
   the order below; the audit already predicts the 1s.
2. **One loudness law.** A `tools/master_audio.gd` pass that reads every
   file in `LIB`, trims leading and trailing silence, applies a 6 ms end fade,
   normalises to −1.4 dB peak (gen 3's level) with a per-role trim table
   (footsteps and UI −6, stingers 0, loops −3), and writes 44.1 kHz mono. Run
   it once over gen 1/2 files; the gen 3 builders already comply. This alone
   removes the clicks and the "why is the tape silent" problem.
3. **Redo the harsh cues in gen 3 style**, one builder `tools/build_world_audio.gd`:
   - `new_order_ping` → two soft wooden xylophone notes (G5→C6), 0.6 s, no noise.
   - `door_chime` → a small brass shop bell: one strike, partials tuned, low-passed at 6 kHz, 0.8 s; positional on the door like door_open.
   - `coins` → three muffled coin ticks on felt (filtered noise bursts over a 2 kHz body), not a cash-register cymbal.
   - `order_complete` → the `reno_done` recipe (three ascending mallet notes) in a different key so the two do not read the same.
   - `day_start` / `day_end` → keep if rated 3+; otherwise a two-note sunrise / three-note wind-down from the same mallet voice.
   - `happy` / `unhappy` → short two-note up / down mallet phrases, so customer mood and juice share one instrument.
   - `ambience_loop` → drop it, or rebuild as a real room tone: pink noise low-passed at 400 Hz at −35 dB plus a slow wall-clock tick.
   - `pickup`, `putdown`, `ui_*`, footsteps → port the 2b plink into GDScript with the 6 ms fade, so they stop clicking and live with the other builders.
   - `snip`, `scissors_run`, `chalk`, `tape`, `stitch` → rebuild with the cut/sewing recipes already in the repo (`build_cut_audio.gd`, `build_sewing_audio.gd`).
4. **Retire what nothing plays:** delete `complete.wav`, `ruined.wav`,
   `slip.wav` and `tools/build_audio.gd`; move the 3b alternates out of `.dev/`
   or delete them once the reno sounds are rated.
5. **Keep Stable Audio for what it is good at:** textured takes such as the
   builders' tools and the sewing-machine recording. Everything that is a cue
   (a ping, a chime, a coin, a mood) is a tuned instrument note, built in code.
6. **Mix rules to write into `sfx.gd`:** stingers never stack (`play_single`),
   the door bell and the pickup ping never fire within the same second (the
   ping already tells you the customer is coming), and every world stinger
   ducks the music by 3 dB for its length.

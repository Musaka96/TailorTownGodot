# Playtest report

`PlayerForm` (globals/player_form.gd) records how a playthrough is going and writes it to
one plain-text file a tester can send back. It only records. Nothing in it changes the game.

## For testers

1. Play as normal. The report updates itself every minute, at closing time, when you
   save, and when you quit.
2. When you're done, press **Esc → Playtest Report**.
3. Either press **Copy to Clipboard** and paste it into a message, or press
   **Open Folder** and send the `report_….txt` file.

The file lives in `%APPDATA%\Godot\app_userdata\TailorTown\playtest\` on Windows. There is
one file per game started from New Game; loading that save later keeps adding to it.

## What's in it

- **Header**: run id, session count (each load of the save is a new session), build,
  OS, graphics card, window size, and where the game stands now.
- **How it's going**: four readings over the last 3 played days, from -1 (easy) to +1
  (struggling). "Easy" is -0.4 or below, "struggling" is +0.4 or above.

  | Reading | Goes up (struggling) with | Goes down (easy) with |
  |---|---|---|
  | Time | late orders, lost orders (×2), share of open time swamped (×1.5) | share of open time with nothing to make (×1.5) |
  | Craft | sewn piece quality under 0.8 (×3), paid under 95% of the quote (×2) | quality and pay above those |
  | Money | lowest cash under $250 | cash growing (every $600 is -1). Plenty of cash alone only reaches -0.3 |
  | Clients | more than 1.6 designs shown at the mirror per yes (×1.2) | fewer |

  These weights are first guesses. Tune them once real reports come in.
- **Day by day**: one row per shop day. Open minutes, idle and swamped share, walk-ins
  and what you answered (took, booked, referred, declined), designs shown and accepted,
  suits paid for, late, lost and walk-outs, share of quotes paid, average sewn quality,
  cloth bought (metres and dollars), cash at opening, closing and lowest, reputation
  change, average FPS.
- **What happened**: a timestamped line for each greeting (with the brief and any
  stated taste), each mirror verdict with the customer's first objection, each order
  with its suit, pickups, late and lost orders, and cloth bought. Only the last 800
  lines are kept.
- **CSV**: the day table again, comma-separated, for a spreadsheet.

Tutorial time is counted separately and left out of the readings.

## Signals it listens to

`day_began`, `shift_ended`, `customer_answered` (new: the greeting choice),
`design_judged` (new: the mirror verdict and first reason), `order_created`,
`order_fulfilled`, `order_late`, `order_expired` (with `order.ignored` meaning a
walk-out), `order_placed` (cloth), `piece_sewn`. It also samples the shift each frame
for idle, swamped and "fully booked" time.

State is saved under `player_form` in the save file. New Game starts a fresh run.

Test: `tools/test_player_form.gd`.

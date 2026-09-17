# TailorTown — Customers & the Front Desk

> **Status: BUILT (2026-09-17).** How walk-in customers are paced, and how you can say no.
> It serves the economy pillars in [ECONOMY.md](ECONOMY.md): cozy, never a trap, and
> thinking ahead is rewarded. Code: `globals/front_desk.gd` (autoload **FrontDesk**).
> Tests: `tools/test_front_desk.gd`.

## Why a director
Early on, a full suit is about 4 real minutes of work, and a shift is about 5. A timer that
drops shoppers in every few seconds buries a new player. Like Left 4 Dead's AI Director,
the front desk watches **how busy you are** and paces arrivals to match.

## Workload
- `backlog_minutes()` is the work left on open orders: ~1.4 min per unmade part (less with
  Master Shears / Industrial Motor), plus 0.3 min to assemble.
- `load_factor()` = backlog ÷ two shifts. 0 is idle, and **≥ 1.0 is swamped** (no new walk-ins).

## The daily plan (made when the shop opens)
| Stage | When | Walk-ins |
|---|---|---|
| Opening week | days 1–3 at reputation tier 0 | 1 |
| Growing | tiers 0–2 | 1, or 2 if load < 0.4 |
| Established | tier 3+ | 2, or 3 if load < 0.5 |

- **Newspaper event:** +1 walk-in while an event's window covers today. A message
  announces it, and those customers lean toward the event's occasion.
- **Swamped at opening:** 0 walk-ins.
- **Arrival times:** spread over three windows (morning 5–30%, midday 40–55%, afternoon
  62–86% of the shift).
- **The opening bell:** if the shop opens with an empty order book there is nothing to do
  but wait, so the first walk-in is pulled forward to 1–5% of the shift instead of anywhere
  in the morning window. That is what stops day one — especially after skipping the
  tutorial — starting with a minute of empty shop.
- **Holds:** no walk-in while the **Fully Booked** sign is up, while a greeting or fitting
  is on screen, for 6% of the shift after a suit is handed over, or while swamped.
- **Safety net:** broke (< $150) with no open orders means a customer comes right away.
- **Regulars** are 1.5× as likely on quiet days (load < 0.3).
- **The rival's favour:** on a quiet afternoon, once a day, if you've referred someone to
  Pinch & Pleat, they send a customer back.

## One at a time
The shop serves exactly one customer from the greeting to the goodbye. While someone holds
that slot — walking in, waiting to be greeted, on their way to the mirror, at it, or on
their way back out — the front desk sends nobody else in, the tutorial won't poof anyone
in, and the F3 debug "call a customer" does nothing. If a second customer ever does end up
inside, `route_to_mirror` refuses them: they go back to waiting to be greeted rather than
sharing the mirror. Returning customers collecting a finished order are separate — they
wait by the door and never use the mirror.

The `CustomerManager` runs two independent clocks: `arrival_interval` (3 s) asks the front
desk whether a real customer is due, and `spawn_interval` (9 s) sends a pedestrian past the
window. They are separate so street dressing hitting `max_alive` can never hold up a
customer who is actually due.

## Due days you can meet
`suggest_due_day(parts, rush)` works out how long the queue (backlog + this order) takes,
counting what's left of today's shift, then adds slack: +2 in the opening week, +1 after.
The result is capped at 1–5 days. Rush orders are due tomorrow.

## Client types
| Type | From | Effect |
|---|---|---|
| **Regular ★N** | `Clientele` | Same face; budget +10% per loyalty (see ECONOMY) |
| **Rush** | 15% growing / 20% established, only when load < 0.6 | Due tomorrow, pays **+30%** (agreed in the quote) |
| **Picky** | 10% / 15% | Budget −15%; judged 0.2 harsher for full pay, **double tips** |
| **Appointment** | Booked earlier | Arrives early on the booked day, even with the sign up |
| **Referral** | Pinch & Pleat's favour | A normal brief, "sent over by …" |

## Saying no (the greeting bubble)
| Choice | Result |
|---|---|
| **Take the fitting** | Sent to the mirror (the only choice in the tutorial) |
| **Book them for day N** | `next_free_day()`: after the backlog clears, max 2 bookings per day. They return that morning and are remembered by Clientele |
| **Send them to Pinch & Pleat** | +1 reputation, +1 rival goodwill (a favour later) |
| **Be honest: I can't make that yet** | Shown when the brief needs cloth no unlocked supplier stocks, or even the cheapest suitable suit is over budget. **+2 reputation** |
| **Politely decline** | Nothing, unless they're a regular on a quiet day (−1 loyalty). Never costs money |
| **Esc: later** | They keep waiting |

**Fully Booked sign:** the third card on the phone hub. While it's up, a burgundy badge sits
under the reputation patch and a stamp shows on the orders board. Walk-ins stop, but
appointments and pickups still come.

**Order-book calendar:** the orders board (O) shows the next 5 days: pickups due (coloured
red / amber / green like the tickets) and booked fittings.

## Tunables (in `front_desk.gd`)
| Setting | Value |
|---|---|
| `PART_MINUTES` | 1.4 |
| `BREATHER` | 0.06 |
| `WINDOWS` | three arrival windows (see above) |
| `SWAMPED` | 1.0 |
| `BROKE` | 150 |
| `RUSH_CHANCE` | 0 / 0.15 / 0.2 |
| `PICKY_CHANCE` | 0 / 0.1 / 0.15 |
| `RUSH_BONUS` | 0.3 |
| `MAX_APPOINTMENTS_PER_DAY` | 2 |
| `HONEST_REP` | 2 |
| `OPENING_BELL` | 0.01 – 0.05 of the shift |

## Ideas not built yet
- A visible door sign prop.
- Haggling.
- Rush orders you can counter-offer ("the day after tomorrow?").
- Named rival shop visits.

## Sources
- [Left 4 Dead Director](https://left4dead.fandom.com/wiki/The_Director)
- [PlateUp! daily operations](https://wiki.plateupgame.com/gameplay/DailyOperations)
- [Cook, Serve, Delicious!](https://cookservedelicious.fandom.com/wiki/How_to_play_guide_for_Cook,_Serve,_Delicious)
- [Two Point Hospital patient flow](https://steamcommunity.com/app/535930/discussions/0/2590022385654728302/)
- [Travellers Rest reputation](https://travellers-rest.fandom.com/wiki/Reputation)
- [Recettear haggling](https://recettear.fandom.com/wiki/Haggling)
- [Game Dev Tycoon contracts](https://gamedevtycoon.fandom.com/wiki/Contracts)

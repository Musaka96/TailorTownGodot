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

## When the shop stands idle
If there is nothing left to make (every order is made and waiting to be collected, or
there are none) and nobody has come in for `IDLE_WAIT` (8% of the shift, about half a
minute), the next planned walk-in is sent now instead of at its time. If the day's plan
is used up, one extra walk-in comes, once a day, unless it is past `LAST_CALL` (80% of
the shift). Opening week plans two walk-ins a day while the bench is under
`OPENING_ROOM` load, one otherwise.

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
| **Regular ★N** | `Clientele` | Same face (the saved look, `face_style` included: their cut-paper preset, see `FaceCast`); budget +10% per loyalty (see ECONOMY) |
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

## Opening and closing: the door sign
The day has three phases (`Shift.Phase`), and the OPEN / CLOSED sign just inside the door
(`scenes/world/door_sign.gd`, built in code — no map edit) moves between them:

| Phase | What's happening | Flip the sign to… |
|---|---|---|
| **Morning** | The day has dawned (`EventBus.day_began`): the day's edition is printed and the pot is refilled. The clock waits at the opening hour, the benches work — prep time. No customers, and no paper yet: the boy's round reaches the shop a while after the sign is flipped. | **open** the shop (`Shift.open_shop()` → `shift_started`) |
| **Open** | The clock runs; walk-ins, appointments and collectors arrive. | **close early** and finish the day. It asks first (flip again within 5 s); anyone still due today calls first thing tomorrow. |
| **After hours** | The bell has rung: no new shoppers, the work stations refuse. | **lock up** and finish the day. |

Finishing the day plays the night card and dawns the next morning. A save made in the
morning loads back into the morning; a direct boot of `main.tscn` (tests, F5) opens at once.

## When the suit isn't ready
A collector whose suit isn't finished no longer turns on his heel. He waits at the counter
with a patience meter overhead (`CustomerWait`, `collector_patience_s`; regulars ×1.5):

- **Finish the suit while he waits** → it becomes an ordinary collection.
- **Speak to him** → the bubble offers *Apologise*:
  - a **regular** always agrees to call tomorrow, and no standing is lost;
  - a **stranger** agrees `reschedule_chance` of the time (the usual late penalty: part
    pay, −`late_rep_loss`); otherwise the order is lost, softened to −`apologised_rep_loss`;
  - **never twice** for one order, and **never past a city event** the suit is for — those
    are simply lost (softened).
- **Leave him standing** until the meter empties → he walks out: the order is lost and it
  costs `expired_rep_loss` **plus** `ignored_rep_loss`.

## A coffee for the customer
Once the coffee machine is in (and the pot isn't empty), both bubbles gain *Offer them a
coffee first*. You make the cup on the spot — the same minigame, one of the day's cups.

- **Greeting a new customer:** the welcome is remembered on their order (`SuitOrder.coffee`)
  as a small thank-you on the bill (`coffee_tip_share` × cup quality) and earns
  `coffee_rep` standing. Greet them again afterwards to carry on.
- **A waiting collector:** patience starts over and drains at `coffee_patience_drain`, and a
  stranger is `coffee_goodwill` likelier to agree to call tomorrow. One cup per wait.

## Pitching to passers-by
Every stroller on the street can be pitched to, once (`StreetPitch`): the player calls out
a line, they stop and answer, and sometimes they turn for the door as a walk-in (tagged
"Won over by your pitch on the street"). The odds are `pitch_base_chance` +
`pitch_tier_bonus` per reputation tier. It can't make more work than the shop can take: no
pitching while someone is being served, Fully Booked is up, or the book is swamped — and a
win uses one of the day's planned walk-ins (`FrontDesk.claim_walk_in`).

## Taste
Why: solid navy passes 9 of the 16 briefs, and a new shop starts with exactly navy
worsted and white cotton, so every early customer ended up in the same suit. Taste gives
customers reasons to say no to it, without forcing the player to buy cloth they can't
afford. Designed with the owner on 2026-09-22 (a simulator of the rules was used to tune
them). Code: `data/scripts/suit_taste.gd` (shared rules), `entities/customer/brief_director.gd`
(shapes each walk-in after `FrontDesk.season_brief`), `Clientele` (memory), the mirror
(`CustomerPreference.evaluate`). Test: `tools/test_suit_taste.gd`.

- **Quiet dislike.** A newcomer with no stated dislike may keep one to themselves: a
  colour or a pattern, and a cloth too from tier `cloth_dislike_from_tier`. It's taken
  from what their brief allows and always leaves a suit. They say it the first time you
  show it at the mirror ("Navy again? Half my wardrobe is navy."). After that the design
  screen shows it. Chance by tier: `quiet_dislike_by_tier` (20% / 35% / 35% / 45% / 45%).
  It leans on the safe answers (navy, charcoal, plain, worsted) by `safe_lean_by_tier`,
  which is ×1 at tier 0 so a new shop's starter roll is rarely the one hit.
- **Regulars remember.** The first dislike a customer shows (stated or quiet) is kept for
  good and comes back on every visit, but only while the new brief still leaves them a
  suit. They also won't take a colour and pattern they already bought from you ("I've
  got that one from you already. Something new."). The occasion and style are new each
  visit.
- **Seen about town.** Clientele logs each collected suit's jacket colour and day. A
  newcomer with no dislike of their own may turn down the colour most worn in the last
  `town_window_days` (5), counting only suits collected on an earlier day. It needs
  `town_min_worn` (2) of one colour, then `town_step` (20%) per suit past the first, up
  to `town_cap` (50%). It's said up front at the counter ("I keep seeing your navy about
  town. Something else."). It isn't a personal taste, so a regular doesn't keep it.
- **Cash guard (always on).** A new quiet dislike or town remark is dropped if the shelf
  can't serve the brief and the cheapest suitable cut (one suit's worth, 4 m) would leave
  less than `taste_cash_reserve` (100) in the till. Broke shops still get customers, just
  not pickier ones.
- **Fresh-cloth nudge (opening week).** At tier 0, days 1 to `nudge_days` (3), a walk-in
  whose brief the shelf could serve has a `nudge_chance` (35%) of being rerolled, or
  `nudge_after_shelf` (75%) right after an order made from shelf cloth. It keeps trying
  new occasions and styles until the shelf can't serve the brief but an affordable cut
  can, and the budget covers it. If none turns up, the customer stays as they were.
  Appointments, newspaper-event briefs and the tutorial are never nudged.
- **`brief_feasible`** now finds the cheapest suit the customer would actually take
  (after dislikes and past suits) from cloth an unlocked supplier sells.

All numbers are in `GameConfig` → Economy → Customer taste.

## Ideas not built yet
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

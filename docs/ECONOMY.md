# TailorTown — Economy Pillars

> **Status: ADOPTED (2026-09-17): Option B (cloth + craft) with reputation-scaled budgets.**
> The pillars are meant to be stable. The numbers are the first tuning pass and will move
> after playtesting. Tune them in `data/game_config.tres` (Economy / Orders groups), not
> in code. See §8 for what's built and where.

## 1. The feel we want (pillars)

1. **Cozy, never a trap.** No bankruptcy, no compounding debt, no fail state. The worst
   case of bad play is being *slower*, never *stuck*. The core loop (order cloth → make →
   sell) always works, even at $0.
2. **Thinking is rewarded, carelessness costs a little.** Measuring precisely, ordering
   only what you need and matching the brief make money flow *easily*. Waste, rushed
   work and mismatched designs quietly shave margins — they never wipe you out.
3. **Rewards over punishments.** A wide "good enough" band pays normally; a narrow
   "excellent" band pays *bonuses* (tips, extra reputation). Mistakes lose a bonus or a
   small slice of margin, not the whole job.
4. **Every price is legible in "days".** Players (and we) judge prices against their own
   income: an upgrade costs "about two good days", a luxury "about a week".
5. **Scarcity arrives as an opportunity, not a threat.** The first "I have to be careful"
   moment is *wanting* something nice (an upgrade, a premium supplier) — never fear of
   going broke.
6. **Two gates, never both at once.** Reputation unlocks access, money buys it. Unlock
   access *before* the player can quite afford it, so the tension is "save up", not
   "I can't even see it".
7. **Money stays meaningful late.** As income grows, prices and sinks grow with it
   (premium cloth, bigger machines, decoration, expansion), keeping sources ≈ 1.1–1.3×
   sinks at every stage.

## 2. Research summary

**Economy theory** (Machinations, Lostgarden value chains, Game Developer "Math of Idle
Games", GMTK, StraySpark):
- Model *faucets* (payouts, tips) vs *sinks* (cloth, upgrades, decor). Target
  **faucets ≈ 1.1–1.3× sinks per progression tier** — enough surplus to feel momentum.
- Price purchases as **earnings-rate × value-time** ("N days of typical profit").
- Abundance first: the first session teaches the loop; buffer covers 2–3 orders plus a
  bad cut. First "I'm rich" moment ≈ order 3–5.
- Reputation → better suppliers → more profit → more reputation is a positive loop;
  damp it gently (premium cloth costs more, bigger upgrades cost geometrically more),
  don't punish success.
- Late game needs **non-recoupable sinks** (decoration, showcase, expansion) that scale
  with income.
- Pitfalls: grindy mid-game from flat exponential curves, spreadsheet-only tuning,
  prices you can't read against your income.

**Comparable games** (see sources at the end):
- **Stardew Valley**: 500g start, no debt, no deadlines. Tool upgrades 2k→25k, which is
  steep but purely additive: poor just means slow.
- **Animal Crossing**: the cozy-debt gold standard. 0% interest, no deadline.
- **Travellers Rest**: trend-matched ingredients give +10–15% price and bonus
  reputation. Reputation directly gates best-margin recipes.
- **Moonlighter / Good Pizza, Great Pizza**: precision is rewarded with a "perfect price"
  or accuracy-scaled tips rather than harsh penalties.
- **Recettear**: per-customer reputation raises that customer's *budget* (the loyalty loop).
- **Tailor Simulator**: decorating the shop feeds reputation.
- **Dressmaker** (closest analog): budget-bounded designs, reputation in the newspaper,
  higher-tier customers with progression. Its "restart if broke" is what to avoid.
- Margins in the genre run ~65% (Wylde Flowers) to 3× early and 15× late (Potionomics).
  Cozy titles keep early margins healthy and let late margins grow through premium tiers.

## 3. Where we are today (audit, 2026-09-17)

| Lever | Current | Ref |
|---|---|---|
| Starting money | $500 | `data/scripts/game_config.gd` |
| Cloth | $16–30/m by fabric + $0–7/m pattern | `pricing.gd`, `game_config.tres` |
| Suit price | quote = 2.4 × cloth cost (M sizes), must be ≤ budget | `pricing.gd suit_quote` |
| Budgets | $320–500 random | `customer_preference.gd` |
| Payout | price × avg match × avg quality, on collection | `suit_order.gd payout` |
| Late | order forfeited (no pay), −12 reputation | `order_manager.gd` |
| Rolls | min 4 m, step 2 m, no bulk discount, no delivery fee | `phone_order.gd` |
| Upgrades | $120–320 (tiers 1–2) | `upgrades.gd` |
| Vendors | tier-gated fabric lists, **no price difference** | `upgrades.gd` |
| Reputation | tiers at 0/40/120/260/480; +5..+30 per order, −12 expired | `reputation.gd` |
| Sinks | cloth and upgrades only (trash = pure loss) | — |

Cheapest suit ≈ $74 cloth → $177 quote → ~$100 profit (58%) when bought in bulk. A
first-time 4 m minimum order eats most of that. Early on about 1 full suit fits in a shift.

**Problems to fix regardless of model:**
1. **Two different "days".** Order deadlines tick on `seconds_per_day` = 120 s, but a shift
   lasts 300 s, so a "1 day" order can expire mid-shift. Deadlines should count **shop
   days** (shift ends).
2. **Size isn't priced.** The worktable needs more cloth for L/XL, but the quote ignores size.
3. **Premium vendors aren't premium.** Same price everywhere. There's no reason to prefer
   them beyond fabric choice.
4. **The 4 m minimum roll** guarantees waste for single parts, with no reward for planning bulk.
5. **Upgrades are very cheap** ($120 ≈ one suit) relative to income, so saving never matters.
6. **Config gaps.** `fabric_price_per_m` covers only 5 of 8 fabrics. Debug budgets differ
   from live ones.
7. **No late-game sink.**

## 4. Pricing model options

All three keep pillars 1–7. They differ in *what the customer pays for*.

### Option A: Cost-plus markup (evolve what we have)
`price = cloth cost × markup(tier)`, markup 2.2 → 3.0 by reputation, capped by budget.
Payout × match × quality, plus a tip for excellent work.
- **+** Smallest change. Easy to read ("cloth times ~2.5").
- **−** Expensive cloth is automatically more profit, so the "choose wisely" tension is
  weak. Waste isn't visible in the price.

### Option B: Cloth + craftsmanship fee (how real tailors quote) ⭐ recommended
`price = cloth cost (passed through, +small handling %) + labour fee per part × tier
multiplier`, bounded by budget.
- **Labour fee (size M):** jacket $90, pants $50, shirt $40. Scaled by size (the same
  factor as cloth) and by the reputation multiplier (1.0 / 1.15 / 1.3 / 1.5 / 1.75).
- Cloth is reimbursed at **list price for the metres the part needs**, so **waste is
  your cost**. Measure precisely and you keep the whole fee. Over-order or over-cut and
  you pay the difference. This is exactly the "think and it flows" loop.
- Premium cloth carries a **handling margin** (Harrow 0%, Northern Mill +10%, Savile
  Silk +20%). Premium suppliers are worth unlocking without making cheap cloth useless.
- **+** Most legible and most "tailor-y". Skill (the fee) and planning (waste) are two
  clean profit levers. Scales with reputation without inflating cloth.
- **−** Needs the quote UI to show "cloth $X + craft $Y".

### Option C: Budget-driven ("what the customer can pay")
The customer's budget *is* the ceiling price. You design to fit it, and profit =
payout − the cloth you bought. Budgets scale with reputation tier.
- **+** Very game-y trade-off: cheap cloth gives more profit but worse match on high-end briefs.
- **−** Price is opaque (is $400 good?). Encourages always designing to the cap.
  Riskier for the cozy feel.

**Recommendation: B, with C's budgets.** Price by cloth + craft (B). Customer budgets
scale with reputation (C) and act only as a *ceiling* the design must fit, which the
suit builder already flags.

## 5. Proposed first tuning pass (for Option B)

**Reference income** (what prices are judged against). One "good day" at each tier:

| Tier (rep) | Suits/day (typical) | Profit/suit | ≈ Profit/day |
|---|---|---|---|
| Unknown (0) | 1 | ~$180 | **$180** |
| Apprentice (40) | 1–2 | ~$210 | **$300** |
| Local Name (120) | 2 | ~$240 | **$480** |
| City Favourite (260) | 2–3 | ~$290 | **$700** |
| Master (480) | 3 | ~$340 | **$1,000** |

**Customer budgets (ceiling):** $300–450 → $400–600 → $500–800 → $700–1,100 → $900–1,500.

**Cloth ordering**
- Minimum roll **2 m**, step 1 m (single parts don't force waste).
- Bulk discount: **−10% per metre at 10 m, −20% at 20 m**. Planning ahead is cheaper.
- Delivery stays free and instant. Keep it cozy.

**Upgrades priced in days of profit, at the tier where they unlock**

| Upgrade | Tier | Days | Price |
|---|---|---|---|
| Sharp Scissors / Oiled Machine (sprint) | 1 | ~1.5 | $450 each |
| Extra Rack Hooks | 1 | ~1 | $300 |
| Bulk Orders (bigger rolls) | 2 | ~2 | $950 |
| Master Shears / Industrial Machine (+30%) | 2 | ~3 | $1,400 each |
| *Future:* Apprentice, shop expansion | 3–4 | 5–10 | $3,500–10,000 |
| *Future:* decoration (small reputation boost) | any | 0.3–2 | $60–1,500 |

**Rewards and penalties**
- **Payout:** full price if match × quality ≥ 0.6 (the "good enough" band). Between 0.4
  and 0.6 it scales down gently. **Tip up to +25%** from 0.9 (excellent) to a perfect 1.0.
  **Trend-matched suits (the newspaper) earn extra reputation only, not money.** This was
  the owner's decision.
- **Waste** is paid only through cloth (Option B), so it's never a separate fine.
- **Late orders:** the customer waits one extra day, and the suit is paid at 75% with
  −6 reputation. They leave only after the grace day (−12 then). No money is ever taken.
- **Soft floor:** if cash < cheapest 2 m roll, the phone offers **"On account"**, a free
  bolt repaid automatically from the next collection. 0% interest, no deadline.

**Early-game script (first ~3 days)**
- Start with **$500 plus one free starter bolt** (tutorial cloth).
- Day 1 is abundant: the tutorial suit alone pays for the next bolt with change left over.
- Day 2–3: first rack/sprint upgrade becomes affordable around rep 40. This is the first
  "save for it" moment.
- Premium supplier (Northern Mill) unlocks at rep 40 but its cloth costs ~15% more,
  giving the first "is it worth it?" choice.

**Health checks while tuning**
- Days to afford the next unlocked upgrade: **1–3**, never >5 for functional upgrades.
- Cash after a careful day should rise. After a sloppy day (≈30% waste, one late order)
  it should still be **≥ flat**, never deeply negative.
- Sources/sinks per tier: 1.1–1.3.

## 6. Other gameplay ideas from research

| Idea | Why it fits | Size |
|---|---|---|
| **Perfect-fit tip** (done via the excellent band) | Rewards careful cutting, sewing and matching; Good Pizza / Moonlighter pattern | S |
| **Trend bonus: reputation only** (decided: no price bump) | The newspaper already exists | S |
| **Live margin readout in the suit builder** ("cloth $X + craft $Y = $Z") | Teaches the economy without a tutorial wall | S |
| **Offcut bin**: scraps ≥ 0.5 m become ties / pocket squares (small add-ons) | Turns waste into a mini-reward instead of pure loss | M |
| **Regular customers**: loyalty raises their budget, standing orders | Recettear's loop; gives faces to the economy | M |
| **Event bulk orders** (wedding party: 3 suits, one theme) | Newspaper "coming up" pays off; planning cloth in bulk matters | M |
| **Market day / travelling cloth merchant**: weekly discounted premium bolts | Rewards planning; gives the phone a rhythm | S–M |
| **Shop decoration** raises reputation gain / customer tier | Late sink with meaning (Tailor Simulator) | M |
| **"On account" cloth** (cozy credit) | Soft floor with no fail state (Animal Crossing) | S |
| **Apprentice** auto-cuts standard lengths | Late sink + removes repetition | L |
| **Coffee focus buff** (already on the roadmap) | A small spend that improves quality | S–M |

## 7. Sources

- Machinations: [game economy inflation](https://machinations.io/articles/what-is-game-economy-inflation-how-to-foresee-it-and-how-to-overcome-it-in-your-game-design)
- Lostgarden: [value chains](https://lostgarden.com/2021/12/12/value-chains/)
- Game Developer: [The math of idle games](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i)
- Game Balance Concepts: [cost curves](https://gamebalanceconcepts.wordpress.com/2010/07/21/level-3-transitive-mechanics-and-cost-curves/)
- GMTK: [how video game economies are designed](https://gmtk.substack.com/p/how-video-game-economies-are-designed)
- StraySpark: [economy balancing spreadsheets](https://www.strayspark.studio/blog/game-economy-balancing-spreadsheets)
- Wikis:
  - [Stardew Valley tools](https://stardewvalleywiki.com/Tools)
  - [Nookipedia home loan](https://nookipedia.com/wiki/Home_loan)
  - [Travellers Rest reputation](https://travellers-rest.fandom.com/wiki/Reputation)
  - [Moonlighter selling](https://moonlighter.fandom.com/wiki/Selling_and_Reactions)
  - [Recettear customer reputation](https://recettear.fandom.com/wiki/Customer_Reputation)
  - [Good Pizza, Great Pizza bankruptcy](https://good-pizza-great-pizza.fandom.com/wiki/Bankruptcy)
- Games:
  - [Dressmaker: how to play](https://dressmakergame.com/how-to-play)
  - [Tailor Simulator](https://tailorsimulator.com/)

## 8. What's built (2026-09-17)

| Piece | Where | Notes |
|---|---|---|
| Cloth + craft quote | `Pricing.quote_breakdown/suit_quote` | Cloth = metres (size M) × list × cheapest-supplier premium × (1 + `cloth_handling`). Craft = `craft_fee_*` × `craft_mult_by_tier`. |
| Live readout | `ui/suit_builder.gd` | "Cloth $X + Craft $Y = Quote $Z" against the budget. |
| Budgets by tier | `Pricing.random_budget`, `budget_min/max_by_tier` | Budget is a ceiling; the price is the quote. |
| Payout bands and tips | `Pricing.pay_share/tip_share`, `SuitOrder.payout_breakdown` | `full_pay_at`, `low_pay_at`, `tip_from`, `tip_max`. |
| Shop-day deadlines | `SuitOrder.due_day/arrive_at`, `OrderManager._process` | 1–4 days (`deadline_min/max_days`). The customer walks in partway through the due day's shift. The old real-time `seconds_per_day` is gone. |
| Grace day | `OrderManager.grant_grace`, `CustomerManager._on_collector_arrived` | First miss: back tomorrow, pays `late_pay`, −`late_rep_loss`. Second miss: expired, −`expired_rep_loss`. |
| Bolt pricing | `Pricing.roll_price` | Supplier `price_mult` (1.0 / 1.1 / 1.2), `bulk_10m/20m_discount`, rolls from `roll_min_m` in `roll_step_m`. |
| Market day | `Pricing.is_market_day/market_discount` | Every `market_day_every` days. Toast at opening; shown on the phone. |
| Cloth on account | `GameState.account_owed/buy_on_account/settle_account` | Only when broke, one bolt ≤ `account_limit`. Settled automatically at the next collection. |
| Free first bolt | `Tutorial.first_bolt_free` | The tutorial's order step. |
| Regular customers | `globals/clientele.gd` (autoload) | Remembers faces. Fulfilled +1 loyalty (max 5), expired −1. `regular_chance` of shoppers are regulars; budget × (1 + loyalty × `loyalty_budget_step`, cap `loyalty_budget_max`). Shown as "Name ★N". |
| Decoration hook | `ShopDecoration` (`scenes/world/shop_decoration.gd`), `Reputation.decor_bonus` | Attach to props; reputation gains × (1 + Σ bonus, cap +50%). **No shop to buy decor yet.** |
| Upgrade prices | `Upgrades.UPGRADES` | $300 / $450 / $950 / $1,400 per §5. |
| Tests | `tools/test_economy.gd` | Quotes, bands, bolts, account, deadlines, regulars. |

**Open / next:**
- A decoration shop.
- Offcut bin.
- Event bulk orders.
- A size for customers. Everyone is size M today, so size only changes how much cloth you use.
- Rebalance after real playtests against the §5 health checks.

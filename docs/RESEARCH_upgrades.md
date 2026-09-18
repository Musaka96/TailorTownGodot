# Research — upgrades for the bench games (and the rest of the shop)

Written 2026-09-18. Builds on `RESEARCH_cutting_minigame.md` (cutting v2 is the pick)
and `RESEARCH_sewing_minigame.md` ("Pedal & Guide" is the pick), and on the
`Upgrades` autoload (phone → Shop Upgrades, reputation tier gates, money buys).
The existing ids (`cut_sharp`, `cut_master`, `sew_oiled`, `sew_industrial`,
`rack_hooks`, `bulk_orders`) keep their ids so saves stay valid. Only their effects are
re-pointed at the new games.

## Rules for every upgrade

1. **Raise the floor, keep the ceiling.** Upgrades make a job faster, easier to read or
   more forgiving. 100% still needs skill. No upgrade grants "perfect" for free.
2. **Never required.** The unupgraded game can be finished and is fun (cozy pillar:
   worst case is *slower*, never *stuck*).
3. **You can see it and hear it.** Every purchase changes something on the bench:
   new shears art, a guide screwed to the machine plate, a deeper motor. You should
   *notice* you bought it the first time you sit down.
4. **Five kinds, one per axis.** Each station gets a bit of each, spread across tiers:
   - **Tempo:** faster (speed, glide, spin-up)
   - **Read:** easier to see what's coming (clearer lines, warnings)
   - **Control:** less fighting the material (drift, snapping, guides)
   - **Capability:** a new move or a skipped chore (fold, needle-down, auto-backstitch)
   - **Hands-off:** an apprentice does it at a fixed, average quality (late, optional)
5. **Forgiveness caps.** Band-widening upgrades stack to at most +50%, so the chalk
   line always means something.
6. **Accessibility is a setting, not a purchase.** A "Steady hand" option (wider bands,
   slower speeds) lives in Settings and is free. Upgrades are progression, not help
   locked behind money.

Tiers and prices follow ECONOMY.md ("an upgrade costs a few good days" at its tier):
T0 ≈ $150–250, T1 ≈ $300–500, T2 ≈ $900–1500, T3 ≈ $2.5–4k, T4 ≈ $5k+.

---

## Cutting table (v2 "Seam Allowance")

**Base game** (no upgrades): hold to push, steer, glide on straights (1.8×),
cloth drift by fabric, corners pivot on their own. ~12–14 s per piece.

| Tier | Upgrade | Kind | Effect | On the bench |
|---|---|---|---|---|
| T0 | **Pattern Weights** | Control | cloth drift −60% (the weights hold it flat) | brass weights on the cloth |
| T1 | **Sharp Scissors** *(existing `cut_sharp`)* | Tempo | hold Shift to push faster (riskier) | brighter blades |
| T1 | **Chalk Wheel** | Read | crisper chalk line and a small mark painted ahead of every curve and corner ("turn coming") | tick marks along the line |
| T2 | **Master Shears** *(existing `cut_master`)* | Tempo | base speed +30%, glide ceiling 1.8 → 2.3, glide builds twice as fast | long tailor's shears art |
| T2 | **Cut on the Fold** | Capability | symmetric pieces (shirt, jacket back) are folded: cut half the outline, then an unfold reveal. About −45% cutting | the folded cloth + reveal |
| T2 | **Pinking Shears** | Control | a "Rough" (too wide) stretch scores as "Good": the zig-zag edge can't fray, so a wide cut is harmless | zig-zag trail |
| T3 | **Rotary Cutter & Rule** | Capability | straight runs cut in one press (the rule snaps to the chalk). Only curves are steered | rotary wheel on straights |

*Addresses "too much to cut":* glide (built now) and Cut on the Fold / Rotary Cutter
later. The base game stays about 12 s; late upgrades take it to about 5–7 s, and the curves stay where the skill is.

---

## Sewing machine ("Pedal & Guide", revised with upgrades in mind)

**Base machine: a second-hand domestic machine.** Deliberately a bit rough, so
the upgrades feel great:

- **Pedal** (hold Space/F, or RT analog): the motor **spins up slowly** and has a
  modest top speed.
- **Guide** (A/D or stick): keep the cloth edge on the seam guide lines. The cloth drifts by fabric.
- **Corners:** stop with the needle on the chalk mark, then press **Pivot**. On the
  base machine the needle can stop *up*, so you nudge onto the mark before pivoting.
- **Pins:** tap **Pull** before the needle gets to each one.
- **Backstitch:** hold **Reverse** briefly at the start and end (bonus, not required).
- Uneven pedal → uneven stitches (quality); speed is only the risk you choose.

Each of those is a knob an upgrade can turn:

| Tier | Upgrade | Kind | Effect | On the bench |
|---|---|---|---|---|
| T0 | **Speed Dial** | Control | a slider that caps top speed, so you can floor the pedal safely (real machines have one) | a dial on the machine |
| T1 | **Oiled Machine** *(existing `sew_oiled`)* | Tempo | motor spins up 2× faster; Shift = top gear (riskier) | smoother motor sound |
| T1 | **Magnetic Seam Guide** | Control | a metal edge the cloth rides against: a gentle pull back onto the line, drift −50% | guide bar screwed to the plate |
| T1 | **Needle-Down Stop** | Capability | letting go always stops needle-down, and stopping within ~1 cm of a corner snaps onto it | "needle down" light |
| T2 | **Industrial Motor** *(existing `sew_industrial`)* | Tempo | top speed +30%, instant spin-up | deeper motor hum |
| T2 | **Walking Foot** | Control | feeds both layers evenly: slippery cloth (linen, mohair) stops wandering, eased seams sew themselves | a chunkier presser foot |
| T2 | **Knee Lifter** | Tempo | pivots take 0.15 s instead of 0.6 s (hands never leave the cloth) | knee lever under the table |
| T2 | **Sewing Clips** | Control | clips instead of pins: sewing over one no longer bends the needle, it costs only a small bit of quality | clips instead of pins |
| T3 | **Auto-Lock Button** | Capability | one tap does a perfect backstitch at each end | a button on the machine |
| T3 | **Industrial Machine** | Tempo + Control | replaces the machine: servo motor (top speed +60%, finer pedal response), needle-down and knee lift built in | a new machine model |
| T3 | **Overlocker** | Capability | a second machine that finishes edges: any "Rough" stretch from *cutting* is forgiven (cross-station link) | overlocker beside the machine |

Seam types (straight / curved / eased / topstitch) stay as variety. Upgrades change *how
hard* each is, not whether it exists (e.g. Walking Foot makes eased seams easy).

---

## The rest of the shop (small, cheap, felt)

| Station | Upgrade | Kind | Effect |
|---|---|---|---|
| Whole shop | **Workbench Lamp** (T1) | Read | the "perfect" band on every bench game +15%: you can simply *see* the chalk better |
| Whole shop | **Coffee Machine** (T1, consumable) | Control | a cup = the next 3 bench games get +20% bands and −50% drift (ECONOMY "coffee focus") |
| Whole shop | **Radio** (T0) | — | music; cozy only. Not every purchase needs a stat |
| Shelf | **Tall Shelving** (T1) | Capacity | more bolts stored |
| Shelf | **Bolt Labels** (T0) | Read | remaining metres shown on each bolt at a glance |
| Mannequin | **Second Mannequin** (T2) | Capacity | two suits in progress at once |
| Mannequin | **Pressing Iron** (T2) | Capability | "press as you sew": a quick press step that adds a small quality bonus to each piece (could grow into a tiny game) |
| Mirror | **Triple Mirror** (T2) | — | fitting-room delight: a small tip bonus at the mirror |
| Rack | **Extra Hooks** *(existing)* (T1) | Capacity | as now |
| Phone | **Bulk Orders** *(existing)* (T2) | Capacity | as now |
| Phone | **Courier Account** (T2) | Tempo | cloth arrives the same day instead of next morning |
| Front desk | **Appointment Book** (T1) | Control | regulars book slots, so walk-ins are easier to pace |

## A shape for progression

- **T0–T1 (first week):** cheap *control* and *read* upgrades (weights, speed dial,
  labels, lamp). The first buys make the games feel nicer, not faster.
- **T1–T2:** *tempo* (sharp scissors, oiled machine, master shears, industrial motor) and
  the first *capabilities* (fold, needle-down, knee lifter). Days get more done.
- **T3:** the big-ticket replacements (rotary cutter, industrial machine, overlocker),
  which change how the station *looks* too.
- **T4:** apprentices: late money sinks for players who'd rather design than cut.

## What to build when

1. **Now (done):** cutting v2 glide, shorter base cut (`cut2_seconds` 18 → 12).
2. With the sewing rebuild: add the knobs above as `GameConfig` values and
   `Upgrades` effect functions (`sew_top_speed()`, `sew_spin_up()`,
   `guide_pull()`, …), so each upgrade is one table entry plus one getter.
3. Cutting upgrades: Pattern Weights / Chalk Wheel / Pinking (small), then Fold
   (medium: fold-line geometry + reveal), then Rotary (medium).
4. Shop-wide lamp + coffee (small, touch both games through `CutBench` and the new
   sewing base).

---

## Built (2026-09-18)

All in `Upgrades.UPGRADES` (phone → Shop Upgrades), each grantable from the F3 panel's
**Upgrades ▸** column. Numbers live on the entries as `effects` read through
`Upgrades.mult(key)` / `Upgrades.bonus(key)`; on/off abilities are `Upgrades.has(id)`.

| Id | Name | Tier / $ | Where it acts |
|---|---|---|---|
| cut_weights | Pattern Weights | T0 / 200 | v2 drift ×0.4 |
| cut_chalk_wheel | Chalk Wheel | T1 / 350 | v2/v3 chalk marks before turns |
| cut_sharp | Sharp Scissors | T1 / 450 | Shift = faster (all cutting games) |
| cut_master | Master Shears | T2 / 1400 | speed ×1.3, glide +0.5 and builds ×2 (v3: longer strokes) |
| cut_pinking | Pinking Shears | T2 / 900 | "Rough" scores as "Good"; zig-zag edge |
| cut_fold | Cut on the Fold | T2 / 1100 | shirt + jacket back cut as a half, then unfolded |
| cut_rotary | Rotary Cutter & Rule | T3 / 3000 | v2 straights roll true at 3×; v3 straights in one press |
| sew_dial | Speed Dial | T0 / 200 | sewing v2 eases down near corners and pins |
| sew_oiled | Oiled Machine | T1 / 450 | spin-up ×2, coast shorter, Shift top gear |
| sew_guide | Magnetic Seam Guide | T1 / 400 | pull back onto the line, drift ×0.5 |
| sew_needle_down | Needle-Down Stop | T1 / 450 | stops dead; corner windows ×2 |
| sew_industrial | Industrial Motor | T2 / 1400 | top speed ×1.3, spin-up ×1.5 |
| sew_walking_foot | Walking Foot | T2 / 1100 | drift ×0.25 |
| sew_knee | Knee Lifter | T2 / 900 | pivot time ×0.25 |
| sew_clips | Sewing Clips | T2 / 800 | sewing over a clip costs 2%, not a slip |
| sew_autolock | Auto-Lock Button | T3 / 2200 | both ends locked automatically |
| shop_lamp | Workbench Lamp | T1 / 400 | perfect band ×1.15 on every bench game |
| shop_coffee | Coffee Machine | T1 / 350 | station: 2 cups/day, each = focus for 3 bench jobs |
| shop_iron | Pressing Iron | T2 / 1000 | station: press a piece once for +5% |
| courier | Courier Account | T2 / 1200 | cloth arrives in 15 min instead of 2 h |

Not built yet: Industrial Machine and Overlocker (T3 sewing), Tall Shelving, Bolt
Labels, Second Mannequin, Triple Mirror, Appointment Book, Radio.

Cloth now takes time to arrive: `GameConfig.delivery_hours` (2 h of shop time), next
morning if that's past closing; tutorial bolts stay instant. Pending bolts save with the
phone. The coffee machine and ironing board are `UpgradeStation`s — hidden until owned —
at `stations/coffee_machine/` and `stations/ironing_board/`; they still need a spot in the
shop map (F3 → Spawn coffee / Spawn iron drops one beside you for testing).

**Apprentice (changed by the owner):** no per-station apprentices. One shop-wide hire,
gated by reputation, a fixed price, who you talk to and give jobs ("cut this", "sew
that"), and who gets better with time. Design still to settle — see the open questions.

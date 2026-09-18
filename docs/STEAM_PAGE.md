# TailorTown — Steam page copy

Draft store text plus the shot list it's built around. Screenshots are rendered by
`tools/shot_promo.gd` (see §4) into `.dev/promo/` at 1920×1080.

Positioning note: the near neighbours are *Dressmaker* (cosy, dresses, Sept 2026) and
*Tailor Simulator* (fashion business, first person). Our ground is **men's bespoke
tailoring with dress-code rules** — the client's occasion decides what is correct, and
the Handbook is how you learn it. Every line below leans on that.

---

## 1. Short description (Steam max 300 characters)

> Run a bespoke tailoring shop in a cosy little town. Every client walks in with an
> occasion, a style and a budget — design their suit at the mirror, then cut, stitch
> and assemble it by hand before the deadline.

(248 characters.)

Alternates, if you want a different angle:

- **Craft-forward:** "A cosy bespoke-tailoring sim. Choose the cloth, cut it to shape,
  stitch the seams, and dress the client for the occasion — a wedding, a funeral, a
  night out — before their fitting day comes round." (211)
- **Pressure-forward:** "Three clients, two deadlines, one sewing machine. Run a bespoke
  tailor's shop: take the brief, pick the cloth, cut and stitch every piece by hand, and
  make your name on the Row." (183)

---

## 2. About This Game (long description)

Structure follows the "one section, one mechanic, one moving image" pattern. The
bracketed lines are asset slots, not text to paste.

---

[GIF 1 — the mirror: A/D through fabrics and colours, the suit changing on the client in
real time. 4 s loop, no cut.]

Some men need a suit for a wedding. Some need one for a funeral. Every one of them walks
through your door with an occasion, a style and a budget — and only you know what is
actually correct.

TailorTown is a cosy shop sim about bespoke tailoring, from the bolt of cloth to the
handover. You walk the floor, you carry one thing at a time, and everything that leaves
the shop was cut and stitched by your own hand.

### Take the brief

[GIF 2 — a walk-in at the counter, the greeting bubble opening with occasion, style and
budget; the player takes the fitting.]

A client states the occasion, the look they're after and what they can spend. Take the
fitting, book them for a later day, or politely decline — a full bench is a good reason
to say no. Sit them at the mirror and design the suit part by part: jacket, shirt,
trousers, each with its own cloth, colour, pattern and cut. Agree the price, and the
order goes on the board with a deadline.

### Know your cloth

[Screenshot — the cloth shelf, swatches and metres remaining.]

Worsted wool, flannel, tweed, mohair, linen, poplin. Pinstripe, herringbone, houndstooth,
windowpane, glen check. Weight, super number and price per metre all matter, and every
bolt is a finite number of metres — cut carelessly and the last half-metre of a good
cloth is gone. Ring the suppliers from the shop phone; the better houses open their books
to you as your name grows.

### Cut it, stitch it, finish it

[GIF 3 — the cutting minigame followed by the sewing minigame, back to back.]

Chalk the pattern and steer the shears along the line — drift and you nick the cloth,
three slips and it's ruined. Then feed the seam through the machine in rhythm, stitch by
stitch. How cleanly you cut and how steadily you sew becomes the quality of the finished
piece, and the quality of the piece is what the client pays for.

### Dress for the occasion

[Screenshot — the Tailor's Handbook, Dress Codes chapter.]

Black for a funeral. Nothing that upstages the groom. A board meeting is not a party. The
Tailor's Handbook holds the real rules — fabrics, patterns, styles and what each occasion
will accept — written the way a tailor would tell you. Read it, and you'll know what to
put in front of a client before they ask.

### Make your name on the Row

[Screenshot — the morning paper, fashion trend and social calendar.]

The Tailor's Gazette lands each morning with the fashion of the day and the town's
coming events — a wedding in five days, business in nine — so the tailor who reads the
paper is the one with the right cloth already on the shelf. Deliver well and your
standing rises, opening better suppliers and better equipment. Miss a deadline and it
falls.

### Keep the shop

[Screenshot — the order book, four clients waiting.]

Open in the morning, lock up at night, and keep the bench moving in between: appointments
to honour, regulars who come back, rush jobs, and the ones who want something you'd
rather not make. Everything saves, and a first-run walkthrough with Mr. Hemming teaches
the trade before it leaves you to it.

---

**Features**

- A full craft chain you perform yourself: order cloth → cut it to length → shape the
  panels → sew the seams → assemble the suit → hand it over.
- Real tailoring materials — 8 fabrics, 10+ patterns, dozens of colours — rendered as
  woven cloth on the garment and on the client.
- Occasion-and-style dress codes that judge every part of the suit, not just the jacket.
- Two hand-feel minigames whose results carry through to what the client pays.
- A reputation that unlocks premium textile houses and better machines.
- A daily paper that sets the fashion and warns you what the town is planning.
- Days you open and close, appointments, regulars and deadlines you can miss.
- Top-down, walk-the-floor shop in a hand-built town. Keyboard or controller.

---

## 3. Tags (20 slots, most specific first)

Shop Keeper · Crafting · Job Simulator · Time Management · Management · Cozy ·
Simulation · Resource Management · Casual · Relaxing · Design & Illustration ·
Top-Down · Stylized · Colorful · Cute · Singleplayer · Family Friendly · Minigames ·
Indie · 3D

## 4. Screenshots (rendered)

`godot --path . --script res://tools/shot_promo.gd` → `.dev/promo/*.png`, 1920×1080.
Pass shot names to re-render a subset, e.g. `-- mirror cutting storefront`.

Suggested Steam order (first one is the one most people see):

| # | File | Shows |
|---|---|---|
| 1 | `01_shop_overview.png` | the whole shop working — tickets, clock, money, a client at the mirror |
| 2 | `04_suit_builder_zoom.png` | the designed suit on the client, spec panel and quote |
| 3 | `05_cutting_minigame.png` | the cutting minigame |
| 4 | `06_sewing_minigame.png` | the sewing minigame |
| 5 | `07_cloth_shelf.png` | the cloth shelf — variety of fabric |
| 6 | `02_customer_brief.png` | a walk-in's occasion, style and budget |
| 7 | `09_handbook.png` | the Tailor's Handbook |
| 8 | `10_order_book.png` | the order book and deadlines |
| 9 | `11_newspaper.png` | the morning paper |
| 10 | `08_phone_order.png` | ordering cloth from a supplier |
| 11 | `12_shopfront_street.png` | the shopfront and the town |
| 12 | `03_suit_builder.png` | the fitting, whole-suit view |

## 5. Clips (rendered)

Record, then encode (the `--fixed-fps 30` matters — it keeps game time exact while
frames are captured):

```
godot --fixed-fps 30 --path . --script res://tools/shot_promo.gd -- clips
python tools/encode_clips.py
```

Frames land in `.dev/promo/clips/<clip>/`; the encoder writes `<clip>.webp` (1170px,
30 fps — upload these) and `<clip>.gif` (780px, 15 fps fallback) beside them. Name clips
to re-record just those: `-- clip_mirror clip_brief`.

| Slot | Clip | Shows | WebP |
|---|---|---|---|
| GIF 1 (lead) | `mirror` | two suits designed part by part at the mirror, 2x speed, 20 fps | ~6.1 MB |
| GIF 2 | `brief` | a walk-in reaches the counter, waves, states the brief | ~2.3 MB |
| GIF 3 | `cutting` + `sewing` | a full cut, then a full seam (use both, stacked) | ~1.2 + 1.4 MB |
| spare | `shop` | the tailor crossing the floor with a bolt as a client walks in | ~3.6 MB |

The four slotted clips total ~11 MB. Leave `shop` off the page (or use it in an
announcement) — adding it passes the 15 MB point where Valve may strip animations.

## 6. Asset rules worth keeping in mind

- Screenshots: 1920×1080 minimum, 16:9. Animation never plays in the screenshot row.
- About This Game accepts PNG/JPG/GIF/WEBP/**MP4/WEBM**; animation plays only there and
  in announcements. Author moving clips as **MP4/WEBM**, 1170px wide, ≤12 s — Steam
  re-encodes GIFs to WebP and they balloon.
- Keep the whole page under 15 MB of animated assets or Valve may strip the clips.
- Alt text is required on every image in the description.
- About 600 words show before "Read More" — the first three sections have to carry it.
- Capsules are separate art (920×430, 462×174, 1232×706, 748×896, 600×900) and must read
  at thumbnail size. Not screenshots.

## 7. BBCode version (paste into the description field)

```
[img]{GIF_1}[/img]

Some men need a suit for a wedding. Some need one for a funeral. Every one of them walks through your door with an occasion, a style and a budget — and only you know what is actually correct.

TailorTown is a cosy shop sim about bespoke tailoring, from the bolt of cloth to the handover. You walk the floor, you carry one thing at a time, and everything that leaves the shop was cut and stitched by your own hand.

[h2]Take the brief[/h2]
[img]{GIF_2}[/img]
A client states the occasion, the look they're after and what they can spend. Take the fitting, book them for a later day, or politely decline — a full bench is a good reason to say no. Sit them at the mirror and design the suit part by part: jacket, shirt, trousers, each with its own cloth, colour, pattern and cut. Agree the price, and the order goes on the board with a deadline.

[h2]Know your cloth[/h2]
[img]{SHOT_CLOTH_SHELF}[/img]
Worsted wool, flannel, tweed, mohair, linen, poplin. Pinstripe, herringbone, houndstooth, windowpane, glen check. Weight, super number and price per metre all matter, and every bolt is a finite number of metres — cut carelessly and the last half-metre of a good cloth is gone. Ring the suppliers from the shop phone; the better houses open their books to you as your name grows.

[h2]Cut it, stitch it, finish it[/h2]
[img]{GIF_3}[/img]
Chalk the pattern and steer the shears along the line — drift and you nick the cloth, three slips and it's ruined. Then feed the seam through the machine in rhythm, stitch by stitch. How cleanly you cut and how steadily you sew becomes the quality of the finished piece, and the quality of the piece is what the client pays for.

[h2]Dress for the occasion[/h2]
[img]{SHOT_HANDBOOK}[/img]
Black for a funeral. Nothing that upstages the groom. A board meeting is not a party. The Tailor's Handbook holds the real rules — fabrics, patterns, styles and what each occasion will accept — written the way a tailor would tell you. Read it, and you'll know what to put in front of a client before they ask.

[h2]Make your name on the Row[/h2]
[img]{SHOT_NEWSPAPER}[/img]
The Tailor's Gazette lands each morning with the fashion of the day and the town's coming events — a wedding in five days, business in nine — so the tailor who reads the paper is the one with the right cloth already on the shelf. Deliver well and your standing rises, opening better suppliers and better equipment. Miss a deadline and it falls.

[h2]Keep the shop[/h2]
[img]{SHOT_ORDER_BOOK}[/img]
Open in the morning, lock up at night, and keep the bench moving in between: appointments to honour, regulars who come back, rush jobs, and the ones who want something you'd rather not make. Everything saves, and a first-run walkthrough with Mr. Hemming teaches the trade before it leaves you to it.

[h2]Features[/h2]
[list]
[*] A full craft chain you perform yourself: order cloth, cut it to length, shape the panels, sew the seams, assemble the suit, hand it over.
[*] Real tailoring materials — 8 fabrics, 10+ patterns, dozens of colours — rendered as woven cloth on the garment and on the client.
[*] Occasion-and-style dress codes that judge every part of the suit, not just the jacket.
[*] Two hand-feel minigames whose results carry through to what the client pays.
[*] A reputation that unlocks premium textile houses and better machines.
[*] A daily paper that sets the fashion and warns you what the town is planning.
[*] Days you open and close, appointments, regulars and deadlines you can miss.
[*] Top-down, walk-the-floor shop in a hand-built town. Keyboard or controller.
[/list]
```

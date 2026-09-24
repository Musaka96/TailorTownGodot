# Cloth reference prompts

Reference images for how TailorTown's suit cloth should look. They are the target the
cloth shader and `tools/build_textures.gd` are tuned against, not textures to import.
Generated with GPT Image, following the anti-AI-look rules in `UI_STYLE_GUIDE.md` §7.1.

Catalogue sources: `data/scripts/enums.gd` (fabrics, patterns),
`data/scripts/material_factory.gd` (dyes, accents), `data/scripts/cloth_material.gd`
(per-fabric sheen, per-pattern scale and intensity).

## How to use this sheet

Every prompt is three parts glued together, in this order:

```
<PREFIX for the set>  <SUBJECT line from the table>  <SUFFIX for the set>
```

Two sets, two prefixes:

- **Set S, swatches (flat scan).** One image per fabric and per pattern. Square,
  1024x1024. This is what the weave structure, colour and pattern scale are checked
  against.
- **Set J, jacket on a dress form (distance + sheen).** One image per cloth that
  changes with light or distance. Portrait, 1024x1536. This is what sheen, drape and
  the "pattern melts at two metres" look are checked against.

Save results into `IMPORT/cloth_refs/` (not in git) with the file name in the table.
The name is what the comparison sheet script will look for.

The swatch set alone covers most of it. If time is short, do Set S first and the four
starred rows of Set J.

---

## Set S: flat swatches

### S prefix

```
A flatbed scanner capture of a single tailor's cloth-bunch swatch, laid face down on the
glass, so the cloth fills the whole frame edge to edge with no background. Flat, even,
frontal light with no single light source, as a scanner gives. The image is a true
top-down capture with no perspective. The swatch is ten centimetres square and the weave
is seen at the scale a scanner would show it, so individual threads are just visible.
One brass tailor's pin lies across the lower right corner for scale. The cut edges of the
swatch are slightly off square and one loose thread end sits at the bottom edge.
```

### S suffix

```
Real woven cloth, not a drawing and not a render. No gradients, no glow, no bloom, no rim
light, no lens blur, no depth of field, no vignette, no drop shadow, no specular
highlights, no floating particles. The colours are only: {PALETTE}. No text, no
watermark, no signature, no border, no frame, no horizon, no people.
```

Replace `{PALETTE}` with the palette column. Keep it a closed list of hex values.

### S1: fabrics (8 images, all plain solid cloth)

| file | subject line | palette |
|---|---|---|
| `S_fabric_worsted.png` | The cloth is a fine navy worsted wool suiting, Super 120s, tightly woven in a two-up two-down twill so a faint diagonal twill line runs across it, smooth clear finish with no nap, hard and crisp, a cool dry matte with only the slightest lustre where the twill catches the light. | navy `#1b2a4a`, brass pin `#b08d57` |
| `S_fabric_flannel.png` | The cloth is a mid grey woollen flannel suiting, milled and brushed so a soft raised nap hides the weave entirely, a cloudy mottled melange of mixed lighter and darker grey fibres, completely matte, thick and soft. | mid grey `#6e7178`, lighter fibre `#9a9ea6`, darker fibre `#36393f`, brass pin `#b08d57` |
| `S_fabric_tweed.png` | The cloth is a brown Harris-style tweed, a coarse hairy woollen in a two-up two-down twill you can see plainly, a heathered brown ground with scattered small flecks of rust, gold, moss and burgundy spun into the yarn, fuzzy loose fibres standing off the surface, thick and matte. | brown `#5a4633`, rust `#9a4a2a`, gold `#c9a24a`, moss `#5c5a35`, burgundy `#5c1f2a`, brass pin `#b08d57` |
| `S_fabric_mohair.png` | The cloth is a charcoal kid-mohair and wool blend suiting, a very fine flat plain weave with a crisp dry wiry hand, smooth and springy, with the distinct cool glassy sheen mohair has, visible as a lighter cast across the whole face rather than a highlight. | charcoal `#36393f`, sheen cast `#5a5d63`, brass pin `#b08d57` |
| `S_fabric_linen.png` | The cloth is a tan Irish linen suiting, an open plain weave of irregular slubbed yarns, thick and thin threads plainly visible, small knots and slubs, dry and papery, with a few fine creases pressed into it. | tan `#c8b48a`, slub `#a8946e`, brass pin `#b08d57` |
| `S_fabric_cotton.png` | The cloth is a white cotton drill suiting, a fine even cotton twill, soft, matte, dense and smooth with a very faint diagonal line, no sheen at all. | white `#f2f0e8`, brass pin `#b08d57` |
| `S_fabric_poplin.png` | The cloth is a sky blue cotton poplin shirting, a fine tight plain weave with a crosswise rib of crisp horizontal ridges, thin and smooth with a slight silky sheen, lightweight. | sky blue `#bcd0e4`, brass pin `#b08d57` |
| `S_fabric_oxford.png` | The cloth is a sky blue oxford cloth shirting, a two-by-two basket weave of paired threads, blue warp crossed with white weft so the face reads as a fine two-tone speckle, soft, matte and a little heavy. | sky blue `#bcd0e4`, white `#f2f0e8`, brass pin `#b08d57` |

### S2: suiting patterns (8 images, on worsted unless said)

| file | subject line | palette |
|---|---|---|
| `S_pattern_pinstripe.png` | The cloth is a navy worsted wool suiting with a chalk pinstripe: single very thin white threads running vertically, one thread wide, spaced exactly one centimetre apart, slightly broken where the thread dips under the weave. | navy `#1b2a4a`, chalk `#f0efe6`, brass pin `#b08d57` |
| `S_pattern_herringbone.png` | The cloth is a mid grey worsted wool suiting in a herringbone weave: a broken twill whose diagonal reverses every centimetre in vertical columns, so the chevrons meet cleanly at each column edge, tone on tone, the pattern made only by light and dark threads of the same grey. | grey `#6e7178`, lighter thread `#9a9ea6`, darker thread `#36393f`, brass pin `#b08d57` |
| `S_pattern_houndstooth.png` | The cloth is a charcoal and chalk worsted wool suiting in a small houndstooth, woven as a two-up two-down twill with four dark threads then four light in both warp and weft, so each dogtooth has square corners with jagged twill points, the repeat about one centimetre. | charcoal `#36393f`, chalk `#f0efe6`, brass pin `#b08d57` |
| `S_pattern_windowpane.png` | The cloth is a navy worsted wool suiting with a chalk windowpane: single thin light lines crossing to form squares about four centimetres wide, the lines a little uneven where they cross. | navy `#1b2a4a`, chalk `#f0efe6`, brass pin `#b08d57` |
| `S_pattern_glen_check.png` | The cloth is a grey worsted wool suiting in a Prince of Wales glen check: blocks of tiny houndstooth alternating with blocks of fine stripes in charcoal and chalk, forming a large check about five centimetres, with a thin sky blue overcheck line laid over the whole. | grey `#9a9ea6`, charcoal `#36393f`, chalk `#f0efe6`, sky blue `#9fc0e0`, brass pin `#b08d57` |
| `S_pattern_birdseye.png` | The cloth is a burgundy worsted wool suiting in a birdseye weave: a tiny lighter dot at every crossing of a small diamond weave, dots about two millimetres apart, so from arm's length it reads as a textured solid. | burgundy `#5c1f2a`, dot `#8a4a54`, brass pin `#b08d57` |
| `S_pattern_sharkskin.png` | The cloth is a light grey worsted wool suiting in a sharkskin weave: a two-up two-down twill with one light thread then one dark in both directions, so the face is a smooth fine two-tone with a soft sheen and a barely visible diagonal, reading as a solid that shifts tone. | light grey `#9a9ea6`, darker thread `#6e7178`, brass pin `#b08d57` |
| `S_pattern_nailhead.png` | The cloth is a charcoal worsted wool suiting in a nailhead weave: tiny lighter pinhead dots in a regular grid about three millimetres apart, tone on tone, crisp and small. | charcoal `#36393f`, dot `#6e7178`, brass pin `#b08d57` |

### S3: shirting patterns (5 images, on poplin unless said)

| file | subject line | palette |
|---|---|---|
| `S_pattern_bengal_stripe.png` | The cloth is a white cotton poplin shirting with a Bengal stripe: bold even vertical stripes of sky blue and white, each about six millimetres wide, equal width, crisp edges. | white `#f2f0e8`, sky blue `#9fc0e0`, brass pin `#b08d57` |
| `S_pattern_university_stripe.png` | The cloth is a white oxford cloth shirting with a university stripe: narrow even vertical stripes of blue and white about three millimetres wide, equal width, the edges slightly softened by the basket weave. | white `#f2f0e8`, blue `#3a4a63`, brass pin `#b08d57` |
| `S_pattern_gingham.png` | The cloth is a cotton poplin shirting in a small gingham: an even check of pink, white and the blended pink-white where they cross, squares about six millimetres, woven not printed so the blended squares are made of alternating threads. | pink `#c98a96`, white `#f2f0e8`, blend `#e6c6cc`, brass pin `#b08d57` |
| `S_pattern_tattersall.png` | The cloth is an ecru cotton poplin shirting in a tattersall check: two colours of thin single lines, one crimson and one ink, alternating and crossing to form squares about two centimetres. | ecru `#e9e1cf`, crimson `#7a2230`, ink `#20222a`, brass pin `#b08d57` |
| `S_pattern_end_on_end.png` | The cloth is a cotton poplin shirting in an end-on-end weave: the warp alternates one sky blue thread with one white thread so the face is a fine heathered two-tone that shifts between blue and white as it is looked at, no stripes visible, only the shimmer. | sky blue `#9fc0e0`, white `#f2f0e8`, brass pin `#b08d57` |

---

## Set J: jacket on a dress form

Shows how the cloth reads at gameplay distance and how light rolls over folds. The
starred rows are the ones that matter most: two sheen fabrics, one pattern that has to
melt at distance, one that must not.

### J prefix

```
A photograph on colour negative film of a single-breasted jacket on a plain linen-covered
tailor's dress form in a tailor's workroom, seen straight on from two and a half metres
away, the form filling the frame from shoulders to hem. Soft north-facing window daylight
from the left, one light source only, so the cloth shows how it takes light along the
lapels, the sleeve folds and the chest. Plain plaster wall behind, nothing else in frame.
The jacket is finished but unpressed, one sleeve hangs a little forward and the front
edge sits slightly open.
```

### J suffix

```
Real cloth on a real form, not a render. No glow, no bloom, no rim light, no lens blur,
no depth of field, no vignette, no added drop shadow, no floating particles. The colours
are only: {PALETTE}. No text, no watermark, no signature, no border, no frame, no people.
```

Palettes below always end with form `#d9cfb8` and wall `#e8e3d8`.

| file | subject line | palette |
|---|---|---|
| `J_mohair_charcoal.png` * | The jacket is a charcoal kid-mohair and wool blend, plain, and its cool glassy sheen lifts the whole lit side a tone lighter while the shaded side stays deep, the change visible along every fold. | charcoal `#36393f`, sheen `#5a5d63`, form, wall |
| `J_sharkskin_lightgrey.png` * | The jacket is a light grey sharkskin worsted, and at this distance the weave is invisible; the cloth reads as a smooth solid with a soft two-tone shimmer that shifts across the folds. | light grey `#9a9ea6`, darker `#6e7178`, form, wall |
| `J_pinstripe_navy.png` * | The jacket is a navy worsted with a chalk pinstripe one centimetre apart, and at this distance the stripes are still clearly visible as thin light lines, running straight down the body and following the curve of the sleeve. | navy `#1b2a4a`, chalk `#f0efe6`, form, wall |
| `J_birdseye_burgundy.png` * | The jacket is a burgundy birdseye worsted, and at this distance the dots have melted completely into a textured solid a little lighter than a plain cloth would be. | burgundy `#5c1f2a`, dot `#8a4a54`, form, wall |
| `J_glen_check_grey.png` | The jacket is a grey Prince of Wales glen check with a sky blue overcheck, and at this distance the small houndstooth blocks blur into a soft mid grey while the large check and the blue overcheck stay readable. | grey `#9a9ea6`, charcoal `#36393f`, chalk `#f0efe6`, sky `#9fc0e0`, form, wall |
| `J_houndstooth_charcoal.png` | The jacket is a small charcoal and chalk houndstooth worsted, and at this distance the dogtooth reads as a busy fine check, the individual teeth just still visible on the chest. | charcoal `#36393f`, chalk `#f0efe6`, form, wall |
| `J_herringbone_grey.png` | The jacket is a mid grey herringbone worsted, and at this distance the chevrons are gone; only a faint vertical column striping remains, tone on tone. | grey `#6e7178`, lighter `#9a9ea6`, darker `#36393f`, form, wall |
| `J_flannel_midgrey.png` | The jacket is a mid grey flannel, dead matte, and the folds show only as soft value changes with no sheen at all, the surface slightly fuzzy at the edges. | mid grey `#6e7178`, lighter fibre `#9a9ea6`, form, wall |
| `J_tweed_brown.png` | The jacket is a brown tweed with rust, gold and moss flecks, and at this distance the flecks are a fine coloured speckle over a heathered brown, the surface hairy against the light at the shoulder edge. | brown `#5a4633`, rust `#9a4a2a`, gold `#c9a24a`, moss `#5c5a35`, form, wall |
| `J_linen_tan.png` | The jacket is a tan linen, creased across the back of the sleeves and at the elbows, dry and matte, the open weave showing as a slight unevenness of tone. | tan `#c8b48a`, slub `#a8946e`, form, wall |
| `J_worsted_navy.png` | The jacket is a plain navy worsted, and the folds show a faint dry lustre along their crests, the shade side a clean deep navy. | navy `#1b2a4a`, lustre `#2c3d60`, form, wall |

---

## What happens with the results

1. Drop the files into `IMPORT/cloth_refs/`.
2. A comparison sheet pairs each reference with the matching Cloth Lab render
   (`tools/shot_cloth_compare.gd`, scene `scenes/dev/cloth_lab.tscn`) so the two sit side
   by side at the same size.
3. Tuning order: fabric grain and sheen first (`FABRIC_RIM`, normal depth), then pattern
   scale, then pattern intensity at distance against the Set J shots.

## Why these choices

- **Flatbed scan** is a real medium that gives flat even frontal light and no
  perspective by construction, which is what the tile rules in §7.1 ask for. It also
  keeps the model from inventing a studio.
- **A brass pin** is the scale cue. Numbers on a ruler would break the no-text rule.
- **Set J on film with one window** breaks the "no single light source" tile rule on
  purpose: sheen and drape only exist under a directional light, so the light is named
  instead of hidden.
- **Two or three imperfections per prompt** (off-square cut, loose thread, unpressed
  jacket) and no more, per §7.1 rule 6.
- **Colours match the game's dye table** so a reference can be dropped next to the
  in-game swatch without a colour shift getting in the way of a weave comparison. Where
  a real cloth needs a second tone the game does not name (flannel melange, tweed rust,
  glen check overcheck), the value is picked to sit inside the game palette family.

---

## Contact sheets: 15 swatches in one image

Same prefix and suffix idea, but the subject is a numbered list in a fixed reading
order (left to right, top to bottom, three rows of five). Generate at 1536x1024 landscape.
Models drop or merge items past about twelve, so run each sheet two or three times and
keep the one where the order held. Save as `S_sheet_suitings.png` and
`S_sheet_shirtings.png`.

Sheet prefix (replaces the S prefix):

```
A flatbed scanner capture of fifteen tailor's cloth-bunch swatches laid face down on the
glass in three rows of five, each swatch a ten centimetre square, all the same size,
sitting edge to edge with only a thin line of the black scanner lid showing between them.
Flat, even, frontal light with no single light source, as a scanner gives. True top-down
capture with no perspective. Every swatch shows its weave at scanner scale so individual
threads are just visible. A few swatches sit a degree off square and two have a loose
thread end at one edge.

Reading left to right, top to bottom, the swatches are:
```

Then the numbered list, then the S suffix with the union of the palettes and
`scanner lid black #0a0a0a` added.

**Suitings sheet order:** 1 worsted navy solid, 2 flannel mid grey solid, 3 tweed brown
solid, 4 mohair charcoal solid, 5 linen tan solid, 6 pinstripe navy, 7 herringbone grey,
8 houndstooth charcoal/chalk, 9 windowpane navy, 10 glen check grey with sky overcheck,
11 birdseye burgundy, 12 sharkskin light grey, 13 nailhead charcoal, 14 cotton drill
white solid, 15 tweed grey herringbone. Subject wording per item is the S1/S2 table
line, shortened to one clause.

**Shirtings sheet order:** 1 poplin white, 2 poplin sky, 3 oxford white, 4 oxford sky,
5 poplin ecru, 6 Bengal stripe sky on white, 7 Bengal stripe pink on white, 8 university
stripe blue on oxford, 9 university stripe mint on oxford, 10 gingham pink, 11 gingham
sky, 12 tattersall crimson and ink on ecru, 13 tattersall sky and forest on white,
14 end-on-end sky, 15 end-on-end lavender. Palette: white `#f2f0e8`, ecru `#e9e1cf`,
sky `#9fc0e0`, blue `#3a4a63`, pink `#c98a96`, mint `#7fae8f`, lavender `#9a8fc0`,
crimson `#7a2230`, ink `#20222a`, forest `#2f5d3e`.

---

## Experiment scene (2026-09-24)

`scenes/dev/cloth_refs.tscn` rebuilds a reference sheet in-engine, swatch for swatch, with
`materials/cloth_experiment.gdshader` (photo-derived linear grain under a flat dye, Charlie
sheen + wrapped diffuse + optional warp anisotropy in `light()`). Nothing in the game uses it.

- `python tools/cloth_refs/make_grain.py` cuts the 15 squares from each sheet in
  `IMPORT/cloth_refs/S_sheet_*.webp`, writes linear grain (mean 0.25) + normal maps to
  `assets/dev/cloth_refs/` and the mean dye colours to `refs.json`.
- Shot: `godot --path . --script res://tools/screenshot.gd -- res://scenes/dev/cloth_refs.tscn res://.dev/x.png 90 sheet=suitings mode=direct` (`mode=game` swaps squares 6/7/8/10 for
  solid grain + the game's pattern tiles; `flat=1` disables the cloth lighting; `energy=`).
- `python tools/cloth_refs/compare.py compose` writes `IMPORT/cloth_refs/compare_*.png`.
- Exposure calibrated to the scan: ambient = sun = 0.546, linear tonemap.

---

## Leather sheet: shoes (8 swatches in one image)

Same scanner idea as the cloth sheets, but leather is glossy, so the scan is replaced by a
copy-stand photograph under one soft light. Generate at 1536x1024 landscape. Save as
`IMPORT/cloth_refs/S_sheet_leather.png`. Reading order left to right, top to bottom, two rows
of four.

```
A copy-stand photograph of eight shoemaker's leather swatches laid flat on a black felt
board in two rows of four, each swatch a ten centimetre square, all the same size, edge to
edge with only a thin line of the black felt between them. One large soft light from above
and slightly to the left, so the grain of each leather shows as small highlights and the
polished ones show one soft broad reflection, never a hard glare. True top-down view with no
perspective. The threads and grain are seen at real size. Two swatches have a slightly
skived edge and one has a faint crease across a corner.

Reading left to right, top to bottom, the swatches are:
1. black box calf, smooth, tight fine grain, high polish, deep soft reflection;
2. dark brown calf, smooth, medium polish, warm undertone;
3. oxblood shell cordovan, very smooth, glassy polish, deep red-brown;
4. tan calf, smooth, light polish, honey colour;
5. black pebble grain, embossed pebbled surface, low polish, matte between the pebbles;
6. chestnut Scotch grain, coarse embossed grain, medium polish;
7. dark brown suede, short velvet nap, completely matte, lighter where the nap is brushed;
8. black patent, mirror gloss, the reflection of the softbox visible as one white shape.

Real leather, not a drawing and not a render. No bloom, no lens blur, no depth of field, no
vignette, no added drop shadow, no floating particles. The colours are only: black #141416,
dark brown #3a2a1e, oxblood #4a1d1e, tan #a8743f, chestnut #6b3f24, suede brown #4a3627,
felt black #0a0a0a, highlight white #f2f0e8. No text, no watermark, no signature, no border,
no frame, no horizon, no people.
```

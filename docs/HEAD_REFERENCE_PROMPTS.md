# Head and hair reference prompts

Front and back reference sheets of blank-faced heads with hairstyles, made for TripoAI.
The Tripo model of each sheet goes into the shared head and hair pool; the game paints its
own face on the flat face plane, so the sheets have no face.

Same method as `CLOTH_REFERENCE_PROMPTS.md`: a fixed prefix that never changes, one
subject line that does, a fixed suffix, a closed palette, exclusions last.

## Why "Animal Crossing" as a word gives different heads every time

The model holds several Animal Crossings at once (villagers, the player, New Leaf, New
Horizons, fan art) and every run picks a different one, so the skull ratio, the ear size
and the way hair is sculpted all move. Two things fix it:

1. Never name the style. Spell out the geometry instead: the skull ratio, where it is
   widest, the flat face plane, the disc ears, the neck cut, how hair is moulded. That is
   what the prefix below does. Keep it word for word the same on every run.
2. Give the model a picture of our own head to copy. GPT Image takes an image alongside
   the prompt; with our head attached and the prompt saying "change only the hair", the
   skull, ears, layout and colours stay put and only the hair varies.

So the work is two stages.

## How to use

**Stage 1, bald heads.** One image per head shape, no hair. Prompt = PREFIX + a head
shape line + "No hair: the skull is bare and smooth." + SUFFIX. Run each two or three
times, keep the one where the layout held, and pick the shapes you like. These bald
sheets also give Tripo the bare skulls the hair pipeline needs under every hairstyle.

**Stage 2, hairstyles.** Attach the approved bald sheet as the image, prompt = EDIT
PREFIX + a hair line + SUFFIX. Everything but the hair stays. Do every hairstyle you want
on a given skull from that skull's bald sheet, in one session, so the runs match.

**Without image input** (fallback): PREFIX + head shape line + hair line + SUFFIX in one
go. It drifts more; run three times and keep the closest.

Landscape 1536x1024. Save into `IMPORT/CHARREWORK/ref/heads/` as
`<shape>_<style>.png`, for example `egg_side_part.png`, `heavy_horseshoe.png`.
For Tripo multi-view, crop the left half (front) and the right half (back) into two
files. If a tall style (pompadour, quiff, swept-back white) comes out of Tripo flat, add
a third view by changing "shown twice" to "shown three times ... the left profile in the
middle" and crop that too.

---

## PREFIX (Stage 1 and the fallback)

```
A studio product photograph of a painted vinyl collectible toy figure's head, shown
twice on one image: the front view on the left and the back view on the right, the same
head at exactly the same size, standing on the same baseline, with a clear gap between
them and nothing else in the frame. True straight-on views at eye level, no perspective,
no tilt, no three-quarter turn. Flat, even light from the front with no single light
source and no shadow on the background. Matte vinyl, no shine.

The head is a cute toy figure's head: a big smooth skull, the face a gently flattened
plane, the cheeks full, the chin small and soft. The face is blank, as on a figure
before the face is printed on: smooth skin with no eyes, no eyebrows, no nose, no mouth.
Two small round disc ears stick straight out at the height of the middle of the face.
Below the head is a short thick cylindrical neck cut flat at the bottom, and nothing
more: no shoulders, no body.
```

## EDIT PREFIX (Stage 2, with the bald sheet attached)

```
Use the attached image as the character. Keep everything exactly as it is: the skull
shape, the blank face with no features, the disc ears, the neck cut, the two-view layout
with the front view on the left and the back view on the right, the size, the baseline,
the colours and the flat background. Change only one thing: give the head this
hairstyle.
```

---

## Head shapes (Stage 1 subject lines)

`egg` is the skull already in the game (the Tripo suit models). The others are the
variety the customer pool needs. Older shapes carry their age in the silhouette, since
the face is blank.

| shape | line |
|---|---|
| `egg` | The skull is a squat wide egg, wider than it is tall once the ears are counted, the crown a wide low dome, the cheeks full and the jaw broad so the head keeps almost its full width down to a wide soft chin, the front of the face gently flattened, the ears centred on the middle of the head's height. |
| `round` | The skull is a ball, as wide as it is tall, the cheeks and chin one continuous curve with no jaw corners. |
| `square` | The skull is a rounded box: a flat top, nearly straight sides and a wide square jaw with rounded corners. |
| `long` | The skull is a tall oval, clearly taller than it is wide, with a high forehead and a long chin. |
| `heavy` | The skull is wide and heavy, widest low at the jaw, with soft jowls and a fold of double chin resting on the neck, and the ears a little larger. |
| `pear` | The skull is narrow at the crown and widens down to full cheeks and a broad jaw. |
| `domed` | The skull is tall with a high domed crown and a narrow jaw. |
| `heart` | The skull is wide at the temples and narrows to a small pointed chin. |

Add after the line: `No hair: the skull is bare and smooth.`

---

## Hairstyles, gentlemen (Stage 2 subject lines)

Default hair colour dark brown `#2c1e18` on the cream background.

| style | line |
|---|---|
| `side_part` | Hair: a classic side part, combed flat and neat, the parting a straight carved groove on the left of the crown, the larger side swept across to the right, short at the sides and back, both ears fully showing, a clean straight hairline at the nape. |
| `slick_back` | Hair: slicked straight back from the forehead in one smooth mass with parallel comb grooves, tight at the sides, a straight front hairline, the back one rounded cap ending in a clean line at the nape. |
| `pompadour` | Hair: a pompadour, a tall rounded mass swept up and back off the forehead, the volume sitting above the forehead, short tapered sides, the back smooth and swept down toward the nape. |
| `quiff` | Hair: a short quiff, the front lifted up into one soft forward wave, the rest short and neat with a low taper at the sides, ears clear. |
| `crew_cut` | Hair: a crew cut, very short all over, a tight cap that follows the skull with a slightly higher front, a straight low hairline at the nape. |
| `buzz` | Hair: a buzz cut, a thin skin-tight layer over the whole skull, the hairline drawn as a crisp edge across the forehead, around the temples and at the nape. |
| `curly_crop` | Hair: a short curly crop, a cap of round curls moulded as small stacked lumps, the silhouette a little taller at the top, the sides trimmed close, ears clear. |
| `wavy_mop` | Hair: a loose wavy mop of medium length, a few thick soft waves sweeping across the forehead and over the tops of the ears, the back reaching the nape in rounded clumps. |
| `curtains` | Hair: a centre part with curtains, medium length, parted straight down the middle, two smooth masses falling to either side over the temples, the back full and rounded down to the nape. |
| `undercut` | Hair: an undercut, the sides and back shaved to a thin layer with a hard step up to a long top swept over to one side in one thick wave. |
| `flat_top` | Hair: a flat top, the top cut dead flat and square with sharp corners at the temples, the sides short and straight, a straight front hairline. |
| `short_coils` | Hair: short natural coils, a dense even cap of tightly coiled hair moulded as a fine pebbled surface close to the skull, with a crisp lined-up hairline across the forehead and temples. |
| `textured_crop` | Hair: a short textured crop, the top a layer of short forward-brushed clumps ending in a choppy fringe across the forehead, the sides faded short. |

## Hairstyles, older gentlemen (Stage 2 subject lines)

Hair colour silver `#8e9196` or white `#e9e6df` on the slate background. These go best on
`heavy`, `long`, `square` and `domed`.

| style | line |
|---|---|
| `receding_part` | Hair: a receding side part, the hairline pulled back into two deep bays at the temples leaving a narrow point of hair in the middle of the forehead, the rest combed neatly to one side, short at the sides and back. |
| `horseshoe` | Hair: a bald crown and forehead, with a horseshoe of short hair running around the sides and back of the head from temple to temple, its top edge level with the tops of the ears. |
| `comb_over` | Hair: a comb-over, a bald crown with long thin hair from the left side combed across the top in a few flat parallel strands, the sides and back short. |
| `white_swept` | Hair: a full head of white hair swept straight back from a high forehead in thick soft waves, long enough to curl a little at the nape and over the tops of the ears. |
| `grey_neat` | Hair: short grey hair, thick and neat, a slight recession at the temples, side parted, short back and sides, ears clear. |
| `wild_white` | Hair: the front half of the skull bald, with a thick unruly mass of white hair standing out at the sides and back in big soft tufts. |
| `bald_fringe` | Hair: nearly bald, only a thin band of short white hair low around the back of the head and above the ears, the whole crown and top bare. |
| `thinning_slick` | Hair: thinning grey hair slicked back, sparse flat strands combed back over a mostly visible scalp, thicker at the sides, a low neat nape. |
| `widows_peak` | Hair: grey hair swept back with a sharp V of hairline pointing down the centre of the forehead and high bays at the temples, medium length at the back. |
| `grey_curls` | Hair: a receding front with a cap of soft round grey curls over the crown and back, moulded as small stacked lumps. |
| `side_wings` | Hair: bald on top with long grey side wings, the hair combed back over the ears in two thick wings that meet in a low neat mass at the back of the head. |

## Facial hair (optional, append to a hair line)

The game's face sprites sit on the flat face plane; a beard is a third mesh for later.
Generate them now if you want the option in the pool.

| add-on | line |
|---|---|
| `moustache` | Add a thick moustache moulded as one solid piece across the middle of the face where the nose would sit, the ends turned down. |
| `handlebar` | Add a handlebar moustache, one solid piece with the ends curling up and out. |
| `full_beard` | Add a short full beard, one solid moulded mass covering the jaw and chin and joined to the hair at the sideburns, with a moustache. |
| `goatee` | Add a small goatee, one solid piece on the chin only, with a thin moustache. |
| `mutton_chops` | Add mutton chops, two solid masses of sideburn running down the cheeks to the jaw, the chin bare. |

---

## SUFFIX

```
Hair is moulded the way toy figure hair is: a few solid masses with carved grooves and
crisp edges, not separate strands and not fuzzy. Both views show the same hairstyle from
opposite sides, and the back view shows the nape and the backs of the ears. The image has
a plain flat background of one colour, no floor, no shadow, no gradient, no glow, no
bloom, no rim light, no lens blur, no depth of field, no vignette, no specular
highlights. The colours are only: skin #e4b083, hair {HAIR}, background {BG}. No eyes, no
eyebrows, no nose, no mouth, no glasses, no hat, no shoulders, no body, no text, no
watermark, no signature, no border, no frame.
```

For a bald sheet drop "hair {HAIR}," from the palette.

## Colours

The game overrides skin and hair with its own flat colours, so the sheet colours only
have to be readable by Tripo and by the hair/skull split, which tells hair from skin by
colour. Hair must sit far from the skin in hue and value. Blond, sandy and ginger hair
sit too close to `#e4b083` and get merged into the skull, so leave them out.

| use | value |
|---|---|
| skin (from the suit reference sheet) | `#e4b083` |
| hair, dark | near-black `#1a1512`, dark brown `#2c1e18`, chestnut `#5a2a1e` |
| hair, old | silver `#8e9196`, white `#e9e6df` |
| background with dark hair | cream `#e5dbd1` (the suit sheets used it) |
| background with silver or white hair | slate `#3e4a55` |

## Round 1 (2026-09-24)

First egg run with the original egg line ("about as tall as it is wide"): the layout,
blank face, disc ears, neck cut and flat background all held on the first try. The skull
came back as a tall egg (widest at the ear line, then tapering fast to a narrow chin, the
skull 0.84 as wide as tall without ears), which is the model's default head. The egg line
above was rewritten to push the width down into the cheeks and jaw and to put the ears at
mid height; the prefix was left alone since everything in it worked.

## Check before Tripo

- Both views the same size on one baseline, front left and back right; the back view
  really is a back (nape, ear backs), not a second front.
- Face blank. The model likes to sneak in eyebrows or a mouth; reject those runs.
- Hair reads as a few solid masses with grooves. Fuzzy or strand-by-strand hair comes out
  of Tripo as blobs.
- Neck stub present and cut flat, no shoulders.
- Background flat with no shadow under the head.

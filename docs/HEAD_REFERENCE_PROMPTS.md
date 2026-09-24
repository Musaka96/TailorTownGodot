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

Attach two images: the bald base sheet first, the labelled hairstyle sheet
(`IMPORT/CHARREWORK/ref/heads/style_sheet_labelled.png`, the "Hairstyle Ideas (for
Everyone!)" sheet) second. The second one sets how chunky the hair is and, where a cell
is labelled, which style to copy. It has faces, text and a logo, so the prefix tells the
model to ignore those; it has no back views, so the hair line still describes the back.

```
The first attached image is the character. Keep everything in it exactly as it is: the
skull shape, the blank face with no features, the disc ears, the neck cut, the two-view
layout with the front view on the left and the back view on the right, the size, the
baseline, the colours and the flat background. The second attached image is a sheet of
hairstyles: copy how its hair is sculpted, big simple clumps with real volume, and copy
the style named below if it is on the sheet. Take nothing else from it: not its faces,
eyes, clothes, head shape, colours, text, labels, logo or layout. Change only one thing
on the character: give the head this hairstyle.
```

## BATCH PREFIX (Stage 2, four styles per image)

Same two attached images. One image gives four styles on the base head, in a two by two
grid, each cell its own front and back pair. Crop the cells along the dividing lines,
then the halves. Keep one hair colour per batch, so the palette stays closed.

```
The first attached image is the character. Keep its skull shape, blank face with no
features, disc ears, neck cut, colours and flat background exactly as they are. The
second attached image is a sheet of hairstyles: copy how its hair is sculpted, big simple
clumps with real volume, and copy each style named below if it is on the sheet. Take
nothing else from it: not its faces, eyes, clothes, head shape, colours, text, labels,
logo or layout.

Make one image holding four versions of this same head, each with a different hairstyle,
in a two by two grid: top left, top right, bottom left, bottom right. Every cell shows
its head twice at the same size on the same baseline, the front view on the left and the
back view on the right, with a clear gap between them. All four heads are the same size.
A thin straight line of colour #3e4a55 separates the four cells. Each cell has exactly
one hairstyle and no hairstyle is repeated.

The hairstyles, in reading order, are:
1. {HAIR line}
2. {HAIR line}
3. {HAIR line}
4. {HAIR line}
```

Then the SUFFIX, with "The hair is chunky" changed to "All the hair is chunky" and "the
whole head" to "each head". Add divider #3e4a55 to the palette.

Batch plan (gentlemen dark brown `#2c1e18`, older silver `#8e9196`, all on cream):

| batch | styles |
|---|---|
| G1 (done) | slick_back, pompadour, curly_crop, wavy_mop |
| G2 (done) | side_part, deep_part, wavy_side, plus a shaggy miss |
| G3 (done) | brushed_back kept; ivy league faded, centre part came long, long swept spiked |
| V1 (from `egg_side_part`) | ivy_league, short_neat |
| V2 (from `egg_brushed_back`) | long_swept, centre_part |
| G4 | curly_side, plus three on the `squat` or `heavy` base once one exists |
| O1 | receding_part, comb_over, grey_neat, side_wings |
| O2 | thinning_slick, widows_peak, grey_curls, bald_fringe |
| O3 (white `#e9e6df`, background slate `#3e4a55`, divider cream `#e5dbd1`) | white_swept, wild_white, plus two facial hair heads: horseshoe + full_beard, grey_neat + moustache |

If a batch mixes styles between cells or repeats one, drop to two per image (one row)
rather than back to singles.

## VARIANT PREFIX (Stage 3, a new style edited from a keeper)

For styles the model keeps getting wrong from words, edit one of the kept sheets instead.
Attach the cropped keeper cell (its own front and back pair) as the only image. Two
variants per image, side by side, each its own front and back pair.

```
The attached image is the character with a hairstyle. Keep the skull shape, the blank
face with no features, the disc ears, the neck cut, the colours and the flat background
exactly as they are, and keep the hair's sculpting: the same big fat locks and the same
volume. Make one image with two versions of this head side by side, the left version
and the right version, each shown twice at the same size on the same baseline, its
front view on the left and its back view on the right, a thin straight line of colour
#3e4a55 between the two versions. Each version changes the hairstyle in one way only:
Left: {change}
Right: {change}
```

Then the SUFFIX. Changes are written as differences from the keeper, for example "the
same cut but the top cut short, no longer than two finger widths, the sides and back
kept as they are, scissor cut, no fade".

---

## Head shapes (Stage 1 subject lines)

`egg` is the skull already in the game (the Tripo suit models). The others are the
variety the customer pool needs. Older shapes carry their age in the silhouette, since
the face is blank.

| shape | line |
|---|---|
| `egg` | The skull is an egg about as tall as it is wide with the ears, widest at the ear line, with a full round crown and a small soft chin. |
| `squat` | The skull is a squat wide egg, wider than it is tall once the ears are counted, the crown a wide low dome, the cheeks full and the jaw broad so the head keeps almost its full width down to a wide soft chin, the front of the face gently flattened, the ears centred on the middle of the head's height. |
| `round` | The skull is a ball, as wide as it is tall, the cheeks and chin one continuous curve with no jaw corners. |
| `square` | The skull is a rounded box: a flat top, nearly straight sides and a wide square jaw with rounded corners. |
| `long` | The skull is a tall oval, clearly taller than it is wide, with a high forehead and a long chin. |
| `heavy` | The skull is wide and heavy, widest low at the jaw, with soft jowls and a fold of double chin resting on the neck, and the ears a little larger. |
| `pear` | The skull is narrow at the crown and widens down to full cheeks and a broad jaw. |
| `domed` | The skull is tall with a high domed crown and a narrow jaw. |
| `heart` | The skull is wide at the temples and narrows to a small pointed chin. |

Add after the line: `No hair: the skull is bare and smooth.`

---

## Pointing at a cell of the labelled sheet

When our style has a cell on the sheet, start the hair line with
`Hair: the style labelled "<label>" on the second image:` and then keep our line, which
carries the back view. Labels on the sheet:

| ours | sheet label |
|---|---|
| `side_part` | "Classic Part" |
| `slick_back` | "Slick Back" |
| `ivy_league` | "Ivy League" |
| `wavy_side` | "Wavy Business" |
| `short_neat` | "Short Professional" |
| `deep_part` | "Side Swept" |
| `wavy_mop` | "Soft Waves" |
| `curly_crop` | "Curly" |
| `receding_part` | "Receding" |
| `grey_neat` | "Short & Gray" |
| `white_swept` | "Silver Sweep" |
| `wild_white` | "Wise & Wispy" |
| `horseshoe` | "Horseshoe" |

Pompadour, brushed back, centre part, long swept, curly side, comb-over, widow's peak,
side wings and the rest have no cell; their lines stand alone.

## Hairstyles, gentlemen (Stage 2 subject lines)

Old money, not the barbershop: every cut is scissor cut and combed, long enough to lie in
locks everywhere it grows, tapered by scissors at the neck and ears. No fades, no
undercuts, no buzz cuts, no cropped or spiked tops. Default hair colour dark brown
`#2c1e18` on the cream background. Done and kept: `slick_back`, `pompadour`,
`curly_crop`, `wavy_mop` (round 4), `side_part`, `deep_part`, `wavy_side` (round 6),
`brushed_back` (round 7).

| style | line |
|---|---|
| `side_part` | Hair: a classic side part, combed flat and neat, the parting a straight carved groove on the left of the crown, the larger side swept across to the right in a few fat locks, short and tapered at the sides and back, both ears fully showing, a soft scissor-tapered hairline at the nape. |
| `deep_part` | Hair: a deep side part, the parting low on the left, the heavy side combed across the crown to the right in one thick rolling wave that lifts a little above the forehead, the small side combed flat, sides and back short and tapered, ears clear. |
| `slick_back` | Hair: slicked straight back from the forehead in a few fat locks lying side by side, tight at the sides, a straight front hairline, the back one rounded cap ending in a clean line at the nape. |
| `brushed_back` | Hair: brushed straight back from the forehead with volume, every lock running from the forehead toward the nape, nothing hanging over the forehead and no fringe, the mass lifting off the forehead then lying flat over the crown, the sides combed back over the tops of the ears, ending in a soft tapered line at the nape. |
| `pompadour` | Hair: a classic pompadour, a tall rounded mass swept up and back off the forehead, the volume sitting above the forehead, the sides combed back and tapered by scissors, the back smooth and swept down toward the nape. |
| `ivy_league` | Hair: an ivy league cut, short all over: the sides and back scissor-tapered short above the ears and the collar, the top no longer than two finger widths and combed neatly to one side in a few flat locks with a light side part, the forehead fully clear, no fringe and nothing shaggy. |
| `wavy_side` | Hair: wavy hair with a side part, combed over from the left in big soft rolling waves that lift off the forehead, the sides combed back over the tops of the ears, the back in rounded waves down to a tapered nape. |
| `centre_part` | Hair: a nineteen twenties centre part, parted straight down the middle and combed flat to both sides in a few smooth locks, short at the sides and back, ears clear, a straight front hairline. |
| `long_swept` | Hair: collar-length hair swept back behind the ears in thick loose locks, the front lifting off the forehead, the ends curling out at the nape and behind the ears. |
| `short_neat` | Hair: short neat hair, scissor cut, the top combed forward and a little to one side in soft locks, the sides combed down and tapered, a natural hairline, ears clear. |
| `curly_side` | Hair: short natural curls combed to one side, big soft rounded curls over the crown and forehead, tidy and trimmed close at the ears and nape. |

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
The hair is chunky, sculpted like modelling clay on a collectible toy figure, with real
thickness standing off the skull: the whole head has only about a dozen big fat locks,
each lock as thick as a thumb, a soft rounded clump with one blunt rounded tip, the
locks overlapping in the direction the hair is combed with a deep soft groove where two
locks meet. Every style is scissor cut and combed: the hair is long enough to lie in
locks everywhere it grows, and nowhere is it shaved, faded, stubbled or shorter than a
finger's width. The fringe, the temples and the nape end in a few big tufts, not one
smooth edge. Big simple shapes: no fine comb lines, no thin strands, no scales, no feathering,
no fuzz, one hair colour with no lighter streaks. Both views show the same hairstyle from
opposite sides, and the back view shows the nape and the backs of the ears. The image has
a plain flat background of one colour, no floor, no shadow, no gradient, no glow, no
bloom, no rim light, no lens blur, no depth of field, no vignette, no specular
highlights. The colours are only: skin #e4b083, hair {HAIR}, background {BG}. No eyes, no
eyebrows, no nose, no mouth, no glasses, no hat, no shoulders, no body, no text, no
watermark, no signature, no border, no frame.
```

For a bald sheet use the short form: drop the two hair sentences and "hair {HAIR}," from
the palette.

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

First egg run: the layout, blank face, disc ears, neck cut and flat background all held
on the first try. The model offered two skulls; the owner chose the tall egg (widest at
the ear line, tapering to a narrow chin, 0.84 as wide as tall without ears). That sheet
is the BASE for stage 2: `IMPORT/CHARREWORK/ref/heads/egg_bald.png`. The `squat` line
above is the wider, fuller-cheeked alternative if a second base is ever wanted.

Stage 2 with the base attached keeps the cream background, so use silver `#8e9196` for
older hair on it. For white hair add "and change the background to a flat slate
#3e4a55" to the edit prefix, since white on cream has no edge.

## Round 2 (2026-09-25)

Horseshoe (silver) and side part (dark brown) on the base: layout, blank face, colours
and keyable edges all held. The hair came out as one smooth helmet with three grooves,
because the old suffix asked for "a few solid masses". The owner wants the hair as rich
as his own AC-style sheet (many layered locks, tufts, volume). The suffix now asks for
overlapping locks laid like roof tiles with tufted edges, and the edit prefix takes that
sheet as a second image to set the level of detail. At gameplay distance (head about 25
px tall) only the silhouette and the outline read, so detail that changes the outline
(tufts at the fringe and nape, lift off the forehead) matters more than surface grooves.

## Round 3 (2026-09-25)

First four-up batch (G1): grid, cells, styles and blank faces all held, so batches
are the way to spend generations. The hair overshot into fine detail: comb lines on
the slick back, pea-sized curls, scale-like tufts. Cause: "many overlapping locks laid
like roof tiles". The suffix now gives a count and a size (about a dozen locks, each as
thick as a thumb, blunt rounded tips) and bans comb lines, thin strands, scales and
feathering. The curly crop, textured crop, slick back and coils lines were reworded to
name big shapes. Target is the owner's single side-part result and his AC-style sheet.

## Round 4 (2026-09-25)

G1 with the chunky suffix and the labelled AC sheet as the second image: the target
chunkiness, first try. Slick back and pompadour kept; curly kept, though the curls came
as perfect spheres (say "flat rounded scrolls, not balls" to soften that); the cell
pointed at the sheet's "Textured Crop" came back as a wavy mop instead, kept as
`wavy_mop`, and that label was dropped from the map. Textured crop moved to G3 as a
plain line.

## Round 5 (2026-09-25)

G2 (crew cut, buzz, quiff, undercut) came back fuzzy and clipper-textured, and the owner
does not want those cuts at all: "gentlemen's and old money haircuts, not teenage ones".
The gentlemen list was rebuilt around scissor-cut, combed styles (deep part, brushed
back, wavy side, twenties centre part, collar-length swept back, short neat, curly side)
and the suffix now bans shaved, faded and stubbled hair on every run. The four styles
kept from round 4 stay. Also seen: with four styles the model sometimes lays out fronts
on the top row and backs on the bottom row instead of the grid; crop accordingly.

## Round 6 (2026-09-25)

G2 on the old-money list: chunkiness, blank faces and layout all held. Side part and
deep part as asked; brushed back came out as a wavy side style (kept as `wavy_side`);
ivy league came out as a shaggy mop (dropped). "Rolling back" and "curling at the nape"
read as waves and a fringe; "just long enough" read as long. Both lines now say what
must NOT be there (no fringe, forehead clear, nothing shaggy) and give lengths. The
model also drifts the hair hex lighter each run; harmless, the game recolours.

## Round 7 (2026-09-25)

G3: brushed back kept. Ivy league came with a fade (the sheet's cell has clipped sides,
the label pulled it in), the twenties centre part came as a floppy long centre part
(owner to decide), long swept became spikes. Pattern over three batches: styles the
model knows by name land first time, styles built from length descriptions drift. Added
the VARIANT PREFIX: edit a cropped keeper and ask for the difference. Remaining
gentlemen styles go that way (V1, V2 in the batch plan).

## Check before Tripo

- Both views the same size on one baseline, front left and back right; the back view
  really is a back (nape, ear backs), not a second front.
- Face blank. The model likes to sneak in eyebrows or a mouth; reject those runs.
- Hair reads as a few solid masses with grooves. Fuzzy or strand-by-strand hair comes out
  of Tripo as blobs.
- Neck stub present and cut flat, no shoulders.
- Background flat with no shadow under the head.

# Face style guide — cut-paper faces

The owner picked the cut-paper collage row (J1–J4) of `IMPORT/faces_proc/ref/style_sheet_3_GIJ.webp`
on 2026-09-25. Every face asset, drawn by the shader or generated, follows these rules so that all
customers look like they were cut from the same stack of paper. The face is drawn by
`assets/shaders/skin_face.gdshader` on the head material at the baked face UV (see
`docs/CHARACTER_PIPELINE.md`), from a `FaceStyle` preset in `data/face_styles/`.

## 1. Medium

- Every feature is a **flat piece of coloured paper** laid on the skin. There are no drawn lines,
  no outlines, no highlights, no gradients, no shading inside a piece.
- A piece has a **crisp cut edge** with a slight hand-cut wobble, a faint **lighter rim** where the
  white paper core shows at the cut, **fibre grain** over its fill, and a **soft shadow** under it
  where it lies on the layer below. That shadow is what makes the face read as layered paper.
- Layer order, bottom to top: skin, cheeks, eye whites, pupils, lids, brows, nose, mouth pieces.

Paper treatment numbers, in fractions of face height unless stated (tune once, then shared):

| Treatment      | Value                                        |
|----------------|----------------------------------------------|
| Shadow offset  | 0.006 down, 0.004 to the character's right    |
| Shadow         | dark paper colour at 22 % alpha, 0.008 soft  |
| Cut rim        | 0.004 wide, cream at 30 % alpha, inside edge |
| Edge wobble    | 0.003 amplitude, ~6 waves per piece           |
| Grain          | 4 % contrast fibre noise, fixed in face space |

At the gameplay camera (head ≈ 25 px) only the shapes survive; the treatment shows in the customer
portrait, the fitting screen and any close-up. That is intended.

## 2. Palette (closed)

| Paper        | Hex       | Used for                         |
|--------------|-----------|----------------------------------|
| Dark         | `#3a2418` | pupils, mouth, teeth lining      |
| Brow brown   | `#7a4a2a` | brows                            |
| Cream        | `#fff4e2` | eye whites, teeth                |
| Rose         | `#d98c7e` | nose, cheeks, tongue             |
| Skin         | per head  | lids (a skin-coloured piece)     |

No other colours. Eye colour does not tint anything in this style; iris colour is retired.

## 3. Pieces

Sizes are fractions of **face width** (fw) and **face height** (fh) of the baked face rect, so one
preset lands the same on every head.

- **Brow**: a thick rounded strip. Thickness 0.045–0.065 fh (these are thick brows, on purpose),
  length 0.16–0.26 fw, angle −15°…+15°, arch 0–0.35, height 0.06–0.30 fh from the top.
  Round ends always.
- **Eye white**: a cream ellipse, 0.10–0.22 fw wide, aspect 0.8–1.4. May be absent ("dot eye").
- **Pupil**: a dark disc, 0.05–0.13 fw. Optional **pie wedge** cut out of it (60°, pointing
  up-inward, showing the white or the skin below), which is the one G-row detail carried over.
  A pupil is never smaller than 0.05 fw so it still reads at 25 px.
- **Lid**: a skin-coloured paper piece that slides down over the eye from above, with its own
  shadow. `lid` 0 = open, 1 = closed. A closed eye shows the lid's lower edge as a gentle
  downward arc plus a thin dark strip (0.012 fh) along it. Blinks animate this piece.
- **Nose**: one rose piece, kinds `disc`, `oval`, `teardrop` (point up), `strip` (tall rounded
  trapezoid). Width 0.06–0.16 fw, height 0.06–0.22 fh, centre at 0.55–0.68 fh.
- **Mouth (idle)**: a thin dark arc strip, thickness 0.018–0.024 fh, width 0.10–0.22 fw, curve
  +0.10…+0.25 (a faint smile), centre at 0.78–0.86 fh.
- **Mouth (open)**: a dark paper oval (aspect from the state), with an optional cream **teeth**
  strip along the top and an optional rose **tongue** disc at the bottom. Both are paper pieces
  with their own shadow.
- **Cheeks**: optional rose discs 0.06–0.10 fw, outside-below the eyes, on the skin under the
  whites.
- **Moustaches, whisker marks, sparkles, tears**: not in this style.

## 4. The idle face

Every character idles with the **same face**: eyes open, gaze straight ahead, lids at 0
(the heavy-lid look is the single allowed idle variant, `lid` 0.45 with a flat lower edge),
brows at rest, mouth the faint smile. Identity comes from §5, never from an expression.

## 5. What may vary per character

Eye white present or not, eye size, aspect, spacing and height; pupil size and wedge on/off;
brow length, thickness, angle, arch and height within the ranges above; nose kind and size;
mouth width; cheeks on/off; the heavy-lid idle. Nothing else. Colours, the paper treatment, the
stroke thickness ranges and the expression shapes are shared and fixed.

## 6. Expressions (shared states, applied on any face)

| State      | Brows                    | Eyes                              | Mouth                        |
|------------|--------------------------|-----------------------------------|------------------------------|
| blink      | –                        | lid 0 → 1 → 0 in 0.17 s           | –                            |
| happy      | up 0.03 fh, arch +0.1    | pupils −15 %, lids 0.15 curved    | curve +0.6, open 0.5, teeth  |
| sad        | inner ends up, +12°      | lids 0.35 flat, pupils down 0.01  | curve −0.5                   |
| displeased | inner ends down, −12°    | lids 0.30 flat                    | curve −0.2, width −10 %      |
| surprised  | up 0.05 fh               | whites +15 %, pupils −25 %        | small open oval, no teeth    |
| talking    | –                        | –                                 | open pulses 0.05–0.8 around rest |

A face whose idle has heavy lids keeps them; states add to the idle, they never replace it.

## 7. Checking an asset

A new preset or a generated reference is accepted only if: every feature is a paper piece with no
lines; only the five papers are used; sizes sit inside the §3 ranges; the idle matches §4; the
25 px render in `IMPORT/faces_proc/sheet_scale.png` still reads as a face.

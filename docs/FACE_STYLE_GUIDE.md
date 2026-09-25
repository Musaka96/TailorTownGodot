# Face style guide — cut-paper faces

The owner picked the cut-paper collage row (J1–J4) of `IMPORT/faces_proc/ref/style_sheet_3_GIJ.webp`
on 2026-09-25. Every face asset, drawn by the shader or generated, follows these rules so that all
customers look like they were cut from the same stack of paper. The face is drawn by
`assets/shaders/skin_face.gdshader` on the head material at the baked face UV (see
`docs/CHARACTER_PIPELINE.md`), from a `FaceStyle` preset in `data/face_styles/`.

## 1. Medium

- Every feature is a **flat piece of coloured paper** laid on the skin. There are no drawn lines,
  no outlines, no highlights, no gradients, no shading inside a piece.
- A piece has a **crisp, hand-cut edge**: short straight scissor facets and the odd small nick,
  never a perfect curve, and no two edges alike. The exception is an edge that is one real
  straight snip: it is cut clean, with no jag and no nick. Today that is the pupil wedge's two
  sides (`piece_pupil`, `wedge_straight`); the brow ends can go the same way (`piece_brow`,
  `ends_straight`, off). Every other edge stays jagged. It carries clearly visible **paper grain** (speckle
  and short fibres) over its fill, a faint **lighter rim** where the paper core shows at the cut
  (light papers only), and a **soft shadow** under it where it lies on the layer below. That
  shadow is what makes the face read as layered paper.
- Layer order, bottom to top: skin, cheeks, eye whites, pupils, lids, brows, nose, mouth pieces.

Paper treatment numbers, in fractions of face height unless stated (tune once, then shared):

| Treatment      | Value                                        |
|----------------|----------------------------------------------|
| Shadow offset  | 0.006 down, 0.004 to the character's right    |
| Shadow         | dark paper colour at 22 % alpha, 0.008 soft  |
| Cut rim        | 0.003 wide, cream at 25 % alpha, inside edge, skin and cream pieces only (on dark ones it read as a grey ring) |
| Hand-cut edge  | `paper_jag` 0.005: linear value noise, 2 octaves, facets 0.02–0.06 long (a twelfth of the perimeter) and a third of that; about 1 cell in 6 has a V nick one jag deep, 2.5 × as wide; pieces thinner than 0.09 get less, down to a third; seeded per piece |
| Grain          | `paper_grain` 0.10 (was 0.15): soft mottling in 3 octaves of hashed value noise (60 / 170 / 420 per face unit at 0.15 / 0.35 / 0.3), a few soft dark specks (0.35), and long soft fibres: 32 waves per face unit along a streak, 300 across (2.5 × the old length), gently bent (0.02), light ones (0.3) on two directions 35° apart, a few dark ones (0.25) across them; light fibres lift a dark paper less (0.3 of a white one's), so pupils and hair show no scratches. About 5 % contrast (5–95 % spread) on the skin at a 580 px disc, the reference J1 paper 4–4.6 % (the old grain was 10–11 %). Fixed in face space; the constants sit at the top of `face_sdf.gdshaderinc` |

On the head, the reference disc maps to 2.1 × `FaceStyle.face_scale` face-rect widths centred
0.44 + `FaceStyle.face_drop` down the rect (at 2.35 / 0.38 the brows hid under most fringes).
`face_drop` is 0.05 (0.49 in all): the owner wanted the face lower on the head
(`IMPORT/faces_proc/face_drop.png` compares 0.00 / 0.05 / 0.08 on two heads). `face_scale` is 0.8: at
1.0 the face took over the whole head; at 0.8 the brows clear the fringe and the mouth sits above
the chin (`IMPORT/faces_proc/j1_heads.png` compares 1.0 / 0.85 / 0.8 / 0.75). Lids carry their rim and shadow along the lower
edge only, else a closed eye shows a ghost ring; a shadow fades out below one pixel of offset so
25 px faces get no dark outline.

**Paper skin and hair.** With a procedural face the whole character is paper: the head skin all
round the head (`skin_face.gdshader`, `skin_grain` 0.10, `skin_tile` 4.0), the hands and arms and
the hair (`paper_skin.gdshader`, `CharacterRig._paper()`) carry the same grain
(`paper_surface()`). It is sampled at the mesh's own UV1, times a per-material tile (face units per
UV unit, so the fibres come out face-sized): heads 4.0, hair 3.6, the base arms 1.35 (measured:
tripo heads UV1 ~0.47 per mesh unit and the face rect 5.2 × denser in UV2, hair ~0.42, arms 1.39).
UV1 stays on the surface, so the grain never swims when the rig walks or turns; model-space vertex
positions would, on a skinned mesh. Seams only break the noise. The hair keeps `hair_color`; the
strand overlay stays on top by default (`CharacterRig.paper_hair_strands`, false = pure flat
paper hair; owner's pick pending, `IMPORT/faces_proc/paper_char.png`). No cut rim on the head
silhouette. Without a procedural face (the painted sprites) skin and hair keep the flat material.

**Papier-mache surface.** Over the grain, skin and hair carry a papier-mache surface
(`assets/shaders/paper_mache.gdshaderinc`, numbers from a `PaperSurface` preset in
`data/paper_surfaces/`, `CharacterRig.paper_surface`, default `paper_mache.tres`), so the paper
reads at a normal view (head ≈ 140 px, a dialogue portrait or the fitting screen), not only up
close. Two parts, both a HEIGHT turned into the lit normal (surface gradient from screen
derivatives, so no mesh tangents): overlapping torn paper strips (`mache_scale` 1.2 cells per
face unit, a strip up to 2 cells long and 0.8 wide, 85 % of cells carry one, torn edge ±0.09
cells; `mache_strength` 1.0 = each strip 0.008 face units, about 1.5 mm, proud of the one
below, a 0.25-layer lip at the torn edge; `mache_seam` 0.3 = a soft glue shadow just outside
each visible edge and a lighter torn fringe just inside; `mache_tone` 0.04 = each strip ±4 %)
and a scanned paper normal (ambientCG Paper003, creased white paper, CC0, at `scan_scale` 2
tiles per face unit, `normal_strength` 1.0; its colour is off, `scan_albedo` 0). The face pieces
are paper too: the strips' tone and seams stay under them, the relief shows through at 40 %,
and each piece adds its own 0.004 face-unit step (`piece_relief` 1.0) so its cut edge catches
the light. The strips fade out once a cell is under ~15 px (gone under 9 px) and a piece's step
once a face unit is under ~50 px, so a 25 px head keeps its plain silhouette. The head's UV1
is cut into islands across the face, so on the front the strips lie in the face UV (one sheet)
and blend into UV1 round the sides (`FRONT_EDGE`); on the hair the UV islands still cut the
strips into squarish patches. Every variant of the 2026-09-25 experiment
(`IMPORT/faces_proc/mache_variants.png`, `mache_zoom.png`, `tools/shot_mache.gd`) is a preset:
`a_grain` (grain only), `b_paper001`, `c_cardboard002`, `d_paper003` (a scan alone, albedo and
normal at 2 tiles; too faint to read at a normal view), `e_mache12` / `e_mache20` (strips alone),
`f_mache_scan`, `g_mache_strong` (normals and relief 2.0: busy, blotchy highlights). The
strip layer described above is off in the shipped default (see the owner's pick in section 6);
the strips now come from the owner's scan instead.

At the gameplay camera (head ≈ 25 px) only the shapes survive; the treatment shows in the customer
portrait, the fitting screen and any close-up. That is intended.

## 2. Palette (closed)

| Paper        | Hex       | Used for                         |
|--------------|-----------|----------------------------------|
| Dark         | `#3c2515` | pupils, mouth, teeth lining      |
| Brow brown   | `#784a2c` | brows                            |
| Cream        | `#efdcbe` | eye whites, teeth                |
| Rose         | `#d38464` | nose, cheeks, tongue             |
| Skin         | per head  | lids (a skin-coloured piece)     |

Measured on the J1 disc (2026-09-25; the old cream `#fff4e2` and rose `#d98c7e` were brighter and
pinker than the reference). No other colours. Eye colour does not tint anything in this style; iris colour is retired.

## 3. Pieces

Sizes are fractions of **face width** (fw) and **face height** (fh) of the baked face rect, so one
preset lands the same on every head. Disc and ellipse sizes below are **radii**, not full widths
(measured on J1–J4: read as widths they came out half size).

- **Brow**: a thick strip. Thickness 0.065–0.105 fh (thick brows, on purpose; J1's measures 0.10),
  length 0.16–0.26 fw, angle −15°…+15°, arch 0–0.35, height 0.06–0.30 fh from the top. The ends
  are cut square to the strip's chord with corners rounded by `brow_corner` × half the thickness
  (1 = round ends; J1 0.2, squarish), and `brow_taper` makes the inner end thicker (J1 0.2).
- **Eye white**: a cream ellipse, 0.10–0.22 fw wide, aspect 0.8–1.4. May be absent ("dot eye").
- **Pupil**: a dark disc, 0.05–0.13 fw. Optional **pie wedge** cut out of it (60°, showing the
  white or the skin below), which is the one G-row detail carried over. It opens at
  `pupil_wedge_dir` on the left eye (45° = up-inward) and the right eye mirrors it, or with
  `pupil_wedge_mirror` off both open the same way (J1: 3°, both to the viewer's right). A pupil
  pushed past the white's edge is cut by it. A pupil is never smaller than 0.05 fw so it still
  reads at 25 px.
- **Lid**: a skin-coloured paper piece that slides down over the eye from above, with its own
  shadow. `lid` 0 = open, 1 = closed. A closed eye shows the lid's lower edge as a gentle
  downward arc plus a dark paper crescent along it, 0.035 fh thick in the middle and tapering to
  0.4 of that at its round ends (0.012 read as a hairline). Blinks animate this piece.
- **Nose**: one rose piece, kinds `disc`, `oval`, `teardrop` (point up), `strip` (tall rounded
  trapezoid), `shield` (J1's cut pentagon: a wide flat top, shoulders a little uneven, pointing
  down; J1 0.215 wide × 0.146 tall at 0.673). Half-width 0.06–0.16 fw, half-height 0.06–0.22 fh,
  centre at 0.55–0.68 fh.
- **Mouth (idle)**: a dark arc strip of even thickness with round ends, thickness 0.018–0.032 fh,
  width 0.10–0.22 fw, curve +0.10…+0.30 (a faint smile; J1 0.30, 0.030 thick: 0.022 read too thin to the owner), centre at
  0.78–0.86 fh.
- **Mouth (open)**: a dark paper **D**: a straight top edge level with the line's top, a round
  bottom, corners rounded by half the line thickness; shut it is as deep as the smile, open it
  hangs up to 0.9 half-widths deeper. The line morphs into the D over the first 0.12 of opening;
  `mouth_round` rounds the top into an "o". Teeth are ONE flat cream strip along the top edge
  (0.36 of the depth, with its own cut); the tongue is a rose half-disc at the bottom once the
  mouth is open past 0.6. No pinched corners, no bands that thin to nothing.
- **Cheeks**: optional rose discs 0.06–0.10 fw, outside-below the eyes, on the skin under the
  whites.
- **Moustaches, whisker marks, sparkles, tears**: not in this style.

## 4. The idle face

Every character idles with the **same face**: eyes open, gaze straight ahead (J1 is the one
exception: its reference looks to the viewer's right, pupils 0.065 across), lids at 0
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

**Owner's pick (2026-09-26): variant D**, the Paper003 creased-paper scan at 2 tiles with its
normal at strength 1.0 and no procedural strips; the strip variants E-G read as too large a
mess of folds.

**Default since 2026-09-26: `h_gpt_t1`, the owner's own papier-mache texture.** The owner
generated a tileable texture of overlapping torn paper strips
(`assets/textures/paper/mache_gpt_albedo.jpg`, 1K; `mache_gpt_normal.jpg` is its OpenGL
normal, derived from a 40 px high-pass of its luminance at strength 6; a project asset, not
a scan). `data/paper_surfaces/paper_mache.tres` holds it at `scan_scale` 2 tiles per face
unit, `normal_strength` 1.0, `scan_albedo` 0.5 (the skin colour times the scan's luminance
over its own mean, so the head keeps its own tone; half of the scan's light and dark) and no
procedural strips. Compared on `IMPORT/faces_proc/mache_gpt.png` and `mache_gpt_zoom.png`
(`tools/shot_mache.gd -- variants zoom only=... zoom_only=... out=mache_gpt`) against D and
the presets `h_gpt_t3`, `h_gpt_t4` (smaller strips: flat at the 140 px view), `h_gpt_t3_n15`
(normal 1.5), `h_gpt_t3_alb0` / `h_gpt_t3_alb1` (relief only / full light and dark). At 2
tiles a strip is about 5 px on a 140 px head, so it reads there as a fine crumpled paper
rather than as separate strips; `h_gpt_t1` and `h_gpt_t15` (1 and 1.5 tiles,
`mache_gpt_extra.png`) show the strips plainly at that size and are the next step up if the
owner wants them bigger. The 25 px head stays clean with all of them.

## 7. Checking an asset

A new preset or a generated reference is accepted only if: every feature is a paper piece with no
lines; only the five papers are used; sizes sit inside the §3 ranges; the idle matches §4; the
25 px render in `IMPORT/faces_proc/sheet_scale.png` still reads as a face.

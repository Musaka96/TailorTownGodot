# Face style guide — cut-paper faces

The owner picked the cut-paper collage row (J1–J4) of `IMPORT/faces_proc/ref/style_sheet_3_GIJ.webp`
on 2026-09-25. Every face asset, drawn by the shader or generated, follows these rules so that all
customers look like they were cut from the same stack of paper. The face is drawn by
`assets/shaders/skin_face.gdshader` on the head material at the baked face UV (see
`docs/CHARACTER_PIPELINE.md`), from a `FaceStyle` preset in `data/face_styles/`.

## 0. The look as frozen on 2026-09-26 (owner: "okay for now")

Everything that makes a character look like this, so it can be rebuilt or moved:

| Part | File(s) |
|------|---------|
| Face UV bake at load | `data/scripts/face_uv_baker.gd`, `data/scripts/face_frame.gd` |
| Head skin + face shader | `assets/shaders/skin_face.gdshader` + `face_paper.gdshaderinc` + `face_sdf.gdshaderinc` + `paper_mache.gdshaderinc` |
| Hands, arms, hair | `assets/shaders/paper_skin.gdshader` (same mache include) |
| 2D review sheets | `assets/shaders/face_canvas.gdshader` |
| Face preset (J1) | `data/face_styles/paper_j1.tres` (`FaceStyle`, `data/scripts/face_style.gd`; face_scale 0.8, face_drop 0.05, mouth 0.030) |
| Cast presets | `data/face_styles/paper_<name>.tres`, see section 8 |
| Surface preset | `data/paper_surfaces/paper_mache.tres` (`PaperSurface`, `data/scripts/paper_surface.gd`): owner's `mache_gpt` at tile 1, normal 1.0, albedo 0.5, no strips; pieces `piece_paper` tile 2, albedo 1.0, normal 1.5, grain 0.03 |
| Textures (owner-made, project assets) | `assets/textures/paper/mache_gpt_albedo.jpg` + `_normal.jpg`, `piece_paper_albedo.jpg` + `_normal.jpg` (normals derived: 30-40 px high-pass height, strength 4-6) |
| Textures (ambientCG, CC0, kept as alternatives) | `paper001_*`, `paper003_*`, `cardboard002_*` |
| Rig switch | `CharacterRig.procedural_faces` (static), `DEFAULT_FACE_STYLE`, `DEFAULT_PAPER_SURFACE` |
| Sheets | `tools/shot_face_head.gd` (heads, states, side, debug, j1), `tools/shot_faces.gd` (2D refs/states/scale/paper), `tools/shot_mache.gd` (surface variants, zoom, drop, flat, pieces), `tools/shot_paper_char.gd` |
| Generators (git-ignored) | `.dev/make_face_styles.gd`, `.dev/make_paper_surfaces.gd` |
| References | `IMPORT/faces_proc/ref/` (style sheets, J row, owner texture sources) |

Rejected on the way, kept out on purpose: sprite faces, Godot decals, procedural strip relief
(variants E-G), thin brows, expression-as-identity presets, iris colour tinting.

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
| Piece paper    | the owner's sheet paper, see below: `piece_tex_tile` 2 tiles per face unit, `piece_tex_albedo` 1.0, `piece_tex_normal` 1.5 |
| Grain          | on the pieces `paper_grain` 0.03 (0.10 until the piece paper came in, 2026-09-25; the skin and hair keep 0.10): soft mottling in 3 octaves of hashed value noise (60 / 170 / 420 per face unit at 0.15 / 0.35 / 0.3), a few soft dark specks (0.35), and long soft fibres: 32 waves per face unit along a streak, 300 across (2.5 × the old length), gently bent (0.02), light ones (0.3) on two directions 35° apart, a few dark ones (0.25) across them; light fibres lift a dark paper less (0.3 of a white one's), so pupils and hair show no scratches. About 5 % contrast (5–95 % spread) on the skin at a 580 px disc, the reference J1 paper 4–4.6 % (the old grain was 10–11 %). Fixed in face space; the constants sit at the top of `face_sdf.gdshaderinc` |

**Piece paper.** The pieces are cut from one sheet paper the owner generated
(`assets/textures/paper/piece_paper_albedo.jpg`, 1K, seamless neutral grey paper, mean luminance
0.76, 5–95 % spread 0.165; `piece_paper_normal.jpg` is its OpenGL normal from a 30 px high-pass
of its luminance at strength 4; source `IMPORT/faces_proc/ref/piece_paper_src.jpg`; a project
asset, not a scan). It lies in FACE space (the face UV, so it never swims), `piece_tex_tile` 2
tiles per face unit; a piece's colour is its paper colour times the texture's luminance over its
own mean (`piece_tex_albedo` 1.0: the palette stays closed, whites stay cream), and its lit
normal is its cut-edge step plus the texture's normal × `piece_tex_normal` 1.5. The procedural
grain on the pieces drops to 0.03 so the texture is the paper; cut rim, jagged edge and drop
shadow are unchanged. The numbers live on the `PaperSurface` (`piece_tex`, `piece_normal_tex`,
`piece_tex_tile`, `piece_tex_albedo`, `piece_tex_normal`; the skin keeps its own mache scan).
The 2D sheets (`face_canvas.gdshader`) show the normal under a fixed light from the top left
(`PIECE_TEX_SHADE` 0.2). At 4 tiles (the first try) and at 0.7 / 0.7 the fibres were finer than
a pixel at portrait size and the pieces looked plain; at 2 tiles, 1.0 / 1.5 they read as fine
cardstock in the 3× zooms and give a faint tooth at portrait size; the texture averages out
(mipmaps) below that, so the 25 px head is unchanged. Compared on
`IMPORT/faces_proc/pieces_tex.png` (`tools/shot_mache.gd -- pieces`: before, default, strong
1.5 / 2.5, tile 6, then 3× zooms) and `j1_match.png`.

On the head, the reference disc maps to 2.1 × `FaceStyle.face_scale` face-rect widths centred
0.44 + `FaceStyle.face_drop` down the rect (at 2.35 / 0.38 the brows hid under most fringes).
`face_drop` is 0.05 (0.49 in all): the owner wanted the face lower on the head
(`IMPORT/faces_proc/face_drop.png` compares 0.00 / 0.05 / 0.08 on two heads). `face_scale` is 0.8: at
1.0 the face took over the whole head; at 0.8 the brows clear the fringe and the mouth sits above
the chin (`IMPORT/faces_proc/j1_heads.png` compares 1.0 / 0.85 / 0.8 / 0.75). Lids are the skin itself, a layer higher
(the skin's colour, scan and normal, no sheet paper, no rim): only their lower edge shows, by its
step and its shadow on the eye, else a heavy or closed lid shows a pale ghost ring; a shadow fades out below one pixel of offset so
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
carry no strip overlay: each is one flat sheet of its own paper (the piece paper above, cut rim, drop shadow onto
the strips around it), with no scan or strip relief, tone or seam under it (`piece_scan` 0,
blended by the piece's coverage), and a single 0.004 face-unit step at its cut edge
(`piece_relief` 1.0) that catches the light (`IMPORT/faces_proc/pieces_flat.png`). The strips fade out once a cell is under ~15 px (gone under 9 px) and a piece's step
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
| Skin         | per head  | lids (the skin itself)           |

Measured on the J1 disc (2026-09-25; the old cream `#fff4e2` and rose `#d98c7e` were brighter and
pinker than the reference). No other colours. Eye colour does not tint anything in this style; iris colour is retired.
The one exception is the brow paper, which may follow a character's hair: `FaceStyle.brow_color`
(written to `paper_brow`), black `#1f1611` on the noble (`paper_noble`, owner's ask 2026-09-26);
the cast's brow papers are listed in section 8.

## 3. Pieces

Sizes are fractions of **face width** (fw) and **face height** (fh) of the baked face rect, so one
preset lands the same on every head. Disc and ellipse sizes below are **radii**, not full widths
(measured on J1–J4: read as widths they came out half size).

- **Brow**: a thick CUT STRIP of even thickness, never a tapered stroke (owner, 2026-09-26: a
  taper reads as drawn). Thickness 0.065–0.105 fh (thick brows, on purpose; J1's measures 0.10),
  length 0.16–0.26 fw, angle −15°…+18° (> 0 lifts the inner end; +18 is Miss Hartley's worried
  slant, which had to clear J1's own +14 to read), arch 0–0.35 (a gentle bend), height 0.06–0.30
  fh from the top. The ends are cut square to the strip's chord with corners rounded by `brow_corner` × half
  the thickness (0.5 = a quarter of the thickness, the default; J1 0.2, squarer).
  `brow_asym` turns the viewer's right brow alone a few more degrees about its outer end, so it
  sits higher (the noble's haughty brow, 5°; Ms. Portobello's, 14°); keep
  `brow_angle + brow_asym` inside −15°…+18°.
- **Eye white**: a cream ellipse, 0.10–0.22 fw wide, aspect (height over width) 0.75–1.4 (0.77 is
  Ms. Portobello's wide eye). May be absent ("dot eye": the pupil alone is the eye, never cut;
  the white used to cut it away entirely, fixed 2026-09-26).
- **Pupil**: a dark disc, 0.05–0.13 fw. Optional **pie wedge** cut out of it (60°, showing the
  white or the skin below), which is the one G-row detail carried over. It opens at
  `pupil_wedge_dir` on the left eye (45° = up-inward) and the right eye mirrors it, or with
  `pupil_wedge_mirror` off both open the same way (J1: 3°, both to the viewer's right). A pupil
  pushed past the white's edge is cut by it. A pupil is never smaller than 0.05 fw so it still
  reads at 25 px.
- **Lid**: the skin itself, a layer higher, sliding down over the eye from above: the same
  surface as the head round it, so only its lower edge shows (its step and its shadow). `lid` 0 = open, 1 = closed. A closed eye shows the lid's lower edge as a gentle
  downward arc plus a dark paper crescent along it, 0.035 fh thick in the middle and easing to
  0.8 of that at its ends, which are round caps (0.012 read as a hairline; ends thinning to 0.4
  read as sharp points to the owner). Blinks animate this piece.
- **Nose**: one rose piece, kinds `disc`, `oval`, `teardrop` (point up), `triangle` (flat top,
  pointing down, straight sides), `triangle_up` (the same flipped: a flat base, the point up; the
  noble 0.15 wide × 0.24 tall at 0.655), `strip` (tall rounded
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
| happy      | up 0.03 fh, arch +0.1    | pupils −15 %, lids 0.15 curved    | curve +0.6, open 0.5, teeth (a mouth under 0.16 fw opens less, shut at 0.155: a thin smile; the noble is 0.155) |
| sad        | inner ends up, +12°      | lids 0.35 flat, pupils down 0.01  | curve −0.5                   |
| displeased | inner ends down, −12°    | lids 0.30 flat                    | curve −0.2, width −10 %      |
| surprised  | up 0.05 fh               | whites +15 %, pupils −25 %        | small open oval, no teeth    |
| talking    | –                        | –                                 | open pulses 0.05–0.8 around rest |

A face whose idle has heavy lids keeps them; states add to the idle, they never replace it.

**Happy eyes under review (2026-09-26).** The owner does not like the happy row above (the
curved lid on a heavy-lid face slices the white to a half disc and cuts the pupil). The eyes
of the happy state are switchable, `FaceStyle.happy_eye` (one static line; the mouth stays as
above in every mode): **X** `CUT` the row above (still the default until the owner picks);
**A** `BRIGHT` eyes fully open, pupils +10 % and 0.01 up, brows up 0.03 and arch +0.15,
cheeks rise 0.02 (a face without cheeks gets 0.06 rose discs outside-below the eyes);
**B** `SOFT` an upper lid at 0.18 with a curved edge (a heavy lid keeps its flat 0.45), brows
up 0.02; **C** `ARCS` both eyes shut as the closed crescent flipped into an upward arc (same
0.035 strip, round caps; `eye_smile`), brows up 0.03; **D** `TILT` A with each eye turned 6°
outer corner up (`eye_tilt`). Compared on `IMPORT/faces_proc/happy_options.png`
(`tools/shot_faces.gd -- happy`).

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

## 8. The cast

Every character is J1 with different pieces (owner, 2026-09-26): the same paper, the §4 idle and
the §6 expressions; only the §5 pieces change. Unless a character says otherwise the gaze is
straight ahead and any pupil wedge mirrors (opening up and inward); J1's sideways look is J1's
own. The presets come from `.dev/make_face_styles.gd`; `tools/shot_faces.gd -- cast` draws
`IMPORT/faces_proc/cast.png` (states and 25 px) and `cast_zoom.png` (one piece each at 3×),
`tools/shot_face_head.gd -- cast` draws `cast_heads.png` (tripo_head_tl with each hair colour
and glasses, portrait and dialogue size). Hair colour and glasses are set on the rig
(`set_hair_color`, `set_face_look(eye, glasses)`, `glasses_color`); the brow paper follows the
hair where it says so (`brow_color`). "round" glasses are the `wire` part (the legacy key);
frames come in black, tortoise, gold and silver only, so no bright fashion frame yet.

| Character | Preset | Hair | Glasses | Same face | Who | What defines the face |
|-----------|--------|------|---------|-----------|-----|-----------------------|
| J1 | `paper_j1` | default | none | | the base look | the reference: wedge pupils looking right, shield nose |
| the noble | `paper_noble` | black `#1a1410` | none | | bored high society | heavy flat lid 0.45, raised black brows, `brow_asym` 5, nose triangle up, flat mouth 0.155 |
| Mr. Dimmock | `paper_dimmock` | dark `#2a1d15` | never | | the weary: "stopped trying a while ago; almost asleep" | heavy flat lid 0.45 over large whites 0.17, pupils 0.10 centred with the lid over their top (a level, vacant gaze; sunk low they read as staring at the floor), no wedge, set 0.25; long thick dark `#2a1d15` brows (0.25 × 0.10, arch 0.05, set 0.27) raised at the outer ends (angle −8), high at 0.17; small disc nose; the narrowest, flattest mouth (0.10, curve 0.10) |
| Mr. Pettigrew | `paper_pettigrew` | white `#e9e4da` | round, gold | Mrs. Applegarth | the old dear: "the sweetest face in the game" | the biggest round whites 0.20, low (0.50) and wide (0.26), wedge pupils 0.12; short thick brows (0.17 × 0.10) low at 0.255, drooping at the outer ends (+10); the biggest nose (oval 0.16 × 0.11); mouth 0.18; the largest cheeks 0.10 |
| Ms. Portobello | `paper_portobello` | dark auburn `#5e2618` | round, tortoise | Mr. Zanetti | fashion: "sharp and quick; she has already judged your suit" | whites 0.14 wider than tall (aspect 0.77), close set 0.19, pupils pushed 0.065 to the side with J1's sideways wedge; thin long brows (0.26 × 0.065) arched 0.3, inner ends down 5°, the right one 14° higher (`brow_asym`), auburn brow paper `#4a1f14`; small teardrop nose up; wide mouth 0.20 |
| Mr. Bellamy | `paper_bellamy` | dark grey `#4a4746` | none | | the thespian: "a big face for the back row of a theatre" | large round whites 0.18 set wide 0.27, wedge pupils 0.12; the highest, most arched long brows (0.14 from the top, arch 0.35, 0.26 long), grey brow paper `#3a3634`; big shield nose 0.15 × 0.10; the widest mouth 0.22; small cheeks 0.06 |
| Miss Hartley | `paper_hartley` | chestnut `#7a4326` | none | Mr. Rossi, Mr. Penrose | the romantic: "hopeful and a bit worried" | big whites 0.16 taller than wide (aspect 1.18), wedge pupils 0.11; medium brows (0.19) close set 0.21, inner ends up +18 and all but straight (arch 0), her resting shape; small disc nose; small mouth 0.13; cheeks 0.08 |
| Dr. Vance | `paper_vance` | black `#15110f` | round, black | | business: "doing sums while talking to you; tight and level" | dot eyes (pupils 0.06 alone, close set 0.18, a touch high at 0.47); long thick dead-straight brows (0.26 × 0.10, angle 0, arch 0) low at 0.30, black brow paper `#1f1611`; narrow strip nose; narrow mouth 0.12. The other try, small close-set whites 0.11 (`paper_vance_whites`), lost: behind the lenses the cream barely parts from the skin and the dot-in-a-ring stares |

The owner's brow angles were written with the other sign ("−10°, down at the outer ends"); here a
positive angle lifts the inner end, so Pettigrew's +10 and Hartley's +18 are the same slants.

**Future hair meshes (not built; every head above wears tripo_head_tl's hair for now):**
Mr. Dimmock a messy, grown-out fringe; Mr. Pettigrew white wisps or tufts, or a cloud;
Mrs. Applegarth a white bun; Ms. Portobello a sharp bob; Mr. Zanetti a slicked quiff;
Mr. Bellamy long and swept back, or a greying widow's peak; Miss Hartley soft and overdone with
a stray curl; Mr. Rossi and Mr. Penrose a floppy fringe; Dr. Vance short with a hard side
parting.

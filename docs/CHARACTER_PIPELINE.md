# Character pipeline (Tripo -> Rig_Medium)

Status 2026-09-25, branch `characters-tripo`. Since commit 3ef5a9c the game runs on
`CHARTGEN2.glb` (the single-breasted Tripo gentleman): player and customers share that
body, the suit builder's jacket style swaps the jacket model, and the head pool holds the
owner's Tripo heads. `CHARTGEN1.glb` remains only as a reference for dev tools.

## What the owner makes

1. A reference sheet (T-pose, front), then a TripoAI model from it. Same base body every
   time, so proportions stay within a few percent of `CHARTGEN1` (measured: head, span,
   hips, hems all within ~4%; only the trouser hem differs, 2 cm lower).
2. In Blender: split the model into loose shells (Tripo's part output already does most
   of it) and mark UV seams: armholes, sleeve undersides, side seams, centre back,
   shoulder seams, trouser rise and inseams, hairline. Shirt collar seams still wanted.
3. Save the `.blend` into `IMPORT/CHARREWORK/` (gitignored). Seams and the split do not
   survive FBX/GLB export, so the `.blend` is the input.

## What the script does

`tools/blender/tripo_character.py` (headless Blender 5.2):

    blender.exe --background --factory-startup --python tools/blender/tripo_character.py -- \
        --src IMPORT/CHARREWORK/<model>.blend --out assets/characters/<name>.glb --report

- classify shells by geometry into `head` (with ears and neck), `Hair`, `jacket` (with
  flaps, welt, cuff buttons), `shirt` (with the shirt cuffs at the sleeve ends), `legs`,
  `arms` (the hand balls), `shoes`, `tie`, `buttons`, `square`; prints its decisions
- align: scale to 2.248 m, feet on the floor, landmark table against `CHARTGEN1`
- unwrap the cloth meshes along the owner's seams, turn every island so the grain runs
  along its bone, scale to 1 UV unit = 1 m (what `ClothMaterial` expects); shoulder seams
  are cut by the script if the file lacks them
- weights: the most basic rigid rule set, nothing crosses the body (asserted):
  jacket body and tie chest/spine; sleeves own-side upperarm/lowerarm split at the
  armhole seam and STITCHED to the body along the ring over 4 cm; shirt chest, cuffs
  lowerarm; trousers hips/upperleg/lowerleg, one mesh, blended across the centre line;
  shoes foot; hand balls lowerarm; head and hair head. Joint blends: chest, elbow, hip
  4 cm, knee 12 cm. No decimation (the full ~50k-tri Tripo mesh ships; `--decimate` opts in).
- export a glb on the same 22-bone `Rig_Medium` skeleton and re-read it to check.

Verification: `tools/shot_char2.gd` renders the owner's rig next to the new one(s) with
cloth on, `--arm-drop=<deg>` for the shoulder strips, and prints hand-to-cuff and split
measurements; `tools/blender/weight_renders.py` + `tools/weight_sheets.py` make the
per-bone weight sheets; `tools/char_ref_compare.py` overlays the reference images;
`tools/uv_report.gd --glb=` checks UV stretch. Outputs land in `IMPORT/CHARREWORK/report/`.

The calm idle (`CharacterAnimations.calm_idle`, arms straight down) is for these test
renders only. The game keeps the KayKit idle.

## Models so far

| File | Suit | Notes |
|---|---|---|
| `assets/characters/CHARTGEN2.glb` | single-breasted | the BASE character (rig scene built from it); wardrobe top 0 |
| `assets/characters/suit_doublebreasted.glb` | double-breasted | wardrobe top 1, same body; fold seams 45 deg |
| (none yet) | tuxedo | wardrobe top 2 is a placeholder on the single-breasted model, `WardrobePart.placeholder`; the suit builder skips it via `Wardrobe.style_ready` |

Heads: `tools/blender/tripo_heads.py` turns `IMPORT/CHARREWORK/heads.blend` (a shaved
skull with ears + a grid of hair-over-skull heads) into `assets/characters/parts/
tripo_head_*_m.glb` (own skull) and `tripo_bald_*_m.glb` (hair moved onto the shaved
skull, inside vertices lifted 4 mm). The grid skulls differ from the shaved one by 14-21 mm
mean over 810 mm, so ONE skull can carry every hair; heads and hairs are still locked
pairs in the wardrobe (decoupling is the next step).

Rig facts after the swap: model node `Base`; shoes = `shoes` mesh (leather); the top slot
carries jacket, shirt, buttons, square AND tie (each jacket brings its own tie, `tie_color`
tints it); street clothes hide only the square (the tie covers the hole under the collar).

## Next steps (owner's direction)

1. **Tuxedo model** from the owner: drop the .blend in `IMPORT/CHARREWORK/`, run the
   pipeline to `assets/characters/suit_tuxedo.glb`, point wardrobe top 2 at it and clear
   `placeholder`.
2. **Decouple heads and hairs** now that one skull works: pick skull and hair
   independently in the wardrobe / customer dressing; name the styles (tl/tr/bl/br are
   grid positions); more heads through the same script.
3. **Trousers and shirt as real slots**: pleated / shorts bottoms have no models yet
   (they clamp to Flat Front); shirt collar seams from the owner (the shirt front still
   smears); lapel grain; the knee fold in the walk (accept, double-sided cloth, or a hand
   touch); hair budget (3-4k tris each at full res).
4. **Street clothes** through the same slots; until then street = recoloured suit with a
   knit tie.
5. Carry pose feel check on the new body (skeleton unchanged, so probably not new).

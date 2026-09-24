# Character pipeline (Tripo -> Rig_Medium)

Status 2026-09-24, branch `characters-tripo`. The live game still runs `CHARTGEN1.glb`.
Nothing here is wired into gameplay yet; this is the asset route and the plan.

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
| `assets/characters/CHARTGEN2.glb` | single-breasted | first model, all rules above |
| `assets/characters/suit_doublebreasted.glb` | double-breasted | second model, same body |

Planned by the owner: a tuxedo.

## Next steps (owner's direction)

1. **Suits as choices in the suit maker.** The point of these models is not complete
   characters but suit STYLES: single-breasted, double-breasted, tuxedo. Each becomes a
   selectable jacket (with its buttons and square) in the suit maker; trousers, shirt,
   tie and shoes are their own slots. This means the wardrobe grows from head/hair/top/
   bottom to jacket / trousers / shirt / shoes / tie / buttons / square, each a
   `WardrobePart` pulled from a suit glb by mesh name (see `entities/character/
   character_rig.gd` `_attach_from`). Cloth still comes from `set_outfit` per mesh.
2. **Heads and hairs reused for other characters.** Every generated head+hair combo
   goes into the head/hair pool (`tools/build_wardrobe.gd` already scans parts glbs),
   with a `FaceProfile` per head for the sprite face.
3. Shirt collar seams from the owner (the shirt front still smears); lapel grain; the
   knee fold in the walk (accept, double-sided cloth, or a hand touch); hair budget.
4. Street clothes later, through the same slots.

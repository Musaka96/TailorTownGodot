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

Street clothes (commit 23ee6cf): `IMPORT/CHARREWORK/streetclothes.blend` (a 3-figure
sheet) -> `--figure n --street --auto-seams --fold-seams 45` ->
`assets/characters/street_overshirt.glb` (figure 2) and `street_overcoat.glb` (figure 3),
meshes jacket (outer layer) / shirt (inner layer, carved out of the outer shell) / legs /
shoes / arms, no head. Figure 1 (sweater, has a stray cape) is skipped. In the game a
`StreetOutfit` (data/scripts/street_outfit.gd) = top + trousers + shoe model + three
`MaterialType` cloths + a shoe leather; `WardrobeLibrary.street_outfits` holds the two;
customers pick one on arrival (persisted in their Clientele look as `street`), the rig's
`shoes` slot swaps models and restores the base pair in the wearer's own leather at the
suit. Cloth chosen: olive cotton / white cotton / cream cotton + white sneakers; camel
flannel / near-black worsted / charcoal flannel + chestnut shoes (the camel flannel reads
grainy at gameplay size; a smoother wool may sit better).

Glasses (commit cdc5438): `tools/blender/tripo_glasses.py` on `IMPORT/CHARREWORK/glasses.blend`
(a 2x2 grid of bald heads wearing frames) -> `assets/characters/parts/glasses_{round,square,
wire,halfmoon}.glb`, frames only, fitted to the shaved skull, bound to bone `head`. In the
game glasses are no longer sprites: `WardrobeLibrary.glasses` lists the styles, the rig
mounts the frames as plain meshes on a head-bone attachment (placed from the part's bind
pose, pushed forward by `face_z_for(head) - 0.421`), frame colour from
`CharacterRig.GLASSES_COLORS` rides on the customer look (`glasses_color`). Old look values
map: round -> wire, sun -> black square.

Heads: `tools/blender/tripo_heads.py` turns `IMPORT/CHARREWORK/heads.blend` (a shaved
skull with ears + a grid of hair-over-skull heads) into `assets/characters/parts/
tripo_head_*_m.glb` (own skull) and `tripo_bald_*_m.glb` (hair moved onto the shaved
skull, inside vertices lifted 4 mm). The grid skulls differ from the shaved one by 14-21 mm
mean over 810 mm, so ONE skull can carry every hair; heads and hairs are still locked
pairs in the wardrobe (decoupling is the next step).

Rig facts after the swap: model node `Base`; shoes = `shoes` mesh (leather); the top slot
carries jacket, shirt, buttons, square AND tie (each jacket brings its own tie, `tie_color`
tints it); street clothes hide only the square (the tie covers the hole under the collar).

## Faces on the head material (2026-09-25, owner-approved)

The face is not a set of sprites any more. `data/scripts/face_uv_baker.gd` takes the head
mesh at load, moves its vertices into the head bone's rest space, keeps the vertices that
face forward and sit within 15 % of the frontmost depth (that is the flat front; ears and
neck drop out), takes their bounding rect as the FACE RECT and writes it as UV2 (0..1 across
the rect; back vertices pushed 8 units outward so a triangle never crosses the face). The
rebuilt mesh is cached per head. `assets/shaders/skin_face.gdshader` is the head's skin
material (matte, like the old flat material) and composites brows, eyes, cheeks, nose and
mouth at that UV from `assets/shaders/face_sdf.gdshaderinc`; one material copy per rig,
plain uniforms. A `FaceStyle` (`data/face_styles/*.tres`) places the pieces in FACE UNITS
(fractions of the rect), so one preset lands the same on every head; `FaceFrame` holds the
optional per-head nudges. Blink, talk and expressions tween dials on the material. Glasses
are 3D parts on the head bone. `CharacterRig.procedural_faces` switches the mode.

**Live since 2026-09-27:** `procedural_faces` defaults to true, so every rig (player,
customers, portraits, the apprentice, tools) wears a paper face; the painted sprites stay
behind the flag as the fallback. `data/scripts/face_cast.gd` (`FaceCast`) is the cast
registry: `PLAYER` = `paper_j1` (set in `player.gd _dress()`), `MENTOR` = `paper_hemming`
(the tutorial portrait, `mentor_dialog._look()`), `CUSTOMER_PRESETS` = the seven cast faces,
`BY_NAME` = surname -> preset, hair colour, glasses and frame colour (guide section 8, with the
aliases Applegarth, Zanetti, Rossi, Penrose, and the titled nobles Ashcombe and Tewkesbury on
`paper_noble`). `preset_for(name)` gives a cast member their own face and anyone else a
stable pick by a hash of the name; `style(preset)` loads and caches the `FaceStyle` (unknown =
J1). A customer carries `face_style` (a preset name) with the rest of their look:
`CustomerManager._dress()` picks it from the brief's name (a passer-by with no name yet gets
one at random, and a pitch that names them after a cast member puts that face on), a named
cast member always wears their hair colour and glasses (`_wear_cast`, also over older saved
looks), `Clientele.note_customer()` stores it, and a regular's look without it (older saves)
falls back to `preset_for(name)`, so no save version bump. The glasses parts are fitted to
J1's eye spacing (0.226); `_place_glasses()` scales them across by the face's `eye_spacing`
over that (Portobello 0.84, Vance 0.80, Pettigrew 1.15, Bellamy 1.19). Check sheet:
`tools/shot_live_cast.gd` -> `IMPORT/faces_proc/live_cast.png` (everyone dressed through the
game's own path); test: `tools/test_face_cast.gd`.

Why this over sprites and decals: the face sits on the skin, follows the head to 180 degrees
with no float, no sorting against hair, no per-head hand placement; Godot decals take no
custom shader. Style rules live in `docs/FACE_STYLE_GUIDE.md` (cut-paper faces). Review
sheets: `tools/shot_face_head.gd` -> `IMPORT/faces_proc/heads_uv*.png`, 2D sheets
`tools/shot_faces.gd`. Face rects on the tripo heads are ~0.30-0.33 m wide, 0.52-0.59 m
tall (aspect 0.55-0.60); the Base head's is 25 % wider.

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
4. **More street clothes** through the same route (figure 1 once the cape is removed;
   women's outfits); a smoother wool for the overcoat if the flannel grain bothers the eye.
5. Carry pose feel check on the new body (skeleton unchanged, so probably not new).

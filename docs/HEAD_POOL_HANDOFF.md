# Head pool handoff: from Tripo heads to game parts

What the owner hands over after generating the heads with TripoAI, and what the next
session does with it. The reference sheets and their prompts are in
`HEAD_REFERENCE_PROMPTS.md`; the suit pipeline these heads join is in
`CHARACTER_PIPELINE.md`.

## What the pool is for

Customers are assembled from swappable parts on Rig_Medium (`data/wardrobe/
default_wardrobe.tres`, built by `tools/build_wardrobe.gd`). Today the pool has six
head+hair combos. These Tripo heads replace and extend it: one base skull, a set of
gentlemen's hairstyles, a set of older gentlemen's hairstyles, and a few beards. The game
paints its own animated face on the flat face plane, so the heads are blank.

## What the owner delivers

One Blender file, `IMPORT/CHARREWORK/heads/heads.blend` (the folder is gitignored),
with the Tripo output for every kept sheet. The ask is small; the script does the rest.

1. **One Tripo model per kept sheet, untouched.** Same Tripo settings for all of them
   (multi-view, front + back crops of the sheet, texture on). No decimation, no
   remesh, no smoothing. Full resolution is wanted; the script decides the budget.
2. **The bald base too.** `egg_bald` is the skull the script fits under every hairstyle,
   so it must come from the same Tripo run as the hair, not from an older head.
3. **One collection per head, named after the style** exactly as the prompt doc names
   the files: `egg_bald`, `egg_side_part`, `egg_slick_back`, `egg_pompadour`,
   `egg_curly_crop`, `egg_wavy_mop`, `egg_deep_part`, `egg_wavy_side`,
   `egg_brushed_back`, `egg_horseshoe`, and so on. Inside, whatever Tripo produced. If
   Tripo's part segmentation was used and hair came out as its own mesh, keep it as its
   own object; that saves the colour split.
4. **Textures packed.** File > External Data > Pack Resources before saving. The
   hair/skin split works on Tripo's colour texture, so a head without its texture cannot
   be split.
5. **Rough alignment only.** Every head facing Blender's front view (-Y), upright, at
   roughly the same size. Exact scale and position are fitted by the script against the
   base skull.
6. **The 2D sheets** stay in `IMPORT/CHARREWORK/ref/heads/` under the same names, for
   the comparison renders.

Nothing else. No seams, no rigging, no renaming of meshes inside a collection.

## What the next session does

Per head, scripted in headless Blender (start from the working parts of
`IMPORT/char_gen/edit_kg_heads.py`, which did this for the KoseGlave heads):

1. **Split hair from skin.** By Tripo's colour texture: skin reference = median cheek
   colour, hair reference = median crown colour, nearest wins with neighbour votes. Hair
   colours on the sheets were chosen far from the skin (dark browns, silver, white on
   slate) so this is clean. Skip the split where Tripo already delivered hair as a part.
2. **Fit the base skull.** Align `egg_bald` to each head by the ear discs and the neck
   cut, then lift every hair vertex a hair's breadth outside the skull so nothing pokes
   through. Beards are split the same way and kept as a third mesh.
3. **Budget.** Previous parts were 113 to 360 tris per head and 360 to 800 per hair;
   the outline pass and the two-layer hair material only show silhouette and clean
   normals at gameplay size (head about 25 px tall). Decimate to that range and render a
   before/after sheet for the owner. The owner rejected collapse decimation on the suit
   ("way too organic"); on hair, check by eye and keep the full mesh if the silhouette
   suffers.
4. **Rig and export.** Bind skull, hair and beard to bone `head` on Rig_Medium (the rig
   remaps `head` to `head_2` at load, see `CharacterRig._rebind_skin`), export one
   `assets/characters/parts/<style>.glb` per head, gender tag `_m` in the file name.
5. **Wardrobe and faces.** Run `tools/build_wardrobe.gd`; add a FaceLayout per new head
   in `data/face_profiles.tres` (face depth and eye height differ per skull); check in
   `scenes/dev/char_preview.tscn`.
6. **Engine sheet.** godot-runner renders every combo at gameplay distance and in the
   fitting close-up; hand the screenshots to the owner before anything is committed
   as live.

## Decisions for the owner in that session

- **Shared skull or locked combos.** Today heads and hairs are locked pairs (same index).
  With one base skull under every style, hair could be swapped freely on the egg skull
  and the wardrobe decoupled. Other skull shapes (`squat`, `heavy`) would each need
  their own hair set or a shrinkwrap.
- **Hair budget.** Full Tripo hair is around 18k tris. Choose between decimated parts
  and full meshes after seeing the sheet.
- **Beards.** Third mesh under the 2D mouth sprite; the mouth sprite may need lifting
  on bearded heads.

## Kept sheets so far (2026-09-25)

Gentlemen: `egg_slick_back`, `egg_pompadour`, `egg_curly_crop`, `egg_wavy_mop`,
`egg_side_part`, `egg_deep_part`, `egg_wavy_side`, `egg_brushed_back`, optionally
`egg_centre_part_long`. Older: `egg_horseshoe`. Base: `egg_bald`. The older batches
O1 to O3 and the variants V1, V2 in the prompt doc were handed over ready to run.

# Environment reference prompts

Reference sheets for the tailor shop's surfaces and the street outside, made the same way
as the cloth sheets in `CLOTH_REFERENCE_PROMPTS.md`: one image, a fixed reading order, a
closed palette, a real medium named, the anti-AI-look rules from `UI_STYLE_GUIDE.md` §7.1.

What they are for: the same grain-under-dye method that now runs the cloth. Each square
becomes a linear grain tile (mean 0.25) multiplied under the kit's own flat colour, so the
town keeps its cute palette and gets real surface. The colour on the sheet does not have
to match the game; the surface does.

Materials come from what the kit and stations already use (`IMPORT/town_kit` texture names,
`assets/models/stations/*_st_*`): plaster, brick, stone, cobble, kerb, asphalt, terracotta,
wood, paint, paper, cardboard, cork, felt, chalk, canvas, velvet, rug, brass, iron, steel,
enamel, grass, soil, bark, leaves, manhole metal.

Generate at 1536x1024 landscape. Save as `IMPORT/cloth_refs/S_sheet_interior.png`,
`S_sheet_street.png`, `S_sheet_garden.png`. Run each two or three times and keep the one
where the reading order held.

---

## Sheet 1: shop interior (15 squares, 3 rows of 5)

Ten centimetre samples, so wallpaper repeats and wood grain show at scanner scale.

```
A flatbed scanner capture of fifteen sample squares from a tailor's shop, laid face down on
the glass in three rows of five, each ten centimetres square, all the same size, edge to
edge with only a thin line of the black scanner lid between them. Flat, even, frontal light
with no single light source, as a scanner gives. True top-down capture with no perspective.
Surfaces are seen at the scale a scanner shows them, so wood pores, weave and brush marks
are just visible. One brass tailor's pin lies across the lower right corner of the whole
sheet. Two samples sit a degree off square and one has a chipped corner.

Reading left to right, top to bottom, the samples are:
1. fern damask wallpaper, a matte paper with a tone-on-tone fern and scroll pattern in two
   greens, the repeat about eight centimetres, slightly raised ink;
2. lime plaster wall, off-white, soft trowel marks and a fine sand texture, matte;
3. dark green painted wainscot panel, brushed oil paint with faint brush strokes and one
   bevelled panel edge running across it, satin;
4. oak floorboards, two board edges visible, honey brown, open grain, worn matte finish
   with fine scratches along the grain;
5. mahogany furniture veneer, deep red-brown, straight fine grain, French polished to a
   soft sheen;
6. walnut worktable top, mid brown with darker streaks, oiled, small dents and a pencil
   line;
7. solid brass fitting, aged, soft satin gold with fine scratches and a darker patina in the
   recesses;
8. cast iron, black, pebbly sand-cast surface, matte, one small rust spot;
9. brushed steel, cool grey, fine straight brushing, low sheen;
10. cream enamel, glossy painted metal with a slight orange-peel surface and one chip
    showing dark metal beneath;
11. bottle green velvet, dense short pile, matte where brushed one way and lighter where
    brushed the other;
12. wool rug, burgundy ground with a small cream geometric border, flat woven, slightly
    worn;
13. cork board, warm tan, granular, one pin hole;
14. kraft cardboard, brown, corrugation lines showing through, one bent corner;
15. grey felt, thick, matte, fibrous surface, with one white tailor's chalk mark across it.

Real materials, not a drawing and not a render. No gradients, no glow, no bloom, no rim
light, no lens blur, no depth of field, no vignette, no drop shadow, no specular highlights,
no floating particles. The colours are only: fern green #4f6b4a, pale green #9fb894,
plaster #e8e3d8, wainscot green #2f4a39, oak #b98a4e, mahogany #5a2a1e, walnut #6b4a2e,
brass #b08d57, iron #26262a, steel #8e9196, enamel cream #ece1b6, velvet green #1f4a3a,
burgundy #5c1f2a, cork #c8a071, kraft #a8743f, felt grey #7a7a78, chalk #f0efe6, scanner
lid black #0a0a0a. No text, no watermark, no signature, no border, no frame, no horizon,
no people.
```

---

## Sheet 2: shop front and street (15 squares, 3 rows of 5)

Thirty centimetre samples, because brick, cobbles and roof tiles need the room. A matchbox
is the scale cue.

```
A copy-stand photograph of fifteen thirty-centimetre sample slabs of building and street
materials, laid flat on a black felt board in three rows of five, all the same size, edge to
edge with only a thin line of felt between them. One large soft light straight above, so
there is no single direction of shadow, only a gentle darkening in the joints and pits.
True top-down view with no perspective. Surfaces are seen at real size, so mortar joints,
tool marks and grain read clearly. One matchbox lies in the lower right corner of the board
for scale. Two slabs have a broken corner and one has a small weed growing from a joint.

Reading left to right, top to bottom, the slabs are:
1. red clay brick in stretcher bond, five courses, slightly uneven bricks, pale lime mortar,
   some bricks darker than others;
2. sandstone ashlar block, warm buff, tooled face with fine diagonal chisel marks, one thin
   joint;
3. painted render facade, cream, slightly lumpy, with a hairline crack and a patch of
   flaking paint;
4. terracotta roof tiles, plain clay tiles overlapping in three rows, orange-brown with
   moss in the shadows of the overlaps;
5. slate roof, blue-grey, split faces, overlapping in three rows;
6. painted shopfront wood, dark green gloss paint on tongue-and-groove boards, one board
   edge, brush marks, a chip showing older paint beneath;
7. weathered oak door, grey-brown, deep open grain, two iron nail heads;
8. granite cobblestones, grey with pink and black speckle, rounded tops, sand in the joints;
9. kerb stone, granite, one long straight block with a chamfered edge, worn on top;
10. asphalt, black-grey, coarse aggregate, one tar-filled crack;
11. concrete paving slab, pale grey, fine aggregate, a corner broken off;
12. striped canvas awning, cream and green stripes eight centimetres wide, heavy cotton
    weave, faded at one edge;
13. cast iron street furniture, black, sand-cast texture with a raised rope moulding and a
    little rust in the recesses;
14. copper flashing gone green, verdigris mottle over brown copper;
15. pea gravel, mixed tan, grey and white pebbles, loose.

Real materials, not a drawing and not a render. No bloom, no rim light, no lens blur, no
depth of field, no vignette, no added drop shadow, no floating particles. The colours are
only: brick red #9a4a3a, mortar #d9cfb8, sandstone #d4b483, render cream #ece4d2,
terracotta #c46a3c, moss #5c5a35, slate #4a5560, shopfront green #2f4a39, weathered oak
#7a6a58, granite grey #8e9196, granite pink #c9a0a0, asphalt #3a3a3c, concrete #b8b8b4,
canvas cream #ece1b6, canvas green #4f6b4a, iron black #26262a, rust #9a4a2a, verdigris
#6fa08c, copper #7a4a2e, gravel tan #c8b48a, felt black #0a0a0a. No text, no watermark, no
signature, no border, no frame, no horizon, no people.
```

---

## Sheet 3: garden and ground (10 squares, 2 rows of 5)

Thirty centimetre trays, top-down, same board and matchbox.

```
A copy-stand photograph of ten thirty-centimetre trays of garden ground and plant surfaces,
laid flat on a black felt board in two rows of five, all the same size, edge to edge with
only a thin line of felt between them. One large soft light straight above, no single
direction of shadow. True top-down view with no perspective. Everything is seen at real
size. One matchbox lies in the lower right corner for scale. One tray has a fallen leaf on
it and one has a small stone out of place.

Reading left to right, top to bottom, the trays are:
1. mown lawn grass, dense, slightly uneven, a few clover leaves;
2. long meadow grass lying in one direction, with seed heads;
3. dark garden soil, crumbly, a few small stones and a root;
4. bark mulch, brown chips of different sizes;
5. fallen autumn leaves, oak and beech, brown and ochre, dry and curled;
6. clipped box hedge seen from above, small dense dark green leaves;
7. moss on stone, bright green cushions over grey rock;
8. flower bed with small pink and white blossoms among green leaves;
9. river pebbles, rounded, grey and tan, dry;
10. packed earth path, tan, dusty, with a shoe print.

Real materials, not a drawing and not a render. No bloom, no rim light, no lens blur, no
depth of field, no vignette, no added drop shadow, no floating particles. The colours are
only: lawn green #5f8a3e, meadow #8ea04c, soil #3e2e22, bark #5a4633, leaf brown #8a5a2e,
ochre #c9a24a, box green #2f4a39, moss #7fae4f, rock grey #8e9196, blossom pink #e6c6cc,
blossom white #f2f0e8, pebble tan #c8b48a, path tan #b89a6e, felt black #0a0a0a. No text,
no watermark, no signature, no border, no frame, no horizon, no people.
```

---

## After generating

1. Drop the three PNGs into `IMPORT/cloth_refs/`.
2. `tools/cloth_refs/make_grain.py` cuts squares by finding the black gaps, so it works on
   these sheets as they are for the 3x5 layouts; the 2x5 garden sheet needs the row count
   passed. Output goes to `assets/dev/cloth_refs/` as linear grain plus normals.
3. Promotion is a mapping like `promote_grain.py`: square number to kit texture name, into
   `assets/textures/grain/`. The kit's materials then take a grain slot the way the cloth
   shader did, behind a strength dial that defaults to the current look.

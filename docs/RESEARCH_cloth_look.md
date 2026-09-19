# Cloth Look v2 — plan (Cloth Lab + Tier 1/2 material upgrades)

Implementation plan, written 2026-09-19 for a future session to execute. Read
[`PROJECT_STATE.md`](PROJECT_STATE.md) / [`HANDOFF.md`](HANDOFF.md) first as usual.
Everything here was assessed against the current code; file anchors are exact.

**The problem.** The cloth system's pattern side is solid (thread-true weaves, honest
coverage, per-pattern intensity dials — keep all of it), but the *surface* is
lighting-blind: grain and thread relief are baked brightness multiplies on ALBEDO, and
both cloth shaders force `ROUGHNESS 1.0 / SPECULAR 0.0`. A jacket looks the same whether
light rakes across it or hits it head-on, and the five suiting fabrics are near-identical
grayscale noise at gameplay distance — the fabric choice the economy sells is invisible.
Owner approved this plan: build a debug lab first, then Tier 1 lighting upgrades, then
Tier 2 pattern richness. Full analysis in the 2026-09-19 session; the tiers below are
self-contained.

**Current system map** (read these before coding):

| Piece | File |
| --- | --- |
| UV cloth shader (items + worn suits) | `materials/cloth.gdshader` |
| Triplanar variant (shelf rolls) | `materials/cloth_triplanar.gdshader` |
| Outline next_pass | `materials/cloth_outline.gdshader` |
| Material builder + per-pattern tables | `data/scripts/cloth_material.gd` |
| Base .tres generator (globals live here) | `tools/build_cloth_materials.gd` |
| Fabric/pattern texture generator | `tools/build_textures.gd` |
| Contact-sheet preview (far sheet matters) | `tools/preview_patterns.gd` |
| Customer-facing data | `data/scripts/material_type.gd`, `material_factory.gd` |
| Rig cloth application (`CLOTH_UV_SCALE` 6.0) | `entities/character/character_rig.gd` |
| Dev-harness precedent to copy | `scenes/dev/char_preview.gd` |

Non-goals: no garment re-unwrap (see the `garment-uvs-and-fabric-scale` warnings — UVs
are metric and hand-fixed, welding not packing), no SaveCodec changes in Tier 1, no
swatch-UI rework (2D `ui/material_swatch.gd` stays albedo-only for now).

---

## Workstream A — the Cloth Lab (build FIRST; it's the harness for everything else)

A standalone F6 dev scene, sibling of `char_preview`: **`scenes/dev/cloth_lab.tscn`** +
**`scenes/dev/cloth_lab.gd`**. Copy `char_preview.gd`'s skeleton wholesale: root
`Control`, left scroll column of controls (340 px), right `SubViewportContainer` with
`own_world_3d`, its own `WorldEnvironment` + `DirectionalLight3D`. The `.tscn` is just
root node + script (dev scenes are ours to own; never touch the user's map scenes).
Autoloads (`Enums`, `Wardrobe`, …) are available when the scene runs — same as
char_preview.

**Subjects** (dropdown swaps what's in the viewport):

1. **Suit on rig** — one `character_rig.tscn`, `set_outfit()` with a `MaterialType`
   built from the current control state, idle animation, optional slow turntable
   (checkbox). This is the truth view; `tools/shot_rig.gd` outside a running scene
   canNOT show cloth (known trap), but inside a running scene `set_outfit` works —
   char_preview proves it.
2. **Fabric lineup** — 5 rigs in a row, one per suiting fabric (WORSTED_WOOL…LINEN),
   same pattern/colour, so fabric differences are judged side-by-side. Pause their
   `AnimationPlayer`s at a fixed idle frame if 5 animated rigs stutter.
3. **Pattern lineup** — up to 14 rigs (one per `Enums.Pattern`) with a page toggle
   (suitings 0–8 / shirtings 9–13) if 14 is too heavy.
4. **Flat cloth** — a 2×2 m subdivided `PlaneMesh` angled ~30° plus a `CylinderMesh`,
   both with `ClothMaterial.build(mat, 6.0)`. Best view for raking-light checks on
   normals/relief.
5. **Items row** — instanced `entities/items/{material_roll,garment_piece,suit}.tscn`
   with `_apply_visual` fed the current material, to check UV-vs-triplanar parity.

**Controls** (top to bottom; live-update the active materials via
`set_shader_parameter` — rebuild the material only when fabric/pattern change):

- *Material:* Fabric dropdown (`Enums.Fabric` keys), Pattern dropdown, cloth colour
  (a `ColorPickerButton` plus a row of the standard mill colours), accent dye dropdown
  (`MaterialFactory.PATTERN_ACCENTS`, index 0 = Auto via `pattern_color_for`).
- *Existing dials:* `fabric_strength`, `pattern_strength`, `pattern_scale`,
  `pattern_intensity`, `pattern_relief`, `uv_scale`/`tri_scale`.
- *Tier 1 dials* (each with an enable checkbox so any feature can be A/B'd alone):
  `rim_strength`, `normal_depth`, `macro_strength`, and (Tier 2, stub now)
  `shot_strength`, `pattern_color2`.
- *Version presets* — one-click buttons that set ALL dials: **"Current live"** (reads
  the base .tres values), **"Everything off"** (pre-Tier-1 look), **"Tier 1"** (the
  tuned bundle). This is the old-vs-new comparison the owner asked for.
- *Light:* sun azimuth (−180..180), elevation (5..80), sun energy, ambient energy,
  shadows toggle, plus a **"Raking"** preset (low elevation, side azimuth — makes
  normal maps sing or exposes their absence).
- *Camera:* zoom + orbit sliders (as char_preview) plus a **"Gameplay cam"** preset:
  pitch **−55°**, distance **~7.7 m** — copied from
  `scenes/camera/camera_rig.tscn` (`Transform3D` basis = 0.5735/0.8192). Every tuning
  decision must be checked at this preset; close-ups lie.
- *Export:* a **"Copy tuning"** button that builds a GDScript snippet of the current
  values formatted as the `ClothMaterial` tables (`FABRIC_RIM := [...]` etc.) and puts
  it on `DisplayServer.clipboard_set` — tuned numbers paste straight into code.

Lint rules apply (typed vars, member order, ≤100 cols, funcs ≤6 returns); char_preview
shows the compliant idioms for dropdown/slider builders — reuse them.

## Workstream B — Tier 1 shader/texture upgrades

**B0 — plumbing rule (applies to every step).** The base materials
`materials/cloth.tres` / `cloth_triplanar.tres` are GENERATED by
`tools/build_cloth_materials.gd`: every new uniform gets its default there, and the
builder is re-run (then `--import`). Both shaders stay feature-identical. Every new
uniform defaults to **off/0** so that with defaults the frame is pixel-identical to
today — that's the regression guard. New per-fabric values live in `ClothMaterial`
tables indexed by `Enums.Fabric` (8 entries — don't forget the 3 shirting fabrics),
applied in `_apply()` next to the pattern params, with bounds-safe getters like
`pattern_intensity()`.

**B1 — per-fabric rim sheen** (do first; smallest change, biggest read).
Godot spatial shaders have built-in `RIM` / `RIM_TINT`, independent of specular, so the
matte look survives. In both fragment shaders:

```glsl
uniform float rim_strength = 0.0;  // per fabric, set by ClothMaterial
RIM = rim_strength;
RIM_TINT = 0.7;  // mostly light-coloured sheen, slightly tinted by albedo
```

New table (starting values — tune in the lab at the gameplay cam, with the owner):

```gdscript
# Fibre sheen: how much grazing light the fabric catches. Mohair is sold on it;
# flannel is dead-matte. Indexed by Enums.Fabric.
const FABRIC_RIM := [0.08, 0.0, 0.05, 0.35, 0.12, 0.05, 0.08, 0.05]
```

The bright rim inside the existing dark inverted-hull outline is the intended
storybook look — check them together, and check a dark navy vs a pale cloth (rim adds
light, so dark cloths show it more).

**B2 — weave normal maps.** `tools/build_textures.gd` already computes per-thread
crown/dip heights ( `_thread()` for weaves; fabrics have implicit heightfields). Emit
real normal-map PNGs rather than deriving in-shader:

- Fabrics: refactor each `_fab_*` to produce a height array; keep writing the existing
  grayscale PNG from it (unchanged output), and additionally bake
  `assets/textures/fabrics/<name>_n.png` via Sobel on the tiled height (wrap at edges —
  the tile must stay seamless).
- Patterns: only the three woven ones carry relief — bake
  `assets/textures/patterns/<name>_n.png` from the same relief field the G channel uses.
  Flat patterns get no normal (shader falls back to the fabric normal alone).
- Shader: `uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap_anisotropic,
  repeat_enable;` (same for `pattern_normal`), `uniform float normal_depth = 0.0;` then
  `NORMAL_MAP = blended; NORMAL_MAP_DEPTH = normal_depth;`. Blend fabric + woven-pattern
  normals with UDN (`normalize(vec3(a.xy + b.xy, a.z))`) — cheap and fine here. For the
  triplanar shader sample per-axis like the albedo does; with `_weights` power 12 it's
  effectively single-axis, so plain blending is acceptable.
- `ClothMaterial._apply()` sets both normal textures (fabric always; pattern normal only
  for herringbone/houndstooth/sharkskin — a small `PATTERN_HAS_RELIEF` lookup or reuse
  of the existing tex-name mapping).
- **Import gotchas** (both burned us before): new PNGs need their `.import` files set to
  `mipmaps/generate=true`, and normal maps should get `compress/normal_map=1` /
  `roughness/mode=1` (Normal). First `--import` creates the files; edit, re-`--import`.
  `process/fix_alpha_border=false` as the others.
- Once normals carry the relief, the baked G-channel multiply double-darkens — expect to
  drop `pattern_relief` (now 0.85) to roughly half, by eye in the lab. Keep the G channel
  itself: it's what survives at distance after mipmaps flatten the normal map.

**B3 — coloured tweed flecks.** Generalise the grain multiply from scalar to RGB in both
shaders — one-line change, grayscale fabrics render identically:

```glsl
vec3 grain = mix(vec3(1.0), texture(fabric_tex, uv).rgb * 1.75, fabric_strength);
```

Then `_fab_tweed()` scatters sparse neps (1–3 px blobs, ~2% coverage, Poisson-ish via
the existing `_hash`) tinted rust / gold / moss *around the 0.5 neutral* (e.g. neutral
gray ±0.15 toward the fleck hue). Because grain multiplies the cloth colour, flecks
stay harmonious on any dye (navy tweed → dark rusty flecks). No new uniform needed;
`fabric_strength` already scales it.

**B4 — macro breakup.** Texture-free, in-shader value noise (2 octaves of a hash-based
`vnoise`, ~0.35 repeats/m on the same UV/world position the fabric uses):

```glsl
uniform float macro_strength = 0.0;  // ~0.07 tuned
col *= 1.0 + (macro_noise(uv / uv_scale * 0.35) - 0.5) * macro_strength;
```

Purpose: a suit at distance stops being a perfectly flat tint once mipmaps eat the
weave. Keep it subtle enough to be invisible in the close-up view.

**Status (2026-09-19):** A and B1 shipped. Deviation from the B1 snippet above: the
engine's rim is `pow(1 - N·V, (1 - roughness) * 16)`, and with our `ROUGHNESS = 1.0` that
exponent is 0 — a flat brightening, no rim. So the shaders shape it themselves:
`RIM = rim_strength * pow(1 - dot(NORMAL, VIEW), rim_power)` (the engine term is then 1),
with global `rim_power` 3.0 and `rim_tint` 0.4 on the base .tres (0.7 tinted dark cloth
nearly to nothing: navy's linear albedo ~0.03). Roughness stays 1.0, so matte diffuse and
the rim-off regression guard hold. The FABRIC_RIM starting values are subtle at the
gameplay cam — the top-down view mostly sees faces head-on — so tune with the owner.
Lab extras: `rim_tint`/`rim_power` dials, and key=value command-line args for automated
shots (see the header of `scenes/dev/cloth_lab.gd`).

**Recommended order:** A → B1 (playtest with owner) → B2 → B3 → B4 (playtest again,
tune everything via the lab's Copy-tuning button, commit the tuned tables).

## Workstream C — Tier 2 (SHIPPED 2026-09-19, owner asked to keep going)

All three landed: C1 (glen check / tattersall overcheck in the pattern texture's B
channel, `pattern_color2` auto-derived by `MaterialFactory.derive_pattern_color2` —
nothing new in the save), C2 (`shot_strength` per pattern: end-on-end 0.2, sharkskin
0.12), C3 (real poplin weft-rib and oxford basket weaves). The swatch shader gained
the same two-colour + RGB-grain path. Original spec below for reference.

- **C1 — second accent channel.** Pattern textures' **B** channel (currently constant
  0.5) becomes overcheck coverage. `build_textures.gd`: glen check writes its overpane
  to B (fine check stays in R); tattersall splits its two line directions R/B. Shader:
  `uniform vec4 pattern_color2` mixed after the first accent. `MaterialFactory` derives
  colour 2 from colour 1 automatically (e.g. hue-rotate the accent, or a fixed
  blue/rust pairing for glen check — classic Prince of Wales), so **SaveCodec and the
  phone UI stay untouched**; an explicit second dye row is a later premium-mill unlock
  (`Upgrades` pattern). NOTE: B stops being constant — confirm nothing reads it as
  padding, and `preview_patterns.gd` should render it.
- **C2 — shot-cloth two-tone.** End-on-end (currently the blank "solid" texture — it
  finally gets to exist) and sharkskin get a view-dependent warp/weft colour mix:
  `col = mix(col, pattern_color.rgb, fresnel * shot_strength)` with `shot_strength`
  ~0.15, per-pattern table entry (0 for everything else).
- **C3 — dedicated shirting weaves.** `_fab_oxford` (2×2 basket) and `_fab_poplin`
  (fine weft rib) replace the worsted/linen stand-ins in `ClothMaterial.FABRIC_TEX`
  **and** `ui/material_swatch.gd` (the two lists are kept in sync by hand — grep both).

## Validation loop + acceptance

```bash
GODOT="E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
timeout 90 "$GODOT" --headless --path . --script res://tools/build_textures.gd
timeout 90 "$GODOT" --headless --path . --script res://tools/build_cloth_materials.gd
"$GODOT" --headless --path . --import          # + hand-edit new .import flags, re-import
timeout 90 "$GODOT" --headless --path . --script res://tools/preview_patterns.gd
timeout 90 "$GODOT" --headless --path . --script res://tools/validate.gd
python -m gdtoolkit.linter globals data entities stations ui scenes tools main.gd
```

Accept when: (1) all-toggles-off renders identical to today; (2) the 5 suiting fabrics
are tellable apart in the lab's fabric lineup **at the gameplay-cam preset**; (3) the
far contact sheet from `preview_patterns.gd` shows no new moire or brightness shift;
(4) the owner has playtested (rim + normals are feel calls — ask, per
`feedback-testing-and-git`); (5) tuned tables committed, work pushed.

Known traps recap: `shot_rig.gd`/bare-`--script` renders can't show cloth; never
re-unwrap garments; base .tres is generated (edit the builder, not the .tres); the
static `_base` cache in `ClothMaterial` means a rebuilt .tres needs a scene restart;
the outline material is a shared static instance — don't set per-item params on it.

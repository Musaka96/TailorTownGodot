# TailorTown — Session Handoff

For a future Claude (or human) picking this up cold. Read
[`PROJECT_STATE.md`](PROJECT_STATE.md) for *what exists* and
[`ROADMAP.md`](ROADMAP.md) for *what's next*. This file is *how to work here*.

---

## Ready-to-paste session prompt

> You're working on **TailorTown**, a Godot 4.7.2 top-down bespoke-tailoring shop
> sim at `E:/Chewdlaka/Dev/tailor-town`. Read `docs/PROJECT_STATE.md` and
> `docs/ROADMAP.md` first. Key rules: **scenes are hand-owned — never run a scene
> generator or bulk-regenerate `.tscn`** (the old `build_phase1.gd` is gone; the
> user edits scenes in the Godot editor and owns the map). Code is data-driven
> Resources + autoload singletons talking through `EventBus` signals. Before
> committing, run `gdlint`, `tools/validate.gd`, and the relevant
> `tools/test_phase*.gd` headlessly (Godot exe path below); prefer asking the user
> to playtest feel/motion. Write gdformat-clean, typed GDScript the first time.
> Commit finished work and push to `origin/main`.

## The engine & commands

```bash
GODOT="E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
```

Route stderr to `/dev/null` — the RID/leaked-allocation lines Godot prints at exit
are **harmless noise**. Always wrap runs in `timeout 90` (a `--script` that errors
before `quit()` hangs the main loop forever).

```bash
"$GODOT" --headless --path . --import                                 # refresh class_name cache after adding a class
"$GODOT" --headless --path . --script res://tools/validate.gd         # loads every script/scene → .dev/validate.log
"$GODOT" --headless --path . --script res://tools/test_phase6.gd      # smoke tests (phase1..6, save, shift, news, wardrobe)
"$GODOT" --headless --path . --script res://tools/build_character.gd  # rebuild the character rig (import pipeline)
python -m gdtoolkit.linter globals data entities stations ui scenes tools main.gd   # gdlint
python -m gdtoolkit.formatter <files...>                              # gdformat
```

**Screenshots need a GPU — no `--headless`.** Args after `--` are `scene out frames`:

```bash
timeout 90 "$GODOT" --path . --script res://tools/screenshot.gd -- res://main.tscn res://.dev/shot.png 90
```

Scratch/output goes in `.dev/` (git-ignored). The Godot MCP editor bridge may be
live in a session, but the workflow stays builder-script/headless based.

## Rules that save rework

1. **Never bulk-regenerate scenes.** All `.tscn` are hand-owned and edited in the
   editor. Add nodes/models in-editor. The only builders that still touch scenes
   are `build_character.gd` (rig import) and `build_dev.gd` (the `scenes/dev/`
   sandbox, which nests hand-owned scenes as instances — safe). Editing a scene
   from a script/builder risks clobbering the user's map.
2. **gdlint before committing.** Member order: consts → `@export` → public vars →
   private vars → `@onready` → funcs. Funcs ≤6 returns, lines ≤100 cols.
   `gdlintrc` sets max-file-lines 1500 (for the big generators).
3. **Write gdformat-compliant code the first time.** gdformat collapses a
   parenthesised single-string literal onto one line — to keep a long string
   wrapped, split it with `+` concatenation (see `globals/tutorial.gd` `T_*`).
   Use trailing commas in multiline literals.
4. **Warnings are errors.** `var x := <Variant>` fails ("inferred as Variant").
   Type explicitly. New `class_name` needs `--import` before a `--script` run sees it.
5. **`--script` probe gotchas:** use `_initialize()` not `_init()` for autoload
   access; a `SceneTree` script has no `get_tree()`/`get_viewport()` (use `root`,
   `self.paused`); `get_tree().current_scene` is null if you `root.add_child()` a
   scene instead of changing to it — call the method under test directly, or set
   current_scene. Don't `load()` a Config/Pricing-dependent script in a top-level
   member initializer (it compiles before autoloads register).
6. **Shader code** uses `//` comments, not `#`. Matte look = `ROUGHNESS=1.0`,
   `SPECULAR=0.0` (shader) / `SPECULAR_DISABLED` (StandardMaterial3D).
7. **Emoji glyphs** (hand pointer, etc.) need a `SystemFont` with Segoe UI Emoji /
   Noto / Apple fallbacks — Fredoka (the UI font) has no emoji or bold face.
8. **Skinned meshes:** measure height via `Skeleton3D.get_bone_global_pose`, not
   `MeshInstance3D.get_aabb()` (node scale fools it). A glTF with mismatched
   mesh/armature scale can't be fixed in-engine — re-export from Blender with
   transforms applied. `.blend` import is disabled; use pre-exported glTF.

## Architecture conventions

- **Data-driven content:** definitions are `Resource` classes authored as `.tres`;
  no hardcoded item lists. Tunables live in `data/game_config.tres` (`GameConfig`,
  read via the `Config` autoload).
- **Decoupling via EventBus:** systems emit/listen on `globals/event_bus.gd`
  signals instead of referencing each other. (A few read-only cross-manager
  lookups exist and are accepted — see PROJECT_STATE §7.)
- **Composition:** `Interactable` (Area3D) + `CarrySlot` components; each station
  is its own scene with `get_interaction_prompt(actor)` / `interact(actor)`.
- **Stateful stations** implement `save_state()`/`load_state()`; SaveManager now
  discovers them by capability (no capture-list edit needed for a new station).
- **Autoload discipline:** global & save-worthy → autoload; gameplay that resets
  with the scene → node in the scene. Reference autoloads lazily and null-guard
  `UI`/`Shift`/`News`/`Tutorial`/`Upgrades`.

## Testing & git

- Verify non-visual changes with `validate` + the `test_phase*` smoke tests; use
  small (~512px) screenshots sparingly for visual checks. For a number (size,
  count, name), write a tiny headless script that `print`s it rather than reading
  an image.
- **Always check edge cases:** empty/full hands, at-capacity containers,
  insufficient funds, item consumed to zero, save/load round-trip.
- Commit finished work without being asked; push to `origin/main`
  (`https://github.com/Musaka96/TailorTownGodot.git`). Prefer asking the user to
  interactively playtest feel/motion; headless checks are guardrails, not proof of
  feel. End commit messages with the Co-Authored-By trailer.
- The user has lots of in-progress uncommitted scene/asset edits (active model
  work). **Commit only the specific files you changed** — never `git add -A` or
  sweep in their WIP.

## Where things live (quick map)

| Need to… | Look in |
|---|---|
| Add/adjust a station | `stations/<name>/`, wire `UI.open_*` in `ui/ui.gd` |
| Add a UI screen | `ui/`, use the `Style` kit + a `MenuSkin`; check with `tools/check_ui.gd` |
| Change economy/tuning | `data/game_config.tres` (+ `tools/build_config.gd` to regenerate) |
| Add a fabric/material | `data/materials/*.tres` (+ `tools/build_content.gd`) |
| Change order-matching / dress rules | `data/scripts/dress_code.gd` + `data/dress_code.tres` |
| Character look/anim/faces | `entities/character/`, `data/wardrobe|face_*|animations`, `tools/build_character.gd` |
| Save a new bit of state | add `save_state`/`load_state` to the node; SaveManager auto-captures |
| A new cross-system event | declare a signal in `globals/event_bus.gd`, emit + listen |

See also the per-subsystem notes in the auto-memory (character faces/parts/carry,
item-models-and-cloth, phone-upgrades-vendors, reputation-and-newspapers,
save-system, ui-theme-system, tutorial-system).

# Architecture & conventions

How the project is organised and *why*. For the full implemented-system inventory
see [`PROJECT_STATE.md`](PROJECT_STATE.md); for the day-to-day workflow, commands,
and gotchas see [`HANDOFF.md`](HANDOFF.md). This file is the short "principles"
reference.

## Guiding principles

- **Data-driven content.** Definitions are `Resource` classes authored as `.tres`
  (materials, dress rules, news, config, wardrobe). Adding content = adding a
  resource, not code. Tunables live in `data/game_config.tres` (`GameConfig`, read
  via the `Config` autoload) — don't hardcode economy/minigame numbers.
- **Decoupled systems via EventBus.** Systems emit/listen on
  `globals/event_bus.gd` signals instead of referencing each other. A handful of
  read-only cross-manager lookups exist and are accepted (see PROJECT_STATE §7),
  but new coupling should go through a signal.
- **Composition over inheritance.** Behaviour is assembled from small components —
  `Interactable` (Area3D) and `CarrySlot` — not deep class trees. Each station and
  entity is its own scene with one responsibility.
- **Separation of data and view.** A garment's *state* is data on a node; the node
  visualises it. Customers/orders/materials follow the same split.
- **Explicit state machines.** Garment lifecycle (CUT→SEWN), customer modes, the
  day cycle, and the minigames are explicit states, not boolean soup.
- **Autoload discipline.** Global & save-worthy → autoload; gameplay that should
  reset with the scene → a node in the scene. Null-guard optional autoloads
  (`UI`, `Shift`, `News`, `Tutorial`, `Upgrades`) and reference them lazily.

## Naming & style

- Files/folders `snake_case`; classes/nodes `PascalCase`; private members and
  helpers prefixed `_`.
- **Typed GDScript everywhere** (`var speed: float`, typed params/returns);
  `@export` anything a designer should tune. `var x := <Variant>` is an error.
- Member order (gdlint): consts → `@export` → public vars → private vars →
  `@onready` → funcs. Funcs ≤6 returns, lines ≤100 cols.

## Input

Actions are defined in `project.godot [input]`, each binding **both** keyboard and
gamepad on device `-1`. Gameplay reads *actions*, never raw keys, so bindings are
remappable (see `globals/settings.gd`). Movement uses
`Input.get_vector(...)` projected onto the camera's ground axes (camera-relative).

## Scenes are hand-owned

**All `.tscn` are edited directly in the Godot editor and are the source of truth.**
There is no all-scene generator (the old `build_phase1.gd` was deleted). Add nodes/
models in-editor. The only builders that still touch scenes are
`tools/build_character.gd` (the character-rig import pipeline) and
`tools/build_dev.gd` (the `scenes/dev/` sandbox, which nests hand-owned scenes as
instances). Never bulk-regenerate scenes — it clobbers the map.

## Verification

Every change is checked headlessly before commit: `tools/validate.gd` (loads all
scripts/scenes), `gdlint`, `tools/check_ui.gd` (UI style guide), and the relevant
`tools/test_phase*.gd` smoke tests. Prefer asking the owner to playtest feel/motion;
headless checks are guardrails. See `HANDOFF.md` for exact commands.

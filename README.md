# TailorTown

A **top-down 3D bespoke-tailoring shop sim** built in **Godot 4.7.2** (Forward+,
Jolt physics, D3D12 on Windows). You run a Savile-Row-style tailor: order cloth,
cut and sew garment pieces through a hands-on crafting pipeline, design suits for
customers at the mirror, fulfil their orders, and build your shop's reputation
day by day.

> **New to this codebase?** Read [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md)
> for where the project stands and how it's built, and
> [`docs/HANDOFF.md`](docs/HANDOFF.md) for the working rules and a ready-to-use
> session prompt.

## Running

Open the project in Godot 4.7.2+ and press **F5**, or from the command line:

```bash
godot --path .
```

The boot scene is `scenes/menu/main_menu.tscn` (a 3D main menu). `main.tscn` is
the in-game shop scene it loads into.

## The game loop

Phone (order cloth) → Shelf (store the bolt, cut a length) → Worktable (configure
a part + **cutting minigame**) → Sewing machine (**sewing minigame**) → Clothing
rack (hang finished pieces) → Mannequin (assemble a Suit). Customers arrive, sit
at the Mirror, and you design a suit to their **occasion + style** brief within
budget; a confirmed design becomes an **order** with a deadline. Fulfil it well to
earn money and reputation; reputation unlocks premium suppliers and shop upgrades
on the phone. A day is a timed shift you open and close.

## Controls

| Action     | Keyboard        | Gamepad        |
| ---------- | --------------- | -------------- |
| Move       | `WASD` / arrows | Left stick     |
| Sprint     | `Shift`         | —              |
| Jump       | `Space`         | A / Cross      |
| Interact   | `E`             | X / Square     |
| Cut        | `F`             | Y / Triangle   |
| Pause      | `Esc`          | Start          |
| Debug menu | `F3` (debug builds) | —          |

Movement is analog on a gamepad and camera-relative on both — "up" always moves
away from the camera. Bindings are remappable in Settings.

## Project layout

```
main.tscn / main.gd        In-game shop scene; calls SaveManager.notify_game_ready().
globals/                   Autoload singletons (EventBus, GameState, Catalog, Orders,
                           Reputation, Upgrades, News, Shift, DayNight, SaveManager,
                           Tutorial, Config, Sfx, PostFX, Settings, Debug, McpBridgeGame).
data/
  scripts/                 Resource + helper classes (enums, MaterialType, pricing,
                           dress code, orders, config, save codec, wardrobe/faces…).
  materials/ dress_code.tres game_config.tres news/ postfx/ …  authored .tres content.
entities/
  player/                  Player controller, CarrySlot, InteractionController.
  items/                   Carried items: MaterialRoll, FabricPiece, GarmentPiece, Suit.
  customer/                Customer AI + CustomerManager (spawning, fitting flow).
  character/               Shared skinned CharacterRig (modular wardrobe + 2D faces).
stations/                  phone, shelf, worktable, sewing_machine, clothing_rack,
                           mannequin, mirror, bookshelf, trash_can.
ui/                        UI autoload + every screen, the Style theme kit, minigames.
scenes/                    world/ (shop_room — the map), player/, camera/, menu/, dev/.
tools/                     Headless builders, validate.gd, check_ui.gd, test_phase*.gd,
                           shot_*.gd render tools. NOT shipped with the game.
docs/                      PROJECT_STATE, HANDOFF, ROADMAP, ARCHITECTURE, style guide.
```

## Development

See [`docs/HANDOFF.md`](docs/HANDOFF.md) for the full workflow. In short: scenes
are **hand-owned** (edited in the Godot editor — there is no scene generator to
run); code changes are verified headlessly with `tools/validate.gd`, `gdlint`,
and the `tools/test_phase*.gd` smoke tests before committing.

Git remote: `https://github.com/Musaka96/TailorTownGodot.git` (branch `main`).

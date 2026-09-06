# TailorTown

A 3D top-down game built in **Godot 4.7** (Forward+, Jolt physics).

## Running

Open the project in Godot 4.7+ and press **F5**, or from the command line:

```bash
godot --path .
```

The main scene is `main.tscn`.

## Controls

| Action    | Keyboard        | Gamepad          |
| --------- | --------------- | ---------------- |
| Move      | `WASD` / arrows | Left stick       |
| Jump      | `Space`         | A / Cross        |
| Interact  | `E`             | X / Square       |
| Pause     | `Esc`           | Start            |
| Quit      | `F10`           | —                |

Movement is analog on a gamepad and camera-relative on both — "up" always
moves away from the camera.

## Project layout

```
main.tscn / main.gd        Entry scene; composes level + player + camera.
globals/                   Autoload singletons (GameState).
scenes/
  player/                  Player: CharacterBody3D controller + scene.
  camera/                  CameraRig: smooth top-down follow camera.
  world/                   Level scenes (greybox playground for now).
assets/                    Art/audio (models, materials, audio).
tools/                     Editor/build scripts, not shipped with the game.
docs/                      Architecture notes and conventions.
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for conventions and the
reasoning behind the structure.

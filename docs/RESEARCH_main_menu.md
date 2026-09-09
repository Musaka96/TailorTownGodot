# Research — main-menu / front-end options for TailorTown

Prep notes for when we flesh out the front-of-house (main menu, options, credits,
key rebinding). Written 2026-09-09.

## Where we are now

We already ship a **bespoke, code-built front end**:

- `scenes/menu/main_menu.tscn` → `ui/main_menu.gd` (New Game / Continue / Load / Quit)
- `ui/pause_menu.gd` (Resume / Save / Load / Main Menu / Quit), built at runtime by `ui.gd`
- `globals/save_manager.gd` — full save/load to `user://saves`, plus autosave
- `ui/menu_kit.gd` + `ui/style.gd` — the atelier look (Savile Row palette, brass, paper)

So we do **not** need a template to "get a menu". The open question is only what to
pull in for the *options* surface (video/audio/controls settings, key rebinding,
resolution) that we haven't built yet.

## The realistic options

### 1. Keep bespoke, borrow patterns (recommended)

Build the Options menu ourselves with `MenuKit`/`Style` so it matches the shop, and
copy the **settings-persistence patterns** (not the scenes) from an MIT template.
Everything reads as one game, and it plugs straight into our existing `Config` /
`SaveManager` rather than fighting a second UI framework and a second save system.

- Pros: consistent art, no dependency, no duplicate save/settings systems.
- Cons: we write the settings screen + audio-bus/resolution/rebind glue ourselves
  (a day or two of work, most of which is the rebind UI).

### 2. Maaack's Menus Template — the reference to crib from

[Godot Asset Store](https://store.godotengine.org/asset/maaack/maaacks-menus-template-addon/) ·
[GitHub](https://github.com/Maaack/Godot-Menus-Template) · **MIT** · Godot 4.7 (4.4+).
The most popular, actively maintained menu template (last updated 01 Sep 2026).
Includes main menu, options menus, **pause menu, credits, key rebinding, audio
controls, scene loader**, gamepad support, 640×360→4K.

- Best use for us: **reference implementation** for key rebinding and audio-bus
  wiring — the parts we don't have. Its own theme is generic, so adopting it
  wholesale would clash with our atelier kit, and it brings its own settings/scene
  flow that overlaps our `SaveManager`.
- If we ever wanted its scene-transition/loader polish, it's the cleanest source.

### 3. Lighter templates (fallback references)

- [Godot 4 Main Menu Template](https://godotengine.org/asset-library/asset/954) — Play/Options/Quit, video + audio tabs. Minimal.
- [Easy Menus](https://godotassetlibrary.com/asset/V9TnH2/easy-menus) — main/options/pause, keyboard+gamepad, autosaves settings. Small and focused.
- [Menus Plugin](https://godotassetlibrary.com/asset/VpIqk4/menus-plugin) — includes a **Save/Load menu** node (worth a look for slot-UI ideas, though ours already works).
- [Chris-Baker/godot-game-template](https://github.com/Chris-Baker/godot-game-template) — main/options/pause/credits/scene-loader, MIT.
- [SimpleTemplateMainMenu](https://github.com/Unchained112/SimpleTemplateMainMenu) — reusable settings menu with Video/Audio/Controls tabs, Godot 4.7.

## Recommendation

Go with **Option 1**: keep our bespoke menu + save system, and build the Options
screen in `MenuKit`/`Style`, lifting the **key-rebinding and audio-bus code** from
Maaack's MIT template as a reference. That keeps one coherent art style and one save
system while saving us the fiddly rebind/resolution plumbing.

### Concrete next steps when we build it

1. Add an **Options** entry to `main_menu.gd` and `pause_menu.gd`.
2. New `ui/options_menu.gd` (built with `MenuKit`): tabs for Audio (master/music/sfx
   via `AudioServer` buses), Video (fullscreen/vsync/resolution), Controls (rebind
   the existing `InputMap` actions — we already have move_*/interact/pause/etc.).
3. Persist settings **separately from save slots** — a small `user://settings.cfg`
   (`ConfigFile`) loaded by `Config` at boot, so settings are global, not per-save.
4. Credits screen (cheap, do it with a scrolling `RichTextLabel`).
5. First-launch defaults + an "apply/reset to defaults" affordance.

Sources: the asset pages linked above.

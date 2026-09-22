# Continuous builds

Every push to GitHub builds the Windows export on this PC and marks the commit
green or red. The workflow is `.github/workflows/build.yml`. The steps are in
`tools/ci/build.ps1`, which also runs by hand from any clone.

## Why a runner on this PC

The game loads about 40 files from `IMPORT/` (town kit glTFs, station models,
textures). `IMPORT/` is gitignored and weighs 1.7 GB, so GitHub's own machines
can't build a working game. A self-hosted GitHub Actions runner builds here,
with the art and the Steam Godot that are already on disk. It costs nothing,
and after the first build it only re-imports what changed.

The catch: builds only run while the PC is on. Pushes made while it's off
queue up and build when the runner comes back (the newest push per branch wins).

## What a build does

1. Checks out the pushed commit into the runner's own folder (never this working copy).
2. Mirrors `IMPORT/` in from `E:\Chewdlaka\Dev\tailor-town\IMPORT`. It only reads that folder and copies what changed.
3. `godot --headless --import`
4. `tools/validate.gd`: every script and scene must load.
5. Exports the `TailorTown` preset to `E:\Chewdlaka\Dev\TailorTown-builds\TailorTown-<version>-<branch>-<sha>\TailorTown.exe`. The newest 15 builds are kept.
6. Smoke test: boots the exported exe headless to the main menu and quits. Fails on a crash, a non-zero exit or a script error.
7. Uploads the exe to GitHub only for a `v*` tag, or a manual run (Actions tab > Build > Run workflow). A regular push doesn't upload, because the exe is about 900 MB.

Note that `IMPORT/` is not versioned. A build uses whatever art is on disk at build
time, not the art as it was at that commit.

## One-time setup

1. On GitHub: repo **Settings > Actions > Runners > New self-hosted runner**, pick Windows x64. It shows download and `config.cmd` commands with a one-time token.
2. Run them in PowerShell from a folder outside the repo, e.g. `E:\actions-runner`. When `config.cmd` asks:
   - runner group: Enter
   - name: Enter (or `tailortown-pc`)
   - **additional labels: `tailortown`** (the workflow targets this label)
   - work folder: Enter
   - run as service: **Y**
   - service account: your own Windows account (`.\<username>`) plus its password. The default NETWORK SERVICE account may not be able to read `E:\`.
3. Check that the runner shows as Idle on the Runners page, then push any commit and watch the Actions tab.

The first build imports everything from scratch and takes a while. Later builds
reuse `.godot/` in the runner folder.

## Security: this repo is public

A self-hosted runner runs whatever a workflow tells it to, on this PC. The
workflow never runs on `pull_request`, but a fork's pull request could add that
trigger. In **Settings > Actions > General**, under approval for fork pull
request workflows, pick the strictest option (approval required for all
outside contributors). Never approve a run from a PR you haven't read.

## Changing things

- Godot path, art source, preset: parameters at the top of `tools/ci/build.ps1`.
- Where builds go and how many are kept: `BUILD_STORE` / `KEEP_BUILDS` in the workflow.
- Adding the `tools/test_*.gd` suites as a gate: add steps to `build.ps1` after Validate.

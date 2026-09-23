<#
.SYNOPSIS
  One CI build of TailorTown: sync the untracked art, import, validate, export.

.DESCRIPTION
  Run by .github/workflows/build.yml on the self-hosted runner, and runnable by
  hand from any clean clone. IMPORT/ is gitignored (1.7 GB of Blender exports and
  asset packs), so it is mirrored in from the working copy that owns it. The
  mirror is one-way: the source folder is only ever read.

  The export lands in <OutDir>/TailorTown.exe. Exit code is non-zero if any step
  fails.

.EXAMPLE
  ./tools/ci/build.ps1 -OutDir E:/builds/test
#>
param(
    [string]$Godot = 'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [string]$ImportSource = 'E:\Chewdlaka\Dev\tailor-town\IMPORT',
    [string]$Preset = 'TailorTown',
    # Debug matches the editor's Export dialog default ("Export With Debug"),
    # which is how playtest builds are made.
    [ValidateSet('debug', 'release')][string]$Mode = 'debug',
    # Fails the build if the exe grows past this. The size is mostly art: when
    # this trips, run tools/report_unused_assets.gd before raising the number.
    [int]$MaxSizeMB = 650,
    [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$LogDir = Join-Path $ProjectDir '.dev\ci'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Step([string]$name) { Write-Host "`n=== $name ===" }

# Godot's Steam exe is GUI-subsystem: `&` neither waits for it nor shows its
# output, so run it through Start-Process and echo the log afterwards.
function Invoke-Godot([string]$name, [string[]]$GodotArgs) {
    $out = Join-Path $LogDir "$name.out.log"
    $err = Join-Path $LogDir "$name.err.log"
    $allArgs = @('--path', "`"$ProjectDir`"") + $GodotArgs
    $p = Start-Process -FilePath $Godot -ArgumentList $allArgs -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $out -RedirectStandardError $err
    Get-Content $out, $err -ErrorAction SilentlyContinue |
        Where-Object { $_ -notmatch 'leaked|RID allocations|still in use|PagedAllocator|Storing File' } |
        Write-Host
    return $p.ExitCode
}

if (-not (Test-Path $Godot)) { throw "Godot not found at '$Godot'." }
if (-not (Test-Path $ImportSource)) { throw "IMPORT source not found at '$ImportSource'." }

Step 'Sync IMPORT'
# /MIR copies only what changed since the last run, so after the first build
# this takes seconds. Robocopy exit codes below 8 mean success.
robocopy $ImportSource (Join-Path $ProjectDir 'IMPORT') /MIR /NFL /NDL /NJH /NP /R:2 /W:2 | Write-Host
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)." }

Step 'Import'
# Imports new or changed assets into .godot/ and registers class_name globals.
# The runner keeps .godot/ between builds, so only the first import is slow.
$code = Invoke-Godot 'import' @('--headless', '--import')
if ($code -ne 0) { throw "Import failed ($code)." }

Step 'Validate'
$code = Invoke-Godot 'validate' @('--headless', '--script', 'res://tools/validate.gd')
$vlog = Join-Path $ProjectDir '.dev\validate.log'
if (Test-Path $vlog) { Get-Content $vlog | Write-Host }
if ($code -ne 0) { throw "Validate failed ($code)." }

Step 'Export'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$exe = Join-Path (Resolve-Path $OutDir).Path 'TailorTown.exe'
Remove-Item $exe -ErrorAction SilentlyContinue
$code = Invoke-Godot 'export' @('--headless', "--export-$Mode","`"$Preset`"", "`"$exe`"")
if ($code -ne 0 -or -not (Test-Path $exe)) { throw "Export failed ($code)." }
$sizeMB = [int]((Get-Item $exe).Length / 1MB)
Write-Host ("Exported {0} ({1:N0} MB, budget {2} MB)" -f $exe, $sizeMB, $MaxSizeMB)
if ($sizeMB -gt $MaxSizeMB) {
    throw "Build is ${sizeMB} MB, over the ${MaxSizeMB} MB budget. See docs/CI.md."
}

Step 'Smoke test'
# Boot the exported game headless to the main menu and quit. Catches what only
# breaks in an export (remapped resources, stripped files) and crashes on exit.
$out = Join-Path $LogDir 'smoke.out.log'
$err = Join-Path $LogDir 'smoke.err.log'
$p = Start-Process -FilePath $exe -ArgumentList '--headless', '--quit-after', '120' -Wait -PassThru `
    -RedirectStandardOutput $out -RedirectStandardError $err
$lines = Get-Content $out, $err -ErrorAction SilentlyContinue |
    Where-Object { $_ -notmatch 'leaked|RID allocations|still in use|PagedAllocator' }
$lines | Write-Host
$scriptErrors = $lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Failed to load' }
if ($p.ExitCode -ne 0) { throw ("Exported game exited with code {0} (0x{0:X8})." -f $p.ExitCode) }
if ($scriptErrors) { throw "Exported game logged script errors." }
# Content folders listed at boot must not come up empty in the export.
if ($lines -match 'Catalog: 0 materials|News: 0 articles') { throw "Exported game loaded no materials or news." }

<#
.SYNOPSIS
  Developer console for TailorTown. One entry point for the common Godot tasks
  so the engine path and flags live in exactly one place.

.EXAMPLE
  ./tools/dev.ps1 validate      # headless: load every script/scene, report errors
  ./tools/dev.ps1 shot          # render the main scene to .dev/screenshot.png
  ./tools/dev.ps1 shot res://scenes/world/level_playground.tscn
  ./tools/dev.ps1 run           # play the game in a window
  ./tools/dev.ps1 build         # regenerate base scenes from tools/build_project.gd
  ./tools/dev.ps1 format        # gdformat all scripts (needs: pip install gdtoolkit)
  ./tools/dev.ps1 lint          # gdlint all scripts
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('validate', 'shot', 'run', 'build', 'format', 'lint', 'help')]
    [string]$Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
$Godot = 'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'

if (-not (Test-Path $Godot)) {
    Write-Error "Godot not found at '$Godot'. Edit the `$Godot path in tools/dev.ps1."
    exit 1
}

function Invoke-Godot {
    param([string[]]$GodotArgs)
    & $Godot --path $ProjectDir @GodotArgs
    return $LASTEXITCODE
}

# Resolve a Python console script (gdformat/gdlint) from the active interpreter.
function Get-PyScript([string]$name) {
    $scripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
    $userScripts = python -c "import sysconfig; print(sysconfig.get_path('scripts', scheme='nt_user'))" 2>$null
    foreach ($dir in @($scripts, $userScripts)) {
        if ($dir) {
            $exe = Join-Path $dir "$name.exe"
            if (Test-Path $exe) { return $exe }
        }
    }
    $onPath = Get-Command $name -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    return $null
}

switch ($Command) {
    'validate' {
        exit (Invoke-Godot @('--headless', '--script', 'res://tools/validate.gd'))
    }
    'shot' {
        # No --headless: rendering to a PNG needs a real GPU context.
        $godotArgs = @('--script', 'res://tools/screenshot.gd', '--')
        if ($Rest) { $godotArgs += $Rest }
        exit (Invoke-Godot $godotArgs)
    }
    'run' {
        exit (Invoke-Godot @())
    }
    'build' {
        exit (Invoke-Godot @('--headless', '--script', 'res://tools/build_project.gd'))
    }
    'format' {
        $gdformat = Get-PyScript 'gdformat'
        if (-not $gdformat) { Write-Error "gdformat not found. Run: pip install gdtoolkit"; exit 1 }
        & $gdformat (Join-Path $ProjectDir 'scenes') (Join-Path $ProjectDir 'globals') (Join-Path $ProjectDir 'tools') (Join-Path $ProjectDir 'main.gd')
        exit $LASTEXITCODE
    }
    'lint' {
        $gdlint = Get-PyScript 'gdlint'
        if (-not $gdlint) { Write-Error "gdlint not found. Run: pip install gdtoolkit"; exit 1 }
        & $gdlint (Join-Path $ProjectDir 'scenes') (Join-Path $ProjectDir 'globals') (Join-Path $ProjectDir 'tools') (Join-Path $ProjectDir 'main.gd')
        exit $LASTEXITCODE
    }
    default {
        Get-Help $PSCommandPath -Detailed
    }
}

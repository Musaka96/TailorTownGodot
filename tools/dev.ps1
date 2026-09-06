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
    # Start-Process -Wait is used deliberately: PowerShell's `&` does not reliably
    # wait for (or capture the exit code of) Godot's GUI-subsystem exe, which made
    # the wrapper read output files before the engine had finished writing them.
    # Godot's raw stdout/stderr (incl. harmless RID-leak noise it prints at exit)
    # is routed to log files so the console stays clean; commands print their own
    # summaries. Raw logs live in .dev/ if you need them.
    $dev = Join-Path $ProjectDir '.dev'
    if (-not (Test-Path $dev)) { New-Item -ItemType Directory -Path $dev | Out-Null }
    $outLog = Join-Path $dev 'godot.out.log'
    $errLog = Join-Path $dev 'godot.err.log'
    $allArgs = @('--path', $ProjectDir) + $GodotArgs
    $p = Start-Process -FilePath $Godot -ArgumentList $allArgs -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    return $p.ExitCode
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
        # Godot's GUI exe doesn't stream stdout to PowerShell, so read the log
        # the validator writes and print it here.
        $code = Invoke-Godot @('--headless', '--script', 'res://tools/validate.gd')
        $log = Join-Path $ProjectDir '.dev/validate.log'
        if (Test-Path $log) { Get-Content $log | Write-Host }
        exit $code
    }
    'shot' {
        # No --headless: rendering to a PNG needs a real GPU context.
        $godotArgs = @('--script', 'res://tools/screenshot.gd', '--')
        $out = if ($Rest -and $Rest.Count -ge 2) { $Rest[1] } else { '.dev/screenshot.png' }
        if ($Rest) { $godotArgs += $Rest }
        $code = Invoke-Godot $godotArgs
        $abs = Join-Path $ProjectDir $out
        if (Test-Path $abs) { Write-Host "Saved screenshot: $abs" } else { Write-Host "Screenshot not produced." }
        exit $code
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

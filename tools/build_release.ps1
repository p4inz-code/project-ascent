# build_release.ps1
# Reproducible standalone release build for Project Ascent.
#
# Produces, under ./build/:
#   windows/ProjectAscent.exe + ProjectAscent.pck   (Windows Desktop standalone)
#   web/index.html, .wasm, .pck                     (HTML5 export)
# Builds the launcher (PyInstaller, tools/build_launcher.py) and packages a
# player-facing ZIP into ./dist/:
#   Project-Ascent-v0.10.0-Windows.zip
#     ProjectAscentLauncher.exe  <- players run this, not ProjectAscent.exe
#     ProjectAscent.exe / .pck
#     version.txt                (read by the launcher's updater)
#     README.txt
#
# The $version below must match project.godot's config/version. Update both
# together when you bump the release.
#
# USAGE
#   powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
#
# The Godot executable is NOT hard-coded. Supply it one of these ways:
#   1. $env:GODOT_BIN  -or-
#   2. -Godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"  -or-
#   3. Found on PATH as `godot`/`godot.exe`
# If none resolve, the script stops with a clear message.
#
# Environment:
#   Use the exported template matching the engine version (4.7.x). Windows
#   templates must be installed (Godot -> Editor -> Manage Export Templates).
#
# Note: dist/ and build/ are git-ignored, so these artifacts are never committed.
#
# The repo must be at the project root when this runs. The script computes the
# root by joining this script's directory to the parent, so it can be invoked
# from anywhere.

param(
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"

# Locate the project root (two levels up from this tools\ script).
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$version = "0.12.0"
$projectName = "ProjectAscent"

# --- Resolve the Godot binary -------------------------------------------------
function Resolve-Godot {
    param([string]$Hint)
    if ($Hint -and (Test-Path -LiteralPath $Hint)) { return $Hint }
    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $onPath = Get-Command "godot.exe" -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $onPath2 = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($onPath2) { return $onPath2.Source }
    return ""
}

$godot = Resolve-Godot -Hint $Godot
if (-not $godot) {
    Write-Error "Godot executable not found. Supply it via -Godot <path>, `$env:GODOT_BIN, or PATH."
}

Write-Host "Using Godot: $godot"
Write-Host "Project root: $root"

# Version sanity check: confirm the engine matches the export templates.
& $godot --version | ForEach-Object { Write-Host "Engine: $_" }

# --- Export Windows Desktop ---------------------------------------------------
Write-Host "`n[1/4] Exporting Windows Desktop ..."
$winDir = Join-Path $root "build\windows"
New-Item -ItemType Directory -Force -Path $winDir | Out-Null
& $godot --headless --path $root --export-release "Windows Desktop" (Join-Path $winDir "$projectName.exe")
if ($LASTEXITCODE -ne 0) { Write-Error "Windows export failed (exit $LASTEXITCODE)." }

$winExe = Join-Path $winDir "$projectName.exe"
$winPck = Join-Path $winDir "$projectName.pck"
if (-not (Test-Path -LiteralPath $winExe)) { Write-Error "Windows export produced no $projectName.exe" }
if (-not (Test-Path -LiteralPath $winPck)) { Write-Error "Windows export produced no $projectName.pck (embed_pck disabled, PCK expected)." }
Write-Host "  OK: $winExe ($((Get-Item $winExe).Length) bytes)"
Write-Host "  OK: $winPck ($((Get-Item $winPck).Length) bytes)"

# --- Export HTML5 -------------------------------------------------------------
Write-Host "`n[2/4] Exporting HTML5 ..."
$webDir = Join-Path $root "build\web"
New-Item -ItemType Directory -Force -Path $webDir | Out-Null
& $godot --headless --path $root --export-release "Web" (Join-Path $webDir "index.html")
if ($LASTEXITCODE -ne 0) { Write-Error "HTML5 export failed (exit $LASTEXITCODE)." }
Write-Host "  OK: $webDir"

# --- Build the launcher --------------------------------------------------------
# Players must always go through the launcher, never the raw game exe — see
# launcher/launcher.py's _play_game(), which subprocess.Popen()s ProjectAscent.exe
# from its own folder with no network dependency, so this bundling works fully
# offline. tools/build_launcher.py already wraps the PyInstaller invocation.
Write-Host "`n[3/4] Building launcher ..."
python (Join-Path $root "tools\build_launcher.py")
if ($LASTEXITCODE -ne 0) { Write-Error "Launcher build failed (exit $LASTEXITCODE)." }
$launcherExe = Join-Path $root "dist\ProjectAscentLauncher.exe"
if (-not (Test-Path -LiteralPath $launcherExe)) { Write-Error "Launcher build produced no ProjectAscentLauncher.exe" }
Write-Host "  OK: $launcherExe ($((Get-Item $launcherExe).Length) bytes)"

# --- Package Windows distribution ZIP -----------------------------------------
Write-Host "`n[4/4] Packaging Windows distribution ZIP ..."
$distDir = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# Staging folder for the player package.
$stage = Join-Path $root "dist\Project-Ascent-v$version-Windows"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Copy-Item -LiteralPath $winExe -Destination $stage
Copy-Item -LiteralPath $winPck -Destination $stage
Copy-Item -LiteralPath $launcherExe -Destination $stage

# The launcher's updater reads a plain "major.minor.patch" version.txt next to
# the game exe (launcher/updater.py's VERSION_FILE) to know the game is already
# current. Without this the launcher always reports "you have vNone" and shows
# a spurious "Update Available" prompt on every single launch.
# -Encoding ascii (not utf8 — PowerShell 5.1's "utf8" always prepends a BOM,
# which breaks version.py's int() parsing and reproduces the exact "vNone"
# bug this file exists to fix). The version string is always plain digits
# and dots, so ascii is lossless here.
Set-Content -LiteralPath (Join-Path $stage "version.txt") -Value $version -NoNewline -Encoding ascii

# Player-facing README lives at the repo root (tracked); copy it into the package.
$playerReadme = Join-Path $root "PLAYER_README.txt"
if (Test-Path -LiteralPath $playerReadme) {
    Copy-Item -LiteralPath $playerReadme -Destination (Join-Path $stage "README.txt")
} else {
    Write-Host "  (PLAYER_README.txt not found; packaging without a player README)"
}

$zipPath = Join-Path $distDir "Project-Ascent-v$version-Windows.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "`nDONE."
Write-Host "Windows standalone:  $winDir"
Write-Host "HTML5 export:        $webDir"
Write-Host "Distribution ZIP:    $zipPath ($((Get-Item $zipPath).Length) bytes)"
Write-Host ""
Write-Host "To share, send $zipPath. Recipients unzip, open the folder, run ProjectAscentLauncher.exe (not ProjectAscent.exe directly)."

# Publish a .sha256 sidecar alongside the zip. The updater now REFUSES to
# install a release without one (it used to install unverified when the asset
# was missing, which was every release), so this is required, not optional.
$zipPath = Join-Path $distDir "Project-Ascent-v$version-Windows.zip"
if (Test-Path -LiteralPath $zipPath) {
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLower()
    $shaFile = "$zipPath.sha256"
    # ASCII, no BOM: the updater parses this with a plain split, and a BOM
    # would corrupt the first hex character.
    [System.IO.File]::WriteAllText($shaFile,
        "$hash  Project-Ascent-v$version-Windows.zip", [System.Text.ASCIIEncoding]::new())
    Write-Host "Checksum sidecar:    $shaFile"
}

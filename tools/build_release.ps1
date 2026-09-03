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
# The $version below must match project.godot's config/version, AND
# export_presets.cfg's per-platform version fields (Windows Desktop's
# application/file_version + application/product_version, macOS's
# application/short_version + application/version) — those are static
# strings baked into the exported binaries themselves, not read from
# project.godot, so they silently go stale if not bumped by hand too.
# Caught once already (found sitting at 0.8.0/0.13.0 during a 0.14.0 ship).
# Update all of these together when you bump the release.
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

$version = "0.13.0"
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

# Bundle the version string into res://version.txt BEFORE exporting, so it
# ships inside the PCK on every platform (desktop and web alike) and
# start_menu.gd can read it the same way regardless of platform. This file is
# git-ignored and regenerated fresh on every build — it must never be hand-
# edited or committed, or a stale value would silently ship.
Set-Content -LiteralPath (Join-Path $root "version.txt") -Value $version -NoNewline -Encoding ascii

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

# --- Export macOS and Linux (best-effort) --------------------------------------
# These two are NOT part of the required [n/4] sequence: they need their own
# export templates (Editor -> Manage Export Templates), which are a separate,
# sizeable download this script cannot fetch for you. When they're missing,
# skip with a clear message instead of failing the whole release build over
# platforms nobody asked to build yet.
$templateDir = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"
$hasMacTemplate = Test-Path -LiteralPath (Join-Path $templateDir "macos.zip")
$hasLinuxTemplate = Test-Path -LiteralPath (Join-Path $templateDir "linux_release.x86_64")

if ($hasMacTemplate) {
    Write-Host "`n[macOS] Exporting ..."
    $macDir = Join-Path $root "build\macos"
    New-Item -ItemType Directory -Force -Path $macDir | Out-Null
    & $godot --headless --path $root --export-release "macOS" (Join-Path $macDir "ProjectAscent.zip")
    if ($LASTEXITCODE -ne 0) { Write-Error "macOS export failed (exit $LASTEXITCODE)." }
    Write-Host "  OK: $macDir"
} else {
    Write-Host "`n[macOS] SKIPPED - export template not installed ($templateDir\macos.zip missing)."
}

if ($hasLinuxTemplate) {
    Write-Host "`n[Linux] Exporting ..."
    $linuxDir = Join-Path $root "build\linux"
    New-Item -ItemType Directory -Force -Path $linuxDir | Out-Null
    & $godot --headless --path $root --export-release "Linux" (Join-Path $linuxDir "ProjectAscent.x86_64")
    if ($LASTEXITCODE -ne 0) { Write-Error "Linux export failed (exit $LASTEXITCODE)." }
    Write-Host "  OK: $linuxDir"
} else {
    Write-Host "`n[Linux] SKIPPED - export template not installed ($templateDir\linux_release.x86_64 missing)."
}

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

# --- Package macOS / Linux distribution ZIPs (best-effort) ---------------------
# Neither platform has a launcher (build_launcher.py's PyInstaller output is
# Windows-only), so these ship the raw export directly, itch-style: unzip and
# run. No updater bundled here either — itch's own app (or butler channels)
# is the update path for these, not this project's Windows-only launcher.
$macZipPath = $null
if ($hasMacTemplate) {
    $macSrc = Join-Path $root "build\macos\ProjectAscent.zip"
    $macZipPath = Join-Path $distDir "Project-Ascent-v$version-macOS.zip"
    if (Test-Path -LiteralPath $macSrc) {
        Copy-Item -LiteralPath $macSrc -Destination $macZipPath -Force
        # Godot's own export produces a bare zip of just the .app - add a
        # README the same way Windows/Linux get one, so a macOS player isn't
        # left with zero instructions (Gatekeeper's "unidentified developer"
        # block is the one thing every macOS player here will hit).
        $macReadme = @"
PROJECT ASCENT - v$version (macOS)
=========================================

HOW TO LAUNCH
-------------
1. Unzip this file.
2. Right-click ProjectAscent.app and choose Open (not double-click) the
   first time - macOS Gatekeeper blocks unsigned apps from an unidentified
   developer otherwise. Choose "Open" in the dialog that follows.
   (Alternative: System Settings -> Privacy & Security -> "Open Anyway".)
3. After that first Open, it launches normally like any other app.

Developer: p4inz (Atharva Patil) / Northbyte Studios
Engine: Godot Engine 4.7.2
"@
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $macReadmeTmp = Join-Path $env:TEMP "ProjectAscent-macOS-README.txt"
        Set-Content -LiteralPath $macReadmeTmp -Value $macReadme -Encoding utf8
        $zipHandle = [System.IO.Compression.ZipFile]::Open($macZipPath, [System.IO.Compression.ZipArchiveMode]::Update)
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipHandle, $macReadmeTmp, "README.txt") | Out-Null
        $zipHandle.Dispose()
        Remove-Item -LiteralPath $macReadmeTmp -Force
        Write-Host "macOS ZIP:           $macZipPath"
    }
}

$linuxZipPath = $null
if ($hasLinuxTemplate) {
    $linuxStage = Join-Path $root "dist\Project-Ascent-v$version-Linux"
    if (Test-Path -LiteralPath $linuxStage) { Remove-Item -LiteralPath $linuxStage -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $linuxStage | Out-Null
    Copy-Item -LiteralPath (Join-Path $linuxDir "ProjectAscent.x86_64") -Destination $linuxStage
    Copy-Item -LiteralPath (Join-Path $linuxDir "ProjectAscent.pck") -Destination $linuxStage
    Set-Content -LiteralPath (Join-Path $linuxStage "version.txt") -Value $version -NoNewline -Encoding ascii
    # NOT the Windows PLAYER_README.txt - that one tells players to run a
    # launcher exe that doesn't exist on this platform. Linux has no
    # launcher; the player runs the binary directly.
    @"
PROJECT ASCENT - v$version (Linux)
=========================================

HOW TO LAUNCH
-------------
1. Extract this ZIP to a folder of your choice.
2. Make the binary executable: chmod +x ProjectAscent.x86_64
3. Run ./ProjectAscent.x86_64

Keep ProjectAscent.x86_64, ProjectAscent.pck, and version.txt together in
the same folder. No launcher, no installation - it runs directly.

Developer: p4inz (Atharva Patil) / Northbyte Studios
Engine: Godot Engine 4.7.2
"@ | Set-Content -LiteralPath (Join-Path $linuxStage "README.txt") -Encoding utf8
    $linuxZipPath = Join-Path $distDir "Project-Ascent-v$version-Linux.zip"
    if (Test-Path -LiteralPath $linuxZipPath) { Remove-Item -LiteralPath $linuxZipPath -Force }
    Compress-Archive -Path (Join-Path $linuxStage "*") -DestinationPath $linuxZipPath -CompressionLevel Optimal
    Write-Host "Linux ZIP:           $linuxZipPath"
}

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

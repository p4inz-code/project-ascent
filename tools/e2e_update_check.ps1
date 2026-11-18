# e2e_update_check.ps1 - the real exported game updating itself, end to end, on this PC.
#   powershell -ExecutionPolicy Bypass -File tools\e2e_update_check.ps1 -Version 0.18.0 [-OldLauncherZip dist\Project-Ascent-v0.17.0-Windows.zip]
# Installs the built zip into a fresh folder (with a space in its name) and a fresh user-data folder. If an old
# release zip is given, ITS launcher is installed beside the new game: that is what a player has who updated
# through the old launcher, which cannot apply updates. Then a "next version" zip (same files, the version
# bumped, holding the new launcher) is staged exactly as the game stages a download (verified, in its update
# folder, with the pending-update record), and the game is started. The game must:
#   take the installer out of the zip, start it, quit; the installer must replace the game files and the old
#   launcher, write its verdict and restart the game; the game must read the verdict and clear the pending update.
# The network part (check, download, redirects, checksum) is covered by tools\run_updater_live.ps1.
param([Parameter(Mandatory = $true)][string]$Version, [string]$NextVersion = "", [string]$OldLauncherZip = "", [int]$WaitSeconds = 40)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dist = Join-Path $root "dist"
if (-not $NextVersion) { $p = $Version.Split("."); $NextVersion = "{0}.{1}.{2}" -f $p[0], $p[1], ([int]$p[2] + 1) }
$work = Join-Path $env:TEMP ("ascent_e2e_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$fails = 0
function Check($label, $ok) { if ($ok) { Write-Host "[PASS] $label" } else { Write-Host "[FAIL] $label"; $script:fails++ } }

$zip = Join-Path $dist "Project-Ascent-v$Version-Windows.zip"
$game = Join-Path $work "Project Ascent"
Expand-Archive -LiteralPath $zip -DestinationPath $game
$oldHash = ""
if ($OldLauncherZip) {
    $oldDir = Join-Path $work "old"
    Expand-Archive -LiteralPath (Join-Path $root $OldLauncherZip) -DestinationPath $oldDir
    Copy-Item (Join-Path $oldDir "ProjectAscentLauncher.exe") (Join-Path $game "ProjectAscentLauncher.exe") -Force
    $oldHash = (Get-FileHash (Join-Path $game "ProjectAscentLauncher.exe") -Algorithm SHA256).Hash
    Write-Host "installed launcher is the OLD one ($($OldLauncherZip))"
}
# the next version's zip: the same files, the version bumped, and the NEW launcher from this build
$stage = Join-Path $work "next"
New-Item -ItemType Directory -Force $stage | Out-Null
$fresh = Join-Path $work "fresh"
Expand-Archive -LiteralPath $zip -DestinationPath $fresh
foreach ($f in "ProjectAscent.exe", "ProjectAscent.pck", "ProjectAscentLauncher.exe", "README.txt") { Copy-Item (Join-Path $fresh $f) $stage }
Set-Content (Join-Path $stage "version.txt") $NextVersion -NoNewline -Encoding ascii
$nextZip = Join-Path $work "next.zip"
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $nextZip
$nextHash = (Get-FileHash $nextZip -Algorithm SHA256).Hash.ToLower()
$newLauncher = (Get-FileHash (Join-Path $fresh "ProjectAscentLauncher.exe") -Algorithm SHA256).Hash

# the user-data folder, with the staged update recorded the way the game records a verified download
$appdata = Join-Path $work "appdata"
$udir = Join-Path $appdata "Godot\app_userdata\Project Ascent"
$updir = Join-Path $udir "update"
New-Item -ItemType Directory -Force $updir | Out-Null
$staged = Join-Path $updir "Project-Ascent-v$NextVersion-Windows.zip"
Copy-Item $nextZip $staged
$rec = @{ pending = @{ version = $NextVersion; file = "user://update/Project-Ascent-v$NextVersion-Windows.zip"; sha = $nextHash }; mode = 0; attempts = 0 } | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText((Join-Path $udir "updater.json"), $rec, (New-Object System.Text.UTF8Encoding($false)))

$env:APPDATA = $appdata
$log = Join-Path $work "game.log"
$t0 = Get-Date
$p = Start-Process (Join-Path $game "ProjectAscent.exe") -ArgumentList "--log-file", "`"$log`"" -WorkingDirectory $game -PassThru
$ok = $false
$ver = ""
for ($i = 0; $i -lt $WaitSeconds; $i++) {
    Start-Sleep -Seconds 1
    $ver = (Get-Content (Join-Path $game "version.txt") -Raw -ErrorAction SilentlyContinue)
    if ($ver -and $ver.Trim() -eq $NextVersion) { $ok = $true; break }
}
Check "the installer replaced the game: version.txt is now $NextVersion" $ok
Start-Sleep -Seconds 8   # the restarted game starts, reads the verdict and cleans up
$running = Get-Process -Name ProjectAscent -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt $t0.AddSeconds(2) }
Check "the game was restarted by the installer" ($null -ne $running)
$res = Join-Path $game "update_result.json"
$verdictLeft = Test-Path $res
Check "the game read the verdict and removed it" (-not $verdictLeft)
$state = Get-Content (Join-Path $udir "updater.json") -Raw -ErrorAction SilentlyContinue
Check "the pending update was cleared" ($state -and ($state -notmatch "pending"))
Check "the staged zip was removed" (-not (Test-Path $staged))
Check "the installer folder was cleaned up" (-not (Test-Path (Join-Path $game "update_helper")))
if ($OldLauncherZip) {
    $now = (Get-FileHash (Join-Path $game "ProjectAscentLauncher.exe") -Algorithm SHA256).Hash
    Check "the OLD launcher was replaced by the new one" (($now -eq $newLauncher) -and ($now -ne $oldHash))
}
Check "no rollback or staging leftovers beside the game" (-not (Get-ChildItem $game -Force | Where-Object { $_.Name -in ".update_backup", ".update_staging", ".update_in_progress" }))
$leftover = (Get-ChildItem $game -Force | ForEach-Object Name) -join ", "
Write-Host "game folder now: $leftover"
if (Test-Path (Join-Path $game "update_log.txt")) { Write-Host "update_log.txt:"; Get-Content (Join-Path $game "update_log.txt") | ForEach-Object { Write-Host "    $_" } }
Get-Process -Name ProjectAscent -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
Write-Host ""
Write-Host "e2e_update_check: $fails failure(s). Work folder: $work"
exit $(if ($fails -gt 0) { 1 } else { 0 })

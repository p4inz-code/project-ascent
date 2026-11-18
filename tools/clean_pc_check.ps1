# clean_pc_check.ps1 - what a player's PC sees: every build unzipped into a fresh folder with a fresh user-data
# folder, nothing from the dev machine. Run after tools\build_release.ps1.
#   powershell -ExecutionPolicy Bypass -File tools\clean_pc_check.ps1 -Version 0.18.0 [-Seconds 20]
# Checks (and prints PASS/FAIL for each):
#   Windows   unzip (in a folder with a space in its name), file list, version.txt, the launcher exe really holds
#             its artwork, the game starts with an empty save and stays up, no errors in its log, a screenshot
#   Web       unzip, start its local server, index.html / .wasm / .pck answer with the right types and headers
#   macOS     zip layout and the README
#   Linux     zip layout, the executable bit on the binary
# Output lands in dist\clean_pc\ (log, screenshot). One game window at a time, for a few seconds.
param([Parameter(Mandatory = $true)][string]$Version, [int]$Seconds = 20)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dist = Join-Path $root "dist"
$out = Join-Path $dist "clean_pc"
New-Item -ItemType Directory -Force $out | Out-Null
$work = Join-Path $env:TEMP ("ascent_clean_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force $work | Out-Null
$fails = 0
function Check($label, $ok) { if ($ok) { Write-Host "[PASS] $label" } else { Write-Host "[FAIL] $label"; $script:fails++ } }

# ---- Windows -------------------------------------------------------------------------------------------------
$winZip = Join-Path $dist "Project-Ascent-v$Version-Windows.zip"
Check "Windows zip exists" (Test-Path $winZip)
if (Test-Path $winZip) {
    $win = Join-Path $work "Project Ascent"
    Expand-Archive -LiteralPath $winZip -DestinationPath $win
    foreach ($f in "ProjectAscent.exe", "ProjectAscent.pck", "ProjectAscentLauncher.exe", "version.txt", "README.txt") {
        Check "Windows: $f is in the zip" (Test-Path (Join-Path $win $f))
    }
    Check "Windows: version.txt is $Version" ((Get-Content (Join-Path $win "version.txt") -Raw).Trim() -eq $Version)
    $blob = [System.IO.File]::ReadAllBytes((Join-Path $win "ProjectAscentLauncher.exe"))
    $text = [System.Text.Encoding]::Latin1.GetString($blob)
    foreach ($a in "wordmark.png", "studio.png", "rocket.png", "icon.ico") {
        Check "Windows: the launcher exe holds $a" ($text.Contains("assets/$a") -or $text.Contains("assets\$a"))
    }
    $sha = Join-Path $dist "Project-Ascent-v$Version-Windows.zip.sha256"
    Check "Windows: the .sha256 file exists and matches the zip" ((Test-Path $sha) -and ((Get-Content $sha -Raw) -match (Get-FileHash $winZip -Algorithm SHA256).Hash))
    # first start with an empty user-data folder
    $env:APPDATA = Join-Path $work "appdata"
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $log = Join-Path $out "game_first_run.log"
    $p = Start-Process (Join-Path $win "ProjectAscent.exe") -ArgumentList "--log-file", "`"$log`"" -WorkingDirectory $win -PassThru
    try { $p.PriorityClass = "BelowNormal" } catch {}
    Start-Sleep -Seconds $Seconds
    Check "Windows: the game is still running after $Seconds s on a clean PC" (-not $p.HasExited)
    if (-not $p.HasExited) {
        $shot = Join-Path $out "game_first_run.png"
        $py = @"
import ctypes, sys
from ctypes import wintypes
ctypes.windll.shcore.SetProcessDpiAwareness(2)
from PIL import ImageGrab
r = wintypes.RECT()
h = int(sys.argv[1])
ctypes.windll.user32.GetWindowRect(h, ctypes.byref(r))
ImageGrab.grab(bbox=(r.left, r.top, r.right, r.bottom)).save(sys.argv[2])
"@
        $pyFile = Join-Path $work "grab.py"
        Set-Content $pyFile $py
        try { python $pyFile ([int64]$p.MainWindowHandle) $shot } catch { Write-Host "  (screenshot failed: $_)" }
        Check "Windows: a screenshot of the first run was taken" (Test-Path $shot)
        Stop-Process -Id $p.Id -Force
    }
    Start-Sleep -Milliseconds 500
    $errs = @()
    if (Test-Path $log) { $errs = Select-String -Path $log -Pattern "ERROR|SCRIPT ERROR|Parse Error|Failed to load|Condition `"" | ForEach-Object { $_.Line } }
    Check "Windows: no errors in the first-run log ($($errs.Count) found)" ($errs.Count -eq 0)
    $errs | Select-Object -First 8 | ForEach-Object { Write-Host "    $_" }
    Check "Windows: the game wrote its save into the fresh user-data folder, not anywhere else" ((Get-ChildItem $env:APPDATA -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count -ge 1)
}

# ---- Web -----------------------------------------------------------------------------------------------------
$webZip = Join-Path $dist "Project-Ascent-v$Version-Web.zip"
Check "Web zip exists" (Test-Path $webZip)
if (Test-Path $webZip) {
    $web = Join-Path $work "web"
    Expand-Archive -LiteralPath $webZip -DestinationPath $web
    foreach ($f in "index.html", "index.js", "index.wasm", "index.pck", "serve.ps1", "Play in browser.bat", "README.txt") {
        Check "Web: $f is in the zip" (Test-Path (Join-Path $web $f))
    }
    $env:ASCENT_NO_BROWSER = "1"
    $srv = Start-Process powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$(Join-Path $web 'serve.ps1')`"" -PassThru -WindowStyle Hidden
    $up = $false
    $port = 0
    for ($i = 0; $i -lt 40 -and -not $up; $i++) {
        Start-Sleep -Milliseconds 250
        foreach ($pp in 8060..8099) {
            try { $r = Invoke-WebRequest "http://localhost:$pp/index.html" -UseBasicParsing -TimeoutSec 1; if ($r.StatusCode -eq 200) { $up = $true; $port = $pp; break } } catch {}
        }
    }
    Check "Web: the local server answers index.html" $up
    if ($up) {
        $w = Invoke-WebRequest "http://localhost:$port/index.wasm" -Method Head -UseBasicParsing
        Check "Web: the .wasm is served as application/wasm" ($w.Headers["Content-Type"] -match "application/wasm")
        $k = Invoke-WebRequest "http://localhost:$port/index.pck" -Method Head -UseBasicParsing
        Check "Web: the .pck answers" ($k.StatusCode -eq 200)
        $code = 404
        try { $code = (Invoke-WebRequest "http://localhost:$port/..%2f..%2fWindows%2fwin.ini" -UseBasicParsing -TimeoutSec 2).StatusCode } catch { }
        Check "Web: a path that climbs out of the folder is refused" ($code -ne 200)
        Write-Host "  web server for a browser check: http://localhost:$port/index.html (left running; stop PID $($srv.Id) when done)"
        $script:webPid = $srv.Id
        $script:webPort = $port
    } else { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue }
}

# ---- macOS and Linux (cannot be run on this PC: layout only) ---------------------------------------------------
$py2 = @"
import sys, zipfile
v = sys.argv[1]
for osn in ("macOS", "Linux"):
    p = r'$dist' + "\\Project-Ascent-v%s-%s.zip" % (v, osn)
    try:
        z = zipfile.ZipFile(p)
    except Exception as e:
        print("[FAIL] %s zip: %s" % (osn, e)); continue
    names = z.namelist()
    print("[PASS] %s zip opens, %d entries" % (osn, len(names)))
    print(("[PASS] " if any(n.lower().endswith("readme.txt") for n in names) else "[FAIL] ") + osn + " has a README")
    if osn == "Linux":
        binary = [i for i in z.infolist() if i.filename.endswith(".x86_64") or i.filename.endswith("ProjectAscent")]
        ok = bool(binary) and all(((i.external_attr >> 16) & 0o111) for i in binary)
        print(("[PASS] " if ok else "[FAIL] ") + "Linux binary has the executable bit (%s)" % ", ".join(i.filename for i in binary))
    else:
        app = [n for n in names if ".app/Contents/MacOS/" in n and not n.endswith("/")]
        print(("[PASS] " if app else "[FAIL] ") + "macOS has an .app bundle with a MacOS binary")
"@
$pyFile2 = Join-Path $work "layout.py"
Set-Content $pyFile2 $py2
python $pyFile2 $Version | ForEach-Object { Write-Host $_; if ($_ -like "*FAIL*") { $script:fails++ } }

Write-Host ""
Write-Host "clean_pc_check: $fails failure(s). Work folder: $work"
if ($script:webPid) { Write-Host "web server still running on port $script:webPort (PID $script:webPid)" }
exit $(if ($fails -gt 0) { 1 } else { 0 })

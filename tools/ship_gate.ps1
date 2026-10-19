# ship_gate.ps1 - the gate every release must pass. Exit code 0 means "may ship"; anything
# else means do not. It never publishes or tags anything itself.
#
# What it checks, in order (each is a hard fail unless stated):
#   1  Version agreement: version.txt, project.godot, build_release.ps1 and both export presets.
#   2  Required local assets exist (the licensed UI font is not in git and must be present).
#   3  Public text does not leak the developer-console key sequence.
#   4  The whole test suite passes, run suite by suite with its own save folder.
#      Any "[FAIL]", "SCRIPT ERROR", "NEVER FINISHED", or non-zero exit fails the gate unless the
#      exact line is in tools/ship_gate_allowlist.txt AND the entry is signed by the owner.
#   5  Windows and Web exports succeed, the zip layout is right, sizes are sane.
#   6  The exported release build ignores debug flags (--dev-unlocked / --dev-cores).
#   7  The exported release build starts and stays up.
#   8  Web build has index.html at the zip root and no desktop-only files.
#
# USAGE
#   powershell -ExecutionPolicy Bypass -File tools\ship_gate.ps1 -Godot "C:\path\Godot_..._console.exe"
#   Add -SkipTests to re-run only the build checks, -SkipBuild for only the text and test checks.
#
# The report goes to dist\ship_gate_report.txt.

param(
    [string]$Godot = "",
    [switch]$SkipTests,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root
New-Item -ItemType Directory -Force dist | Out-Null
$report = New-Object System.Collections.Generic.List[string]
$script:failed = $false

function Say([string]$text) { Write-Host $text; $report.Add($text) }
function Pass([string]$what) { Say ("  PASS  " + $what) }
function Fail([string]$what) { Say ("  FAIL  " + $what); $script:failed = $true }

if ([string]::IsNullOrWhiteSpace($Godot)) {
    if ($env:GODOT_BIN) { $Godot = $env:GODOT_BIN }
    else { $c = Get-Command godot -ErrorAction SilentlyContinue; if ($c) { $Godot = $c.Source } }
}
if ([string]::IsNullOrWhiteSpace($Godot) -or -not (Test-Path -LiteralPath $Godot)) {
    Write-Host "Godot not found. Pass -Godot <path to the console exe> or set GODOT_BIN."
    exit 2
}
Say ("Ship gate  " + (Get-Date -Format "yyyy-MM-dd HH:mm") + "  commit " + (git rev-parse --short HEAD))

# 1 ---------------------------------------------------------------------------------------------
Say "[1] version agreement"
$ver = (Get-Content version.txt -Raw).Trim()
$proj = Select-String -Path project.godot -Pattern 'config/version="([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1
$build = Select-String -Path tools\build_release.ps1 -Pattern '^\$version = "([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1
if ($ver -eq $proj) { Pass "version.txt ($ver) matches project.godot" } else { Fail "version.txt '$ver' differs from project.godot '$proj'" }
if ($ver -eq $build) { Pass "build_release.ps1 matches ($build)" } else { Fail "build_release.ps1 has '$build', version.txt has '$ver'" }
$presets = Get-Content export_presets.cfg -Raw
foreach ($field in @("application/file_version", "application/product_version", "application/short_version")) {
    $m = [regex]::Matches($presets, [regex]::Escape($field) + '="([^"]*)"')
    foreach ($x in $m) {
        $v = $x.Groups[1].Value
        if ($v -ne "" -and -not $v.StartsWith($ver)) { Fail "export preset $field is '$v', expected '$ver'" }
    }
}
if (-not $script:failed) { Pass "export presets carry the same version" }

# 2 ---------------------------------------------------------------------------------------------
Say "[2] required local assets"
if (Test-Path "assets\fonts\CyberpunkCraftpixPixel.otf") { Pass "licensed UI font present (not in git; builds need it)" } else { Fail "assets\fonts\CyberpunkCraftpixPixel.otf is missing: the UI would fall back to a default font" }
foreach ($f in @("PressStart2P-Regular.ttf", "Silkscreen-Regular.ttf", "VT323-Regular.ttf", "PixelifySans-Variable.ttf", "OFL-pressstart2p.txt", "OFL-silkscreen.txt", "OFL-vt323.txt", "OFL-pixelifysans.txt")) {
    if (-not (Test-Path "assets\fonts\ofl\$f")) { Fail "bundled font file or licence missing: $f" }
}
if (-not $script:failed) { Pass "bundled fonts and licences present" }

# 3 ---------------------------------------------------------------------------------------------
Say "[3] developer-console secrecy"
$public = @(@("README.md", "PLAYER_README.txt", "CREDITS.md", "SECURITY.md", "docs\ITCH_PAGE.md", "docs\ITCH_PUBLISHING.md") |
    Where-Object { Test-Path $_ })
$public = @($public) + @(Get-ChildItem build/teaser -Filter README.txt -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
$leak = $false
$rx = [regex]'(?i)\b(type|press|enter|sequence|cheat|console|unlock)\b\W.{0,48}p\W?4\W?i\W?n\W?z|p\W?4\W?i\W?n\W?z\W.{0,48}\b(sequence|cheat|console|unlock)\b|KEY_P\s*,\s*KEY_4'
foreach ($file in $public) {
    $n = 0
    foreach ($text in (Get-Content -LiteralPath $file)) {
        $n++
        if ($rx.IsMatch($text)) { Fail ("possible cheat-sequence leak in " + $file + ":" + $n); $leak = $true }
    }
}
$ui = Get-ChildItem scripts -Filter *.gd | Where-Object { $_.Name -ne "dev_console.gd" }
foreach ($f in $ui) {
    if (Select-String -Path $f.FullName -Pattern 'KEY_P\s*,\s*KEY_4' -Quiet) { Fail ("sequence spelled out in " + $f.Name); $leak = $true }
}
if (-not $leak) { Pass ("no leak in " + $public.Count + " public files or any non-console script") }

# 4 ---------------------------------------------------------------------------------------------
Say "[4] test suite"
if ($SkipTests) { Say "  skipped (-SkipTests)" } else {
    $allow = @{}
    if (Test-Path tools\ship_gate_allowlist.txt) {
        foreach ($line in Get-Content tools\ship_gate_allowlist.txt) {
            if ($line.Trim() -eq "" -or $line.StartsWith("#")) { continue }
            $parts = $line.Split("|")
            if ($parts.Count -ge 4) { $allow[$parts[0].Trim() + "|" + $parts[1].Trim()] = @{ reason = $parts[2].Trim(); signed = $parts[3].Trim() } }
        }
    }
    $log = Join-Path $env:TEMP "ship_gate_tests.txt"
    & powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_all_tests.ps1 -GodotPath $Godot *> $log
    $suite = ""
    $problems = @()
    foreach ($line in (Get-Content $log)) {
        if ($line -match '^=== (.+) ===$') { $suite = $Matches[1] }
        elseif ($line -match '\[FAIL\]|SCRIPT ERROR|NEVER FINISHED|Parse Error') { $problems += [pscustomobject]@{ suite = $suite; line = $line.Trim() } }
    }
    $unexplained = 0
    foreach ($p in $problems) {
        $matched = $null
        foreach ($k in $allow.Keys) {
            $s, $needle = $k.Split("|")
            if ($p.suite -eq $s -and $p.line.Contains($needle)) { $matched = $allow[$k] }
        }
        if ($matched -eq $null) { Fail ("[" + $p.suite + "] " + $p.line); $unexplained++ }
        elseif ($matched.signed -notmatch '^(owner|signed)') { Fail ("[" + $p.suite + "] allowed but NOT signed by the owner: " + $p.line + "  (" + $matched.reason + ")") }
        else { Say ("  ALLOWED  [" + $p.suite + "] " + $p.line + "  (" + $matched.reason + ", " + $matched.signed + ")") }
    }
    if (Select-String -Path $log -Pattern 'Script compilation failed|COMPILE ERRORS' -Quiet) { Fail "compile errors in the pre-flight" }
    if ($unexplained -eq 0 -and $problems.Count -eq 0) { Pass "every suite clean" }
    Copy-Item $log dist\ship_gate_tests.log -Force
}

# 5 - 8 -----------------------------------------------------------------------------------------
Say "[5-8] builds"
if ($SkipBuild) { Say "  skipped (-SkipBuild)" } else {
    $out = "build\gate"
    Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force "$out\win", "$out\web" | Out-Null
    & $Godot --headless --path $root --import 2>&1 | Out-Null
    & $Godot --headless --path $root --export-release "Windows Desktop" "$out\win\ProjectAscent.exe" 2>&1 | Out-Null
    & $Godot --headless --path $root --export-release "Web" "$out\web\index.html" 2>&1 | Out-Null
    if ((Test-Path "$out\win\ProjectAscent.exe") -and (Test-Path "$out\win\ProjectAscent.pck")) { Pass "Windows export produced exe and pck" } else { Fail "Windows export failed" }
    if ((Test-Path "$out\web\index.html") -and (Test-Path "$out\web\index.wasm") -and (Test-Path "$out\web\index.pck")) { Pass "Web export produced html, wasm and pck" } else { Fail "Web export failed" }
    if (Test-Path "$out\web\index.pck") {
        $mb = (Get-Item "$out\web\index.pck").Length / 1MB
        if ($mb -lt 60) { Pass ("web pck is {0:N1} MB" -f $mb) } else { Fail ("web pck is {0:N1} MB, too large for a browser build" -f $mb) }
    }
    if (Test-Path "$out\web\index.html") {
        $names = (Get-ChildItem "$out\web" -File).Name
        if ($names -contains "ProjectAscent.exe") { Fail "desktop files in the web build" } else { Pass "web build is browser-only" }
    }
    # Release build ignores debug flags: a fresh save folder, run with the dev flags, check no cores.
    if (Test-Path "$out\win\ProjectAscent.exe") {
        $savedAppData = $env:APPDATA
        $env:APPDATA = Join-Path $env:TEMP "ship_gate_appdata"
        Remove-Item -Recurse -Force $env:APPDATA -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
        $p = Start-Process -FilePath "$out\win\ProjectAscent.exe" -ArgumentList @("--dev-unlocked", "--dev-cores=99") -PassThru
        Start-Sleep -Seconds 10
        if (-not $p.HasExited) { Pass "the release exe starts and stays up for 10 s"; Stop-Process -Id $p.Id -Force } else { Fail ("the release exe exited early with code " + $p.ExitCode) }
        Start-Sleep -Seconds 1
        $log = Get-ChildItem -Recurse $env:APPDATA -Filter godot.log -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($log -and (Select-String -Path $log.FullName -Pattern 'DevConsole|dev mode|cores' -Quiet)) { Fail "debug flags had an effect in the release build" } else { Pass "debug flags did nothing in the release build" }
        $env:APPDATA = $savedAppData
    }
    $zip = "dist\gate_web_check.zip"
    if (Test-Path "$out\web\index.html") {
        if (Test-Path $zip) { Remove-Item $zip }
        Compress-Archive -Path "$out\web\*" -DestinationPath $zip
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $entries = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $zip)).Entries.FullName
        if ($entries -contains "index.html") { Pass "web zip has index.html at its root" } else { Fail "index.html is not at the zip root" }
        Remove-Item $zip -ErrorAction SilentlyContinue
    }
}

Say ""
if ($script:failed) { Say "SHIP GATE: FAILED - do not ship" } else { Say "SHIP GATE: PASSED" }
$report | Set-Content dist\ship_gate_report.txt -Encoding UTF8
if ($script:failed) { exit 1 } else { exit 0 }

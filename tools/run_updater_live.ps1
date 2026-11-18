# run_updater_live.ps1 - the updater against a fake GitHub: starts tools/fake_github.py, runs
# tests/live_updater.gd headless at idle priority (one Godot, its own save folder), then stops the server.
# Usage: powershell -File tools\run_updater_live.ps1 -Godot <console exe> [-Port 8765]
param([string]$Godot, [int]$Port = 8765, [string]$Out = "dist\updater_live.txt")
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$server = Start-Process python -ArgumentList @("tools\fake_github.py", "$Port") -PassThru -WindowStyle Hidden
try {
    $up = $false
    for ($i = 0; $i -lt 40 -and -not $up; $i++) {
        Start-Sleep -Milliseconds 250
        try { Invoke-WebRequest "http://127.0.0.1:$Port/_hits" -UseBasicParsing -TimeoutSec 2 | Out-Null; $up = $true } catch {}
    }
    if (-not $up) { throw "the fake GitHub did not start on port $Port" }
    $env:APPDATA = Join-Path $env:TEMP "ap_updater_live"
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $p = Start-Process $Godot -ArgumentList "--headless", "--path", ".", "--script", "res://tests/live_updater.gd", "--", "$Port" -PassThru -NoNewWindow -RedirectStandardOutput $Out -RedirectStandardError ($Out + ".err")
    try { $p.PriorityClass = "Idle" } catch {}
    if (-not $p.WaitForExit(600000)) { $p.Kill(); Add-Content $Out "TIMEOUT"; exit 2 }
    Select-String $Out -Pattern "\[FAIL\]|failures=|SCRIPT ERROR" | ForEach-Object { $_.Line }
    # Godot's console launcher hides the real exit code, so the verdict is the failure count in the output
    $m = Select-String $Out -Pattern "\[live_updater\] failures=(\d+)" | Select-Object -Last 1
    if ($null -eq $m) { Write-Host "NO RESULT LINE: the test did not finish"; exit 2 }
    exit ([int]$m.Matches[0].Groups[1].Value -gt 0)
} finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
}

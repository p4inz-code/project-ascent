# run_updater_live.ps1 - the updater against a fake GitHub: starts tools/fake_github.py, runs
# tests/live_updater.gd headless at idle priority (one Godot, its own save folder), then stops the server.
# Usage: powershell -File tools\run_updater_live.ps1 -Godot <console exe> [-Port 8765]
# Leaves nothing behind: the server is stopped, the save folder and the log are removed (the log is kept, and named,
# only when the run failed).
param([string]$Godot, [int]$Port = 8765, [string]$Out = "")
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root
if (-not $Out) { $Out = Join-Path $env:TEMP "ap_updater_live_run.txt" }
$origAppData = $env:APPDATA
$appdata = Join-Path $env:TEMP "ap_updater_live"
$server = Start-Process python -ArgumentList @("tools\fake_github.py", "$Port") -PassThru -WindowStyle Hidden
$code = 2
try {
    $up = $false
    for ($i = 0; $i -lt 40 -and -not $up; $i++) {
        Start-Sleep -Milliseconds 250
        try { Invoke-WebRequest "http://127.0.0.1:$Port/_hits" -UseBasicParsing -TimeoutSec 2 | Out-Null; $up = $true } catch {}
    }
    if (-not $up) { throw "the fake GitHub did not start on port $Port" }
    $env:APPDATA = $appdata
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $p = Start-Process $Godot -ArgumentList "--headless", "--path", ".", "--script", "res://tests/live_updater.gd", "--", "$Port" -PassThru -NoNewWindow -RedirectStandardOutput $Out -RedirectStandardError ($Out + ".err")
    try { $p.PriorityClass = "Idle" } catch {}
    if (-not $p.WaitForExit(600000)) { $p.Kill(); Add-Content $Out "TIMEOUT"; $code = 2 }
    else {
        Select-String $Out -Pattern "\[FAIL\]|failures=|SCRIPT ERROR" | ForEach-Object { $_.Line }
        # Godot's console launcher hides the real exit code, so the verdict is the failure count in the output
        $m = Select-String $Out -Pattern "\[live_updater\] failures=(\d+)" | Select-Object -Last 1
        if ($null -eq $m) { Write-Host "NO RESULT LINE: the test did not finish"; $code = 2 }
        else { $code = [int]([int]$m.Matches[0].Groups[1].Value -gt 0) }
    }
} finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    $env:APPDATA = $origAppData
    Remove-Item -Recurse -Force -LiteralPath $appdata -ErrorAction SilentlyContinue
    if ($code -eq 0) { Remove-Item -Force $Out, ($Out + ".err") -ErrorAction SilentlyContinue }
    else { Write-Host "(log kept: $Out)" }
}
exit $code

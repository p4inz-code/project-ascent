# run_some.ps1 - run a list of suites one at a time at idle priority, each with its own save folder.
# Usage: powershell -File tools\run_some.ps1 -Godot <console exe> -Suites test_a,test_b -Out dist\some.txt
param([string]$Godot, [string[]]$Suites, [string]$Out = "dist\some.txt")
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
"" | Set-Content $Out
foreach ($t in ($Suites -join "," -split ",")) {
    $env:APPDATA = Join-Path $env:TEMP ("ap_some_" + $t)
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $log = Join-Path $env:TEMP ("some_" + $t + ".txt")
    $p = Start-Process $Godot -ArgumentList "--headless", "--path", ".", "--script", "res://tests/$t.gd" -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
    try { $p.PriorityClass = "Idle" } catch {}
    if (-not $p.WaitForExit(900000)) { $p.Kill(); Add-Content $Out "== $t TIMEOUT"; continue }
    Add-Content $Out "== $t exit $($p.ExitCode)"
    Select-String $log -Pattern "\[FAIL\]|failures=|SCRIPT ERROR|NEVER FINISHED" | Select-Object -Last 6 | ForEach-Object { Add-Content $Out $_.Line }
}
Add-Content $Out "ALL DONE"

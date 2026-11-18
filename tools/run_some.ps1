# run_some.ps1 - run a list of suites one at a time at idle priority, each with its own save folder.
# Usage: powershell -File tools\run_some.ps1 -Godot <console exe> -Suites test_a,test_b -Out dist\some.txt
# Leaves nothing behind: each suite's save folder is removed when it ends, and its log too when it passed (the log
# of a failing suite is kept in %TEMP% and named in the output, so the failure can be read).
param([string]$Godot, [string[]]$Suites, [string]$Out = "dist\some.txt")
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
"" | Set-Content $Out
$origAppData = $env:APPDATA
try {
    foreach ($t in ($Suites -join "," -split ",")) {
        $env:APPDATA = Join-Path $env:TEMP ("ap_some_" + $t)
        New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
        $log = Join-Path $env:TEMP ("some_test_" + $t + ".txt")
        $p = Start-Process $Godot -ArgumentList "--headless", "--path", ".", "--script", "res://tests/$t.gd" -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
        try { $p.PriorityClass = "Idle" } catch {}
        $keepLog = $false
        if (-not $p.WaitForExit(900000)) {
            $p.Kill(); Add-Content $Out "== $t TIMEOUT"; $keepLog = $true
        } else {
            Add-Content $Out "== $t exit $($p.ExitCode)"
            $lines = Select-String $log -Pattern "\[FAIL\]|failures=|SCRIPT ERROR|NEVER FINISHED" | Select-Object -Last 6
            $lines | ForEach-Object { Add-Content $Out $_.Line }
            if ($lines | Where-Object { $_.Line -match "\[FAIL\]|SCRIPT ERROR|NEVER FINISHED|failures=[1-9]" }) { $keepLog = $true }
        }
        Remove-Item -Recurse -Force -LiteralPath $env:APPDATA -ErrorAction SilentlyContinue
        if ($keepLog) { Add-Content $Out "   (log kept: $log)" } else { Remove-Item -Force $log, ($log + ".err") -ErrorAction SilentlyContinue }
    }
} finally {
    $env:APPDATA = $origAppData
}
Add-Content $Out "ALL DONE"

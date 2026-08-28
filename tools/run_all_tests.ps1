param(
    [string]$GodotPath = "F:\PROJECT ASCENT\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$testScripts = @(
    "test_movement.gd",
    "test_feel.gd",
    "test_loop.gd",
    "test_level.gd",
    "test_presentation.gd"
)
$failed = 0

foreach ($testScript in $testScripts) {
    Write-Host "=== $testScript ==="
    & $GodotPath --headless --path (Get-Location) --script "res://tests/$testScript"
    if ($LASTEXITCODE -ne 0) {
        $failed++
    }
}

if ($failed -ne 0) {
    Write-Error "$failed test suite(s) failed."
}
else {
    Write-Host "All $($testScripts.Count) test suites passed."
}

exit $failed

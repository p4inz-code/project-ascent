param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $godotCommand) {
        $GodotPath = $godotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Error "Godot 4.7.2 was not found. Install it or pass -GodotPath 'C:\path\to\Godot_v4.7.2-stable_console.exe'."
    exit 2
}

$testScripts = @(
    "test_boot.gd",
    "test_movement.gd",
    "test_feel.gd",
    "test_loop.gd",
    "test_level.gd",
    "test_level3_route.gd",
    "test_presentation.gd",
    "test_save.gd",
    "test_new_mechanics.gd",
    "test_customization.gd",
    "test_hazard_placement.gd",
    "test_all_routes.gd",
    "test_full_campaign.gd",
    # Slowest suite last (real-time physics across all 25 levels, several
    # minutes) so a fast-failing regression above is reported without
    # waiting for this one.
    "test_all_levels_reachable.gd"
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

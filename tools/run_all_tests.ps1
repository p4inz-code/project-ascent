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
    "test_level_rhythm.gd",
    "test_chaser_ledges.gd",
    "test_new_verbs.gd",
    "test_dev_console.gd",
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

# Godot writes script errors to stderr, and capturing that with 2>&1 makes
# PowerShell 5.1 wrap each line in a NativeCommandError. Under the script's
# `ErrorActionPreference = "Stop"` that is a TERMINATING error, which silently
# aborted the whole run after the first suite while still exiting 0. Relax it
# for the loop and restore afterwards.
$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"

foreach ($testScript in $testScripts) {
    Write-Host "=== $testScript ==="
    $output = & $GodotPath --headless --path (Get-Location) --script "res://tests/$testScript" 2>&1
    $output | ForEach-Object { Write-Host $_ }

    $suiteFailed = $false
    if ($LASTEXITCODE -ne 0) { $suiteFailed = $true }

    # A suite can report "failures=0" while GDScript failed to COMPILE: the
    # assertions that would have caught the problem simply never ran, and the
    # suite exits 0 having proved nothing. This happened for real — test_boot
    # printed a clean pass while main_scene.gd failed to compile. Treat any
    # parse/compile error as a suite failure regardless of exit code.
    $scriptErrors = $output | Select-String -Pattern 'SCRIPT ERROR|Compile Error|Parse Error|Failed to load script'
    if ($scriptErrors) {
        Write-Host "  ^ script/compile errors detected - treating as FAILURE" -ForegroundColor Red
        $suiteFailed = $true
    }

    if ($suiteFailed) { $failed++ }
}

$ErrorActionPreference = $previousEap

if ($failed -ne 0) {
    Write-Error "$failed test suite(s) failed."
}
else {
    Write-Host "All $($testScripts.Count) test suites passed."
}

exit $failed

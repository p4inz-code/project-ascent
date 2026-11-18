# sandbox_check.ps1 - the Windows zip on a CLEAN Windows with no graphics driver: Windows Sandbox is a fresh,
# disposable copy of Windows (nothing installed, nothing from this PC), and with the virtual GPU disabled it has no
# real OpenGL either, which is what a remote-desktop session, a virtual machine or a very old graphics card looks like.
# If the game starts there (it should fall back to DirectX through ANGLE), it will start on almost any Windows 10 or 11 PC.
#   powershell -ExecutionPolicy Bypass -File tools\sandbox_check.ps1 -Version 0.18.0
# Needs the Windows Sandbox feature (Windows 10/11 Pro or Enterprise) and virtualization enabled in the BIOS.
# The sandbox is closed by the test itself; nothing is installed on this PC; the folders made here are deleted at
# the end; the screenshots and the game's log are kept in dist\clean_pc\sandbox.
param([Parameter(Mandatory = $true)][string]$Version, [int]$TimeoutSec = 480, [int]$MemoryMB = 3072, [switch]$WithGpu)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dist = Join-Path $root "dist"
$zip = Join-Path $dist "Project-Ascent-v$Version-Windows.zip"
if (-not (Test-Path $zip)) { Write-Host "[FAIL] $zip does not exist"; exit 2 }
if (-not (Get-Command WindowsSandbox.exe -ErrorAction SilentlyContinue)) { Write-Host "[FAIL] Windows Sandbox is not installed on this PC"; exit 2 }
$work = Join-Path $env:TEMP ("ap_sandbox_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$in = Join-Path $work "in"
$out = Join-Path $work "out"
New-Item -ItemType Directory -Force $in, $out | Out-Null
$fails = 0
function Check($label, $ok) { if ($ok) { Write-Host "[PASS] $label" } else { Write-Host "[FAIL] $label"; $script:fails++ } }
try {
    Copy-Item $zip (Join-Path $in "game.zip")
    $run = @'
$out = "C:\Out"
function Step($m) { Add-Content "$out\steps.txt" ("{0} {1}" -f (Get-Date -Format HH:mm:ss), $m) }
function Shot($name) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
    $bmp.Save("$out\$name", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}
try {
    Step "start"
    $os = Get-CimInstance Win32_OperatingSystem
    Step ("OS " + $os.Caption + " build " + $os.BuildNumber + " " + $os.OSArchitecture)
    Get-CimInstance Win32_VideoController | ForEach-Object { Step ("GPU " + $_.Name + " driver " + $_.DriverVersion) }
    $dst = "C:\Users\WDAGUtilityAccount\Desktop\Project Ascent"
    Expand-Archive C:\In\game.zip $dst
    Step "unzipped"
    $l = Start-Process "$dst\ProjectAscentLauncher.exe" -PassThru
    Start-Sleep -Seconds 8
    Step ("launcher alive=" + (-not $l.HasExited))
    Shot "launcher.png"
    if (-not $l.HasExited) { Stop-Process -Id $l.Id -Force }
    $p = Start-Process "$dst\ProjectAscent.exe" -ArgumentList "--log-file", "`"$out\game.log`"" -PassThru
    Start-Sleep -Seconds 35
    Step ("game alive=" + (-not $p.HasExited))
    if ($p.HasExited) { Step ("game exit code " + $p.ExitCode) }
    Shot "game.png"
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
} catch { Step ("ERROR " + $_.Exception.Message) }
finally { "done" | Set-Content "$out\done.txt"; Start-Sleep -Seconds 2; shutdown.exe /s /t 3 }
'@
    Set-Content (Join-Path $in "run.ps1") $run
    $gpu = if ($WithGpu) { "Default" } else { "Disable" }
    $wsb = @"
<Configuration>
  <VGpu>$gpu</VGpu>
  <Networking>Disable</Networking>
  <MemoryInMB>$MemoryMB</MemoryInMB>
  <MappedFolders>
    <MappedFolder><HostFolder>$in</HostFolder><SandboxFolder>C:\In</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$out</HostFolder><SandboxFolder>C:\Out</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder>
  </MappedFolders>
  <LogonCommand><Command>powershell -NoProfile -ExecutionPolicy Bypass -File C:\In\run.ps1</Command></LogonCommand>
</Configuration>
"@
    $wsbFile = Join-Path $work "check.wsb"
    Set-Content $wsbFile $wsb
    Write-Host "starting Windows Sandbox ($(if ($WithGpu) { 'with' } else { 'WITHOUT' }) a virtual GPU, ${MemoryMB} MB)..."
    Start-Process WindowsSandbox.exe -ArgumentList "`"$wsbFile`""
    $t0 = Get-Date
    while (-not (Test-Path (Join-Path $out "done.txt")) -and ((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) { Start-Sleep -Seconds 3 }
    $finished = Test-Path (Join-Path $out "done.txt")
    Check "the sandbox ran the test to the end" $finished
    if (-not $finished) { Write-Host "  (the sandbox did not finish in $TimeoutSec s: close its window by hand; nothing was installed on this PC)" }
    $steps = Join-Path $out "steps.txt"
    if (Test-Path $steps) { Get-Content $steps | ForEach-Object { Write-Host "    $_" } }
    $text = if (Test-Path $steps) { Get-Content $steps -Raw } else { "" }
    Check "Windows ran the launcher on a clean PC" ($text -match "launcher alive=True")
    Check "the game started and was still running 35 s later on a clean PC" ($text -match "game alive=True")
    Check "screenshots were taken of the launcher and the game" ((Test-Path (Join-Path $out "launcher.png")) -and (Test-Path (Join-Path $out "game.png")))
    $log = Join-Path $out "game.log"
    $errs = @()
    if (Test-Path $log) { $errs = Select-String -Path $log -Pattern "ERROR|SCRIPT ERROR|Parse Error|Failed to load|Condition `"" | ForEach-Object { $_.Line } }
    Check "no errors in the game's log ($($errs.Count) found)" ($errs.Count -eq 0)
    $errs | Select-Object -First 8 | ForEach-Object { Write-Host "    $_" }
    if (Test-Path $log) { Select-String -Path $log -Pattern "OpenGL|ANGLE|Vulkan|D3D|renderer|Renderer" | Select-Object -First 4 | ForEach-Object { Write-Host "    log: $($_.Line)" } }
    $keep = Join-Path $dist "clean_pc\sandbox"
    New-Item -ItemType Directory -Force $keep | Out-Null
    foreach ($f in "steps.txt", "game.log", "game.png", "launcher.png") { if (Test-Path (Join-Path $out $f)) { Copy-Item (Join-Path $out $f) $keep -Force } }
} finally {
    Start-Sleep -Seconds 4
    Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
}
Write-Host ""
Write-Host "sandbox_check: $fails failure(s). The sandbox and the folders made for it are gone; results are in dist\clean_pc\sandbox."
exit $(if ($fails -gt 0) { 1 } else { 0 })

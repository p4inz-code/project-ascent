# Project Ascent, web build: a tiny local web server for this folder, then the game opens in your browser.
# Browsers will not run a web game straight from a file on disk (file://): the page may not load its own
# .wasm and .pck files that way. This serves the folder on http://localhost instead. Nothing leaves your PC.
# Close this window to stop the server.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$types = @{
    ".html" = "text/html; charset=utf-8"; ".js" = "application/javascript"; ".wasm" = "application/wasm";
    ".pck" = "application/octet-stream"; ".png" = "image/png"; ".ico" = "image/x-icon"; ".json" = "application/json";
    ".svg" = "image/svg+xml"; ".webmanifest" = "application/manifest+json"
}
$listener = $null
$port = 0
foreach ($p in 8060..8099) {
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add("http://localhost:$p/")
        $l.Start()
        $listener = $l; $port = $p
        break
    } catch { }
}
if ($listener -eq $null) {
    Write-Host "Could not open a local port (8060-8099). Close other servers and try again."
    Read-Host "Press Enter to close"
    exit 1
}
$url = "http://localhost:$port/index.html"
Write-Host ""
Write-Host "  PROJECT ASCENT is running at $url"
Write-Host "  Keep this window open while you play. Close it to stop."
Write-Host ""
if (-not $env:ASCENT_NO_BROWSER) { Start-Process $url }      # tests set ASCENT_NO_BROWSER and open it themselves
while ($listener.IsListening) {
    try { $ctx = $listener.GetContext() } catch { break }
    $req = $ctx.Request
    $res = $ctx.Response
    try {
        $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
        if ($rel -eq "") { $rel = "index.html" }
        $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
        if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $res.StatusCode = 404
        } else {
            $ext = [IO.Path]::GetExtension($path).ToLower()
            $res.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" })
            # Cross-origin isolation headers: harmless for this build and required by threaded web builds.
            $res.Headers.Add("Cross-Origin-Opener-Policy", "same-origin")
            $res.Headers.Add("Cross-Origin-Embedder-Policy", "require-corp")
            $res.Headers.Add("Cache-Control", "no-cache")
            if ($req.HttpMethod -eq "HEAD") {
                $res.ContentLength64 = (Get-Item -LiteralPath $path).Length      # headers only, no body
            } else {
                $bytes = [IO.File]::ReadAllBytes($path)
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        }
    } catch {
        $res.StatusCode = 500
    } finally {
        try { $res.OutputStream.Close() } catch { }
    }
}

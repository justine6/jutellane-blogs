param(
  [int]$Port = 5050
)

$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot ".." "public" | Resolve-Path -ErrorAction Stop

Add-Type -AssemblyName System.Net.HttpListener
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $($root.Path) at $prefix (Ctrl+C to stop)" -ForegroundColor Cyan

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = $ctx.Request.Url.AbsolutePath.TrimStart('/')

    if ([string]::IsNullOrWhiteSpace($path)) { $path = "index.html" }
    # Clean URLs emulation (.html fallback)
    $candidate = Join-Path $root.Path $path
    if (-not (Test-Path $candidate)) {
      $candidateHtml = "$candidate.html"
      if (Test-Path $candidateHtml) { $candidate = $candidateHtml }
    }

    if (Test-Path $candidate) {
      $bytes = [IO.File]::ReadAllBytes($candidate)
      $ctx.Response.StatusCode = 200
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
    }
    $ctx.Response.Close()
  }
} finally {
  $listener.Stop()
}

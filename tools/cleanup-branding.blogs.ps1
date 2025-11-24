Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Blog branding cleanup starting..." -ForegroundColor Cyan

$root = Get-Location
$files = Get-ChildItem -Recurse -File -Include *.html, *.md

$replacements = @{
  "https://www.jutellane.com"            = "https://justinelonglat-lane.com"
  "https://blogs.jutellane.com"          = "https://blogs.justinelonglat-lane.com"
  "https://projects.jutellane.com"       = "https://consulting.justinelonglat-lane.com"
  "Jutellane Solutions"                  = "JustineLonglaT-Lane Consulting"
  "Jutellane"                            = "JustineLonglaT-Lane"
}

$changed = @()

foreach ($file in $files) {
    $original = Get-Content -LiteralPath $file.FullName -Raw

    # --- Skip empty or invalid files ---
    if ([string]::IsNullOrWhiteSpace($original)) {
        Write-Host "⚠️ Skipping empty or non-text file: $($file.FullName)" -ForegroundColor Yellow
        continue
    }

    # Ensure it's a string
    $updated = [string]$original

    foreach ($key in $replacements.Keys) {
        if ($updated -and $updated.Contains($key)) {
            $updated = $updated.Replace($key, $replacements[$key])
        }
    }

    if ($updated -ne $original -and $updated) {
        $updated | Set-Content -LiteralPath $file.FullName -Encoding UTF8
        $changed += $file.FullName
        Write-Host "✓ Updated: $($file.FullName)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "✔ Cleanup completed!" -ForegroundColor Green
Write-Host "Files changed: $($changed.Count)"

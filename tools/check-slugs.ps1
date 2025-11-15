<#
.SYNOPSIS
Validates post slugs under /posts:
- Warns about invalid characters (only a-z, 0-9, - allowed).
- Warns about duplicate slugs across the site.
#>

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path
Set-Location $root

$postsRoot = Join-Path $root "posts"

if (!(Test-Path $postsRoot)) {
    Warn "Posts folder not found at: $postsRoot"
    exit 1
}

Say "Scanning posts in: $postsRoot …"

$items = @()

Get-ChildItem -Path $postsRoot -Recurse -Filter "index.html" | ForEach-Object {
    $file   = $_.FullName
    $folder = Split-Path $file -Parent
    $slug   = Split-Path $folder -Leaf
    $month  = Split-Path (Split-Path $folder -Parent) -Leaf
    $year   = Split-Path (Split-Path (Split-Path $folder -Parent) -Parent) -Leaf

    $items += [pscustomobject]@{
        Slug  = $slug
        Year  = $year
        Month = $month
        Path  = $file
    }
}

if (-not $items) {
    Warn "No posts found."
    exit 0
}

# 1) Invalid characters
$badFormat = $items | Where-Object { -not [regex]::IsMatch($_.Slug, '^[a-z0-9-]+$') }

if ($badFormat) {
    Warn "Slugs with invalid characters (only a-z, 0-9, and '-' allowed):"
    $badFormat | Sort-Object Year, Month, Slug | Format-Table Slug, Year, Month, Path
} else {
    Good "All slugs match pattern ^[a-z0-9-]+$."
}

# 2) Duplicate slugs
$dupes = $items | Group-Object Slug | Where-Object { $_.Count -gt 1 }

if ($dupes) {
    Warn "Duplicate slugs found:"
    foreach ($d in $dupes) {
        Write-Host "Slug: $($d.Name) (count: $($d.Count))" -ForegroundColor Yellow
        $d.Group | Sort-Object Year, Month | Format-Table Year, Month, Path
        Write-Host ""
    }
} else {
    Good "No duplicate slugs detected."
}

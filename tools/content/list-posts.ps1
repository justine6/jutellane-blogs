<#
.SYNOPSIS
Lists all blog posts with slug, date folder, and title.
#>

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }

# Always run from repo root (tools folder may vary)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path
Set-Location $root

$postsRoot = Join-Path $root "posts"

if (!(Test-Path $postsRoot)) {
    Warn "Posts folder not found at: $postsRoot"
    exit 1
}

Say "Scanning all posts in: $postsRoot …"

$results = @()

# Scan: posts/YYYY/MM/slug/index.html
Get-ChildItem -Path $postsRoot -Recurse -Filter "index.html" | ForEach-Object {
    $file = $_.FullName
    $folder = Split-Path $file -Parent
    $slug = Split-Path $folder -Leaf
    $month = Split-Path (Split-Path $folder -Parent) -Leaf
    $year  = Split-Path (Split-Path (Split-Path $folder -Parent) -Parent) -Leaf

    # Extract <title>…</title>
    $title = Select-String -Path $file -Pattern "<title>(.*?)</title>" |
             ForEach-Object {
                $_.Matches[0].Groups[1].Value.Trim()
             }

    if (-not $title) { $title = "(no title tag)" }

    $results += [pscustomobject]@{
        Slug  = $slug
        Year  = $year
        Month = $month
        Title = $title
        Path  = $file
    }
}

Good "Found $($results.Count) posts."
$results | Sort-Object Year, Month, Slug | Format-Table

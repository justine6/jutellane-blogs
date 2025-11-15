<#
.SYNOPSIS
Checks all posts for a <meta name="tags" ...> element in the <head>.
Reports any posts that are missing tags.
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

Say "Checking posts for <meta name=""tags""> …"

$missing = @()

Get-ChildItem -Path $postsRoot -Recurse -Filter "index.html" | ForEach-Object {
    $file   = $_.FullName
    $folder = Split-Path $file -Parent
    $slug   = Split-Path $folder -Leaf
    $month  = Split-Path (Split-Path $folder -Parent) -Leaf
    $year   = Split-Path (Split-Path (Split-Path $folder -Parent) -Parent) -Leaf

    $title = Select-String -Path $file -Pattern "<title>(.*?)</title>" -ErrorAction SilentlyContinue |
             ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }

    $hasTags = Select-String -Path $file -Pattern '<meta\s+name="tags"\s+content="' -Quiet -ErrorAction SilentlyContinue

    if (-not $hasTags) {
        $missing += [pscustomobject]@{
            Slug  = $slug
            Year  = $year
            Month = $month
            Title = $title
            Path  = $file
        }
    }
}

if ($missing.Count -eq 0) {
    Good "All posts have a <meta name=""tags""> element."
} else {
    Warn "Posts missing <meta name=""tags"">:"
    $missing | Sort-Object Year, Month, Slug | Format-Table Slug, Year, Month, Title, Path
}

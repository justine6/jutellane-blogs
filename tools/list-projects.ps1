<#
.SYNOPSIS
Lists all project pages under /projects with slug/date/title.
Assumes structure: projects/YYYY/MM/<slug>/index.html
#>

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path
Set-Location $root

$projectsRoot = Join-Path $root "projects"

if (!(Test-Path $projectsRoot)) {
    Warn "Projects folder not found at: $projectsRoot"
    exit 1
}

Say "Scanning projects in: $projectsRoot …"

$results = @()

Get-ChildItem -Path $projectsRoot -Recurse -Filter "index.html" | ForEach-Object {
    $file   = $_.FullName
    $folder = Split-Path $file -Parent
    $slug   = Split-Path $folder -Leaf
    $month  = Split-Path (Split-Path $folder -Parent) -Leaf
    $year   = Split-Path (Split-Path (Split-Path $folder -Parent) -Parent) -Leaf

    $title = Select-String -Path $file -Pattern "<title>(.*?)</title>" -ErrorAction SilentlyContinue |
             ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }

    if (-not $title) { $title = "(no title tag)" }

    $results += [pscustomobject]@{
        Slug  = $slug
        Year  = $year
        Month = $month
        Title = $title
        Path  = $file
    }
}

Good "Found $($results.Count) project(s)."
$results | Sort-Object Year, Month, Slug | Format-Table

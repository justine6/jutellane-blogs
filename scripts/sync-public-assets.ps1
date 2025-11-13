[CmdletBinding()]
param(
    [string]$SrcRoot   = "..",
    [string]$PublicRoot = "..\public"
)

$ErrorActionPreference = "Stop"

function Say  ($m) { Write-Host "› $m" }
function Good ($m) { Write-Host "✓ $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "! $m" -ForegroundColor Yellow }

# Folders we want to copy into /public
$Sections = @("blog", "projects")

Say "Syncing sections into $PublicRoot ..."

foreach ($name in $Sections) {
    $src = Join-Path $SrcRoot   $name
    $dst = Join-Path $PublicRoot $name

    if (-not (Test-Path $src)) {
        Warn "Skip $name (source folder not found: $src)"
        continue
    }

    Say "• $name → $dst"

    # Clean existing
    if (Test-Path $dst) {
        Remove-Item $dst -Recurse -Force
    }

    # Copy fresh content
    Copy-Item $src $dst -Recurse -Force

    Good "Synced $name"
}

Good "All sections synced into $PublicRoot"

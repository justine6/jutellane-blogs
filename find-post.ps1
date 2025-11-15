param(
  [Parameter(Mandatory = $true)]
  [string]$Slug,

  [switch]$Open   # if passed, auto-open in VS Code
)

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }
function Bad($m){ Write-Host "✗ $m" -ForegroundColor Red }

# Always run from script root for consistency
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$searchRoot = Join-Path $root "posts"

Say "Searching for slug: '$Slug'..."

$matches = Get-ChildItem -Path $searchRoot -Recurse -File -Filter "*.html" |
  Where-Object { $_.FullName -match $Slug }

if (-not $matches) {
  Bad "No post found for slug '$Slug'"
  exit 1
}

if ($matches.Count -gt 1) {
  Say "Multiple matches found:"
  $matches | ForEach-Object { " - $($_.FullName)" }
  Say "Pick the exact file you want."
  exit 0
}

$post = $matches[0]

Good "Found:"
Write-Host "  $($post.FullName)" -ForegroundColor Yellow

if ($Open) {
  Say "Opening in VS Code..."
  code $post.FullName
}

param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [switch]$Open   # if passed, auto-open in VS Code
)

$ErrorActionPreference = "Stop"

function Say($m)  { Write-Host "› $m" -ForegroundColor Cyan }
function Good($m) { Write-Host "✓ $m" -ForegroundColor Green }
function Bad($m)  { Write-Host "✗ $m" -ForegroundColor Red }

# Always resolve paths relative to the script itself
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root      = Split-Path -Parent $scriptDir   # jutellane-blogs/
Set-Location $root

$postsRoot = Join-Path $root "posts"

if (!(Test-Path $postsRoot)) {
  Bad "Posts folder not found at: $postsRoot"
  exit 1
}

Say "Searching for slug: '$Slug' in $postsRoot ..."

# Find any HTML file whose name/path contains the slug
$matches = Get-ChildItem -Path $postsRoot -Recurse -File -Filter "*.html" |
  Where-Object { $_.FullName -like "*$Slug*" }

if (-not $matches) {
  Bad "No matching post found for slug '$Slug'."
  exit 1
}

Good "Found $($matches.Count) match(es):"
$matches | ForEach-Object { "  $($_.FullName)" }

# Optional: open single match in VS Code
if ($Open -and $matches.Count -eq 1) {
  $file = $matches[0].FullName
  if (Get-Command code -ErrorAction SilentlyContinue) {
    Say "Opening in VS Code: $file"
    code $file
  } else {
    Warn "VS Code 'code' command not found; install / add to PATH to use -Open."
  }
}

<#
.SYNOPSIS
  Interactive wrapper for Add-Post.ps1

.DESCRIPTION
  Prompts for title, summary, and tags, then calls Add-Post.ps1
  automatically with all inputs validated.
#>

Write-Host "📝 Create a new Jutellane Blog Post" -ForegroundColor Cyan

$title   = Read-Host "Enter the post title"
if ([string]::IsNullOrWhiteSpace($title)) { Write-Host "❌ Title is required." -ForegroundColor Red; exit 1 }

$summary = Read-Host "Enter a short summary"
$tagsRaw = Read-Host "Enter tags (comma-separated, e.g. AWS,Security,Startups)"

# Normalize and clean up tag input
$tags = $tagsRaw -split '\s*,\s*' | Where-Object { $_ -ne "" }

# Locate the generator
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Generator = Join-Path $Root "Add-Post.ps1"

if (-not (Test-Path $Generator)) {
  Write-Host "❌ Could not find Add-Post.ps1 at $Generator" -ForegroundColor Red
  exit 1
}

# Run the generator
Unblock-File $Generator
Write-Host "⚙️ Generating new post..." -ForegroundColor Yellow
& $Generator -Title $title -Summary $summary -Tags $tags -Open
Write-Host "✅ Done." -ForegroundColor Green

<#
Jutellane Blog Validator (hardened)
- Skips _archive/ folders
- Robust YAML capture (BOM, CRLF/LF)
- Validates: title, date (yyyy-MM-dd), summary, slug
- Checks duplicate slugs among publishable files only
- Warns if canonical is missing
#>

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $PSScriptRoot
$drafts = Join-Path $root "drafts"
$posts  = Join-Path $root "posts"

Write-Host "🔍 Validating drafts and posts in '$root'..." -ForegroundColor Cyan

# Collect markdown files, EXCLUDING any *_archive* path
$allFiles = @()
if (Test-Path $drafts) { $allFiles += Get-ChildItem $drafts -Recurse -Filter *.md }
if (Test-Path $posts)  { $allFiles += Get-ChildItem $posts  -Recurse -Filter *.md }
$files = $allFiles | Where-Object { $_.FullName -notmatch "\\_archive(\\|/)" }

if (-not $files) { Write-Host "⚠️  No Markdown files found (excluding _archive)" -ForegroundColor Yellow; exit 0 }

# Helpers
function Get-Rel([string]$full){ $full.Replace($root, '').TrimStart('\','/') }
function Parse-FM {
  param([string]$content)
  $fm = @{}
  $content = $content -replace '^\uFEFF',''             # strip BOM
  $yaml = $null
  if ($content -match '(?s)^\s*---\s*(.*?)\s*---') { $yaml = $Matches[1] }
  if (-not $yaml) { return $fm }

  foreach ($line in ($yaml -split "`r?`n")) {
    if ($line -match '^\s*(\w+)\s*:\s*(.*)$') {
      $k = $Matches[1]
      $v = $Matches[2].Trim()
      $v = $v.Trim('"').Trim("'")
      $fm[$k] = $v
    }
  }
  return $fm
}
function Require([string]$cond,[string]$msg){ if (-not $cond){ $script:errors += $msg } }

$errors = @()
$warnings = @()
$slugIndex = @{}  # only for publishable (non-_archive) files

foreach ($f in $files) {
  $rel = Get-Rel $f.FullName
  $raw = Get-Content $f.FullName -Raw
  $fm  = Parse-FM $raw

  # Required fields
  Require $fm.title    "❌ Missing title in $rel"
  Require $fm.summary  "❌ Missing summary in $rel"
  Require $fm.date     "❌ Missing date in $rel"
  if ($fm.date -and ($fm.date -notmatch '^\d{4}-\d{2}-\d{2}$')) {
    $errors += "❌ Invalid date format in $rel ($($fm.date)) — expected yyyy-MM-dd"
  }
  Require $fm.slug     "❌ Missing slug in $rel"

  # Canonical (warning only)
  if (-not $fm.canonical) {
    $warnings += "⚠️  No canonical link in $rel (optional but recommended)"
  }

  # Duplicate slug check (among publishable files only)
  if ($fm.slug) {
    if ($slugIndex.ContainsKey($fm.slug)) {
      $other = $slugIndex[$fm.slug]
      $errors += "❌ Duplicate slug '$($fm.slug)' found in $rel and $other"
    } else {
      $slugIndex[$fm.slug] = $rel
    }
  }
}

# Output
$warnings | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }

if ($errors.Count) {
  Write-Host "`n❌ Validation failed:`n" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  Write-Host "`nFix the above errors before publishing." -ForegroundColor Red
  exit 1
} else {
  Write-Host "`n✅ All drafts/posts passed validation." -ForegroundColor Green
}

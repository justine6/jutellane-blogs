param()

$ErrorActionPreference = 'Stop'

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }

Say "Branding blog posts as 'Justine Longla T. DevOps Blog'..."

# 1) Target all post HTML files
$postFiles = Get-ChildItem -Path "posts" -Recurse -Filter "index.html"

# 2) Patterns we want to replace
$replacements = @(
  @{ From = 'Jutellane Blog';    To = 'Justine Longla T. DevOps Blog' },
  @{ From = 'Jutellane Blogs';   To = 'Justine Longla T. DevOps Blog' }
)

$changed = 0

foreach ($file in $postFiles) {
  $html = Get-Content $file.FullName -Raw
  $original = $html

  foreach ($r in $replacements) {
    $fromEscaped = [Regex]::Escape($r.From)
    $html = $html -replace $fromEscaped, $r.To
  }

  if ($html -ne $original) {
    $html | Set-Content -Encoding UTF8 $file.FullName
    Say "Updated $($file.FullName)"
    $changed++
  }
}

Good "Done. Updated $changed file(s)."

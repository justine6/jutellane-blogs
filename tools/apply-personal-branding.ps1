param(
  [switch]$WhatIf  # run with -WhatIf first to see changes
)

$ErrorActionPreference = 'Stop'

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }

# 1) Limit scope to content + layouts (NOT build outputs of other sites)
$roots = @(
  "docs",
  "posts",
  "projects",
  "templates",
  "src",
  "public/_layout"
)

# 2) Replacement map (visible text only)
$replacements = @(
  @{ From = "Jutellane Blogs";  To = "Justine Longla T. — DevOps Blog"; },
  @{ From = "Jutellane Blog";   To = "Justine Longla T. — DevOps Blog"; },
  @{ From = "Jutellane Docs";   To = "Justine Longla — DevOps Toolkit"; },
  @{ From = "Jutellane Solutions"; To = "Justine Longla T."; }
)

# 3) Also catch plain 'Jutellane' in text (but NOT in domains like jutellane.com)
$plainPattern = '\bJutellane\b(?!\.)'   # "Jutellane" not followed by a dot

Say "Scanning content roots: $($roots -join ', ')"

$files = foreach ($root in $roots) {
  if (Test-Path $root) {
    Get-ChildItem $root -Recurse -File -Include *.html,*.md
  }
}

if (-not $files) {
  Say "No files found in target roots – nothing to do."
  return
}

$changedCount = 0

foreach ($file in $files) {
  $text = Get-Content $file.FullName -Raw
  $original = $text

  foreach ($r in $replacements) {
    $text = $text -replace [regex]::Escape($r.From), $r.To
  }

  # generic Jutellane → Justine Longla T. (text only)
  $text = [regex]::Replace($text, $plainPattern, 'Justine Longla T.')

  if ($text -ne $original) {
    $changedCount++
    if ($WhatIf) {
      Say "Would update $($file.FullName)"
    } else {
      Set-Content -Path $file.FullName -Value $text -Encoding UTF8
      Good "Updated $($file.FullName)"
    }
  }
}

Say "Done. Files changed: $changedCount"

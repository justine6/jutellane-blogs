param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }

# Always run from script root
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$headerPath = "public/_layout/header.html"
$footerPath = "public/_layout/footer.html"

if (!(Test-Path $headerPath) -or !(Test-Path $footerPath)) {
  Warn "Header/footer partials missing in public/_layout – nothing to refresh."
  return
}

$header = Get-Content $headerPath -Raw
$footer = Get-Content $footerPath -Raw

# Targets to normalize
$targets = @(
  "public/index.html",
  "public/blog/index.html",
  "public/projects/index.html",
  "public/docs/index.html",
  "public/posts/index.html"
) | Where-Object { Test-Path $_ }

if (-not $targets.Count) {
  Warn "No target HTML files found to refresh."
  return
}

Say "Refreshing layout on $($targets.Count) file(s)..."
foreach ($file in $targets) {
  Say "• $file"

  $html = Get-Content $file -Raw

  # 1) Strip any existing header/footer blocks we know about
  $before = $html

  # remove any old "Site header" block
  $html = [regex]::Replace(
    $html,
    '(?s)<!--\s*Site header\s*-->.*?</header>',
    ''
  )

  # remove any header with id="jl-header" (safety)
  $html = [regex]::Replace(
    $html,
    '(?s)<header[^>]*id="jl-header"[^>]*>.*?</header>',
    ''
  )

  # remove any old "Global footer" block
  $html = [regex]::Replace(
    $html,
    '(?s)<!--\s*Global footer\s*-->.*?</footer>',
    ''
  )

  # remove any footer with id="jl-footer" (safety)
  $html = [regex]::Replace(
    $html,
    '(?s)<footer[^>]*id="jl-footer"[^>]*>.*?</footer>',
    ''
  )

  # 2) Inject fresh header right after <body>
  $bodyOpen = $html.IndexOf('<body', [StringComparison]::OrdinalIgnoreCase)
  if ($bodyOpen -ge 0) {
    $close = $html.IndexOf('>', $bodyOpen)
    if ($close -ge 0) {
      $html = $html.Insert($close + 1, "`r`n  <!-- Site header -->`r`n" + $header + "`r`n")
    }
  } else {
    Warn "Could not find <body> in $file – skipped header injection."
  }

  # 3) Inject fresh footer just before </body>
  $bodyClose = $html.LastIndexOf('</body>', [StringComparison]::OrdinalIgnoreCase)
  if ($bodyClose -ge 0) {
    $html = $html.Insert($bodyClose, "`r`n  <!-- Global footer -->`r`n" + $footer + "`r`n")
  } else {
    Warn "Could not find </body> in $file – skipped footer injection."
  }

  if ($DryRun) {
    Good "Dry run: would refresh $file"
  } else {
    Set-Content -Path $file -Value $html -Encoding UTF8
    Good "Refreshed $file"
  }
}

Good "Layout refresh complete."

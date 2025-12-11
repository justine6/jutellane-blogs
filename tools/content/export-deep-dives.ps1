param(
  [string]$SourceRoot = "posts/2025/11",
  [string]$OutputDir  = "public/docs/deep-dives"
)

$ErrorActionPreference = "Stop"

function Say($msg) { Write-Host "› $msg" -ForegroundColor Cyan }
function Good($msg){ Write-Host "✓ $msg" -ForegroundColor Green }
function Bad($msg) { Write-Host "✗ $msg" -ForegroundColor Red }

# 👉 Call wkhtmltopdf by full path, no PATH required
$wkhtml = "C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe"

if (-not (Test-Path $wkhtml)) {
  Bad "wkhtmltopdf.exe not found at $wkhtml"
  exit 1
}

if (!(Test-Path $OutputDir)) {
  New-Item -Type Directory -Path $OutputDir | Out-Null
  Say "Created output directory $OutputDir"
}

# Deep Dive slugs – extend this list as you add more
$deepDiveSlugs = @(
  "self-healing-blog-pipeline",
  "cicd-pipeline-performance",
  "audit-html-powershell",
  "audit-containers-with-powershell"
)

foreach ($slug in $deepDiveSlugs) {
  $htmlPath = Join-Path $SourceRoot "$slug.html"
  if (-not (Test-Path $htmlPath)) {
    Say "Skipping $slug (HTML not found at $htmlPath)"
    continue
  }

  $pdfOut   = Join-Path $OutputDir "$slug.pdf"
  $fullPath = (Resolve-Path $htmlPath).ProviderPath

  # Resolve CSS file for wkhtmltopdf
  $cssPath = (Resolve-Path "public/assets/css/main.css").ProviderPath

  Say "Using stylesheet: $cssPath"

  & $wkhtml `
    --print-media-type `
    --enable-local-file-access `
    --user-style-sheet "$cssPath" `
    $fullPath $pdfOut


  if ($LASTEXITCODE -eq 0) {
    Good "PDF created: $pdfOut"
  } else {
    Bad "Failed to export $slug (exit code $LASTEXITCODE)"
  }
}

Good "Deep Dive PDF export complete."

param(
  [string]$Root = "."
)

$Intro    = "https://jutellane.com/booking"
$Contact  = "https://jutellane.com/contact"
$Resume   = "https://jutellane.com/resume.pdf"
$Brochure = "https://jutellane.com/files/brochure.pdf"

Write-Host "› Updating header links under $Root\public ..." -ForegroundColor Cyan

Get-ChildItem -Path (Join-Path $Root "public") -Recurse -Filter *.html -File | ForEach-Object {
  $path = $_.FullName

  $original = Get-Content -Path $path -Raw
  $updated  = $original `
    -replace "https://YOUR-MAIN-SITE/intro-call",   $Intro `
    -replace "https://YOUR-MAIN-SITE/contact",      $Contact `
    -replace "https://YOUR-MAIN-SITE/resume.pdf",   $Resume `
    -replace "https://YOUR-MAIN-SITE/brochure.pdf", $Brochure

  if ($updated -ne $original) {
    Set-Content -Path $path -Value $updated -NoNewline
    Write-Host "✓ Patched $path" -ForegroundColor Green
  }
}

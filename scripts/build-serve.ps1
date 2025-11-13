<#
.SYNOPSIS
Builds and serves Jutellane Blogs locally, ensuring all required folders and assets exist.
#>

param([int]$Port = 8080)

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }

# --- 1) Ensure 'public' and assets structure exist ----------------------------
$pub = "public"
$css = Join-Path $pub "assets\css"
$img = Join-Path $pub "assets\img"
$ico = Join-Path $pub "favicon.ico"

Say "Checking folder structure..."
New-Item -ItemType Directory -Force -Path $css, $img | Out-Null

# --- 2) Ensure main.css exists -----------------------------------------------
$cssFile = Join-Path $css "main.css"
if (!(Test-Path $cssFile)) {
  Warn "main.css missing → creating placeholder."
  @"
body {
  font-family: system-ui, sans-serif;
  background: #fff;
  color: #111;
  margin: 2rem;
}
h1 { font-size: 2.2rem; }
a { color: royalblue; text-decoration: none; }
a:hover { text-decoration: underline; }
"@ | Set-Content -Encoding UTF8 $cssFile
}

# --- 3) Ensure favicon.ico exists -------------------------------------------
if (!(Test-Path $ico)) {
  Warn "favicon.ico missing → creating minimal placeholder."
  $icoBytes = [byte[]](0x00,0x00,0x01,0x00,0x01,0x00,0x10,0x10,0x00,0x00,0x01,0x00,0x04,0x00,0x28,0x01,0x00,0x00)
  [IO.File]::WriteAllBytes($ico, $icoBytes)
}

# --- 4) Ensure index.html exists --------------------------------------------
$index = Join-Path $pub "index.html"
if (!(Test-Path $index)) {
  Warn "index.html missing → creating sample homepage."
  @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Welcome 👋 | Jutellane Blogs</title>
  <link rel="icon" href="/favicon.ico">
  <link rel="stylesheet" href="/assets/css/main.css">
</head>
<body>
  <main class="container">
    <h1>Welcome 👋</h1>
    <ul>
      <li><a href="/blog/">All Blog Posts</a></li>
      <li><a href="/projects/">Projects</a></li>
    </ul>
  </main>
</body>
</html>
'@ | Set-Content -Encoding UTF8 $index
  Good "Created $index"
}

# --- 5) Run build step -------------------------------------------------------
Say "Cleaning previous build and running index generator..."
if (Test-Path "public_layout") { Remove-Item "public_layout" -Recurse -Force -ErrorAction SilentlyContinue }
npm run prebuild

# --- 6) Serve locally --------------------------------------------------------
Say "Starting local server on http://localhost:$Port ..."
npx http-server $pub -p $Port -a 0.0.0.0 -c-1

<#
.SYNOPSIS
Builds and serves Justine Longla T. DevOps Blog locally, ensuring all required folders and assets exist.
#>

param([int]$Port = 8080)

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }

# Optional: always run from the repo root (one level above /scripts)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path   # ...\scripts
$root      = Split-Path -Parent $scriptDir                     # repo root
Set-Location $root

# --- 1) Ensure 'public' and assets structure exist ----------------------------
$pub = "public"
$css = Join-Path $pub "assets\css"
$img = Join-Path $pub "assets\img"
$ico = Join-Path $pub "favicon.ico"

# --- GUARD: never treat public/posts or public/tags as source-of-truth -------
$publicPosts = Join-Path $pub "posts"
$publicTags  = Join-Path $pub "tags"

if (Test-Path $publicPosts) {
  Say "Guard: cleaning generated public/posts (edit files in 'posts/', not 'public/posts/')."
  Remove-Item $publicPosts -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path $publicTags) {
  Say "Guard: cleaning generated public/tags (edit files in 'src/partials/tags', not 'public/tags/')."
  Remove-Item $publicTags -Recurse -Force -ErrorAction SilentlyContinue
}

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
  <title>Welcome 👋 | Justine Longla T. DevOps Blog</title>
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
if (Test-Path "public_layout") {
  Remove-Item "public_layout" -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Make docs available in public/ ------------------------------------------
$docsSrc  = Join-Path $root "docs"
$docsDest = Join-Path $pub "docs"

if (Test-Path $docsDest) {
  Remove-Item $docsDest -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path $docsSrc) {
  try {
    # Try symlink first (best DX)
    New-Item -ItemType SymbolicLink -Path $docsDest -Target $docsSrc -ErrorAction Stop | Out-Null
    Say "Linked docs/ → public/docs (symbolic link)."
  }
  catch {
    # Fallback: just copy the folder if symlink fails
    Warn "Could not create symbolic link for docs (falling back to copy)."
    Copy-Item $docsSrc $docsDest -Recurse -Force
    Good "Copied docs/ → public/docs."
  }
}
else {
  Warn "docs/ folder not found → skipping docs link."
}

npm run prebuild

# --- 6) Serve locally --------------------------------------------------------
Say "Starting local server on http://localhost:$Port ..."
npx http-server $pub -p $Port -a 0.0.0.0 -c-1
if ($LASTEXITCODE -ne 0) {
  Warn "http-server exited with code $LASTEXITCODE. If you see EADDRINUSE, another server may already be running on port $Port."
}

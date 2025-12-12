param(
  [Parameter(Mandatory = $true)]
  [string]$DraftPath
)

$ErrorActionPreference = "Stop"

# 🔧 Site-level constants (update here when branding or paths change)
$SiteName = "Justine Longla T. DevOps Blog"
$BackHref = "/blog/"  # where your "Back" link should go

if (-not (Test-Path $DraftPath)) {
  throw "Draft not found: $DraftPath"
}

Write-Host "📄 Publishing draft: $DraftPath" -ForegroundColor Cyan

# Repo root = parent of /tools
$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Resolve-Path ".").Path }

# posts source folder (content) — this matches your repo: /posts/2025/...
$postsRoot = Join-Path $root "posts"

# public output folder — your site deploys /public/**
$publicRoot = Join-Path $root "public"
$publicPostsRoot = Join-Path $publicRoot "posts"

# Read RAW Markdown
$raw = Get-Content -Path $DraftPath -Raw

if ($raw -notmatch "(?s)^---\s*(.*?)\s*---\s*(.*)$") {
  throw "❌ No YAML front matter found in draft."
}

$fm   = $Matches[1]
$body = $Matches[2]

function Get-YamlVal([string]$yaml, [string]$key) {
  if ($yaml -match "(?m)^\s*$key\s*:\s*(.+?)\s*$") {
    return ($Matches[1] -replace '^\s*["'']|["'']\s*$','')
  }
  return $null
}

function Get-YamlTags([string]$yaml) {
  # supports: tags: ["a","b"]  OR  tags:\n - a\n - b
  if ($yaml -match "(?s)^\s*tags\s*:\s*\[(.*?)\]") {
    return ($Matches[1] -split ",") |
      ForEach-Object { ($_ -replace "['""]","").Trim() } |
      Where-Object { $_ -ne "" }
  }

  $block = $yaml -match "(?ms)^\s*tags\s*:\s*\r?\n((?:\s*-\s*.*\r?\n)+)"
  if ($block) {
    return ($Matches[1] -split "\r?\n") |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -like "- *" } |
      ForEach-Object { ($_ -replace "^- ","").Trim() } |
      Where-Object { $_ -ne "" }
  }

  return @()
}

function Slugify([string]$s) {
  if (-not $s) { return "" }
  $slug = $s -replace "[^a-zA-Z0-9\s-]", ""
  $slug = $slug.ToLower()
  $slug = $slug -replace "\s+","-"
  $slug = $slug -replace "-+","-"
  return $slug.Trim("-")
}

$title     = Get-YamlVal $fm "title"
$dateStr   = Get-YamlVal $fm "date"
$canonical = Get-YamlVal $fm "canonical"
$slug      = Get-YamlVal $fm "slug"
$tags      = Get-YamlTags $fm

if (-not $title) { throw "Missing 'title' in YAML front matter." }

if (-not $slug -or $slug.Trim() -eq "") {
  $slug = Slugify $title
}

# Parse date safely
[datetime]$date = Get-Date
if ($dateStr) {
  $formats = @("yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy")
  $culture = [System.Globalization.CultureInfo]::InvariantCulture
  $parsed  = $null

  foreach ($fmt in $formats) {
    try { $parsed = [datetime]::ParseExact($dateStr, $fmt, $culture); break } catch {}
  }

  if ($parsed -eq $null) {
    throw "Invalid date format: '$dateStr'. Expected: $($formats -join ', ')"
  }

  $date = $parsed
}

$year  = $date.ToString("yyyy")
$month = $date.ToString("MM")

# Source destination: /posts/YYYY/MM/slug/
$destContentDir = Join-Path $postsRoot (Join-Path $year (Join-Path $month $slug))
New-Item -ItemType Directory -Force -Path $destContentDir | Out-Null

# Public destination: /public/posts/YYYY/MM/slug/
$destPublicDir = Join-Path $publicPostsRoot (Join-Path $year (Join-Path $month $slug))
New-Item -ItemType Directory -Force -Path $destPublicDir | Out-Null

Write-Host "📁 Writing content to: $destContentDir" -ForegroundColor Green
Write-Host "🌐 Writing public HTML to: $destPublicDir" -ForegroundColor Green

# Save Markdown source
$postMd = Join-Path $destContentDir "post.md"
Set-Content -Path $postMd -Value $raw -Encoding UTF8

# Always generate public index.html (your site is static under /public)
Add-Type -AssemblyName System.Web
$titleEsc = [System.Web.HttpUtility]::HtmlEncode($title)

$tagsMeta = ($tags -join ", ")
$tagsEsc  = [System.Web.HttpUtility]::HtmlEncode($tagsMeta)
$bodyEsc  = [System.Web.HttpUtility]::HtmlEncode($body)

$chips = ""
if ($tags.Count -gt 0) {
  $chips = ($tags | ForEach-Object { "<span class=""tag"">$([System.Web.HttpUtility]::HtmlEncode($_))</span>" }) -join " "
}

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>$titleEsc — $SiteName</title>
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta name="description" content="$titleEsc" />
  <meta name="tags" content="$tagsEsc" />
  <link rel="stylesheet" href="/assets/css/main.css" />
</head>
<body>
  <a class="skip" href="#content">Skip to content</a>
  <main id="content" class="container prose">
    <p class="post-meta">
      By Justine Longla ·
      <time datetime="$($date.ToString("yyyy-MM-dd"))">$($date.ToString("MMM d, yyyy"))</time>
    </p>

    <h1>$titleEsc</h1>

    <div class="meta">$($date.ToString("yyyy-MM-dd")) · $chips</div>

    <div class="content">
      <pre style="white-space:pre-wrap">$bodyEsc</pre>
    </div>

    <p style="margin-top:2rem;">
      <a href="$BackHref">← Back</a>
    </p>
  </main>
</body>
</html>
"@

Set-Content -Path (Join-Path $destPublicDir "index.html") -Value $html -Encoding UTF8

# Archive the draft
$archive = Join-Path (Split-Path -Parent $DraftPath) "_archive"
New-Item -ItemType Directory -Force -Path $archive | Out-Null
Move-Item -Force -Path $DraftPath -Destination (Join-Path $archive (Split-Path $DraftPath -Leaf))

Write-Host ""
Write-Host "✅ Draft published successfully" -ForegroundColor Yellow
[PSCustomObject]@{
  Title = $title
  Slug  = $slug
  Date  = $date.ToString("yyyy-MM-dd")
  Tags  = ($tags -join ", ")
  ContentPath = $destContentDir
  PublicPath  = $destPublicDir
} | Format-Table -AutoSize

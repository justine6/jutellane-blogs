param(
  [string]$SiteUrl = "https://justine6.github.io/jutellane-blogs",
  [switch]$FillCanonical = $true
)
$ErrorActionPreference = "Stop"

$root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Resolve-Path ".").Path }
$drafts = Join-Path $root "drafts"
$posts  = Join-Path $root "posts"

Write-Host "🔧 Fixing front matter under $root..." -ForegroundColor Cyan

function Slugify([string]$t) {
  ($t.ToLower() -replace "[^a-z0-9\s-]", "" -replace "\s+", "-" -replace "-+", "-").Trim("-")
}
function Capture-FM([string]$raw) {
  $raw = $raw -replace '^\uFEFF',''
  if ($raw -match '(?s)^\s*---\s*(.*?)\s*---\s*(.*)$') { @{ yaml=$Matches[1]; body=$Matches[2] } } else { $null }
}
function Parse-FM([string]$yaml) {
  $h=@{}; foreach($line in ($yaml -split "`r?`n")){
    if ($line -match '^\s*(\w+)\s*:\s*(.*)$'){ $k=$Matches[1]; $v=$Matches[2].Trim().Trim('"').Trim("'"); $h[$k]=$v }
  }; $h
}
function Build-FM($h) { @"
---
title: "$($h.title)"
date: $($h.date)
tags: [$($h.tags)]
summary: "$($h.summary)"
canonical: "$($h.canonical)"
slug: "$($h.slug)"
---
"@ }

# Collect markdown files (skip _archive)
$files=@()
if (Test-Path $drafts){ $files += Get-ChildItem $drafts -Recurse -Filter *.md }
if (Test-Path $posts ){ $files += Get-ChildItem $posts  -Recurse -Filter *.md }
$files = $files | Where-Object { $_.FullName -notmatch "\\_archive(\\|/)" }

if (-not $files){ Write-Host "⚠️  No markdown files found." -ForegroundColor Yellow; exit 0 }

# Pass 1: parse + fill
$slugCount=@{}; $metas=@()
foreach($f in $files){
  $raw = Get-Content $f.FullName -Raw -Encoding UTF8
  $cap = Capture-FM $raw
  if(-not $cap){ Write-Warning "No front matter: $($f.FullName)"; continue }

  $h = Parse-FM $cap.yaml
  if(-not $h.title){ $h.title = [IO.Path]::GetFileNameWithoutExtension($f.Name) }
  if(-not $h.date ){ $h.date  = (Get-Date -Format "yyyy-MM-dd") }
  if(-not $h.tags ){ $h.tags  = "" }
  if(-not $h.slug ){ $h.slug  = Slugify $h.title }

  if(-not $h.summary){
    $plain = ($cap.body -replace '\r','' -replace '\n',' ' -replace '\s+',' ').Trim()
    $h.summary = if ($plain.Length -gt 160) { $plain.Substring(0,160) + "..." } else { $plain }
  }

  if ($FillCanonical -and (-not $h.canonical)) {
    $rel = $f.FullName.Replace($root,'').TrimStart('\','/'); $rel = $rel -replace '\\','/'; $rel = $rel -replace 'drafts/','posts/'
    $h.canonical = "$SiteUrl/$rel".Replace('post.md','')
  }

  $metas += [pscustomobject]@{ File=$f; H=$h; Body=$cap.body }
  if(-not $slugCount.ContainsKey($h.slug)){ $slugCount[$h.slug]=0 }; $slugCount[$h.slug]++
}

# Pass 2: resolve duplicate slugs
$dups = $slugCount.GetEnumerator() | Where-Object { $_.Value -gt 1 } | ForEach-Object { $_.Key }
foreach($slug in $dups){
  $i=1
  foreach($m in $metas | Where-Object { $_.H.slug -eq $slug } | Sort-Object { $_.File.FullName }){
    if($i -gt 1){ $m.H.slug = "$slug-v$i"; Write-Host "⚙️  $slug -> $($m.H.slug)" -ForegroundColor Yellow }
    $i++
  }
}

# Pass 3: write back
foreach($m in $metas){
  $yaml = Build-FM $m.H
  Set-Content -Path $m.File.FullName -Encoding UTF8 -Value ($yaml + "`r`n" + $m.Body)
  Write-Host "✅ Updated: $($m.File.FullName) (slug: $($m.H.slug))"
}

Write-Host "`n✨ Fix completed." -ForegroundColor Green

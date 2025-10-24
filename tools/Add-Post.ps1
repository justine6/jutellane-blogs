param([Parameter(Mandatory = $true)] [string] $DraftPath)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $DraftPath)) { throw "Draft not found: $DraftPath" }

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Resolve-Path ".").Path }

$postsDir = Join-Path $root "posts"

$raw = Get-Content -Path $DraftPath -Raw
if ($raw -notmatch "(?s)^---\s*(.*?)\s*---\s*(.*)$") { throw "No YAML front matter found." }
$fm   = $Matches[1]
$body = $Matches[2]

function Get-YamlVal([string]$yaml, [string]$key) {
  if ($yaml -match "(?m)^\s*$key\s*:\s*(.+?)\s*$") { return ($Matches[1] -replace '^\s*["'']|["'']\s*$','') }
  return $null
}
function Get-YamlTags([string]$yaml) {
  if ($yaml -match "(?s)^\s*tags\s*:\s*\[(.*?)\]") {
    $inner = $Matches[1]
    return ($inner -split ",") | ForEach-Object { ($_ -replace "['""]","").Trim() } | Where-Object { $_ -ne "" }
  } else { @() }
}

$title     = Get-YamlVal $fm "title"
$date      = Get-YamlVal $fm "date"
$canonical = Get-YamlVal $fm "canonical"
$slug      = Get-YamlVal $fm "slug"
$tags      = Get-YamlTags $fm

if (-not $title) { throw "Missing 'title'." }
if (-not $date)  { $date = (Get-Date -Format "yyyy-MM-dd") }
if (-not $slug)  { $slug = ($title -replace "[^a-zA-Z0-9\s-]","").ToLower() -replace "\s+","-" -replace "-+","-" }

$dt   = [datetime]::Parse($date)
$dest = Join-Path $postsDir (Join-Path ($dt.ToString("yyyy")) (Join-Path ($dt.ToString("MM")) $slug))
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# keep the original markdown in the published folder
$mdOut = Join-Path $dest "post.md"
Set-Content -Path $mdOut -Value $raw -Encoding UTF8

# create a minimal HTML if no canonical
if (-not $canonical) {
  Add-Type -AssemblyName System.Web
  $titleEsc = [System.Web.HttpUtility]::HtmlEncode($title)
  $chips    = ($tags | ForEach-Object { "<span class='tag'>$_</span>" }) -join " "
  $html = @"
<!doctype html>
<meta charset="utf-8">
<title>$titleEsc — Jutellane Blogs</title>
<link rel="stylesheet" href="../../../../styles.postpage.css">
<main class="wrap">
  <nav><a href="/jutellane-blogs/">← Back</a></nav>
  <article>
    <h1>$titleEsc</h1>
    <div class="meta">$($dt.ToString("yyyy-MM-dd")) · $chips</div>
    <div class="content"><pre style="white-space:pre-wrap">$([System.Web.HttpUtility]::HtmlEncode($body))</pre></div>
  </article>
</main>
"@
  Set-Content -Path (Join-Path $dest "index.html") -Value $html -Encoding UTF8
}

# archive the draft
$archive = Join-Path (Split-Path -Parent $DraftPath) "_archive"
if (-not (Test-Path $archive)) { New-Item -ItemType Directory -Path $archive | Out-Null }
Move-Item -Force -Path $DraftPath -Destination (Join-Path $archive (Split-Path $DraftPath -Leaf))

Write-Host "Published → $dest"

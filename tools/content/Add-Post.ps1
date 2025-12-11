param(
  [Parameter(Mandatory = $true)]
  [string]$DraftPath
)

# 🔧 Site-level constants (update here when branding or paths change)
$SiteName = "JustineLonglaT-Lane Blogs"
$BackHref = "/justinelonglat-lane-blogs/"   # e.g. blog home route

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DraftPath)) {
    throw "Draft not found: $DraftPath"
}

Write-Host "📄 Publishing draft: $DraftPath" -ForegroundColor Cyan

# Root = tools/ (parent of tools/content)
$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Resolve-Path ".").Path }

# tools/posts
$postsDir = Join-Path $root "posts"

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
    if ($yaml -match "(?s)^\s*tags\s*:\s*\[(.*?)\]") {
        return ($Matches[1] -split ",") |
            ForEach-Object { ($_ -replace "['""]","").Trim() } |
            Where-Object { $_ -ne "" }
    }
    return @()
}

$title     = Get-YamlVal $fm "title"
$dateStr   = Get-YamlVal $fm "date"
$canonical = Get-YamlVal $fm "canonical"
$slug      = Get-YamlVal $fm "slug"
$tags      = Get-YamlTags $fm

if (-not $title) { throw "Missing 'title' field in YAML." }

if (-not $slug -or $slug.Trim() -eq "") {
    $slug = ($title -replace "[^a-zA-Z0-9\s-]", "").ToLower() -replace "\s+","-" -replace "-+","-"
}

# Date parsing (robust across PowerShell/.NET versions)
[datetime]$date = Get-Date
if ($dateStr) {
    $formats = @("yyyy-MM-dd", "MM/dd/yyyy", "yyyy/MM/dd")
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $parsed  = $null

    foreach ($fmt in $formats) {
        try {
            $parsed = [datetime]::ParseExact($dateStr, $fmt, $culture)
            break
        }
        catch {
            # try next format
        }
    }

    if ($parsed -eq $null) {
        throw "Invalid date format: '$dateStr'. Expected one of: $($formats -join ', ')"
    }

    $date = $parsed
}

# Build post folder structure: tools/posts/YYYY/MM/slug
$year  = $date.ToString("yyyy")
$month = $date.ToString("MM")

$dest = Join-Path $postsDir (Join-Path $year (Join-Path $month $slug))
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "📁 Writing post to: $dest" -ForegroundColor Green

# Write Markdown
$postMd = Join-Path $dest "post.md"
Set-Content -Path $postMd -Value $raw -Encoding UTF8

# Build HTML fallback if no canonical
if (-not $canonical -or $canonical.Trim() -eq "") {

    Add-Type -AssemblyName System.Web
    $titleEsc = [System.Web.HttpUtility]::HtmlEncode($title)
    $chips    = ($tags | ForEach-Object { "<span class='tag'>$_</span>" }) -join " "

    $html = @"
<!doctype html>
<meta charset="utf-8">
<title>$titleEsc — $SiteName</title>
<link rel="stylesheet" href="../../../../styles.postpage.css">
<main class="wrap">
  <nav><a href="$BackHref">← Back</a></nav>
  <article>
    <h1>$titleEsc</h1>
    <div class="meta">$($date.ToString("yyyy-MM-dd")) · $chips</div>
    <div class="content"><pre style="white-space:pre-wrap">$([System.Web.HttpUtility]::HtmlEncode($body))</pre></div>
  </article>
</main>
"@

    Set-Content -Path (Join-Path $dest "index.html") -Value $html -Encoding UTF8
}

# Archive draft
$archive = Join-Path (Split-Path -Parent $DraftPath) "_archive"
New-Item -ItemType Directory -Force -Path $archive | Out-Null

Move-Item -Force -Path $DraftPath -Destination (Join-Path $archive (Split-Path $DraftPath -Leaf))

# Summary Table
Write-Host ""
Write-Host "✅ Post published successfully:" -ForegroundColor Yellow
Write-Host ""

$table = [PSCustomObject]@{
    Title = $title
    Slug  = $slug
    Date  = $date.ToString("yyyy-MM-dd")
    Tags  = ($tags -join ", ")
    Path  = $dest
}

$table | Format-Table -AutoSize

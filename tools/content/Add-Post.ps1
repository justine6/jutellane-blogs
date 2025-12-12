param(
  [Parameter(Mandatory = $true)]
  [string]$DraftPath
)

$ErrorActionPreference = "Stop"

# ---------------------------
# Site constants
# ---------------------------
$SiteTitle = "Justine Longla T. DevOps Blog"
$SiteOwner = "Justine Longla"
$CssHref   = "/assets/css/main.css"   # your global stylesheet
$LogoHref  = "/logo.png"

# repo root = parent of /tools
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $repoRoot) { $repoRoot = (Resolve-Path ".").Path }

$publicRoot = Join-Path $repoRoot "public"
$publicPostsRoot = Join-Path $publicRoot "posts"

if (-not (Test-Path $DraftPath)) {
  throw "Draft not found: $DraftPath"
}

Write-Host "📄 Publishing draft: $DraftPath" -ForegroundColor Cyan

# ---------------------------
# Read raw markdown
# ---------------------------
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
  # supports tags: [a, b] OR tags:\n - a\n - b
  if ($yaml -match "(?s)^\s*tags\s*:\s*\[(.*?)\]") {
    return ($Matches[1] -split ",") |
      ForEach-Object { ($_ -replace "['""]","").Trim() } |
      Where-Object { $_ -ne "" }
  }

  $block = $yaml -match "(?ms)^\s*tags\s*:\s*\r?\n(.*?)(^\s*[a-zA-Z_]+\s*:|\z)"
  if ($block) {
    return ($Matches[1] -split "\r?\n") |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -like "- *" } |
      ForEach-Object { $_.Substring(2).Trim() } |
      Where-Object { $_ -ne "" }
  }

  return @()
}

function To-Slug([string]$text) {
  $text = $text -replace "[^a-zA-Z0-9\s-]", ""
  $text = $text.ToLower() -replace "\s+", "-" -replace "-+", "-"
  return $text.Trim("-")
}

$title     = Get-YamlVal $fm "title"
$dateStr   = Get-YamlVal $fm "date"
$canonical = Get-YamlVal $fm "canonical"
$slug      = Get-YamlVal $fm "slug"
$desc      = Get-YamlVal $fm "description"
$readMins  = Get-YamlVal $fm "readMinutes"
$tags      = Get-YamlTags $fm

if (-not $title) { throw "Missing 'title' field in YAML." }

if (-not $slug -or $slug.Trim() -eq "") {
  $slug = To-Slug $title
}

# Parse date (safe across PS versions)
[datetime]$date = Get-Date
if ($dateStr) {
  $formats = @("yyyy-MM-dd", "MM/dd/yyyy", "yyyy/MM/dd")
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
$iso   = $date.ToString("yyyy-MM-dd")
$human = $date.ToString("MMM d, yyyy")

if (-not $desc -or $desc.Trim() -eq "") {
  $desc = "Practical notes and automation for DevSecOps, cloud, and reliability."
}
if (-not $readMins -or $readMins.Trim() -eq "") {
  $readMins = "3 min read"
}

# ---------------------------
# Destination (PUBLIC)
# ---------------------------
$dest = Join-Path $publicPostsRoot (Join-Path $year (Join-Path $month $slug))
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$indexHtml = Join-Path $dest "index.html"

Write-Host "📁 Writing PUBLIC post page to: $indexHtml" -ForegroundColor Green

# ---------------------------
# HTML: if canonical exists, create redirect page; otherwise render content
# ---------------------------
Add-Type -AssemblyName System.Web
$titleEsc = [System.Web.HttpUtility]::HtmlEncode($title)
$descEsc  = [System.Web.HttpUtility]::HtmlEncode($desc)
$tagsMeta = ($tags -join ", ")

# Basic markdown->HTML (lightweight): keep paragraphs + headings readable.
# If you later want true markdown rendering, we can swap in a renderer.
function MarkdownToHtml([string]$md) {
  $lines = $md -split "\r?\n"
  $out = New-Object System.Collections.Generic.List[string]

  foreach ($line in $lines) {
    $l = $line.TrimEnd()

    if ($l -match '^\s*#\s+(.+)$') { $out.Add("<h1>$([System.Web.HttpUtility]::HtmlEncode($Matches[1]))</h1>"); continue }
    if ($l -match '^\s*##\s+(.+)$') { $out.Add("<h2>$([System.Web.HttpUtility]::HtmlEncode($Matches[1]))</h2>"); continue }
    if ($l -match '^\s*###\s+(.+)$') { $out.Add("<h3>$([System.Web.HttpUtility]::HtmlEncode($Matches[1]))</h3>"); continue }

    if ($l -match '^\s*-\s+(.+)$') {
      # start a UL if previous isn't <ul>
      if ($out.Count -eq 0 -or -not ($out[$out.Count-1] -match '^<li>')) {
        $out.Add("<ul>")
      }
      $out.Add("<li>$([System.Web.HttpUtility]::HtmlEncode($Matches[1]))</li>")
      continue
    }

    if ($l -eq "") {
      # close UL if needed
      if ($out.Count -gt 0 -and $out[$out.Count-1] -match '^</li>$') { }
      if ($out.Count -gt 0 -and $out.Contains("<ul>")) {
        # if last added was list item, ensure ul closes once paragraph resumes
        if ($out[$out.Count-1] -match '^<li>') {
          $out.Add("</ul>")
        }
      }
      continue
    }

    # normal paragraph
    # close UL if previous line was list item and ul not closed
    if ($out.Count -gt 0 -and $out[$out.Count-1] -match '^<li>') { $out.Add("</ul>") }
    $out.Add("<p>$([System.Web.HttpUtility]::HtmlEncode($l))</p>")
  }

  # close any open UL at end
  if ($out.Count -gt 0 -and $out[$out.Count-1] -match '^<li>') { $out.Add("</ul>") }

  return ($out -join "`n")
}

if ($canonical -and $canonical.Trim() -ne "") {
  $canon = $canonical.Trim()
  $redirect = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>$titleEsc — $SiteTitle</title>
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta http-equiv="refresh" content="0; url=$canon" />
  <link rel="canonical" href="$canon" />
</head>
<body>
  <p>Redirecting… <a href="$canon">Continue</a></p>
</body>
</html>
"@
  Set-Content -Path $indexHtml -Value $redirect -Encoding UTF8
}
else {
  $contentHtml = MarkdownToHtml $body

  $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>$titleEsc — $SiteTitle</title>
  <meta name="viewport" content="width=device-width,initial-scale=1" />

  <meta name="description" content="$descEsc" />
  <meta name="tags" content="$tagsMeta" />

  <link rel="stylesheet" href="$CssHref" />
</head>

<body>
  <a class="skip" href="#content">Skip to content</a>

  <main id="content" class="container prose">
    <p class="post-meta">
      By $SiteOwner · $readMins ·
      <time datetime="$iso">$human</time>
    </p>

    <h1>$titleEsc</h1>

    $contentHtml
  </main>

  <footer class="site-footer">
    <div class="container footer-grid">
      <div class="footer-left">
        <a class="brand small" href="/">
          <img class="brand-logo small" src="$LogoHref" alt="JustineLonglaT-Lane logo" />
          <span class="brand-title small">$SiteTitle</span>
        </a>

        <p class="copyright">
          © <span id="y"></span> <strong>JustineLonglaT-Lane Consulting</strong>.
        </p>
      </div>

      <nav class="footer-nav">
        <a href="/">Home</a>
        <a href="/blog">All Blog Posts</a>
        <a href="/projects">Projects</a>
      </nav>
    </div>

    <script>
      document.getElementById("y").textContent = new Date().getFullYear();
    </script>
  </footer>
</body>
</html>
"@

  Set-Content -Path $indexHtml -Value $html -Encoding UTF8
}

# ---------------------------
# Archive draft
# ---------------------------
$archive = Join-Path (Split-Path -Parent $DraftPath) "_archive"
New-Item -ItemType Directory -Force -Path $archive | Out-Null

Move-Item -Force -Path $DraftPath -Destination (Join-Path $archive (Split-Path $DraftPath -Leaf))

# ---------------------------
# Summary
# ---------------------------
Write-Host ""
Write-Host "✅ Post published to PUBLIC successfully:" -ForegroundColor Yellow
Write-Host ""

[PSCustomObject]@{
  Title = $title
  Slug  = $slug
  Date  = $iso
  Tags  = ($tags -join ", ")
  Path  = $dest
} | Format-Table -AutoSize

param([string] $SiteUrl = "https://justine6.github.io/jutellane-blogs")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web

# -----------------------------
# Resolve repo root (parent of /tools)
# -----------------------------
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
  $scriptDir = Split-Path -Parent $PSCommandPath -ErrorAction SilentlyContinue
  if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
}
$repoRoot = Split-Path -Parent $scriptDir  # ...\jutellane-blogs

# Base path for GitHub Pages under a repo (important for correct URLs)
$BasePath = "/jutellane-blogs"

# -----------------------------
# Paths
# -----------------------------
$postsDir         = Join-Path $repoRoot 'posts'
$tagsDir          = Join-Path $repoRoot 'tags'
$postPageTemplate = Join-Path $postsDir 'postpage.html'   # posts\postpage.html
$coverPartial     = Join-Path $postsDir 'template.html'   # posts\template.html

Write-Host "Repo root:          $repoRoot"
Write-Host "Post page template: $postPageTemplate"
Write-Host "Cover partial:      $coverPartial"

if (-not (Test-Path $postPageTemplate)) { throw "Missing post page template: $postPageTemplate" }
if (-not (Test-Path $coverPartial))     { throw "Missing cover partial: $coverPartial" }
if (-not (Test-Path $tagsDir))          { New-Item -ItemType Directory -Path $tagsDir | Out-Null }

# -----------------------------
# Helpers (must be defined BEFORE use)
# -----------------------------
function Parse-FM([string]$yaml) {
  $obj = [ordered]@{}
  foreach ($line in ($yaml -split "`r?`n")) {
    if ($line -match "^\s*#|^\s*$") { continue }
    if ($line -match "^\s*([A-Za-z0-9_]+)\s*:\s*(.+?)\s*$") {
      $k = $Matches[1]; $v = $Matches[2].Trim()
      $v = $v -replace '^\s*["'']|["'']\s*$',''
      if ($k -eq "tags" -and $v -match "^\[(.*)\]$") {
        $inner = $Matches[1]
        $obj[$k] = @()
        foreach ($t in ($inner -split ",")) { $obj[$k] += (($t -replace "['""]","").Trim()) }
      } else { $obj[$k] = $v }
    }
  }
  [pscustomobject]$obj
}

function Join-WebPath([string]$left, [string]$right) {
  # Safe join for web paths, preserving single slash
  $l = ($left  -replace '/+$','')
  $r = ($right -replace '^/+','')
  if ($l.Length -eq 0) { return "/$r" }
  return "$l/$r"
}

function Render-CoverHtml {
  [CmdletBinding()]
  param(
    [hashtable]$fm,
    [Parameter(Mandatory)]
    [string]$Template
  )
  if (-not $fm)        { return "" }
  if (-not $fm.cover)  { return "" }
  if (-not (Test-Path $Template)) { return "" }

  $tpl = Get-Content -Raw -Path $Template
  $title    = [string]$fm.title
  $titleEsc = [System.Web.HttpUtility]::HtmlEncode($title)
  $coverUrl = [string]$fm.cover

  $html = $tpl
  $html = $html.Replace('{{ post.cover }}', $coverUrl)
  $html = $html.Replace('{{post.cover}}',  $coverUrl)
  $html = $html.Replace('{{ post.title | escape }}', $titleEsc)
  $html = $html.Replace('{{ post.title }}',          $title)
  $html = $html.Replace('{{post.title}}',           $title)
  return $html
}

function Build-MetaLine {
  [CmdletBinding()]
  param([hashtable]$fm)

  $dateOut = ""
  if ($fm.date) {
    try { $dateOut = ([datetime]::Parse($fm.date)).ToString('yyyy-MM-dd') } catch {}
  }

  $tagsOut = ""
  if ($fm.tags) {
    $tagsOut = ($fm.tags | ForEach-Object { $_.ToString() } | Where-Object { $_ -ne "" }) -join ', '
  }

  if ($tagsOut) { return "$dateOut · $tagsOut" }
  return $dateOut
}

function Get-DateAndSlugFromFolder([IO.DirectoryInfo]$dir) {
  # expects ...\posts\YYYY\MM\<slug>\
  $sep   = [IO.Path]::DirectorySeparatorChar
  $parts = $dir.FullName -split [regex]::Escape($sep)
  $slug  = $parts[-1]
  $mm    = $parts[-2]
  $yyyy  = $parts[-3]
  @{
    Date = [datetime]::ParseExact("$yyyy-$mm-01",'yyyy-MM-dd',$null)
    Slug = ($slug.ToLower() -replace '[^a-z0-9\-]','-' -replace '-+','-')
  }
}

function Get-DateAndSlugFromFlatName([string]$name) {
  # YYYY-MM-DD-<slug>.md
  $m = [regex]::Match($name,'^(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})-(?<slug>.+)\.md$')
  if (-not $m.Success) { return $null }
  @{
    Date = [datetime]::ParseExact("$($m.Groups['y'])-$($m.Groups['m'])-$($m.Groups['d'])",'yyyy-MM-dd',$null)
    Slug = ($m.Groups['slug'].Value.ToLower() -replace '[^a-z0-9\-]','-' -replace '-+','-')
  }
}

# -----------------------------
# Collect posts (both layouts) & render pages
# -----------------------------
$items   = @()

$mdFiles = @()
# folder layout: .../YYYY/MM/<slug>/post.md
$mdFiles += Get-ChildItem -Path $postsDir -Recurse -File -Filter post.md -ErrorAction SilentlyContinue
# flat layout: .../YYYY-MM-DD-<slug>.md
$mdFiles += Get-ChildItem -Path $postsDir -Recurse -File -Include ????-??-??-*.md -ErrorAction SilentlyContinue

foreach ($f in $mdFiles) {
  $raw = Get-Content -Path $f.FullName -Raw
  $raw = $raw -replace '^\uFEFF',''  # strip BOM

  # capture YAML + body
  $yaml = $null; $body = $null
  if ($raw -match '(?s)^\s*---\s*(?<yaml>.*?)\s*---\s*(?<body>.*)$') {
    $yaml = $Matches['yaml']
    $body = $Matches['body']
  } else { continue }

  $m = Parse-FM $yaml

  # --- derive Date and Slug (front-matter > folder > filename) ---
  $fromFolder = $null; $fromFlat = $null
  if ($f.Name -ieq 'post.md') { $fromFolder = Get-DateAndSlugFromFolder $f.Directory }
  else                       { $fromFlat   = Get-DateAndSlugFromFlatName $f.Name }

  $dt = $null
  if ($m.date) { try { $dt = [datetime]::Parse($m.date) } catch {} }
  if (-not $dt) { $dt = if ($fromFolder) { $fromFolder.Date } elseif ($fromFlat) { $fromFlat.Date } else { $null } }
  if (-not $dt) { continue }  # still missing date → skip

  $slug = $null
  if     ($m.slug)      { $slug = ($m.slug.ToLower() -replace '[^a-z0-9\-]','-' -replace '-+','-') }
  elseif ($fromFolder)  { $slug = $fromFolder.Slug }
  elseif ($fromFlat)    { $slug = $fromFlat.Slug }
  else {
    $slug = (($m.title) -replace "[^a-zA-Z0-9\s-]","").ToLower() -replace "\s+","-" -replace "-+","-"
  }

  # URL visible on the site (prefer canonical if absolute)
  $postPath = "/posts/{0}/{1}/{2}/" -f $dt.ToString("yyyy"), $dt.ToString("MM"), $slug
  $local    = Join-WebPath $BasePath $postPath
  $url      = if ($m.canonical -and ($m.canonical -match '^https?://')) { $m.canonical } else { $local }

  # --- render page from template ---
  $html = Get-Content -LiteralPath $postPageTemplate -Raw

  $html = $html -replace '<title>\s*- Jutellane Blogs</title>',
          ("<title>" + [System.Web.HttpUtility]::HtmlEncode($m.title) + " - Jutellane Blogs</title>")
  $html = $html -replace '<h1>\s*</h1>',
          ("<h1>" + [System.Web.HttpUtility]::HtmlEncode($m.title) + "</h1>")

  $coverHtml = ""
  if ($m.cover) { $coverHtml = Render-CoverHtml -fm @{ title=$m.title; cover=$m.cover } -Template $coverPartial }
  $html = $html.Replace('<!-- COVER -->', $coverHtml)

  $metaLine = Build-MetaLine -fm @{ date=$dt.ToString('yyyy-MM-dd'); tags=$m.tags }
  $html = $html -replace '<div class="meta">.*?</div>',
          ('<div class="meta">' + [System.Web.HttpUtility]::HtmlEncode($metaLine) + '</div>')

  $bodyEscaped = $body -replace '</', '<\/'
  $html = $html -replace '<pre style="white-space:pre-wrap"></pre>',
          "<pre style=""white-space:pre-wrap"">$bodyEscaped</pre>"

  # write /posts/YYYY/MM/slug/index.html
  $outDir = Join-Path $postsDir (Join-Path ($dt.ToString("yyyy")) (Join-Path ($dt.ToString("MM")) $slug))
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
  Set-Content -LiteralPath (Join-Path $outDir "index.html") -Value $html -Encoding UTF8

  # collect for JSON/feed/tags
  $items += [pscustomobject]@{
    title   = $m.title
    date    = $dt.ToString('yyyy-MM-dd')
    tags    = @($m.tags)
    summary = $m.summary
    url     = $url
    cover   = $m.cover
  }
}

# newest first
$items = $items | Sort-Object { [datetime]::Parse($_.date) } -Descending

# -----------------------------
# posts.json
# -----------------------------
$items | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $repoRoot "posts.json") -Encoding UTF8

# -----------------------------
# feed.xml
# -----------------------------
$rss = @()
$rss += '<?xml version="1.0" encoding="UTF-8" ?>'
$rss += '<rss version="2.0"><channel>'
$rss += "  <title>Jutellane Blogs</title>"
$rss += "  <link>$SiteUrl/</link>"
$rss += "  <description>Thoughts on AWS, security, startups, and cloud craftsmanship.</description>"
$rss += "  <lastBuildDate>$((Get-Date).ToString("r"))</lastBuildDate>"
foreach ($i in $items) {
  $link = if ($i.url -match '^https?://') { $i.url } else { "$SiteUrl$($i.url)" }
  $rss += "  <item>"
  $rss += "    <title>$([System.Web.HttpUtility]::HtmlEncode($i.title))</title>"
  $rss += "    <link>$link</link>"
  $rss += "    <guid isPermaLink=""true"">$link</guid>"
  $rss += "    <pubDate>$([datetime]::Parse($i.date).ToString("r"))</pubDate>"
  $rss += "    <description>$([System.Web.HttpUtility]::HtmlEncode($i.summary))</description>"
  $rss += "  </item>"
}
$rss += "</channel></rss>"
Set-Content -Path (Join-Path $repoRoot "feed.xml") -Value ($rss -join "`n") -Encoding UTF8

# -----------------------------
# tags index + pages
# -----------------------------
$tagMap = @{}
foreach ($i in $items) { foreach ($t in ($i.tags)) { if (-not $tagMap.ContainsKey($t)) { $tagMap[$t] = @() }; $tagMap[$t] += ,$i } }

$tagsIndex = @"
<!doctype html><meta charset="utf-8"><title>Tags — Jutellane Blogs</title>
<main class="wrap" style="max-width:860px;margin:24px auto;font-family:ui-sans-serif,system-ui">
<h1>All tags</h1><ul>
$(
  ($tagMap.Keys | Sort-Object) | ForEach-Object {
    "<li><a href=""./$([uri]::EscapeDataString($_))/"" >$_</a> ($($tagMap[$_].Count))</li>"
  } | Out-String
)
</ul><p><a href="../">← Back</a></p></main>
"@
Set-Content -Path (Join-Path $tagsDir "index.html") -Value $tagsIndex -Encoding UTF8

foreach ($t in $tagMap.Keys) {
  $folder = Join-Path $tagsDir ([uri]::EscapeDataString($t))
  if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
  $list = ""
  foreach ($p in ($tagMap[$t])) {
    $dateStr = ([datetime]::Parse($p.date)).ToString("yyyy-MM-dd")
    $list += "<li><a href=""$($p.url)"">$($p.title)</a> <span style=""color:#6b7280"">$dateStr</span></li>`n"
  }
  $html = @"
<!doctype html><meta charset="utf-8"><title>#$t — Jutellane Blogs</title>
<main class="wrap" style="max-width:860px;margin:24px auto;font-family:ui-sans-serif,system-ui">
<h1>#${t}</h1><ul>$list</ul><p><a href="../">← All tags</a></p></main>
"@
  Set-Content -Path (Join-Path $folder "index.html") -Value $html -Encoding UTF8
}

# -----------------------------
# sitemap.xml
# -----------------------------
$urls = New-Object System.Collections.Generic.List[string]
$urls.Add("$SiteUrl/"); $urls.Add("$SiteUrl/tags/")
foreach ($t in $tagMap.Keys) { $urls.Add("$SiteUrl/tags/$([uri]::EscapeDataString($t))/") }
$siteMap = @()
$siteMap += '<?xml version="1.0" encoding="UTF-8"?>'
$siteMap += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
$siteMap += ($urls | Sort-Object -Unique | ForEach-Object { "  <url><loc>$_</loc><changefreq>weekly</changefreq></url>" })
$siteMap += '</urlset>'
Set-Content -Path (Join-Path $repoRoot "sitemap.xml") -Value ($siteMap -join "`n") -Encoding UTF8

Write-Host "Generated: posts.json ($($items.Count)), feed.xml, sitemap.xml, tags/"

param([string] $SiteUrl = "https://justine6.github.io/jutellane-blogs")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Resolve-Path ".").Path }

$postsDir = Join-Path $root "posts"
$tagsDir  = Join-Path $root "tags"
if (-not (Test-Path $tagsDir)) { New-Item -ItemType Directory -Path $tagsDir | Out-Null }

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

# Collect published posts
$items   = @()
$mdFiles = Get-ChildItem -Path $postsDir -Recurse -Filter post.md -ErrorAction SilentlyContinue

foreach ($f in $mdFiles) {
  $raw = Get-Content -Path $f.FullName -Raw

  # strip UTF-8 BOM if present
  $raw = $raw -replace '^\uFEFF',''

  # capture YAML front-matter safely (works with CRLF/LF and leading spaces)
  $yaml = $null
  if ($raw -match '(?s)^\s*---\s*(.*?)\s*---') {
    $yaml = $Matches[1]
  } else {
    # no front-matter: skip this file
    continue
  }

  $m = Parse-FM $yaml
  if (-not $m.title -or -not $m.date) { continue }

  # slug + URL resolution
  $slug = if ($m.slug) { $m.slug } else { ($m.title -replace "[^a-zA-Z0-9\s-]","").ToLower() -replace "\s+","-" -replace "-+","-" }
  $dt   = [datetime]::Parse($m.date)

  $local = "/posts/{0}/{1}/{2}/" -f $dt.ToString("yyyy"), $dt.ToString("MM"), $slug
  $url   = if ($m.canonical) { $m.canonical } else { $local }

  $items += [pscustomobject]@{
    title   = $m.title
    date    = $m.date
    tags    = @($m.tags)
    summary = $m.summary
    url     = $url
  }
}


$items = $items | Sort-Object { [datetime]::Parse($_.date) } -Descending

# posts.json
$items | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $root "posts.json") -Encoding UTF8

# feed.xml
$rss = @()
$rss += '<?xml version="1.0" encoding="UTF-8" ?>'
$rss += '<rss version="2.0"><channel>'
$rss += "  <title>Jutellane Blogs</title>"
$rss += "  <link>$SiteUrl/</link>"
$rss += "  <description>Thoughts on AWS, security, startups, and cloud craftsmanship.</description>"
$rss += "  <lastBuildDate>$((Get-Date).ToString(""r""))</lastBuildDate>"
foreach ($i in $items) {
  $link = if ($i.url -match '^https?://') { $i.url } else { "$SiteUrl$($i.url)" }
  $rss += "  <item>"
  $rss += "    <title>$([System.Web.HttpUtility]::HtmlEncode($i.title))</title>"
  $rss += "    <link>$link</link>"
  $rss += "    <guid isPermaLink=""true"">$link</guid>"
  $rss += "    <pubDate>$([datetime]::Parse($i.date).ToString(""r""))</pubDate>"
  $rss += "    <description>$([System.Web.HttpUtility]::HtmlEncode($i.summary))</description>"
  $rss += "  </item>"
}
$rss += "</channel></rss>"
Set-Content -Path (Join-Path $root "feed.xml") -Value ($rss -join "`n") -Encoding UTF8

# tags index + pages
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

# sitemap.xml
$urls = New-Object System.Collections.Generic.List[string]
$urls.Add("$SiteUrl/"); $urls.Add("$SiteUrl/tags/")
foreach ($t in $tagMap.Keys) { $urls.Add("$SiteUrl/tags/$([uri]::EscapeDataString($t))/") }
$siteMap = @()
$siteMap += '<?xml version="1.0" encoding="UTF-8"?>'
$siteMap += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
$siteMap += ($urls | Sort-Object -Unique | ForEach-Object { "  <url><loc>$_</loc><changefreq>weekly</changefreq></url>" })
$siteMap += '</urlset>'
Set-Content -Path (Join-Path $root "sitemap.xml") -Value ($siteMap -join "`n") -Encoding UTF8

Write-Host "Generated: posts.json ($($items.Count)), feed.xml, sitemap.xml, tags/"

[CmdletBinding()]
param(
  [string]$SiteBaseUrl = "",
  [string]$SiteTitle   = "Jutellane Blogs",
  [string]$SiteDesc    = "Latest posts from Jutellane Blogs"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$postsDir = Join-Path $root "posts"
if (-not (Test-Path $postsDir)) {
  Write-Host "No /posts directory yet; nothing to index." -ForegroundColor Yellow
  exit 0
}

function Get-PostEntries {
  $entries = @()
  $mdFiles = Get-ChildItem $postsDir -Filter "*.md" -File
  foreach ($md in $mdFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($md.Name)
    if ($name -notmatch '^\d{4}-\d{2}-\d{2}-') { continue }

    $htmlCandidate = Join-Path $postsDir ($name + ".html")
    $relUrl = if (Test-Path $htmlCandidate) { "posts/$name.html" } else { "posts/$name.md" }

    $raw = Get-Content $md.FullName -Raw
    if ($raw -notmatch "(?s)^---\s*(.*?)\s*---") { continue }
    $fm = $Matches[1]

    function fm($key){
      if ($fm -match "(?m)^\s*$key\s*:\s*(.+?)\s*$"){ return ($Matches[1].Trim('"')) }
      return ""
    }

    $title   = fm "title"
    $date    = fm "date"
    $summary = fm "summary"
    $slug    = fm "slug"
    $tagsRaw = fm "tags"

    $tags = @()
    try { if ($tagsRaw) { $tags = ($tagsRaw | ConvertFrom-Json) } } catch {}

    try {
      $dt = [datetime]::Parse($date, [Globalization.CultureInfo]::InvariantCulture)
    } catch {
      $dt = [datetime]::ParseExact($name.Substring(0,10), "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
    }

    $entries += [pscustomobject]@{
      title   = $title
      date    = $dt.ToString("yyyy-MM-dd")
      summary = $summary
      slug    = $slug
      tags    = $tags
      url     = $relUrl
    }
  }
  $entries | Sort-Object { $_.date } -Descending
}

$posts = Get-PostEntries

# ----------------- posts.json -----------------
$postsJson = $posts | ConvertTo-Json -Depth 5
Set-Content -Path (Join-Path $root "posts.json") -Value $postsJson -Encoding UTF8
Write-Host "✅ posts.json written ($(($posts | Measure-Object).Count) posts)"

# ----------------- feed.xml -------------------
$nowRfc = [DateTimeOffset]::UtcNow.ToString("r")
$rssItems = foreach ($p in $posts) {
  $absUrl = if ($SiteBaseUrl) { ($SiteBaseUrl.TrimEnd('/') + '/' + $p.url) } else { $p.url }
  @"
    <item>
      <title>$([System.Security.SecurityElement]::Escape($p.title))</title>
      <link>$absUrl</link>
      <guid isPermaLink="true">$absUrl</guid>
      <pubDate>$([datetime]::ParseExact($p.date,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture).ToUniversalTime().ToString("r"))</pubDate>
      <description>$([System.Security.SecurityElement]::Escape($p.summary))</description>
    </item>
"@
}

$rss = @"
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>$([System.Security.SecurityElement]::Escape($SiteTitle))</title>
    <link>$SiteBaseUrl</link>
    <description>$([System.Security.SecurityElement]::Escape($SiteDesc))</description>
    <lastBuildDate>$nowRfc</lastBuildDate>
$(($rssItems -join "`n"))
  </channel>
</rss>
"@
Set-Content -Path (Join-Path $root "feed.xml") -Value $rss -Encoding UTF8
Write-Host "✅ feed.xml written"

# ----------------- sitemap.xml ----------------
$urls = @()
if ($SiteBaseUrl) { $urls += ($SiteBaseUrl.TrimEnd('/') + '/') } else { $urls += 'index.html' }
foreach ($p in $posts) {
  if ($SiteBaseUrl) { $urls += ($SiteBaseUrl.TrimEnd('/') + '/' + $p.url) } else { $urls += $p.url }
}
$smUrls = foreach ($u in $urls) {
  @"
  <url><loc>$u</loc></url>
"@
}
$sm = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$(($smUrls -join "`n"))
</urlset>
"@
Set-Content -Path (Join-Path $root "sitemap.xml") -Value $sm -Encoding UTF8
Write-Host "✅ sitemap.xml written"

# ----------------- TAG PAGES ------------------
function Slugify([string]$t) {
  return ($t.ToLower() -replace "[^a-z0-9]+","-").Trim("-")
}

# Collect unique tags
$tagMap = @{}
foreach ($p in $posts) {
  foreach ($t in $p.tags) {
    if (-not $tagMap.ContainsKey($t)) { $tagMap[$t] = @() }
    $tagMap[$t] += $p
  }
}

$tagsDir = Join-Path $root "tags"
if (-not (Test-Path $tagsDir)) { New-Item -ItemType Directory -Path $tagsDir | Out-Null }

# Common head/style for tag pages
$head = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Tags • $SiteTitle</title>
  <style>
    :root{--bg:#ffffff;--fg:#0f172a;--muted:#475569;--card:#f8fafc;--chip:#e2e8f0;--link:#2563eb;--br:14px;--max:860px}
    @media (prefers-color-scheme: dark){
      :root{--bg:#0b1020;--fg:#e5e7eb;--muted:#93a3b8;--card:#0f162c;--chip:#1d2644;--link:#7aa3ff}
    }
    *{box-sizing:border-box}
    body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto}
    .wrap{max-width:var(--max);margin:0 auto;padding:28px 20px}
    a{color:var(--link)}
    .chip{display:inline-block;margin:6px 8px 6px 0;padding:8px 12px;border-radius:999px;background:var(--chip);text-decoration:none}
    ul{list-style:none;padding:0;margin:16px 0;display:grid;gap:12px}
    li{padding:14px 16px;border-radius:var(--br);background:var(--card);border:1px solid var(--chip)}
    .title{text-decoration:none;color:var(--fg);font-weight:600}
    .muted{color:var(--muted)}
  </style>
</head>
<body>
  <main class="wrap">
    <p><a href="../index.html">← Back</a></p>
"@

$foot = @"
  </main>
  <script>
    const fmt = d => new Date(d+'T00:00:00').toLocaleDateString(undefined,{year:'numeric', month:'short', day:'2-digit'});
  </script>
</body>
</html>
"@

# tags index page (lists all tags)
$tagIndex = $head + @"
    <h1>Tags</h1>
    <div id="chips"></div>
    <script>
      const tags = " + (ConvertTo-Json ($tagMap.Keys | Sort-Object)) + @";
      const el = document.getElementById('chips');
      tags.forEach(t=>{
        const slug = t.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
        const a = document.createElement('a');
        a.href = slug + '.html';
        a.className = 'chip';
        a.textContent = t;
        el.appendChild(a);
      });
    </script>
"@ + $foot
Set-Content -Path (Join-Path $tagsDir "index.html") -Value $tagIndex -Encoding UTF8

# one page per tag (filters posts.json client-side)
foreach ($t in $tagMap.Keys) {
  $slug = Slugify $t
  $html = $head + @"
    <h1># $t</h1>
    <ul id="list"><li class="muted">Loading…</li></ul>
    <script>
      const TAG = " + (ConvertTo-Json $t) + @";
      fetch('../posts.json',{cache:'no-store'})
        .then(r => r.json())
        .then(all => all.filter(p => (p.tags||[]).includes(TAG)))
        .then(posts => {
          const ul = document.getElementById('list');
          ul.innerHTML = '';
          posts.forEach(p=>{
            const li = document.createElement('li');
            const a = document.createElement('a'); a.href = '../' + p.url; a.textContent = p.title; a.className='title';
            const meta = document.createElement('div'); meta.className='muted'; meta.textContent = new Date(p.date+'T00:00:00').toLocaleDateString(undefined,{year:'numeric',month:'short',day:'2-digit'});
            li.append(a, meta); ul.append(li);
          });
          if (ul.children.length===0){ ul.innerHTML = '<li class="muted">No posts yet for this tag.</li>'; }
        })
        .catch(()=>{ document.getElementById('list').innerHTML = '<li class="muted">Could not load posts.</li>'; });
    </script>
"@ + $foot
  Set-Content -Path (Join-Path $tagsDir ($slug + ".html")) -Value $html -Encoding UTF8
}

Write-Host "🏷  tag pages written: $($tagMap.Keys.Count) (+ index)" -ForegroundColor Green

[CmdletBinding()]
param()

# ----- Paths -----
$public = (Resolve-Path ".\public").Path
$layout = Join-Path $public "..\public_layout"
New-Item -ItemType Directory -Force -Path $layout, (Join-Path $public "assets") | Out-Null

$headerPath = Join-Path $layout "header.html"
$footerPath = Join-Path $layout "footer.html"
$cssPath    = Join-Path $public "assets\blog.css"
$logoPath   = Join-Path $public "assets\logo-32.png"

# ----- Seed layout + assets if missing -----
if (!(Test-Path $headerPath)) {
$header = @"
<header class="site-header">
  <div class="wrap">
    <a class="brand" href="https://jutellane.com">
      <img src="/assets/logo-32.png" alt="Jutellane" width="32" height="32" />
      <span>Jutellane Solutions</span>
    </a>
    <nav class="nav">
      <a href="/">Home</a>
      <a href="/posts/">Blog</a>
      <a href="https://jutellane.com/services">Services</a>
      <a href="https://jutellane.com/contact">Contact</a>
    </nav>
  </div>
</header>
"@
Set-Content $headerPath -Value $header -Encoding UTF8
}

if (!(Test-Path $footerPath)) {
$footer = @"
<footer class="site-footer">
  <div class="wrap">
    <p>&copy; $(Get-Date -Format 'yyyy') Jutellane Solutions · Cloud Confidence. Delivered.</p>
    <p class="links">
      <a href="/privacy">Privacy</a>
      <span>·</span>
      <a href="/terms">Terms</a>
      <span>·</span>
      <a href="/posts/">Blog</a>
    </p>
  </div>
</footer>
"@
Set-Content $footerPath -Value $footer -Encoding UTF8
}

if (!(Test-Path $cssPath)) {
$css = @"
:root{--bg:#ffffff;--fg:#0f172a;--muted:#64748b;--brand:#1e40af}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:#fff;color:var(--fg)}
.wrap{max-width:980px;margin:0 auto;padding:16px}
.site-header{position:sticky;top:0;z-index:10;background:#fff;border-bottom:1px solid #e5e7eb}
.site-header .wrap{display:flex;align-items:center;justify-content:space-between;gap:16px}
.brand{display:flex;align-items:center;gap:10px;text-decoration:none;color:var(--fg);font-weight:700}
.nav a{margin-left:16px;text-decoration:none;color:var(--fg)}
.nav a:hover{color:#0b5bd3}
h1,h2,h3{line-height:1.25}h1{font-size:clamp(1.5rem,3vw,2rem);margin:1rem 0}
a{color:#0b5bd3}a:hover,a:focus{text-decoration:underline}
.site-footer{margin-top:48px;border-top:1px solid #e5e7eb;background:#fff}
.site-footer .wrap{display:flex;flex-wrap:wrap;justify-content:space-between;gap:12px;padding:20px}
.site-footer .links a{color:var(--muted);text-decoration:none}
.site-footer .links a:hover{color:#0b5bd3;text-decoration:underline}
code,pre{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono",monospace}
img{max-width:100%;height:auto}
main{padding:16px}
.hero{background:radial-gradient(circle at top,#0b1020 10%,#0f172a 80%);color:#f8fafc;border-bottom:1px solid #1e293b}
.hero-wrap{max-width:980px;margin:0 auto;text-align:center;padding:3.5rem 1rem}
"@
Set-Content $cssPath -Value $css -Encoding UTF8
}

if (!(Test-Path $logoPath)) {
$px = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==')
[System.IO.File]::WriteAllBytes($logoPath, $px)
}

# ----- Content helpers -----
$HeaderHtml = Get-Content -Raw $headerPath
$FooterHtml = Get-Content -Raw $footerPath

function Strip-ExistingHeaderFooter([string]$html){
  # remove any pre-existing <header>..</header> and <footer>..</footer> to avoid duplicates
  $out = [regex]::Replace($html, '(?is)<header\b.*?</header>', '')
  $out = [regex]::Replace($out , '(?is)<footer\b.*?</footer>', '')
  return $out
}

# Hero block (only for the listing page)
$Hero = @"
<section class="hero">
  <div class="hero-wrap">
    <div style="display:inline-flex;align-items:center;justify-content:center;width:72px;height:72px;border-radius:9999px;background:rgba(255,255,255,.1);border:1px solid rgba(148,163,184,.25);margin-bottom:1rem">
      <img src="assets/img/logo.png" alt="Jutellane Blogs" width="48" height="48" style="object-fit:contain"/>
    </div>
    <h2 style="font-size:clamp(24px,3.5vw,36px);margin:.75rem 0 .5rem">Jutellane Blogs</h2>
    <p style="color:#cbd5e1;font-size:1.05rem">DevSecOps • Cloud • Sustainability</p>
  </div>
</section>
"@

function Wrap-File([string]$file) {
  $raw = Get-Content -Raw -Path $file
  if ($raw -match '<!-- wrapped:blog v1 -->') { return } # idempotent guard

  # Strip existing headers/footers from the original HTML
  $html = Strip-ExistingHeaderFooter $raw

  # Title extraction
  $title = if ($html -match '<title>(.*?)</title>') { $matches[1] } else { 'Jutellane Blog' }

  $head = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <link rel="icon" href="/assets/logo-32.png" />
  <link rel="stylesheet" href="/assets/blog.css" />
  <title>$title</title>
</head>
<body>
<!-- wrapped:blog v1 -->
"@

  $isIndex = ([IO.Path]::GetFileName($file)).ToLower() -eq 'index.html'
  $body = if ($isIndex) { $HeaderHtml + $Hero + "<main class='wrap'>" + $html + "</main>" + $FooterHtml }
          else          { $HeaderHtml         + "<main class='wrap'>" + $html + "</main>" + $FooterHtml }

  $wrapped = $head + $body + "`r`n</body>`r`n</html>"
  Set-Content -Path $file -Value $wrapped -Encoding UTF8
}

# ----- Targets: /public/index.html + /public/posts/*.html -----
$targets = @()
if (Test-Path (Join-Path $public "index.html")) { $targets += (Join-Path $public "index.html") }
if (Test-Path (Join-Path $public "posts")) {
  $targets += Get-ChildItem (Join-Path $public "posts") -Filter *.html -Recurse | Select-Object -Expand FullName
}

foreach ($t in $targets) { Wrap-File $t }
Write-Host "✓ Layout (de-dupe) applied to $($targets.Count) file(s)" -ForegroundColor Cyan

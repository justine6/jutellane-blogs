param(
  [string]$Index = "public/posts/index.html",
  [string]$Header = "public/_layout/header.html",
  [string]$Footer = "public/_layout/footer.html"
)

$ErrorActionPreference = 'Stop'
function Keep-OneBlock {
  param(
    [string]$html,
    [string]$begin,   # e.g. '<!-- JL:HERO-BEGIN -->'
    [string]$end      # e.g. '<!-- JL:HERO-END -->'
  )
  $opt = [Text.RegularExpressions.RegexOptions]::IgnoreCase
  $pattern = "(?s)$([regex]::Escape($begin)).*?$([regex]::Escape($end))"
  $m = [regex]::Matches($html, $pattern, $opt)
  if ($m.Count -le 1) { return $html }
  $keep = $m[0].Value
  # remove all
  $html = [regex]::Replace($html, $pattern, '', $opt)
  # re-insert the one we keep right after <header> if present, else after <body>
  $bodyMatch = [regex]::Match($html, '(?is)<header\b[^>]*>.*?</header>')
  if ($bodyMatch.Success) {
    $idx = $bodyMatch.Index + $bodyMatch.Length
    return $html.Insert($idx, "`r`n$keep")
  }
  return [regex]::Replace($html, '(?is)(<body[^>]*>)', "`$1`r`n$keep", 1, $opt)
}

# usage after you’ve built $html with the latest header/hero/footer:
$html = Keep-OneBlock $html '<!-- JL:HEADER-BEGIN -->' '<!-- JL:HEADER-END -->'
$html = Keep-OneBlock $html '<!-- JL:HERO-BEGIN -->'   '<!-- JL:HERO-END -->'
$html = Keep-OneBlock $html '<!-- JL:FOOTER-BEGIN -->' '<!-- JL:FOOTER-END -->'


function ReadRaw($p){ Get-Content $p -Raw -ErrorAction Stop }

# --- Load sources
$html   = ReadRaw $Index
$header = Test-Path $Header ? (ReadRaw $Header) : ''
$footer = Test-Path $Footer ? (ReadRaw $Footer) : ''

# --- 0) Normalize newlines (simplifies regex)
$html = $html -replace "`r`n|`r","`n"

# MARKER PATTERNS
$reHeaderBlock = '<!-- JL:HEADER-BEGIN -->[\s\S]*?<!-- JL:HEADER-END -->'
$reHeroBlock   = '<!-- JL:HERO-BEGIN -->[\s\S]*?<!-- JL:HERO-END -->'
$reFooterBlock = '<!-- JL:FOOTER-BEGIN -->[\s\S]*?<!-- JL:FOOTER-END -->'

# LEGACY FRAGMENTS (unmarked)
$reLegacyHeader = '<header[^>]*class="site-header"[\s\S]*?</header>'
$reLegacyHero   = '<section[^>]*class="hero"[\s\S]*?</section>'
$reLegacyFooter = '<footer[^>]*class="site-footer"[\s\S]*?</footer>'

# --- 1) Hard remove any *extra* marked copies (keep the first hit)
function RemoveExtraMatches([string]$text,[string]$pattern){
  $m = [regex]::Matches($text,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if($m.Count -gt 1){
    for($i=1;$i -lt $m.Count;$i++){ $text = $text.Replace($m[$i].Value,'') }
  }
  return $text
}
$html = RemoveExtraMatches $html $reHeaderBlock
$html = RemoveExtraMatches $html $reHeroBlock
$html = RemoveExtraMatches $html $reFooterBlock

# --- 2) Scrub legacy duplicates (any extras beyond our marked ones)
#    Keep the first *marked* hero; if none marked, we’ll inject our canonical one later.
#    Remove *all* legacy unmarked header/hero/footer to avoid the “trinity”.
$html = [regex]::Replace($html,$reLegacyHeader,'', 'IgnoreCase')
$html = [regex]::Replace($html,$reLegacyHero,  '', 'IgnoreCase')
$html = [regex]::Replace($html,$reLegacyFooter,'', 'IgnoreCase')

# --- 3) Ensure exactly one HEADER (marked)
if(-not [regex]::IsMatch($html,$reHeaderBlock,'IgnoreCase')){
  if(-not $header){ throw "Missing $Header; cannot inject header." }
  # Insert right after <body> if present, else at very top
  if([regex]::IsMatch($html,'(<body[^>]*>)','IgnoreCase')){
    $html = [regex]::Replace($html,'(<body[^>]*>)',('$1' + "`n" + $header),1,'IgnoreCase')
  } else {
    $html = $header + "`n" + $html
  }
}

# --- 4) Ensure exactly one HERO (marked)
if(-not [regex]::IsMatch($html,$reHeroBlock,'IgnoreCase')){
  # Insert after header block we just guaranteed
  $m = [regex]::Match($html,$reHeaderBlock,'IgnoreCase')
  if($m.Success){
    $insertAt = $m.Index + $m.Length
    $html = $html.Insert($insertAt,"`n" + @"
<!-- JL:HERO-BEGIN -->
<section class="hero" id="jl-hero" style="position:relative;background:linear-gradient(135deg,#0b1020 0%,#0f172a 35%,#0a4cc7 100%);color:#f8fafc;border-bottom:1px solid rgba(148,163,184,.25);">
  <div class="hero-wrap" style="position:relative;z-index:1;text-align:center;padding:3rem 1rem;min-height:320px">
    <div id="jl-badge-wrap" style="display:inline-flex;align-items:center;justify-content:center;width:92px;height:92px;border-radius:9999px;background:rgba(255,255,255,.10);border:1px solid rgba(148,163,184,.25);margin-bottom:1rem;">
      <img id="jl-badge" src="/assets/img/logo-32.png" width="56" height="56" alt="Jutellane" style="object-fit:contain"/>
    </div>
    <h1 style="margin:.9rem 0;font-size:clamp(28px,3.8vw,44px);">Jutellane Blogs</h1>
    <p style="color:#cbd5e1;font-size:1.08rem">DevSecOps • Cloud • Sustainability</p>
  </div>
</section>
<!-- JL:HERO-END -->
"@ + "`n")
  }
}

# After the guaranteed hero, make sure we don’t have a second badge
$reBadge = '<div id="jl-badge-wrap"[\s\S]*?</div>'
$mBadges = [regex]::Matches($html,$reBadge,'IgnoreCase')
if($mBadges.Count -gt 1){
  for($i=1;$i -lt $mBadges.Count;$i++){ $html = $html.Replace($mBadges[$i].Value,'') }
}

# --- 5) Ensure exactly one FOOTER (marked)
if(-not [regex]::IsMatch($html,$reFooterBlock,'IgnoreCase')){
  if(-not $footer){ throw "Missing $Footer; cannot inject footer." }
  if([regex]::IsMatch($html,'</body>','IgnoreCase')){
    $html = [regex]::Replace($html,'</body>',("`n" + $footer + "`n</body>"),1,'IgnoreCase')
  } else {
    $html += "`n" + $footer + "`n"
  }
}

# --- 6) One more pass: if somehow multiple marked blocks slipped in, keep first only
$html = RemoveExtraMatches $html $reHeaderBlock
$html = RemoveExtraMatches $html $reHeroBlock
$html = RemoveExtraMatches $html $reFooterBlock

# --- 7) Save
Set-Content $Index -Value $html -Encoding UTF8

Write-Host "Layout fixed: exactly one header, one hero (one badge), one footer."

# scripts\fix-layout.ps1  — PS5-safe, idempotent injector (no ? :)
$ErrorActionPreference = "Stop"

$HeaderPath = "public/_layout/header.html"
$FooterPath = "public/_layout/footer.html"
$IndexPath  = "public/posts/index.html"

function ReadRaw([string]$p){ if(Test-Path $p){ Get-Content $p -Raw } else { "" } }

$header = ReadRaw $HeaderPath
$footer = ReadRaw $FooterPath
$html   = Get-Content $IndexPath -Raw

# Ensure CSS + favicon (once)
if($html -notmatch '<link[^>]+href="/assets/blog.css"'){
  $html = $html -replace '(\</head\>)',"`n  <link rel=""stylesheet"" href=""/assets/blog.css"" />`n`$1"
}
if($html -notmatch '<link[^>]+rel="icon"[^>]+/assets/img/logo-32.png'){
  $html = $html -replace '(\</head\>)',"`n  <link rel=""icon"" href=""/assets/img/logo-32.png"" />`n`$1"
}

# Inject HEADER right after <body> (once)
if($header -and $html -notmatch 'id="jl-header"'){
  $bodyOpen = $html.IndexOf('<body',[StringComparison]::OrdinalIgnoreCase)
  if($bodyOpen -ge 0){
    $close = $html.IndexOf('>',$bodyOpen)
    if($close -ge 0){ $html = $html.Insert($close+1,"`r`n$header`r`n") }
  }
}

# Inject FOOTER just before </body> (once)
if($footer -and $html -notmatch 'id="jl-footer"'){
  $bodyClose = $html.LastIndexOf('</body>',[StringComparison]::OrdinalIgnoreCase)
  if($bodyClose -ge 0){ $html = $html.Insert($bodyClose,"`r`n$footer`r`n") }
}

Set-Content $IndexPath -Value $html -Encoding UTF8

# Sanity: each should print 1
(Get-Content $IndexPath -Raw) | Select-String -SimpleMatch 'id="jl-header"' | % Count
(Get-Content $IndexPath -Raw) | Select-String -SimpleMatch 'id="jl-footer"' | % Count

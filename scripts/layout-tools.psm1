# scripts/layout-tools.psm1 (clean final build)
$ErrorActionPreference = "Stop"

function Say ($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }

# --------------------------------------------------------------------
function Add-CssIfMissing {
  param([string]$Html, [string]$Href, [string]$Needle)
  if ($Html -match [regex]::Escape($Href)) { return $Html }
  if ($Html -notmatch '(?is)</head>')     { return $Html }
  return ($Html -replace '(?is)</head>', "  $Needle`r`n</head>")
}

function Ensure-MainContainer {
  param([string]$Html)
  $withClass = '(?is)<main([^>]*)\bclass\s*=\s*"([^"]*)"([^>]*)>'
  $hasClass  = '(?is)<main\b(?:(?!>).)*\bclass\s*='
  $openMain  = '(?is)<main((?:(?!>).)*)>'

  $changed = $false
  $out = [regex]::Replace($Html, $withClass, {
    param($m)
    if ($m.Groups[2].Value -notmatch '\bcontainer\b') {
      $script:changed = $true
      "<main{0}class=""{1} container""{2}>" -f $m.Groups[1].Value,$m.Groups[2].Value,$m.Groups[3].Value
    } else { $m.Value }
  }, 1)
  if ($changed) { return $out }

  if ($Html -notmatch $hasClass -and $Html -match '(?is)<main\b') {
    return [regex]::Replace($Html, $openMain, {
      param($m) "<main{0} class=""container"">" -f $m.Groups[1].Value
    }, 1)
  }
  return $Html
}

function Normalize-ListsToCards {
  param([string]$Html)
  $u = $Html
  $u = [regex]::Replace($u,
    '(?is)<ul([^>]*)\bclass\s*=\s*"([^"]*)\b(posts-grid|projects-grid)\b([^"]*)"(.*?)>',
    { param($m)
      $cls = ($m.Groups[2].Value + " " + $m.Groups[4].Value) `
        -replace '\bposts-grid\b','cards-grid' `
        -replace '\bprojects-grid\b','cards-grid'
      "<ul{0}class=""{1}""{2}>" -f $m.Groups[1].Value,$cls,($m.Groups[5].Value)
    })

  $u = [regex]::Replace($u,
    '(?is)<ul([^>]*)\bid\s*=\s*"guides"([^>]*)>',
    { param($m)
      if ($m.Value -match '\bclass\s*=') { $m.Value }
      else { "<ul{0}class=""cards-grid""{1}>" -f $m.Groups[1].Value,$m.Groups[2].Value }
    })

  $u = [regex]::Replace($u,
    '(?is)<ul([^>]*)\bclass\s*=\s*"([^"]*)\b(docs-grid|guides-grid|cards)\b([^"]*)"(.*?)>',
    { param($m)
      $pre  = $m.Groups[2].Value
      $post = $m.Groups[4].Value
      $tail = $m.Groups[5].Value
      if (($pre + " " + $post) -match '\bcards-grid\b') { $m.Value }
      else { "<ul{0}class=""{1} cards-grid {2}""{3}>" -f $m.Groups[1].Value,$pre,$post,$tail }
    })
  return $u
}

function Get-Targets {
  param([ValidateSet("docs","blog","projects","all")][string]$Scope, [string]$Root)
  $dirs = switch ($Scope) {
    'docs'     { @("$Root/docs") }
    'blog'     { @("$Root/blog") }
    'projects' { @("$Root/projects") }
    'all'      { @("$Root/docs","$Root/blog","$Root/projects") }
  }
  $list = @()
  foreach ($d in $dirs) {
    if (Test-Path $d) {
      $list += Get-ChildItem -Path $d -Recurse -Include *.html -File |
        Where-Object { $_.FullName -notmatch '\\node_modules\\|\\dist\\|\\.vercel\\|\\out\\|\\_site\\' }
    }
  }
  return $list
}

# --------------------------------------------------------------------
function Invoke-LayoutApply {
  [CmdletBinding()]
  param(
    [ValidateSet("docs","blog","projects","all")]
    [string]$Scope = "all",
    [string]$Root  = ".",
    [switch]$WhatIf
  )

  $CssHref   = "/assets/css/main.css"
  $CssNeedle = "<link rel='stylesheet' href='/assets/css/main.css' />"
  $files     = Get-Targets -Scope $Scope -Root $Root
  if (-not $files) { Warn "No HTML files for scope '$Scope'."; return }

  $stamp   = Get-Date -Format "yyyyMMdd-HHmmss"
  $patched = 0
  Say "Scope=$Scope | Files=$($files.Count) | Backups=*.bak-$stamp | WhatIf=$($WhatIf.IsPresent)"

  foreach ($f in $files) {
    $html = Get-Content -Raw -Path $f.FullName
    $orig = $html
    $html = Add-CssIfMissing     $html $CssHref $CssNeedle
    $html = Ensure-MainContainer $html
    $html = Normalize-ListsToCards $html

    if ($html -ne $orig) {
      if ($WhatIf) { Warn "[WhatIf] Would patch: $($f.FullName)"; continue }
      Copy-Item $f.FullName "$($f.FullName).bak-$stamp"
      Set-Content -Path $f.FullName -Value $html -Encoding UTF8
      $patched++
      Good "Patched: $($f.FullName)"
    } else {
      Warn "No change: $($f.FullName)"
    }
  }
  Say "Processed $($files.Count) file(s). Patched: $patched (WhatIf=$($WhatIf.IsPresent))"
}

function Invoke-LayoutUnifyCards {
  [CmdletBinding()]
  param([string]$Root = ".", [switch]$WhatIf)
  $targets = @(
    Join-Path $Root "blog\index.html",
    Join-Path $Root "projects\index.html"
  )
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $patched = 0
  Say "Targets: $($targets.Count) | Backups=*.bak-$stamp | WhatIf=$($WhatIf.IsPresent)"

  foreach ($p in $targets) {
    if (!(Test-Path $p)) { Warn "Skip: $p (not found)"; continue }
    $html = Get-Content -Raw -Path $p
    $orig = $html
    $html = [regex]::Replace($html,
      '(?is)<ul([^>]*)\bid\s*=\s*"list"([^>]*)>',
      { param($m)
        if ($m.Value -match '\bclass\s*=') {
          if ($m.Value -match '\bcards-grid\b') { $m.Value }
          else { $m.Value -replace '(?is)\bclass\s*=\s*"([^"]*)"', 'class="$1 cards-grid"' }
        } else { "<ul{0} id=""list"" class=""cards-grid""{1}>" -f $m.Groups[1].Value,$m.Groups[2].Value }
      }, 1)

    if ($html -ne $orig) {
      if ($WhatIf) { Warn "[WhatIf] Would patch: $p"; continue }
      Copy-Item $p "$p.bak-$stamp"
      Set-Content -Path $p -Value $html -Encoding UTF8
      $patched++
      Good "Patched: $p"
    } else { Warn "No change: $p" }
  }
  Say "Processed $($targets.Count) file(s). Patched: $patched (WhatIf=$($WhatIf.IsPresent))"
}

function Invoke-LayoutAudit {
  [CmdletBinding()]
  param([string]$Root = ".")
  Say "Auditing layout consistency..."

  $htmlFiles = Get-ChildItem -Path $Root -Recurse -Include *.html -File |
               ForEach-Object FullName

  $containers = if ($htmlFiles) {
    Select-String -Path $htmlFiles -Pattern '(?is)<main[^>]*\bclass\s*=\s*"[^"]*\bcontainer\b'
  }
  $cards = if ($htmlFiles) {
    Select-String -Path $htmlFiles -Pattern '(?is)<ul[^>]*\bclass\s*=\s*"[^"]*\bcards-grid\b'
  }

  Write-Host ("  Containers: {0}" -f (($containers | Measure-Object).Count))
  Write-Host ("  Cards-grid: {0}" -f (($cards      | Measure-Object).Count))
  Good "Audit complete."
}

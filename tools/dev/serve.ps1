param(
  [int]$Port = 4173,
  [switch]$Lan
)

$ErrorActionPreference = "Stop"

Write-Host "▶ Dev serve (preview) starting..." -ForegroundColor Cyan
Write-Host "   Port: $Port" -ForegroundColor DarkGray
Write-Host ("   Bind: " + ($(if($Lan){"0.0.0.0"}else{"localhost"}))) -ForegroundColor DarkGray

function Run-Cmd([string]$File, [string[]]$Args) {
  Write-Host ("   > " + $File + " " + ($Args -join " ")) -ForegroundColor DarkGray
  & $File @Args
}

$hostArg = @()
if ($Lan) { $hostArg = @("--host") }

$pkgPath = Join-Path (Get-Location) "package.json"
if (Test-Path $pkgPath) {
  $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
  $scripts = $pkg.scripts

  if ($scripts -and $scripts.PSObject.Properties.Name -contains "preview") {
    Run-Cmd "npm" (@("run","preview","--","--port",$Port) + $hostArg)
    exit 0
  }

  try {
    Run-Cmd "npx" (@("vite","preview","--port",$Port) + $hostArg)
    exit 0
  } catch {
    Write-Host "⚠️ vite preview failed or vite not available. Falling back to static server..." -ForegroundColor Yellow
  }
}

try {
  Run-Cmd "npx" @("serve","public","-l",$Port)
} catch {
  Write-Host "❌ Could not start a local server. Install one of: vite (recommended) or serve." -ForegroundColor Red
  Write-Host "   Try: npm i -D vite" -ForegroundColor DarkGray
  Write-Host "   Or : npm i -D serve" -ForegroundColor DarkGray
  throw
}

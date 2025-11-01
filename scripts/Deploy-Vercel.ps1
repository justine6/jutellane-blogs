param(
  [ValidateSet("preview","production")]
  [string]$Environment = "preview",

  [switch]$Yes
)

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }
function Bad($m){ Write-Host "✗ $m" -ForegroundColor Red }

# Resolve script dir and repo root
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir "..")

# Sanity: public/index.html must exist
$public = Join-Path $RepoRoot "public"
if (!(Test-Path (Join-Path $public "index.html"))) {
  Bad "public/index.html not found. Build/export to public/ first."
  exit 1
}

# Ensure vercel CLI exists
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  Bad "Vercel CLI not found. Install with: npm i -g vercel"
  exit 1
}

# Build vercel args safely
$argv = @('deploy', $public)
if ($Environment -eq 'production') { $argv += '--prod' }
if ($Yes.IsPresent) { $argv += '--yes' }
$cmdEcho = 'vercel ' + ($argv -join ' ')

Say "Deploying '$public' to Vercel ($Environment)..."
Say "  command: $cmdEcho"

# Invoke
$stdout = & vercel @argv 2>&1
if ($LASTEXITCODE -ne 0) { $stdout | Write-Host; Bad "Vercel deploy failed."; exit 1 }
$stdout | Write-Host

# Extract final URL (last *.vercel.app occurrence)
$urls = $stdout | Select-String -Pattern 'https://[^ \r\n"]+\.vercel\.app' -AllMatches |
        ForEach-Object { $_.Matches.Value } | Select-Object -Unique
if ($urls) {
  $final = $urls[-1]
  Good "Deployed: $final"
} else {
  Good "Deployed."
}

if ($Environment -eq "production") {
  Write-Host "`n🚀 Production deploy successful!" -ForegroundColor Green
} else {
  Write-Host "`n�� Preview deploy successful!" -ForegroundColor Cyan
}

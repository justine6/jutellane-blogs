param(
  [switch]$SkipMetadata
)

$ErrorActionPreference = "Stop"

# Directory of this script (tools/ops)
$scriptDir = $PSScriptRoot

# Repo root = two levels up from tools/ops
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")

# Path to metadata generator under tools/content
$metadataScript = Join-Path $scriptDir "..\content\Generate-Metadata.ps1"

Write-Host "📂 Repo root: $repoRoot" -ForegroundColor Cyan
Set-Location $repoRoot

# 1) Run metadata generator if available
if (-not $SkipMetadata) {
    if (Test-Path $metadataScript) {
        Write-Host "📝 Running metadata generator: $metadataScript" -ForegroundColor Cyan
        & $metadataScript
        $metaExit = $LASTEXITCODE
        if ($metaExit -ne $null -and $metaExit -ne 0) {
            Write-Host "⚠ Generate-Metadata.ps1 exited with code $metaExit" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠ Generate-Metadata.ps1 not found under tools/content. Skipping metadata step." -ForegroundColor Yellow
    }
}

# 2) Run the JS build
Write-Host "🏗 Running site build..." -ForegroundColor Cyan

if (Test-Path "pnpm-lock.yaml") {
    pnpm build
}
elseif (Test-Path "package.json") {
    npm run build
}
else {
    Write-Host "⚠ No package.json or pnpm-lock.yaml found; nothing to build." -ForegroundColor Yellow
}

$exit = $LASTEXITCODE
if ($exit -ne $null -and $exit -ne 0) {
    Write-Host "⚠ Build exited with code $exit" -ForegroundColor Yellow
    exit $exit
}

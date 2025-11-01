# Rebuild static blog content into public/
$ErrorActionPreference = "Stop"
Write-Host "› Building Jutellane blog..." -ForegroundColor Cyan

# TODO: add your real build/export here (npm/yarn/pnpm/etc)
# Example placeholders:
# npm run build
# Copy-Item -Recurse -Force src\* public\

Write-Host "✓ Build complete." -ForegroundColor Green

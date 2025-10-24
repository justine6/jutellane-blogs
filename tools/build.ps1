param([string]$SiteUrl = "https://justine6.github.io/jutellane-blogs")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot; if (-not $root) { $root = (Resolve-Path ".").Path }
& "$PSScriptRoot\Generate-Metadata.ps1" -SiteUrl $SiteUrl
Write-Host "Build complete."

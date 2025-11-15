<#
.SYNOPSIS
Lists all draft files in /drafts with a quick title/slug summary.
#>

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }

# Always run from repo root
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path
Set-Location $root

$draftRoot = Join-Path $root "drafts"

if (!(Test-Path $draftRoot)) {
    Warn "Drafts folder not found at: $draftRoot"
    exit 1
}

Say "Scanning drafts in: $draftRoot …"

$files = Get-ChildItem -Path $draftRoot -Recurse -File -Include *.md,*.markdown,*.html

if (-not $files) {
    Warn "No draft files found."
    exit 0
}

$results = @()

foreach ($f in $files) {
    $slug = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $ext  = $f.Extension.TrimStart('.').ToLowerInvariant()

    $title = $null

    if ($ext -in @("md","markdown")) {
        # First Markdown H1
        $m = Select-String -Path $f.FullName -Pattern '^\s*#\s+(.+)$' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($m) { $title = $m.Matches[0].Groups[1].Value.Trim() }
    }
    elseif ($ext -eq "html") {
        $m = Select-String -Path $f.FullName -Pattern '<title>(.*?)</title>' -ErrorAction SilentlyContinue
        if ($m) { $title = $m.Matches[0].Groups[1].Value.Trim() }
    }

    if (-not $title) { $title = "(no title found)" }

    $results += [pscustomobject]@{
        Slug  = $slug
        Type  = $ext
        Title = $title
        Path  = $f.FullName
    }
}

Good "Found $($results.Count) draft file(s)."
$results | Sort-Object Type, Slug | Format-Table

param(
  [Parameter(Mandatory = $true)] [string] $Title,
  [string[]] $Tags = @(),
  [string] $Summary = "",
  [string] $Canonical = ""
)
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Resolve-Path ".").Path }

$drafts = Join-Path $root "drafts"
if (-not (Test-Path $drafts)) { New-Item -ItemType Directory -Path $drafts | Out-Null }

function Slugify([string]$t) {
  $s = $t.ToLower()
  $s = $s -replace "[^a-z0-9\s-]", ""
  $s = $s -replace "\s+", "-"
  $s = $s -replace "-+", "-"
  $s.Trim("-")
}

$slug   = Slugify $Title
$today  = Get-Date -Format "yyyy-MM-dd"
$name   = "$today-$slug.md"
$path   = Join-Path $drafts $name

$tagsYaml      = ($Tags | ForEach-Object { "'$_'" }) -join ", "
$canonicalLine = ($Canonical) ? "canonical: `"$Canonical`"" : "# canonical: ""https://medium.com/..."""

$content = @"
---
title: "$Title"
date: $today
tags: [$tagsYaml]
summary: "$Summary"
$canonicalLine
slug: "$slug"
---
<!-- Write your post below in Markdown -->

"@

Set-Content -Path $path -Value $content -Encoding UTF8 -NoNewline
Write-Host "Draft created: $path"

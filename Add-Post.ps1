[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Title,
  [string]$Slug,
  [string]$Summary = "",
  [string[]]$Tags = @(),
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [switch]$Open
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$PostsDir = Join-Path $Root "posts"
if (-not (Test-Path $PostsDir)) { New-Item -ItemType Directory -Path $PostsDir | Out-Null }

if ([string]::IsNullOrWhiteSpace($Slug)) {
  $Slug = ($Title.ToLower() -replace "[^a-z0-9]+","-").Trim("-")
}

$FileName = "{0}-{1}.md" -f $Date, $Slug
$PostPath = Join-Path $PostsDir $FileName

$escapedTags = @(); foreach ($t in $Tags) { $escapedTags += '"' + ($t -replace '"','\"') + '"' }
$TagList = if ($escapedTags.Count -gt 0) { '[' + [string]::Join(', ', $escapedTags) + ']' } else { '[]' }

$Content = @"
---
title: "$Title"
date: $Date
tags: $TagList
summary: "$Summary"
slug: "$Slug"
---

# $Title

> $Summary

## Overview

Write your content here.
"@
Set-Content -Path $PostPath -Value $Content -Encoding UTF8

$IndexPath = Join-Path $Root "index.html"
$RelativeLink = "posts/$FileName"
$NewLi = "<li><a href=""$RelativeLink"">$Title</a> <small>($Date)</small></li>"

if (Test-Path $IndexPath) {
  Copy-Item $IndexPath "$IndexPath.bak" -Force
  $Index = Get-Content $IndexPath -Raw
  $postsBlockPattern = "<!--\s*posts:start\s*-->(.*?)<!--\s*posts:end\s*-->"

  if ($Index -match [regex]::Escape($RelativeLink)) {
    Write-Host "ℹ️ Link already present; skipping add."
  } else {
    if ([regex]::IsMatch($Index, $postsBlockPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
      $match = [regex]::Match($Index, $postsBlockPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
      $inner = $match.Groups[1].Value
      $existingLis = [regex]::Matches($inner, "<li>.*?</li>", [System.Text.RegularExpressions.RegexOptions]::Singleline) |
        ForEach-Object { $_.Value }
      $rebuilt = "<ul>`n$NewLi"
      if ($existingLis.Count -gt 0) { $rebuilt += "`n" + ($existingLis -join "`n") }
      $rebuilt += "`n</ul>"
      $Index = [regex]::Replace($Index, $postsBlockPattern,
        "<!-- posts:start -->`n$rebuilt`n<!-- posts:end -->",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    } else {
      $section = @"
<section id=""posts"">
  <h2>Posts</h2>
  <!-- posts:start -->
  <ul>
    $NewLi
  </ul>
  <!-- posts:end -->
</section>
"@
      if ($Index -match "</body>") { $Index = [regex]::Replace($Index, "</body>", "$section`n</body>", 1) }
      else { $Index += "`n$section" }
    }
    Set-Content $IndexPath $Index -Encoding UTF8
  }
} else {
  $IndexContent = @"
<!doctype html>
<html lang=""en""><head>
  <meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width, initial-scale=1"">
  <title>Jutellane Blogs</title>
</head><body>
  <main>
    <h1>Jutellane Blogs</h1>
    <section id=""posts"">
      <h2>Posts</h2>
      <!-- posts:start -->
      <ul>
        $NewLi
      </ul>
      <!-- posts:end -->
    </section>
  </main>
</body></html>
"@
  Set-Content $IndexPath $IndexContent -Encoding UTF8
}

if ($Open) { Start-Process $PostPath }
Write-Host "✅ Created post: $PostPath"
if (Test-Path "$IndexPath.bak") { Write-Host "✅ Updated index.html (backup at index.html.bak)" } else { Write-Host "✅ Created index.html" }

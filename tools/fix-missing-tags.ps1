<#
.SYNOPSIS
Adds a <meta name="tags"> element to posts that are missing it.

- Scans posts/ for index.html files.
- Finds files without a <meta name="tags"> in the <head>.
- Suggests tags from the slug (kubernetes-101 -> "kubernetes, 101").
- Shows a summary and asks for confirmation.
- Creates a .bak backup before editing any file.
#>

$ErrorActionPreference = "Stop"

function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }

# --- 1) Always run from repo root --------------------------------------------
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path
Set-Location $root

$postsRoot = Join-Path $root "posts"

if (!(Test-Path $postsRoot)) {
    Warn "Posts folder not found at: $postsRoot"
    exit 1
}

Say "Scanning posts in: $postsRoot for missing <meta name=""tags""> …"

# --- 2) Collect posts missing tags ------------------------------------------
$missing = @()

Get-ChildItem -Path $postsRoot -Recurse -Filter "index.html" | ForEach-Object {
    $file   = $_.FullName
    $folder = Split-Path $file -Parent
    $slug   = Split-Path $folder -Leaf
    $month  = Split-Path (Split-Path $folder -Parent) -Leaf
    $year   = Split-Path (Split-Path (Split-Path $folder -Parent) -Parent) -Leaf

    $html = Get-Content $file -Raw

    $hasTags = [regex]::IsMatch($html, '<meta\s+name="tags"\s+content="', "IgnoreCase")

    if (-not $hasTags) {
        # Try to pull the <title> for nicer output
        $titleMatch = [regex]::Match($html, '<title>(.*?)</title>', "IgnoreCase")
        $title = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { "(no title)" }

        # Suggest tags from slug: split on '-', drop stop words
        $words = $slug -split '-'
        $stop  = @("the","and","for","with","a","an","of","in","to","on","ii","iii")
        $keywords = $words | Where-Object { $_ -and ($_ -notin $stop) }

        if (-not $keywords) {
            $keywords = @("devops")
        }

        $suggested = ($keywords -join ", ")

        $missing += [pscustomobject]@{
            Slug      = $slug
            Year      = $year
            Month     = $month
            Title     = $title
            Tags      = $suggested
            HtmlPath  = $file
        }
    }
}

if ($missing.Count -eq 0) {
    Good "All posts already have <meta name=""tags"">. Nothing to do."
    exit 0
}

Warn "Posts missing <meta name=""tags""> (with suggested tags):"
$missing | Sort-Object Year, Month, Slug | Format-Table Slug, Year, Month, Title, Tags

# --- 3) Ask for confirmation -------------------------------------------------
Write-Host ""
$answer = Read-Host "Patch these $($missing.Count) file(s) with the suggested tags? (y/N)"

if ($answer -notin @("y","Y")) {
    Warn "Aborting without changes."
    exit 0
}

# --- 4) Patch each file ------------------------------------------------------
foreach ($item in $missing) {
    $path = $item.HtmlPath
    $tags = $item.Tags

    Say "Patching tags for: $($item.Slug) …"

    $html = Get-Content $path -Raw

    # Skip if tags were added manually between scan & patch
    if ([regex]::IsMatch($html, '<meta\s+name="tags"\s+content="', "IgnoreCase")) {
        Warn "Tags already present in $path (skipping)."
        continue
    }

    $metaLine = '  <meta name="tags" content="' + $tags + '" />'

    $newHtml = $null

    # Prefer inserting after description meta if present
    $descPattern = '<meta\s+name="description"[^>]*>\s*'
    if ([regex]::IsMatch($html, $descPattern, "IgnoreCase")) {
        $newHtml = [regex]::Replace(
            $html,
            $descPattern,
            { param($m) $m.Value + "`r`n" + $metaLine + "`r`n" },
            1,
            "IgnoreCase"
        )
    }
    elseif ($html -match '</head>') {
        $newHtml = $html -replace '</head>', "$metaLine`r`n</head>"
    }
    else {
        # Fallback: prepend at top
        $newHtml = $metaLine + "`r`n" + $html
    }

    # Backup then write
    $backup = "$path.bak"
    Copy-Item $path $backup -Force
    Set-Content -Encoding UTF8 -NoNewline $path $newHtml

    Good "Patched: $path (backup: $backup)"
}

Good "Finished patching missing tag metadata."

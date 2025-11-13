param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Title,

  [string]$Slug,

  [datetime]$Date = (Get-Date),

  [string]$Description = "Jutellane Blog — Exploring Cloud, DevOps, AI, and Sustainability.",
  [string]$Tags = "devops, pipelines, automation"
)

$ErrorActionPreference = 'Stop'

function Say($msg) { Write-Host "› $msg" -ForegroundColor Cyan }
function Good($msg){ Write-Host "✓ $msg" -ForegroundColor Green }
function Bad($msg) { Write-Host "✗ $msg" -ForegroundColor Red }

# 0) Repo root (scripts/ is one level down)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root      = Split-Path -Parent $scriptDir

$postsRoot     = Join-Path $root "posts"
$templatePath  = Join-Path $root "templates\post-template.html"

if (!(Test-Path $templatePath)) {
  Bad "Template not found at $templatePath"
  exit 1
}

# 1) Slug from title if missing
if (-not $Slug -or !$Slug.Trim()) {
  $Slug = $Title.ToLowerInvariant()
  $Slug = $Slug -replace '[^a-z0-9]+','-'
  $Slug = $Slug -replace '(^-|-$)',''
}

$year  = $Date.ToString('yyyy')
$month = $Date.ToString('MM')

$destDir  = Join-Path $postsRoot (Join-Path $year (Join-Path $month $Slug))
$destFile = Join-Path $destDir "index.html"

Say "Creating new post:"
Say "  Title : $Title"
Say "  Slug  : $Slug"
Say "  Date  : $($Date.ToString('u'))"
Say "  Path  : $destFile"

if (Test-Path $destFile) {
  Bad "File already exists: $destFile"
  exit 1
}

# 2) Ensure folders exist
New-Item -ItemType Directory -Path $destDir -Force | Out-Null

# 3) Load template and replace placeholders
$content = Get-Content $templatePath -Raw

$iso   = $Date.ToString('yyyy-MM-dd')
$human = $Date.ToString('MMM dd, yyyy')

$content = $content.Replace('__TITLE__', $Title)
$content = $content.Replace('__DESCRIPTION__', $Description)
$content = $content.Replace('__TAGS__', $Tags)
$content = $content.Replace('__DATE_ISO__', $iso)
$content = $content.Replace('__DATE_HUMAN__', $human)
$content = $content.Replace('__READTIME__', '1')  # tweak manually later if you like

# 4) Write new post
Set-Content -Path $destFile -Value $content -Encoding UTF8

Good "Created new post at $destFile"
Good "Next: edit the file content, then run 'npm run prebuild' or '.\scripts\build-serve.ps1'."

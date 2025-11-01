param(
  [ValidateSet('docs','branch')]
  [string]$Mode = 'docs',

  [string]$Branch = 'gh-pages',

  [string]$CommitMessage = "chore(pages): publish static blog",

  # Skip confirmations
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
function Say($m){ Write-Host "› $m" -ForegroundColor Cyan }
function Good($m){ Write-Host "✓ $m" -ForegroundColor Green }
function Bad($m){ Write-Host "✗ $m" -ForegroundColor Red }

# 0) Sanity check
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (!(Test-Path ".git")) { Bad "Not a git repo."; exit 1 }

$public = Join-Path $repoRoot "public"
if (!(Test-Path (Join-Path $public "index.html"))) {
  Bad "public/index.html not found. Build first."
  exit 1
}

if ($Mode -eq 'docs') {
  # 1) Mirror to /docs (GitHub Pages → Settings → Pages → Source: 'Deploy from a branch' → Branch: main / folder: /docs)
  $docs = Join-Path $repoRoot "docs"
  if (Test-Path $docs) { Remove-Item $docs -Recurse -Force }
  New-Item -ItemType Directory -Path $docs | Out-Null

  Copy-Item "$public\*" $docs -Recurse -Force
  git add docs
  git commit -m $CommitMessage 2>$null | Out-Null
  git push

  Good "Pushed to main/docs for GitHub Pages."
}
else {
  # 2) gh-pages branch strategy (orphan-publish)
  $tempDir = Join-Path $env:TEMP ("pages_" + ([Guid]::NewGuid()))
  New-Item -ItemType Directory -Path $tempDir | Out-Null
  Copy-Item "$public\*" $tempDir -Recurse -Force

  # create orphan publish
  git fetch origin
  if (git show-ref --verify --quiet "refs/heads/$Branch") {
    git branch -D $Branch | Out-Null
  }
  git checkout --orphan $Branch
  git reset --hard
  Get-ChildItem -Force | Where-Object { $_.Name -notin '.git' } | Remove-Item -Recurse -Force

  Copy-Item "$tempDir\*" . -Recurse -Force
  git add .
  git commit -m $CommitMessage
  git push -u origin $Branch -f
  git checkout -

  Remove-Item $tempDir -Recurse -Force
  Good "Published to branch '$Branch' (force pushed). Configure Pages to use this branch."
}

param(
  [Parameter(Mandatory)][string]$Version,
  [switch]$DryRun,
  [switch]$GenerateNotes
)

Write-Host "🔹 Preparing release for version $Version" -ForegroundColor Cyan

# ----------------------------------------------------
# 1) Ensure working tree is clean
# ----------------------------------------------------
$gitStatus = git status --porcelain
if ($gitStatus) {
  Write-Host "⚠️ Working directory not clean. Commit or stash changes first." -ForegroundColor Yellow
  exit 1
}

# ----------------------------------------------------
# 2) Ensure on main
# ----------------------------------------------------
$branch = (git branch --show-current).Trim()
if ($branch -ne "main") {
  Write-Host "❌ You must be on 'main' (current: $branch)" -ForegroundColor Red
  exit 1
}

git fetch --all
git pull --rebase

# ----------------------------------------------------
# 3) Tag validation
# ----------------------------------------------------
$tagName = "v$Version"
if (git tag --list $tagName) {
  Write-Host "❌ Tag $tagName already exists." -ForegroundColor Red
  exit 1
}

# ----------------------------------------------------
# 4) Optional: Generate Release Notes
# ----------------------------------------------------
if ($GenerateNotes) {
  $today = Get-Date -Format "yyyy-MM-dd"

  $releaseBody = @"
## 🚀 $tagName — $today

### Added
- (Fill this section manually if needed)

### Changed
- (Fill this section manually)

### Fixed
- (Fill this section manually)

### Metadata
- Generated on $today
"@

 Write-Host "`n📌 Suggested GitHub Release Notes for ${tagName}:`n" -ForegroundColor Cyan
  Write-Host $releaseBody

  try {
    $releaseBody | Set-Clipboard
    Write-Host "`n📋 Copied release notes to clipboard!" -ForegroundColor Green
  }
  catch {
    Write-Host "`n⚠️ Could not copy to clipboard automatically. Copy the above manually." -ForegroundColor Yellow
  }
}

# ----------------------------------------------------
# 5) Early exit for dry-run
# ----------------------------------------------------
if ($DryRun) {
  Write-Host "🧪 Dry run OK — would create and push tag $tagName" -ForegroundColor Cyan
  exit 0
}

# ----------------------------------------------------
# 6) Create & push tag
# ----------------------------------------------------
git tag -a $tagName -m "release: $tagName"
git push origin $tagName

Write-Host "✅ Tag $tagName created and pushed!" -ForegroundColor Green

param(
  [Parameter(Mandatory)][string]$Version,
  [switch]$DryRun,
  [switch]$Verbose
)

Write-Host "🔹 Preparing release for version $Version" -ForegroundColor Cyan

# 1) Require clean working tree
$gitStatus = git status --porcelain
if ($gitStatus) {
  Write-Host "⚠️ Working directory not clean. Commit or stash changes before release." -ForegroundColor Yellow
  exit 1
}

# 2) Stay on main and up to date
$branch = (git branch --show-current).Trim()
if ($branch -ne "main") {
  Write-Host "❌ You must be on 'main' (current: $branch)" -ForegroundColor Red
  exit 1
}
git fetch --all
git pull --rebase

# 3) Check tag
$tagName = "v$Version"
$exists = git tag --list $tagName
if ($exists) {
  Write-Host "❌ Tag $tagName already exists." -ForegroundColor Red
  exit 1
}

if ($DryRun) {
  Write-Host "🧪 Dry run OK — would create & push tag $tagName" -ForegroundColor DarkCyan
  exit 0
}

# 4) Create annotated tag and push
git tag -a $tagName -m "release: $tagName"
git push origin $tagName

Write-Host "✅ Tag $tagName created and pushed successfully!" -ForegroundColor Green

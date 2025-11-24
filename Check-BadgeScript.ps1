param([switch]$AutoRun)

$ErrorActionPreference = 'Stop'

# Define both repos you want to check/update
$repos = @(
  @{
    # 🟢 Blogs repo (already works)
    Path            = 'C:\Users\justi\Downloads\jutellane-blogs'
    Kind            = 'blogs'
    Owner           = 'justine6'
    Repo            = 'jutellane-blogs'
    Workflow        = 'blog.yml'
    DefaultSiteUrl  = 'https://justine6.github.io/jutellane-blogs'
    DefaultBlogUrl  = 'https://justine6.github.io/jutellane-blogs'
  },
  @{
    # 🔵 Main repo (update this)
    Path            = 'C:\Users\justi\Downloads\Jutellane-Solutions-main'  # correct git root
    Kind            = 'main'
    Owner           = 'justine6'
    Repo            = 'Jutellane-Solutions'
    Workflow        = 'deploy.yml'
    DefaultSiteUrl  = 'https://justinelonglat-lane.com'
    DefaultBlogUrl  = 'https://justine6.github.io/jutellane-blogs'
  }
)

foreach ($r in $repos) {
  Write-Host "`n🔍 Checking $($r.Path) ..." -ForegroundColor Cyan

  if (-not (Test-Path $r.Path)) {
    Write-Warning "⚠ Repo not found: $($r.Path)"
    continue
  }

  $scriptPath = Join-Path $r.Path 'Update-ReadmeBadges.ps1'

  if (-not (Test-Path $scriptPath)) {
    Write-Warning "⚠ Missing Update-ReadmeBadges.ps1 in $($r.Path)"
  } else {
    Write-Host "✓ Script found: $scriptPath" -ForegroundColor Green
  }

  # Dry test (non-blocking)
  Write-Host "▶ Testing execution..."
  try {
    $args = @(
      '-RepoKind', $r.Kind,
      '-Owner', $r.Owner,
      '-Repo', $r.Repo,
      '-WorkflowFileName', $r.Workflow,
      '-DetectCNAME'
    )
    if ($r.Kind -eq 'blogs') {
      $args += @('-DefaultBlogUrl', $r.DefaultBlogUrl)
    } else {
      $args += @('-DefaultSiteUrl', $r.DefaultSiteUrl, '-DefaultBlogUrl', $r.DefaultBlogUrl)
    }

    if (Test-Path $scriptPath) {
      & pwsh -NoProfile -File $scriptPath @args | Out-Null
      Write-Host "✅ Executed successfully in $($r.Path)" -ForegroundColor Green
    } else {
      Write-Warning "❌ Skipping test; script not found."
    }
  }
  catch {
    Write-Warning "❌ Could not execute script in $($r.Path) — $($_.Exception.Message)"
  }

  if ($AutoRun -and (Test-Path $scriptPath)) {
    Write-Host "🚀 AutoRun enabled — updating badges in $($r.Repo)..." -ForegroundColor Yellow
    try {
      & pwsh -NoProfile -File $scriptPath @args
      Write-Host "🎉 Badges updated in $($r.Repo)." -ForegroundColor Green
    } catch {
      Write-Warning "❌ Badge update failed in $($r.Repo) — $($_.Exception.Message)"
    }
  }
}

Write-Host "`nAll done. If all checks are ✅, you’re ready to run with -AutoRun to apply changes." -ForegroundColor Cyan


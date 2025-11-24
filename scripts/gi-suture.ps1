<#
.SYNOPSIS
    Git Suture Script — Safely commits, pushes, and optionally tags changes.

.DESCRIPTION
    This script stages all modified files, commits them with a message,
    pushes to the current branch, and optionally creates an annotated tag.
    It is part of the Jutellane Automation Toolkit.

.PARAMETER Message
    Commit message to use.

.PARAMETER Tag
    Optional Git tag to create.

.PARAMETER TagMessage
    Optional tag annotation message.

.EXAMPLE
    pwsh ./tools/git-suture.ps1 -Message "fix: layout bug"

.EXAMPLE
    pwsh ./tools/git-suture.ps1 `
      -Message "refactor: improve automation" `
      -Tag "v-refactor-001" `
      -TagMessage "Reference snapshot for refactor work"
#>

param(
  [string]$Message = "chore: suture changes",
  [string]$Tag,
  [string]$TagMessage
)

$ErrorActionPreference = "Stop"

function Say($msg)  { Write-Host "› $msg" -ForegroundColor Cyan }
function Good($msg) { Write-Host "✓ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Bad($msg)  { Write-Host "✗ $msg" -ForegroundColor Red }

try {
  git rev-parse --is-inside-work-tree *> $null
} catch {
  Bad "Not inside a git repository. Run this from your project root."
  exit 1
}

# Show current branch
$branch = git rev-parse --abbrev-ref HEAD
Say "Current branch: $branch"

if ($branch -ne "main") {
  Warn "You are NOT on main. Are you sure you want to suture?"
  $confirm = Read-Host "Type YES to continue"
  if ($confirm -ne "YES") {
    Bad "Aborted."
    exit 1
  }
}

Say "Checking git status..."
$status = git status --short

if (-not $status) {
  Good "Nothing to suture — working tree clean."
  exit 0
}

Write-Host "`nFiles to suture:" -ForegroundColor Yellow
$status | Write-Host
Write-Host ""

Say "Staging changes (git add -A)..."
git add -A

Say "Committing..."
git commit -m $Message
Good "Commit completed."

Say "Pushing..."
git push
Good "Push completed."

if ($Tag) {
  if (-not $TagMessage) { $TagMessage = $Message }

  Say "Creating annotated tag '$Tag'..."
  git tag -a $Tag -m $TagMessage

  Say "Pushing tag..."
  git push --tags
  Good "Tag pushed: $Tag"
}

Good "Suture complete. Repository is now synchronized."

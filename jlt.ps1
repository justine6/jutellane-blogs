param(
  # First token: either a category (ops, content, etc.) OR an alias (build, validate, rebase, add-post, ...)
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$First,

  # Everything after the first token is forwarded to the underlying script unchanged
  [Parameter(ValueFromRemainingArguments = $true, Position = 1)]
  [string[]]$Rest
)

$validCategories = @("release", "ops", "content", "verify", "dev")

$category = $null
$command  = $null
[string[]]$argsToForward = @()

$firstLower = $First.ToLowerInvariant()

# ---------- Mode 1: Category + Command ----------
if ($validCategories -contains $firstLower) {
  if ($Rest.Count -lt 1) {
    Write-Host "❌ Missing command for category '$First'." -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  ./jlt.ps1 <category> <command> [args...]"
    Write-Host "  ./jlt.ps1 <alias> [args...]"
    Write-Host ""
    Write-Host "Categories: release, ops, content, verify, dev" -ForegroundColor Yellow
    exit 1
  }

  $category      = $firstLower
  $command       = $Rest[0]
  $argsToForward = if ($Rest.Count -gt 1) { $Rest[1..($Rest.Count - 1)] } else { @() }
}
else {
  # ---------- Mode 2: Alias only ----------
  switch ($firstLower) {
    "build" {
      $category = "ops"
      $command  = "build"
    }
    "validate" {
      $category = "verify"
      $command  = "validate"
    }
    "rebase" {
      $category = "dev"
      $command  = "Safe-Rebase"
    }
    "safe-rebase" {
      $category = "dev"
      $command  = "Safe-Rebase"
    }
    "suture" {
      $category = "dev"
      $command  = "git-suture"
    }
    "metadata" {
      $category = "content"
      $command  = "Generate-Metadata"
    }
    "add-post" {
      $category = "content"
      $command  = "Add-Post"
    }
    default {
      Write-Host "❌ Unknown alias or category '$First'." -ForegroundColor Red
      Write-Host ""
      Write-Host "Usage:" -ForegroundColor Yellow
      Write-Host "  ./jlt.ps1 <category> <command> [args...]"
      Write-Host "  ./jlt.ps1 <alias> [args...]"
      Write-Host ""
      Write-Host "Categories: release, ops, content, verify, dev" -ForegroundColor Yellow
      Write-Host "Aliases: build, validate, rebase, safe-rebase, suture, metadata, add-post" -ForegroundColor Yellow
      exit 1
    }
  }

  # In alias mode we forward ALL remaining args directly to the tool
  $argsToForward = $Rest
}

# ---------- Resolve and run the target script ----------
$scriptPath = Join-Path -Path "tools" -ChildPath ("{0}\{1}.ps1" -f $category, $command)

if (-not (Test-Path $scriptPath)) {
  Write-Host "❌ Tool not found for category '$category' and command '$command'." -ForegroundColor Red
  Write-Host "   Expected: $scriptPath" -ForegroundColor DarkGray
  exit 1
}

Write-Host "▶ Running: $scriptPath $argsToForward" -ForegroundColor Cyan

& $scriptPath @argsToForward
$exitCode = $LASTEXITCODE

if ($exitCode -ne $null -and $exitCode -ne 0) {
  Write-Host "⚠ Tool exited with code $exitCode" -ForegroundColor Yellow
  exit $exitCode
}


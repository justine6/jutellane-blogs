<#
Jutellane Blogs CLI
Commands:
  new      -Title "<title>" [-Tags tag1,tag2] [-Summary "..."] [-Canonical "https://medium.com/..."]
  publish  [-DraftPath .\drafts\YYYY-MM-DD-slug.md]   # if omitted, picks most recent draft
  gen      [-SiteUrl "https://justine6.github.io/jutellane-blogs"]
  build    [-SiteUrl "..."]  # alias for gen
  help
#>
param(
  [Parameter(Position=0)][ValidateSet("new","publish","gen","build","help")]$cmd = "help",
  [string]$Title,
  [string[]]$Tags = @(),
  [string]$Summary = "",
  [string]$Canonical = "",
  [string]$DraftPath,
  [string]$SiteUrl = "https://justine6.github.io/jutellane-blogs"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot; if (-not $root) { $root = (Resolve-Path ".").Path }

switch ($cmd) {
  "new" {
    if (-not $Title) { throw "Usage: blog.ps1 new -Title '<title>' [-Tags t1,t2] [-Summary '...'] [-Canonical 'URL']" }
    & "$PSScriptRoot\new-post.ps1" -Title $Title -Tags $Tags -Summary $Summary -Canonical $Canonical
  }
  "publish" {
    if (-not $DraftPath) {
      $draftsDir = Join-Path $root "drafts"
      $draft = Get-ChildItem $draftsDir -Filter *.md | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if (-not $draft) { throw "No drafts found. Add one with: pwsh tools/blog.ps1 new -Title '...'" }
      $DraftPath = $draft.FullName
    }
    & "$PSScriptRoot\Add-Post.ps1" -DraftPath $DraftPath
  }
  "gen" { & "$PSScriptRoot\Generate-Metadata.ps1" -SiteUrl $SiteUrl }
  "build" { & "$PSScriptRoot\Generate-Metadata.ps1" -SiteUrl $SiteUrl }
  Default {
@"
Jutellane Blogs CLI

Examples:
  pwsh tools/blog.ps1 new -Title "AWS Landing Zone Tips" -Tags aws,security -Summary "notes"
  pwsh tools/blog.ps1 publish
  pwsh tools/blog.ps1 build -SiteUrl "https://justine6.github.io/jutellane-blogs"
"@ | Write-Host
  }
}

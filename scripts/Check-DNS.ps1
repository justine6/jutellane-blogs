<#
.SYNOPSIS
  Continuous DNS + HTTPS watcher for Vercel or other hosts.

.DESCRIPTION
  Monitors DNS resolution for a domain until it points to a specific provider (default: Vercel),
  then checks HTTPS reachability (200 OK) and logs everything to a timestamped file.

.PARAMETER Domain
  The domain name to watch (e.g., blogs.jutellane.com)

.PARAMETER ProviderPattern
  The regex pattern to detect when DNS has propagated (default: "vercel-dns\.com")

.PARAMETER Interval
  Seconds between DNS checks (default: 60)
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$Domain,

  [string]$ProviderPattern = "vercel-dns\.com",

  [int]$Interval = 60
)

# --- Log setup ---
$logName = "DNS-$($Domain.Replace('.', '-'))-watch.log"
$Log = Join-Path (Get-Location) $logName

function Log {
  param(
    [string]$Message,
    [ConsoleColor]$Color = "Gray"
  )
  $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $entry = "[$timestamp] $Message"
  $entry | Out-File -FilePath $Log -Append -Encoding UTF8
  Write-Host $entry -ForegroundColor $Color
}

# --- Start ---
Log "🔍 Watcher started for $Domain (logging to $Log)" "Cyan"

while ($true) {
  try {
    $lookup = nslookup $Domain 2>$null
  } catch {
    Log "❌ nslookup failed: $($_.Exception.Message)" "Red"
    Start-Sleep -Seconds $Interval
    continue
  }

  if ($lookup -match $ProviderPattern) {
    Log "✅ DNS now points to provider ($ProviderPattern detected)" "Green"
    ($lookup | Select-String "Name|Address|Alias") |
      ForEach-Object { $_.ToString() } |
      Out-File -FilePath $Log -Append -Encoding UTF8

    try {
      $resp = Invoke-WebRequest -Uri "https://$Domain" -UseBasicParsing -TimeoutSec 15
      if ($resp.StatusCode -eq 200) {
        Log "🌐 HTTPS check successful (200 OK) — site is live!" "Cyan"
      } else {
        Log "⚠️ HTTPS reachable but returned status code $($resp.StatusCode)" "Yellow"
      }
    } catch {
      Log "🚧 DNS ready but HTTPS still provisioning or blocked: $($_.Exception.Message)" "Yellow"
    }
    Log "Watcher finished." "Cyan"
    break
  }
  elseif ($lookup -match "github\.io") {
    Log "⚠️ Still pointing to GitHub Pages (justine6.github.io)..." "Yellow"
  }
  else {
    Log "⏳ Waiting for DNS to propagate…" "DarkGray"
  }

  Start-Sleep -Seconds $Interval
}

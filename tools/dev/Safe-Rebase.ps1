# 🔁 Safe rebase helper
Write-Host "🔄 Saving, rebasing, and pushing..." -ForegroundColor Cyan
git add -A
git stash push -m "auto-stash before rebase" | Out-Null
git fetch origin main
git rebase origin/main
git stash pop | Out-Null
git push origin main
Write-Host "✅ Rebase and push completed successfully!" -ForegroundColor Green

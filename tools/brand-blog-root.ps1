param()

Write-Host "Branding blog homepage + metadata..." -ForegroundColor Cyan

$targets = @(
    "index.html",
    "index.html.bak",
    "index.html.bak5",
    "feed.xml",
    "posts.json"
)

foreach ($file in $targets) {
    if (Test-Path $file) {
        Write-Host "› Updating $file"

        $text = Get-Content $file -Raw

        # Titles
        $text = $text -replace "Jutellane Blogs", "Justine Longla T. DevOps Blog"
        $text = $text -replace "Jutellane Blog", "Justine Longla T. DevOps Blog"
        $text = $text -replace "Welcome to the Jutellane Blog", "Welcome to the Justine Longla T. DevOps Blog"

        # RSS feed
        $text = $text -replace "title=""Jutellane Blogs RSS""",
                                    "title=""Justine Longla T. DevOps Blog RSS"""

        # Descriptions inside posts.json
        $text = $text -replace "Jutellane Blog —", "Justine Longla T. DevOps Blog —"

        Set-Content $file -Value $text -Encoding UTF8
    }
}

Write-Host "✔ All blog branding updated." -ForegroundColor Green

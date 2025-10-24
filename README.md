## CI/CD — Build & Deploy

[![Build & Deploy Jutellane Blogs](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml/badge.svg)](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml)

This repo auto-fixes, validates, and rebuilds site metadata on every push to `main`, then deploys to GitHub Pages.

**Pipeline steps:**
1. **Fix front matter** — `tools/fix-frontmatter.ps1`
   - Fills missing `summary`, generates `slug`, resolves duplicates (`-v2`…), and optionally sets `canonical`.
2. **Validate posts** — `tools/validate.ps1`
   - Ensures `title`, `date (yyyy-MM-dd)`, `summary`, `slug` exist; warns on missing `canonical`.
3. **Generate metadata** — `tools/Generate-Metadata.ps1`
   - Rebuilds `posts.json`, `feed.xml`, `sitemap.xml`, and static tag pages under `tags/`.
4. **Deploy to Pages** — uploads the site artifact and publishes via GitHub Actions.

**Local quick start:**
```powershell
# create a draft
pwsh tools/blog.ps1 new -Title "New Post" -Tags aws,security -Summary "blurb"

# publish most recent draft
pwsh tools/blog.ps1 publish

# fix + validate + build
pwsh tools/blog.ps1 fix -SiteUrl "https://justine6.github.io/jutellane-blogs"
pwsh tools/blog.ps1 build -SiteUrl "https://justine6.github.io/jutellane-blogs"
### GitHub Pages Deployment

This project deploys via GitHub Actions.

**Initial setup (one time):**
1. Repo → **Settings** → **Pages** → **Build and deployment** → **Source**: **GitHub Actions**.
2. (Optional) Ensure the `github-pages` environment does not require manual approvals.

**Workflow summary:**
- `configure-pages` prepares the Pages environment.
- `upload-pages-artifact` packages the site from the repo root.
- `deploy-pages` publishes to GitHub Pages.

Status:  
[![Build & Deploy Jutellane Blogs](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml/badge.svg)](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml)

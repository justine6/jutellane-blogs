
<!-- CI/CD & Site Badges -->
[![Build & Deploy — Justine Longla T. DevOps Blog](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml/badge.svg?branch=main)](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml)
[![GitHub Pages](https://img.shields.io/website?url=https%3A%2F%2Fjustine6.github.io%2Fjutellane-blogs)](https://justine6.github.io/jutellane-blogs/)
[![Last commit](https://img.shields.io/github/last-commit/justine6/jutellane-blogs/main)](https://github.com/justine6/jutellane-blogs/commits/main)
[![RSS](https://img.shields.io/badge/RSS-feed.xml-orange)](https://justine6.github.io/jutellane-blogs/feed.xml)

**Live site:** https://justine6.github.io/jutellane-blogs/

# 🧩 Justine Longla T. DevOps Blog CI/CD Workflow
[![Content Status](https://img.shields.io/github/last-commit/justine6/jutellane-blogs/main)](https://github.com/justine6/jutellane-blogs/commits/main)
[![Site](https://img.shields.io/badge/site-live-blue)](https://justine6.github.io/jutellane-blogs/)

[![Build & Deploy](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml/badge.svg?branch=main)](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml)
[![Deploy Status](https://img.shields.io/website?url=https%3A%2F%2Fjustine6.github.io%2Fjutellane-blogs&label=Live%20Site)](https://justine6.github.io/jutellane-blogs)

This repository automates the process of fixing, validating, and deploying blog content to GitHub Pages.  
It ensures each post is properly formatted, metadata is up-to-date, and all site artifacts are published automatically.

# Justine Longla T. DevOps Blog · Public Site

This is the **live site** built from artifacts generated in:
- https://github.com/justine6/md-to-html-static

Deployments are driven from that generator repo using
[`peaceiris/actions-gh-pages`](https://github.com/peaceiris/actions-gh-pages)
and an **SSH Deploy Key**.

Public URL: https://justine6.github.io/jutellane-blogs/

> If you see an empty site or old content, check the last run of
> **Build & Deploy (Pages + Main)** in the generator repo.


---

## ⚙️ CI/CD Workflow Overview

The GitHub Actions workflow consists of two main jobs:

1. **Fix, Validate, Build** – runs PowerShell automation to:
   - Fix front matter in all markdown posts  
   - Validate post structure and metadata  
   - Regenerate `posts.json`, `feed.xml`, `sitemap.xml`, and tag data  
   - Upload the generated site artifact

2. **Deploy to GitHub Pages** – automatically publishes the verified site to GitHub Pages after successful validation and build.

---

## 🧠 Automated Metadata Updates via Pull Requests

To prevent *non–fast-forward push errors* when updating metadata directly on the `main` branch,  
the CI/CD pipeline now uses **[peter-evans/create-pull-request](https://github.com/peter-evans/create-pull-request)**  
to open a Pull Request (PR) automatically for metadata changes.

This ensures safe updates and version control for generated files like `posts.json`, `feed.xml`, `sitemap.xml`, and `tags/`.

When the workflow detects changes, it:
- Commits regenerated metadata  
- Opens a pull request targeting `main`  
- Automatically deletes the branch after merge

---

### 🔧 Workflow Step (YAML)

Add or confirm the following snippet in your `.github/workflows/blog.yml`:

```yaml
- name: Create metadata update PR
  uses: peter-evans/create-pull-request@v6
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    commit-message: "chore(blog): fix/validate/build metadata"
    title: "chore(blog): update generated metadata"
    body: |
      Automated update of posts.json, feed.xml, sitemap.xml, and tags/.
    branch: ci/metadata-update
    delete-branch: true
    add-paths: |
      posts.json
      feed.xml
      sitemap.xml
      tags/*
```
## 🧠 Developer Utility — Safe Rebase & Push (PowerShell)

> A helper script to safely sync local commits with GitHub when your push is rejected because  
> “the remote contains work that you do not have locally.”

This script stashes your current work, rebases your branch onto the latest `main`, restores your changes, and pushes — keeping the Git history **linear and conflict-free**.

---

### ⚙️ Script: `tools/Safe-Rebase.ps1`

```powershell
# 🧠 Safe Rebase & Push Helper
# ---------------------------------------------------------
# Purpose: Handles "non-fast-forward" errors automatically
# Usage  : Run anytime your 'git push' is rejected
# Author : JustineLonglaT-Lane Consulting DevOps Workflow
# ---------------------------------------------------------

Write-Host "🔄 Saving, rebasing, and pushing..." -ForegroundColor Cyan

# Stage all modified, new, and deleted files
git add -A

# Temporarily stash uncommitted work
git stash push -m "auto-stash before rebase" | Out-Null

# Fetch the latest state from GitHub
git fetch origin main

# Rebase local commits onto latest remote main
git rebase origin/main

# Restore your work after rebase
git stash pop | Out-Null

# Push your clean, up-to-date branch
git push origin main

Write-Host "✅ Rebase and push completed successfully!" -ForegroundColor Green

---

### ✅ Workflow Permissions Setup

To enable GitHub Actions to open PRs automatically:

1. Go to **Settings → Actions → General**
2. Under **Workflow permissions**, choose:
   - ✅ *Read and write permissions*  
   - ✅ *Allow GitHub Actions to create and approve pull requests*
3. Save the configuration.

---

### 🧾 Notes

- The `GITHUB_TOKEN` is used for secure authentication when pushing or creating PRs.  
- The `ci/metadata-update` branch is temporary and is auto-deleted once merged.  
- To trigger the workflow manually, go to **Actions → Run workflow → main**.

---

### ✨ Result

Once configured:
- Posts are validated automatically on push.  
- Metadata updates are proposed via pull requests.  
- GitHub Pages deploys only after validation succeeds.

> This ensures a clean, reliable, and traceable publishing workflow for Justine Longla T. DevOps Blog 🚀

<!-- SCRIPTS-TABLE:START -->
## Developer Scripts

| Script | Purpose | Example |
|---|---|---|
| Safe-Rebase.ps1 | Safe rebase of feature branch | `./scripts/Safe-Rebase.ps1 -Base main -Branch feature/xyz` |
| Add-Post.ps1 | Scaffold a new blog post | `./scripts/Add-Post.ps1 -Title "Hello"` |
| Generate-Metadata.ps1 | Build/refresh metadata | `./scripts/Generate-Metadata.ps1 -Path ./content/posts` |
| Cut-Release.ps1 | Tag & publish release | `./scripts/Cut-Release.ps1 -Version 1.2.14` |
<!-- SCRIPTS-TABLE:END -->

# Blog Normalize Kit

Use this if your generator outputs flat HTML posts like:
```
docs/jutellane-blogs/posts/2025-10-24-my-article.html
```
This script converts them to GitHub Pages–friendly routes:
```
docs/jutellane-blogs/posts/2025/10/my-article/index.html
```

## Usage
From the repository root:
```powershell
pwsh .\Normalize-BlogOutput.ps1
# or, to purge empty month folders:
pwsh .\Normalize-BlogOutput.ps1 -PurgeOtherMonths
```

Then commit:
```powershell
git add docs/jutellane-blogs
git commit -m "docs(blog): normalize posts for GitHub Pages"
git push
```

## CI Integration
Add this step after your generator in your GitHub Actions workflow:
```yaml
- name: Normalize blog output for Pages
  shell: pwsh
  run: |
    pwsh ./Normalize-BlogOutput.ps1
```
## Reference Checkpoints

### REF-001 — Unified Footer & Homepage Stable

- **Label:** `REF-001`
- **Branch:** `main`
- **Commit:** `73bc504` (JustineLonglaT-Lane Blogs, unified footer & CTA wiring)  
  > Update this hash if your latest commit ID is different.

**What’s stable in this reference:**

- `public/index.html` is the **canonical blog home**:
  - Unified site header with main navigation (`Home`, `All Blog Posts`, `Projects`, `Automation Toolkit`).
  - “Work with Justine” profile section with CTAs:
    - Intro call → `https://justinelonglat-lane.com/booking`
    - Contact → `https://justinelonglat-lane.com/contact`
    - Résumé → `https://justinelonglat-lane.com/resume.pdf`
    - Brochure → `https://justinelonglat-lane.com/#brochure`
  - Hero section and “Latest writing” / “Featured projects & deep dives” cards.

- Branded site footer is **visible and consistent**:
  - Pulled from `src/partials/footer.html`.
  - Shows logo, tagline, and copyright line:
    - `© <year> Justine Longla T. · JustineLonglaT-Lane Consulting. All rights reserved.`
  - Footer navigation links:
    - Main site → `https://justinelonglat-lane.com/`
    - Projects → `https://justinelonglat-lane.com/projects`
    - Deep-dive blog → `https://justinelonglat-lane.com/blog`
    - Contact → `https://justinelonglat-lane.com/contact`
  - Year is auto-updated via `#footer-year` script.

- Header/CTA links are **synced between**:
  - `public/index.html`
  - `src/partials/header.html`

**Why this reference matters**

This checkpoint is a known-good state where:

- DNS + Vercel deployment for `blogs.jutellane.com` is healthy.
- Homepage layout, CTAs, and footer integration are all working in production.
- It is safe to branch from here for:
  - New posts and project pages
  - Layout refinements
  - Automation / tooling changes

**How to roll back to this reference**

If a future change breaks the layout or navigation:

```bash
# View this reference
git show REF-001

# Reset local branch to the reference (destructive)
git checkout main
git reset --hard REF-001

# Or create a new branch from the reference
git checkout -b fix-from-REF-001 REF-001


# JustineLonglaT-Lane Automation Toolkit

A growing collection of small, reliable scripts that keep my static sites,
blog content, and reference documentation in sync.

Each script lives under `scripts/` with a matching description under
`docs/script_descriptions/`.

## Scripts

### 1. Add-Post.ps1
- **Purpose:** Scaffold a new blog post (folder, HTML/MDX/JSON, metadata).
- **Docs:** `docs/script_descriptions/Add-Post.md`

### 2. Find-Post.ps1
- **Purpose:** Quickly search for posts by title, slug, or tags.
- **Docs:** `docs/script_descriptions/Find-Post.md`

### 3. Check-Tags.ps1
- **Purpose:** Validate tags across posts to keep taxonomy clean and avoid duplicates.
- **Docs:** `docs/script_descriptions/Check-Tags.md`

### 4. git-suture.ps1
- **Purpose:** Safely stage, commit, push, and optionally tag all modified files.
- **Docs:** `docs/script_descriptions/Git-Suture.md`

---

## Usage pattern

From the repo root:

```powershell
# Add a new post
pwsh ./scripts/Add-Post.ps1 -Title "My New Deep Dive"

# Find a post by slug fragment
pwsh ./scripts/Find-Post.ps1 -Query "reproducible-environments"

# Check tags across posts
pwsh ./scripts/Check-Tags.ps1

# Suture and tag a reference state
pwsh ./scripts/git-suture.ps1 `
  -Message "style: align hero + logo branding" `
  -Tag "v-hero-branding-ref" `
  -TagMessage "Reference state for hero/logo look"



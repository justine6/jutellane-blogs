# 🧩 Jutellane Blogs CI/CD Workflow
[![Content Status](https://img.shields.io/github/last-commit/justine6/jutellane-blogs/main)](https://github.com/justine6/jutellane-blogs/commits/main)
[![Site](https://img.shields.io/badge/site-live-blue)](https://justine6.github.io/jutellane-blogs/)

[![Build & Deploy](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml/badge.svg?branch=main)](https://github.com/justine6/jutellane-blogs/actions/workflows/blog.yml)
[![Deploy Status](https://img.shields.io/website?url=https%3A%2F%2Fjustine6.github.io%2Fjutellane-blogs&label=Live%20Site)](https://justine6.github.io/jutellane-blogs)

This repository automates the process of fixing, validating, and deploying blog content to GitHub Pages.  
It ensures each post is properly formatted, metadata is up-to-date, and all site artifacts are published automatically.

# Jutellane Blogs · Public Site

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
# Author : Jutellane Solutions DevOps Workflow
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

> This ensures a clean, reliable, and traceable publishing workflow for Jutellane Blogs 🚀

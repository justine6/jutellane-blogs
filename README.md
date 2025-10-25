# 🧩 Jutellane Blogs CI/CD Workflow
[![Content Status](https://img.shields.io/github/last-commit/justine6/jutellane-blogs/main)](https://github.com/justine6/jutellane-blogs/commits/main)
[![Site](https://img.shields.io/badge/site-live-blue)](https://justine6.github.io/jutellane-blogs/)

This repository automates the process of fixing, validating, and deploying blog content to GitHub Pages.  
It ensures each post is properly formatted, metadata is up-to-date, and all site artifacts are published automatically.

---

## ⚙️ CI/CD Workflow Overview

The GitHub Actions workflow is composed of two major jobs:

1. **Fix, Validate, Build** – runs PowerShell scripts to:
   - Fix front matter in posts  
   - Validate post structure and metadata  
   - Regenerate JSON, feed, sitemap, and tag data  
   - Upload the generated artifacts

2. **Deploy to GitHub Pages** – publishes the verified and built site to GitHub Pages automatically once the validation passes.

---

## 🧠 Automated Metadata Updates via Pull Requests

To avoid *non–fast-forward push errors* caused by the workflow pushing updates directly to `main`,  
the process now uses **peter-evans/create-pull-request** to open a Pull Request (PR) for metadata changes instead.

This allows metadata (like `posts.json`, `feed.xml`, `sitemap.xml`, and `tags/`) to be updated safely and reviewed before merging.

### 🔧 Workflow Step (YAML)

Below is the snippet you should use in your `.github/workflows/blog.yml`:

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
      tags/**

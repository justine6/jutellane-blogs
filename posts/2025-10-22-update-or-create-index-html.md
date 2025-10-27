---
title: "From Commit to Publish: A Complete GitHub Pages CI/CD Flow"
date: 2025-10-24
tags: [GitHub Pages, CI/CD, DevOps, PowerShell, Workflow]
---

## Overview

In this guide, we’ll recreate a complete **commit-to-publish pipeline** for a static blog hosted on **GitHub Pages**.  
You’ll learn how to integrate PowerShell validation scripts with a robust GitHub Actions workflow that handles everything from content verification to deployment.

---

## Step 1: Repository Setup

- Enable GitHub Pages under your repository’s **Settings → Pages**.  
- Create a `.github/workflows/blog.yml` file.  
- Set workflow permissions to **Read and write** and enable **PR creation**.

---

## Step 2: Build Workflow Highlights

The workflow runs in three phases:

1. **Fix Front Matter**  
   Ensures all markdown files have proper metadata.
2. **Validate Posts**  
   Runs pre-publish checks via PowerShell.
3. **Generate Metadata and Deploy**  
   Builds feed, sitemap, and tags, then deploys to GitHub Pages.

---

## Step 3: Safe Metadata Updates

Using the **peter-evans/create-pull-request** action prevents non-fast-forward errors and allows safe, reviewable metadata changes.

```yaml
- name: Create metadata update PR
  uses: peter-evans/create-pull-request@v6
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    commit-message: "chore(blog): update generated metadata"
    title: "chore(blog): refresh feeds and tags"
    body: |
      Automated update of posts.json, feed.xml, sitemap.xml, and tags.
    branch: ci/metadata-update
    delete-branch: true
```

---

## Step 4: Deployment

Once validated and merged, **GitHub Pages** automatically deploys the content live.  
No manual uploads, no command-line fuss — just clean, reproducible publishing.

---

## Final Thoughts

This CI/CD setup transforms GitHub Pages into a full publishing platform.  
Every commit becomes a trusted deployment, every merge a verified release.

> “When your pipeline works for you, creativity becomes continuous.”

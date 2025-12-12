# Build & Serve — Safe Local Preview and Content Integrity

This automation helps you **preview, validate, and harden content before deployment**.
It combines local build preview with automated content integrity checks to prevent
broken links, missing pages, and incomplete feeds from reaching production.

---

## What this automation solves

Before deployment, it ensures:

- Internal links inside posts are valid
- Generated HTML pages actually exist
- Tag indexes are present
- RSS feeds include all published posts
- CI blocks regressions automatically

This eliminates an entire class of **silent production failures**.

---

## Included Automations

### 1. Local Build & Preview

Preview your site locally exactly as it will appear in production.

```powershell
npm run build
npm run preview

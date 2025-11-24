---
title: "PowerShell HTML Audit Automation"
description: "Automate the verification and correction of HTML structures using PowerShell, regex, and Node.js for static-site consistency."
tags: [devops, automation, powershell, regex, static-sites, nodejs]
date: 2025-11-12
---

# 🧩 PowerShell HTML Audit Automation

Automate the verification and correction of HTML structures using PowerShell, regex, and Node.js for static-site consistency.  
This documentation is part of the JustineLonglaT-Lane DevOps toolkit.

---

## 💡 Why This Matters

As static websites evolve, inconsistencies in HTML structure can appear — missing containers, misaligned elements, and broken layout classes.  
This script automates auditing and repairs using PowerShell and regular expressions, ensuring structural uniformity across all pages.

---

## ⚙️ Prerequisites

Before running the script, ensure you have:
- PowerShell 7+
- Node.js 18+
- A directory containing `.html` files to audit

Install optional dependencies:
```bash
npm i -D globby fast-glob gray-matter htmlparser2 cheerio slugify
```

---

## 🧠 Step 1 — Audit HTML Containers

Use this PowerShell command to detect `<main class="container">` elements across the site:

```powershell
$files = Get-ChildItem -Recurse -Include *.html -File |
  Where-Object { $_.FullName -notmatch '\node_modules\|\dist\|\.vercel\|\out\' }

Select-String -Path $files.FullName `
  -Pattern '(?is)<main\b(?:(?!>).)*\bclass\s*=\s*["''][^"']*\bcontainer\b' `
  -AllMatches | Measure-Object
```

---

## 🛠 Step 2 — Patch Missing Containers

The following PowerShell script safely adds `class="container"` to any `<main>` tags that are missing it, while creating backups for each file.

(See the full script in the [blog post](https://blogs.justinelonglat-lane.com/posts/2025/11/audit-containers-with-powershell))

---

## 🔁 Step 3 — Verify Results

After running the patch script, re-audit to confirm all pages now contain the required container class:

```powershell
Select-String -Path $files.FullName `
  -Pattern '(?is)<main\b(?:(?!>).)*\bclass\s*=\s*["''][^"']*\bcontainer\b' `
  -AllMatches | Measure-Object
```

---

## 🧩 Step 4 — Regenerate Indexes with Node.js

If using Node for indexing, ensure your imports align with your Node version.

**For Node 22+ (strict ESM):**
```js
import { globby } from "globby";
```

**Older syntax (Node 18 or below):**
```js
import globby from "globby";
```

---

## 🧱 Step 5 — Serve Locally

Preview your static site locally with:
```powershell
pwsh .\scripts\build-serve.ps1
Start-Process http://localhost:8080
```

If you see 404s, ensure your `public/` directory contains an `index.html` and assets under `/assets`.

---

## 📎 Links & Resources

- 🔗 [Full Blog Post](https://blogs.justinelonglat-lane.com/posts/2025/11/audit-containers-with-powershell)
- 🌐 [Main Site](https://justinelonglat-lane.com)
- 📘 [Docs](https://docs.justinelonglat-lane.com)
- 📅 [Booking Page](https://consulting.justinelonglat-lane.com/booking)

---

> “Automation is elegance repeated—where structure meets intent.”  
> — *Justine Longla Tekang (JustineLonglaT-Lane Consulting)*




# tools\Add-Post.ps1

**Category:** Content creation  
**Repo:** `jutellane-blogs` (portable to any static blog)

`Add-Post.ps1` is the main entry point for creating new posts in my blog and projects
ecosystem. Instead of copying old files by hand, I treat new content as a repeatable
operation.

## What this script does

- Prompts for:
  - **Title** – human-readable title for the article.
  - **Slug** – URL-safe slug (e.g. `new-devops-insights`).
  - **Date** – defaults to today, but can be overridden.
  - **Tags** – comma-separated list.
  - **Summary** – short description used in cards and previews.
- Creates a folder at:

  ```text
  posts\YEAR\MM\slug\

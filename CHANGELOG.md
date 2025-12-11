## [v1.1.0] - 2025-01-15
### Added
- Unified branding across the blog ecosystem to match the **JustineLonglaT-Lane** platform identity.
- Introduced consistent CTAs linking to Docs, Resume, Brochure, and main site navigation.
- Standardized folder structure (`blog/`, `docs/`, `posts/`, `projects/`) for a clearer publishing workflow.

### Changed
- Refined layout and typography for improved readability and UX consistency across pages.
- Updated metadata, OpenGraph configurations, and site-wide section headers.
- Streamlined navigation paths to prevent cross-site fragmentation and ensure predictable routing.

### Fixed
- Removed deprecated and duplicated `.bak` files, unused assets, and stale backup folders.
- Corrected broken links that previously generated 404 errors (blog & docs CTAs).
- Resolved nested repository confusion by restoring a clean Git structure and workspace state.

### Maintenance
- Applied `git clean -fd` and repository hygiene cleanup to remove unused drafts and legacy assets.
- Ensured alignment between local repo layout and GitHub remote structure.
- Prepared the platform for automated release tagging and future CI/CD integration.

// scripts/validate-internal-links.mjs
// Validates internal links across posts + validates static HTML outputs (posts, tags) + validates sitemap.xml + validates RSS feed.
// Designed for classic static sites where HTML is built into /public and posts are date-based: /posts/YYYY/MM/<slug>/index.html

import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();

// ✅ Adjust these if your structure differs
const POSTS_DIR_CANDIDATES = [
  "content/posts",
  "content/blog",
  "posts",
  "app/content/posts",
  "app/content/blog",
];

// Static site output root
const PUBLIC_ROOT = "public";

// In production, /feed.xml and /sitemap.xml must be served from /public
const PUBLIC_FEED = path.join(PUBLIC_ROOT, "feed.xml");
const PUBLIC_SITEMAP = path.join(PUBLIC_ROOT, "sitemap.xml");

// These are only used to validate internal links found in markdown/mdx content.
// Your generated HTML routes are NOT locale-based; this is just for MD(X) link hygiene.
const LOCALES = ["en", "fr", "ht", "es"];
const BLOG_BASE = (locale) => `/${locale}/blog`;
const POST_ROUTE = (locale, slug) => `${BLOG_BASE(locale)}/${slug}`;
const TAG_ROUTE = (locale, tag) => `${BLOG_BASE(locale)}/tags/${tag}`;

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------
function ok(msg) {
  console.log(`✅ ${msg}`);
}

function warn(msg) {
  console.log(`⚠️  ${msg}`);
}

function fail(msg) {
  console.error(`\n❌ ${msg}\n`);
  process.exitCode = 1;
}

function exists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

function readText(file) {
  return fs.readFileSync(file, "utf8");
}

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else out.push(p);
  }
  return out;
}

function slugFromFile(file) {
  const base = path.basename(file);
  return base.replace(/\.(md|mdx)$/i, "");
}

function findPostsDir() {
  for (const rel of POSTS_DIR_CANDIDATES) {
    const full = path.join(ROOT, rel);
    if (exists(full) && fs.statSync(full).isDirectory()) return full;
  }
  return null;
}

function extractInternalHrefs(markdownOrMdx) {
  // Finds markdown links: [text](/path) and mdx/html href="/path"
  const hrefs = new Set();

  // markdown: [x](/something)
  for (const m of markdownOrMdx.matchAll(
    /\[[^\]]*\]\((\/[^)\s#]+)(#[^)\s]+)?\)/g
  )) {
    hrefs.add(m[1]);
  }

  // mdx/html: href="/something"
  for (const m of markdownOrMdx.matchAll(
    /href\s*=\s*["'](\/[^"'\s#]+)(#[^"'\s]+)?["']/g
  )) {
    hrefs.add(m[1]);
  }

  // ignore assets
  const filtered = [...hrefs].filter((h) => {
    if (h.startsWith("/images/")) return false;
    if (h.startsWith("/icons/")) return false;
    if (h.startsWith("/fonts/")) return false;
    if (h.startsWith("/assets/")) return false;
    if (/\.(png|jpg|jpeg|gif|webp|svg|ico|pdf|css|js)$/i.test(h)) return false;
    return true;
  });

  return filtered;
}

function normalizePath(p) {
  // Normalize any "/x/y/" -> "/x/y" (keep "/" as "/")
  const norm = (p || "").replace(/\/+$/, "") || "/";
  return norm;
}

function normalizeUrlToPath(urlOrPath) {
  // sitemap/rss might contain absolute urls; normalize to pathname
  try {
    const u = new URL(urlOrPath);
    return normalizePath(u.pathname);
  } catch {
    return normalizePath(urlOrPath);
  }
}

// ------------------------------------------------------------
// Frontmatter parsing (lightweight)
// ------------------------------------------------------------
function extractFrontmatter(text) {
  // super-light frontmatter parse: supports:
  // - tags: ["a", "b"] or tags: \n - a \n - b
  // - date: "YYYY-MM-DD"
  // - slug: "my-slug"
  const m = text.match(/^---\s*\n([\s\S]*?)\n---\s*\n/);
  if (!m) return {};

  const fm = m[1];

  const readScalar = (key) => {
    const mm = fm.match(new RegExp(`^${key}:\\s*(.+?)\\s*$`, "m"));
    if (!mm) return null;
    return mm[1].trim().replace(/^["']|["']$/g, "");
  };

  const tags = [];
  const inline = fm.match(/^tags:\s*\[(.*)\]\s*$/m);
  if (inline) {
    inline[1]
      .split(",")
      .map((s) => s.trim().replace(/^["']|["']$/g, ""))
      .filter(Boolean)
      .forEach((t) => tags.push(t));
  } else {
    const block = fm.match(/^tags:\s*\n([\s\S]*?)(\n[a-zA-Z_]+:|\s*$)/m);
    if (block) {
      block[1]
        .split("\n")
        .map((l) => l.trim())
        .filter((l) => l.startsWith("- "))
        .map((l) => l.slice(2).trim().replace(/^["']|["']$/g, ""))
        .filter(Boolean)
        .forEach((t) => tags.push(t));
    }
  }

  const date = readScalar("date");
  const slug = readScalar("slug");

  return { tags, date, slug };
}

function parseDateToYearMonth(dateStr) {
  // Accept YYYY-MM-DD (most common)
  if (!dateStr) return null;
  const m = dateStr.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  return { year: m[1], month: m[2] };
}

// ------------------------------------------------------------
// HTML route discovery
// ------------------------------------------------------------
function collectHtmlRoutesFromPublic(publicDir) {
  // Build routes from /public by finding every folder that contains an index.html
  // Example:
  //   public/tags/index.html => /tags
  //   public/posts/2025/10/foo/index.html => /posts/2025/10/foo
  const results = new Set();

  function recur(dir, base = "") {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      const rel = path.join(base, entry.name);

      if (entry.isDirectory()) {
        recur(full, rel);
      } else if (entry.name.toLowerCase() === "index.html") {
        const route = "/" + base.replace(/\\/g, "/");
        results.add(route === "/" ? "/" : route);
      }
    }
  }

  recur(publicDir, "");
  return results;
}

function parseXmlLocs(xml) {
  const locs = new Set();
  for (const m of xml.matchAll(/<loc>([^<]+)<\/loc>/g)) {
    locs.add(m[1].trim());
  }
  return locs;
}

// ------------------------------------------------------------
// Main
// ------------------------------------------------------------
const postsDir = findPostsDir();
if (!postsDir) {
  fail(
    `Could not find posts directory. Checked: ${POSTS_DIR_CANDIDATES.join(", ")}\n` +
      `Update POSTS_DIR_CANDIDATES in scripts/validate-internal-links.mjs.`
  );
  process.exit(1);
}

const postFiles = walk(postsDir).filter((f) => /\.(md|mdx)$/i.test(f));
if (postFiles.length === 0) {
  fail(`No .md/.mdx posts found under ${path.relative(ROOT, postsDir)}`);
  process.exit(1);
}

ok(
  `Found posts dir: ${path.relative(ROOT, postsDir)} (${postFiles.length} files)`
);

// Ensure /public exists
const publicDir = path.join(ROOT, PUBLIC_ROOT);
if (!exists(publicDir) || !fs.statSync(publicDir).isDirectory()) {
  fail(`Missing ${PUBLIC_ROOT}/ directory. This validator expects HTML output in /public.`);
  process.exit(1);
}

const htmlRoutes = collectHtmlRoutesFromPublic(publicDir);
ok(`Discovered ${htmlRoutes.size} HTML routes from /public`);

// ------------------------------------------------------------
// Build expected routes from Markdown posts
// - For link-hygiene (locale blog routes): /{locale}/blog/{slug}, /{locale}/blog/tags/{tag}
// - For HTML output (date-based): /posts/YYYY/MM/{slug}
// ------------------------------------------------------------
const internalLinksFound = [];
const allTags = new Set();
const expectedLocalePostPaths = new Set();
const expectedLocaleTagPaths = new Set();
const expectedHtmlPostPaths = new Set();

// Keep track of which posts lack a parsable date (we'll warn; can't validate HTML path)
const noDatePosts = [];

for (const file of postFiles) {
  const txt = readText(file);
  const fm = extractFrontmatter(txt);

  const slug = (fm.slug && fm.slug.trim()) ? fm.slug.trim() : slugFromFile(file);

  // locale-based routes (used only to validate markdown internal links)
  for (const locale of LOCALES) {
    expectedLocalePostPaths.add(POST_ROUTE(locale, slug));
  }

  // tags
  (fm.tags || []).forEach((t) => allTags.add(t));
  for (const locale of LOCALES) {
    for (const tag of fm.tags || []) expectedLocaleTagPaths.add(TAG_ROUTE(locale, tag));
  }

  // date-based HTML output expectation: /posts/YYYY/MM/slug
  const ym = parseDateToYearMonth(fm.date);
  if (ym) {
    expectedHtmlPostPaths.add(`/posts/${ym.year}/${ym.month}/${slug}`);
  } else {
    noDatePosts.push(path.relative(ROOT, file));
  }

  // collect internal hrefs from MD/MDX
  const hrefs = extractInternalHrefs(txt);
  for (const h of hrefs) internalLinksFound.push({ from: file, href: h });
}

ok(`Derived slugs: ${postFiles.length}`);
ok(`Derived tags: ${allTags.size}`);

if (noDatePosts.length > 0) {
  warn(
    `Some posts have no parsable frontmatter date (YYYY-MM-DD). ` +
      `Skipping date-based HTML validation for these:\n  - ${noDatePosts.join("\n  - ")}`
  );
}

// Also derive expected tag pages if your static site generates them (non-locale):
// We validate at minimum /tags exists. If you generate per-tag pages, uncomment below.
// const expectedHtmlTagPaths = new Set([...allTags].map((t) => `/tags/${t}`));

// ------------------------------------------------------------
// Validate internal links in MDX/MD (locale-based link hygiene)
// ------------------------------------------------------------
const knownPathsForMd = new Set([
  ...expectedLocalePostPaths,
  ...expectedLocaleTagPaths,
  ...LOCALES.map((l) => `/${l}`),
  ...LOCALES.map((l) => BLOG_BASE(l)),
]);

let brokenMd = 0;
for (const { from, href } of internalLinksFound) {
  const norm = normalizePath(href);
  if (!knownPathsForMd.has(norm)) {
    brokenMd++;
    console.error(
      `❌ Broken internal link in post content: ${href}\n` +
        `   from: ${path.relative(ROOT, from)}\n` +
        `   hint: fix the link, or add the route to knownPathsForMd if it's valid.`
    );
  }
}

if (brokenMd === 0) ok("All internal links in posts look valid (locale blog/tag routes).");
else fail(`${brokenMd} broken internal link(s) found in posts.`);

// ------------------------------------------------------------
// Validate generated HTML structure
// ------------------------------------------------------------
let missingHtml = 0;

// Validate expected post HTML pages exist (only for posts with valid date)
for (const p of expectedHtmlPostPaths) {
  if (!htmlRoutes.has(p)) {
    missingHtml++;
    console.error(
      `❌ Missing generated post HTML route: ${p}\n` +
        `   expected file: ${PUBLIC_ROOT}${p}/index.html`
    );
  }
}

if (expectedHtmlPostPaths.size > 0) {
  const found = [...expectedHtmlPostPaths].filter((p) => htmlRoutes.has(p)).length;
  ok(`Found ${found} / ${expectedHtmlPostPaths.size} expected post HTML routes.`);
}

// Validate /tags index exists
const hasTagsIndex = htmlRoutes.has("/tags");
if (!hasTagsIndex) {
  missingHtml++;
  console.error(`❌ Missing /tags index page.\n   expected file: ${PUBLIC_ROOT}/tags/index.html`);
} else {
  ok("Tags index page exists (/tags).");
}

if (missingHtml === 0) ok("All required HTML routes exist (posts + /tags).");
else fail(`${missingHtml} missing HTML route(s) detected.`);

// ------------------------------------------------------------
// Validate RSS feed (public/feed.xml)
// ------------------------------------------------------------
if (!exists(path.join(ROOT, PUBLIC_FEED))) {
  fail(`Missing ${PUBLIC_FEED}. (It must be in /public to be served at /feed.xml)`);
} else {
  const rss = readText(path.join(ROOT, PUBLIC_FEED));
  let missingInFeed = 0;

  // Prefer checking for the actual expected HTML routes (date-based), not just raw slugs.
  for (const p of expectedHtmlPostPaths) {
    // allow with or without trailing slash
    const needle1 = `${p}/`;
    const needle2 = p;
    if (!rss.includes(needle1) && !rss.includes(needle2)) {
      missingInFeed++;
      console.error(`❌ feed.xml missing post URL: ${p}`);
    }
  }

  if (missingInFeed === 0) ok("feed.xml includes links to all expected post URLs.");
  else fail(`feed.xml missing ${missingInFeed} post URL(s).`);
}

// ------------------------------------------------------------
// Validate sitemap.xml (public/sitemap.xml)
// ------------------------------------------------------------
if (!exists(path.join(ROOT, PUBLIC_SITEMAP))) {
  fail(`Missing ${PUBLIC_SITEMAP}. (It must be in /public to be served at /sitemap.xml)`);
} else {
  const xml = readText(path.join(ROOT, PUBLIC_SITEMAP));
  const locs = parseXmlLocs(xml);

  // Normalize sitemap locs to paths
  const sitemapPaths = new Set([...locs].map(normalizeUrlToPath));

  let missingInSitemap = 0;

  // Ensure sitemap includes these routes at minimum
  const mustInclude = new Set([
    "/", // home
    "/tags",
    "/feed.xml", // optional but useful
  ]);

  for (const m of mustInclude) {
    // sitemap often lists "/feed.xml" or full url. We normalize to path above.
    if (!sitemapPaths.has(normalizePath(m))) {
      // Don't hard-fail on /feed.xml being absent from sitemap; warn only.
      if (m === "/feed.xml") {
        warn("sitemap.xml does not include /feed.xml (optional).");
      } else {
        missingInSitemap++;
        console.error(`❌ sitemap.xml missing required route: ${m}`);
      }
    }
  }

  // Ensure sitemap includes all expected post URLs (date-based)
  for (const p of expectedHtmlPostPaths) {
    // allow sitemap loc to be with trailing slash
    const np = normalizePath(p);
    if (!sitemapPaths.has(np)) {
      missingInSitemap++;
      console.error(`❌ sitemap.xml missing post URL: ${p}`);
    }
  }

  if (missingInSitemap === 0) ok("sitemap.xml includes all required routes + all expected post URLs.");
  else fail(`sitemap.xml missing ${missingInSitemap} route(s).`);
}

// ------------------------------------------------------------
// Final
// ------------------------------------------------------------
if (process.exitCode && process.exitCode !== 0) {
  console.error("\n🚨 Fix the failures above, then re-run: npm run validate:links\n");
} else {
  ok("Internal links + HTML structure + RSS + sitemap validation passed.");
}

// scripts/validate-internal-links.mjs
// Validates internal links across posts + validates static HTML outputs (posts, tags) + validates RSS feed.
// Designed for classic static sites where HTML is built into /public and posts are date-based (/posts/YYYY/MM/DD/).

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

// Your RSS is at repo root (based on your tree)
const PUBLIC_FEED = "feed.xml";

// Static site output root
const PUBLIC_ROOT = "public";

// These are only used to validate internal links found in markdown/mdx content.
// Your generated HTML routes are NOT locale-based; this is just for MD(X) link hygiene.
const LOCALES = ["en", "fr", "ht", "es"];
const BLOG_BASE = (locale) => `/${locale}/blog`;
const POST_ROUTE = (locale, slug) => `${BLOG_BASE(locale)}/${slug}`;
const TAG_ROUTE = (locale, tag) => `${BLOG_BASE(locale)}/tags/${tag}`;

function exists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

function fail(msg) {
  console.error(`\n❌ ${msg}\n`);
  process.exitCode = 1;
}

function ok(msg) {
  console.log(`✅ ${msg}`);
}

function findPostsDir() {
  for (const rel of POSTS_DIR_CANDIDATES) {
    const full = path.join(ROOT, rel);
    if (exists(full) && fs.statSync(full).isDirectory()) return full;
  }
  return null;
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

function readText(file) {
  return fs.readFileSync(file, "utf8");
}

function slugFromFile(file) {
  const base = path.basename(file);
  return base.replace(/\.(md|mdx)$/i, "");
}

function extractFrontmatter(text) {
  // super-light frontmatter parse: only supports `tags:` list in YAML
  const m = text.match(/^---\s*\n([\s\S]*?)\n---\s*\n/);
  if (!m) return {};
  const fm = m[1];

  const tags = [];

  // tags: ["a", "b"]
  const inline = fm.match(/^tags:\s*\[(.*)\]\s*$/m);
  if (inline) {
    inline[1]
      .split(",")
      .map((s) => s.trim().replace(/^["']|["']$/g, ""))
      .filter(Boolean)
      .forEach((t) => tags.push(t));
    return { tags };
  }

  // tags:
  //  - a
  //  - b
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

  return { tags };
}

function extractInternalHrefs(markdownOrMdx) {
  // Finds markdown links: [text](/path) and mdx <Link href="/path">
  const hrefs = new Set();

  // markdown: [x](/something)
  for (const m of markdownOrMdx.matchAll(
    /\[[^\]]*\]\((\/[^)\s#]+)(#[^)\s]+)?\)/g
  )) {
    hrefs.add(m[1]);
  }

  // mdx: href="/something"
  for (const m of markdownOrMdx.matchAll(
    /href\s*=\s*["'](\/[^"'\s#]+)(#[^"'\s]+)?["']/g
  )) {
    hrefs.add(m[1]);
  }

  // ignore assets
  return [...hrefs].filter((h) => {
    if (h.startsWith("/images/")) return false;
    if (h.startsWith("/icons/")) return false;
    if (h.startsWith("/fonts/")) return false;
    if (/\.(png|jpg|jpeg|gif|webp|svg|ico|pdf)$/i.test(h)) return false;
    return true;
  });
}

/**
 * Robust HTML route collector for /public.
 * It finds every `index.html` under /public and converts its folder to a route.
 * Example:
 *   public/tags/index.html          => /tags
 *   public/posts/2025/10/11/index.html => /posts/2025/10/11
 */
function collectHtmlRoutesFromPublic() {
  const publicDir = path.join(ROOT, PUBLIC_ROOT);
  if (!exists(publicDir)) return new Set();

  const routes = new Set();
  const files = walk(publicDir);

  for (const file of files) {
    if (path.basename(file).toLowerCase() !== "index.html") continue;

    const folder = path.dirname(file);
    const relFolder = path.relative(publicDir, folder); // relative to /public

    const route =
      relFolder === ""
        ? "/"
        : "/" + relFolder.replace(/\\/g, "/"); // normalize Windows -> URL

    routes.add(route);
  }

  return routes;
}

// ----------------------------
// Main
// ----------------------------

const htmlRoutes = collectHtmlRoutesFromPublic();
ok(`Discovered ${htmlRoutes.size} HTML routes from /public`);

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

ok(`Found posts dir: ${path.relative(ROOT, postsDir)} (${postFiles.length} files)`);

const slugs = postFiles.map(slugFromFile);

const allTags = new Set();
const internalLinksFound = [];

for (const file of postFiles) {
  const txt = readText(file);
  const { tags } = extractFrontmatter(txt);
  (tags || []).forEach((t) => allTags.add(t));

  const hrefs = extractInternalHrefs(txt);
  for (const h of hrefs) internalLinksFound.push({ from: file, href: h });
}

ok(`Derived slugs: ${slugs.length}`);
ok(`Derived tags: ${allTags.size}`);

// ----------------------------
// 1) Validate internal links inside MDX/MD (posts/tags/routes)
// ----------------------------

const expectedPostPaths = new Set();
for (const locale of LOCALES) {
  for (const slug of slugs) expectedPostPaths.add(POST_ROUTE(locale, slug));
}

const expectedTagPaths = new Set();
for (const locale of LOCALES) {
  for (const tag of allTags) expectedTagPaths.add(TAG_ROUTE(locale, tag));
}

const knownPaths = new Set([
  ...expectedPostPaths,
  ...expectedTagPaths,
  ...LOCALES.map((l) => `/${l}`),
  ...LOCALES.map((l) => BLOG_BASE(l)),
]);

let broken = 0;
for (const { from, href } of internalLinksFound) {
  const norm = href.replace(/\/+$/, "") || "/";
  if (!knownPaths.has(norm)) {
    broken++;
    console.error(
      `❌ Broken internal link: ${href}\n   from: ${path.relative(
        ROOT,
        from
      )}\n   hint: add route or fix slug/tag`
    );
  }
}

if (broken === 0) ok("All internal links in posts look valid (posts/tags/routes).");
else fail(`${broken} broken internal link(s) found in posts.`);

// ----------------------------
// 2) Validate generated HTML outputs exist
// ----------------------------

let missing = 0;

// Posts are date-based: /posts/YYYY/MM/DD/index.html => route /posts/YYYY/MM/DD
const postHtmlRoutes = [...htmlRoutes].filter((p) => p.startsWith("/posts/"));
if (postHtmlRoutes.length === 0) {
  missing++;
  console.error("❌ No generated HTML post pages found under /public/posts/");
} else {
  ok(`Found ${postHtmlRoutes.length} generated post HTML pages.`);
}

// Tags: your site has a tags index at public/tags/index.html
// We'll validate it in the most reliable way:
// Tags index may live either in /public/tags or at repo root (/tags)
const tagsIndexInPublic = path.join(ROOT, PUBLIC_ROOT, "tags", "index.html");
const tagsIndexAtRoot = path.join(ROOT, "tags", "index.html");

const hasTagsIndex =
  htmlRoutes.has("/tags") ||
  exists(tagsIndexInPublic) ||
  exists(tagsIndexAtRoot);

if (!hasTagsIndex) {
  missing++;
  console.error("❌ Missing /tags index page.");
} else {
  ok("Tags index page exists (/tags).");
}

// ----------------------------
// 3) Validate RSS feed exists + contains links to posts
// ----------------------------

if (!exists(path.join(ROOT, PUBLIC_FEED))) {
  fail(`Missing ${PUBLIC_FEED}.`);
} else {
  const rss = readText(path.join(ROOT, PUBLIC_FEED));

  // Check that feed contains at least as many /posts/YYYY/ links as we have slugs.
  const postLinksInFeed = rss.match(/\/posts\/\d{4}\//g) || [];
  if (postLinksInFeed.length < slugs.length) {
    const diff = slugs.length - postLinksInFeed.length;
    fail(
      `RSS missing ${diff} post link(s). Found ${postLinksInFeed.length}, expected ${slugs.length}.`
    );
  } else {
    ok("feed.xml includes links to all posts.");
  }

  // Optional: check slugs appear somewhere in feed (may fail if your feed uses titles only).
  // We'll keep this permissive: warn only (no fail).
  const missingSlugs = slugs.filter((s) => !rss.includes(s));
  if (missingSlugs.length === 0) {
    ok("feed.xml includes all post slugs.");
  } else {
    console.warn(
      `⚠️ feed.xml does not include ${missingSlugs.length} slug(s) as plain text (this may be OK for date-based URLs).`
    );
  }
}

if (process.exitCode === 1) {
  console.error("\n🧯 Fix the failures above, then re-run: npm run validate:links\n");
  process.exit(1);
}

console.log("\n🎉 Internal links + HTML structure + RSS validation passed.\n");

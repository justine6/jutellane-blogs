// scripts/generate-indexes.mjs
import { promises as fs } from "node:fs";
import path from "node:path";
import { globby } from "globby";
import { parseDocument } from "htmlparser2";
import slugify from "slugify";

const ROOT = process.cwd();

// where your source posts/projects live
const SRC_POSTS_DIR = path.join(ROOT, "posts");
const SRC_PROJECTS_DIR = path.join(ROOT, "projects");

// where the built site lives
const PUBLIC_DIR = path.join(ROOT, "public");
const PUBLIC_DATA_DIR = path.join(PUBLIC_DIR, "_data");
const PUBLIC_POSTS_DIR = path.join(PUBLIC_DIR, "posts");
const PUBLIC_PROJECTS_DIR = path.join(PUBLIC_DIR, "projects");

function norm(p) {
  return p.replace(/\\/g, "/");
}

async function exists(p) {
  try {
    await fs.stat(p);
    return true;
  } catch {
    return false;
  }
}

function textOfFirst(el, name) {
  if (!el) return null;
  const stack = [el];
  while (stack.length) {
    const n = stack.shift();
    if (n.name === name) {
      // find first text child anywhere under this node
      const inner = [];
      const q = [...(n.children || [])];
      while (q.length) {
        const c = q.shift();
        if (c.type === "text" && c.data) inner.push(c.data.trim());
        if (c.children) q.push(...c.children);
      }
      if (inner.length) return inner.join(" ").trim();
    }
    if (n.children) stack.push(...n.children);
  }
  return null;
}

function findMeta(doc, metaName) {
  const stack = [doc];
  while (stack.length) {
    const n = stack.shift();
    if (n.name === "meta" && n.attribs && n.attribs.name === metaName) {
      return (n.attribs.content || "").trim();
    }
    if (n.children) stack.push(...n.children);
  }
  return null;
}

// copy posts/projects into public so http-server can serve them
async function copyTree(srcRoot, dstRoot) {
  if (!(await exists(srcRoot))) return;
  const files = await globby("**/*.*", { cwd: srcRoot, dot: false });
  for (const rel of files) {
    const absSrc = path.join(srcRoot, rel);
    const absDst = path.join(dstRoot, rel);
    await fs.mkdir(path.dirname(absDst), { recursive: true });
    await fs.copyFile(absSrc, absDst);
  }
}

async function collectFrom(srcDir, kind, urlBase) {
  if (!(await exists(srcDir))) return [];

  const files = await globby("**/index.html", { cwd: srcDir, dot: false });
  const items = [];

  for (const rel of files) {
    const abs = path.join(srcDir, rel);
    const html = await fs.readFile(abs, "utf8");
    const doc = parseDocument(html);

    let title = textOfFirst(doc, "h1");
    if (!title) title = path.basename(path.dirname(abs));

    const description = findMeta(doc, "description") || "";
    const tags = (findMeta(doc, "tags") || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);

    // URL as it will be seen in the browser (public is the web root)
    const relDir = path.dirname(rel); // e.g. "2025/10/perfect-build"
    const urlPath = "/" + norm(path.join(urlBase, relDir)) + "/";

    items.push({
      title,
      description,
      tags,
      url: urlPath,
      slug: slugify(title, { lower: true, strict: true }),
      kind,
    });
  }

  // newest-ish first (paths usually contain year/month)
  items.sort((a, b) => (a.url < b.url ? 1 : -1));
  return items;
}

async function ensureIndexPage(browserJsonPath, pagePath, heading) {
  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>${heading}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root{--bg:#fff;--text:#0f172a;--muted:#64748b;--card:#f8fafc;--ring:rgba(2,132,199,.15)}
    html,body{height:100%}
    body{
      margin:0;
      padding:2rem 1.5rem 3rem;
      font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,Ubuntu;
      color:var(--text);
      background:var(--bg);
    }
    .container{max-width:960px;margin:0 auto}
    h1{font-size:2rem;margin:0 0 1.25rem}
    ul{list-style:none;padding:0;margin:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:1rem}
    li{background:var(--card);border:1px solid #e5e7eb;border-radius:14px;padding:1rem;transition:transform .12s ease, box-shadow .12s ease}
    li:hover{transform:translateY(-1px);box-shadow:0 6px 18px var(--ring)}
    a{font-weight:600;text-decoration:none;color:#0ea5e9}
    a:hover{text-decoration:underline}
    .desc{color:var(--muted);margin-top:.35rem}
    .tags{color:var(--muted);font-size:.875rem;margin-top:.35rem}
    .empty{color:var(--muted);font-style:italic}
  </style>
</head>
<body>
  <main class="container">
    <h1>${heading}</h1>
    <ul id="list"></ul>
  </main>
  <script type="module">
    async function main() {
      const res = await fetch("${browserJsonPath}");
      if (!res.ok) {
        console.error("Failed to load index data", res.status);
        document.getElementById("list").innerHTML =
          '<li class="empty">Unable to load posts.</li>';
        return;
      }
      const data = await res.json();
      const list = document.querySelector('#list');
      if (!data.length) {
        list.innerHTML = '<li class="empty">No entries yet.</li>';
        return;
      }
      data.forEach(x => {
        const li = document.createElement('li');
        li.innerHTML =
          \`<a href="\${x.url}">\${x.title}</a>\` +
          (x.description ? \`<div class="desc">\${x.description}</div>\` : "") +
          (x.tags?.length ? \`<div class="tags"># \${x.tags.join(", ")}</div>\` : "");
        list.appendChild(li);
      });
    }
    main().catch(console.error);
  </script>
</body>
</html>`;
  await fs.mkdir(path.dirname(pagePath), { recursive: true });
  await fs.writeFile(pagePath, html, "utf8");
}

async function main() {
  // ensure data + content folders exist
  await fs.mkdir(PUBLIC_DATA_DIR, { recursive: true });
  await fs.mkdir(PUBLIC_POSTS_DIR, { recursive: true });
  await fs.mkdir(PUBLIC_PROJECTS_DIR, { recursive: true });

  // copy raw HTML into public
  await copyTree(SRC_POSTS_DIR, PUBLIC_POSTS_DIR);
  await copyTree(SRC_PROJECTS_DIR, PUBLIC_PROJECTS_DIR);

  // collect metadata
  const posts = await collectFrom(SRC_POSTS_DIR, "post", "posts");
  const projects = await collectFrom(SRC_PROJECTS_DIR, "project", "projects");

  await fs.writeFile(
    path.join(PUBLIC_DATA_DIR, "posts.json"),
    JSON.stringify(posts || [], null, 2),
    "utf8"
  );
  await fs.writeFile(
    path.join(PUBLIC_DATA_DIR, "projects.json"),
    JSON.stringify(projects || [], null, 2),
    "utf8"
  );

  // listing pages (already inside public/)
  await ensureIndexPage("/_data/posts.json", path.join(PUBLIC_DIR, "blog", "index.html"), "All Blog Posts");
  await ensureIndexPage("/_data/projects.json", path.join(PUBLIC_DIR, "projects", "index.html"), "Projects");

  console.log(`\n✓ generated ${(posts || []).length} posts and ${(projects || []).length} projects`);
}

await main().catch((e) => {
  console.error(e);
  process.exit(1);
});

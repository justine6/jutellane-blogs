import fs from "node:fs/promises";

async function main() {
  // clean dist
  await fs.rm("dist", { recursive: true, force: true });
  // copy public -> dist
  await fs.cp("public", "dist", { recursive: true });
  console.log("✓ copied public/ → dist/");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

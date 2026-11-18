import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, "..");
const siteDir = path.join(rootDir, "site");

const COMMERCIAL_PAGES = new Set([
  "index.html",
  "pt-BR/index.html",
  "developers/index.html",
  "pt-BR/developers/index.html",
  "pricing/index.html",
  "pt-BR/pricing/index.html",
]);

function walkHtml(dir, base = "") {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? `${base}/${entry.name}` : entry.name;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkHtml(full, rel));
    } else if (entry.isFile() && entry.name.endsWith(".html")) {
      results.push(rel);
    }
  }
  return results.sort();
}

function stripTagsAndEntities(html) {
  return html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<[^>]+>/g, " ");
}

function decodeBasicEntities(str) {
  return str
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function extractIds(html) {
  const ids = new Set();
  const re = /\bid\s*=\s*"([^"]+)"/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    ids.add(m[1]);
  }
  return ids;
}

const errors = [];
const htmlFiles = walkHtml(siteDir);
const idCache = new Map();

for (const rel of htmlFiles) {
  const full = path.join(siteDir, rel);
  idCache.set(rel, extractIds(fs.readFileSync(full, "utf8")));
}

const sitemapPath = path.join(siteDir, "sitemap.xml");
const sitemapContent = fs.existsSync(sitemapPath) ? fs.readFileSync(sitemapPath, "utf8") : "";
if (!sitemapContent) {
  errors.push("Missing site/sitemap.xml");
}

const ogImageFile = path.join(siteDir, "assets/images/og-mcnexus.png");
if (!fs.existsSync(ogImageFile)) {
  errors.push("Missing site/assets/images/og-mcnexus.png");
}

for (const rel of htmlFiles) {
  const full = path.join(siteDir, rel);
  const html = fs.readFileSync(full, "utf8");
  const visible = stripTagsAndEntities(html);
  const isCommercial = COMMERCIAL_PAGES.has(rel);
  const is404 = rel === "404.html";

  // 1. Forbidden dashes in visible text
  if (visible.includes("—") || visible.includes("–")) {
    errors.push(`[${rel}] Contains forbidden em-dash (—) or en-dash (–) in visible text`);
  }

  // 2. Forbidden legacy profile terms or legacy anchors
  const forbiddenPatterns = [
    /\bPerfil\s+[AB]\b/i,
    /\bProfile\s+[AB]\b/i,
    /#perfil-b-standalone/i,
    /#profile-b-standalone/i,
    /DEVELOPERS\.md#/i,
  ];
  for (const pat of forbiddenPatterns) {
    if (pat.test(html)) {
      errors.push(`[${rel}] Contains forbidden pattern: ${pat}`);
    }
  }

  // 3. Email scoping rules
  if (isCommercial) {
    if (html.includes("hello@mcnexus.app")) {
      errors.push(`[${rel}] Commercial page must NOT contain hello@mcnexus.app`);
    }
    if (!html.includes("magno@mcnexus.app")) {
      errors.push(`[${rel}] Commercial page missing magno@mcnexus.app`);
    }
  } else {
    if (html.includes("magno@mcnexus.app")) {
      errors.push(`[${rel}] Non-commercial page must NOT contain magno@mcnexus.app`);
    }
  }

  // 4. mailto wrapped in <!--email_off-->
  const mailtoMatches = [...html.matchAll(/<a\b[^>]*href="mailto:[^"]+"[^>]*>[\s\S]*?<\/a>/gi)];
  for (const m of mailtoMatches) {
    const idx = m.index ?? 0;
    const before = html.slice(Math.max(0, idx - 40), idx);
    const after = html.slice(idx + m[0].length, idx + m[0].length + 40);
    if (!before.includes("<!--email_off-->") || !after.includes("<!--/email_off-->")) {
      errors.push(`[${rel}] mailto link not wrapped in <!--email_off-->...<!--/email_off-->: ${m[0]}`);
    }
  }

  // 5. Meta description length (50..160) & og:image
  const descMatch = html.match(/<meta\s+name="description"\s+content="([^"]*)"/i);
  if (!descMatch) {
    errors.push(`[${rel}] Missing <meta name="description">`);
  } else {
    const descLen = decodeBasicEntities(descMatch[1]).length;
    if (descLen < 50 || descLen > 160) {
      errors.push(`[${rel}] Meta description length ${descLen} out of range (50..160)`);
    }
  }

  if (!html.includes('property="og:image"') || !html.includes("og-mcnexus.png")) {
    errors.push(`[${rel}] Missing og:image referencing og-mcnexus.png`);
  }

  // 6. Logo width/height attributes
  const logoTags = [...html.matchAll(/<img\b[^>]*nexus-logo\.svg[^>]*>/gi)];
  for (const m of logoTags) {
    if (!/\bwidth=/.test(m[0]) || !/\bheight=/.test(m[0])) {
      errors.push(`[${rel}] nexus-logo.svg <img> missing width/height: ${m[0]}`);
    }
  }

  // 7. __SITE_VERSION__ preserved for deploy-site.yml
  if (!html.includes("__SITE_VERSION__")) {
    errors.push(`[${rel}] Missing __SITE_VERSION__ cache-buster token`);
  }

  // 8. Sitemap coverage for non-404 pages
  if (!is404 && sitemapContent) {
    const urlPath = rel === "index.html" ? "/" : `/${rel.replace(/\/index\.html$/, "/")}`;
    const expectedLoc = `<loc>https://mcnexus.app${urlPath}</loc>`;
    if (!sitemapContent.includes(expectedLoc)) {
      errors.push(`[${rel}] Missing in sitemap.xml: ${expectedLoc}`);
    }
  }

  // 9. Internal links & fragment resolution
  const hrefMatches = [...html.matchAll(/\bhref="([^"]+)"/gi)];
  for (const m of hrefMatches) {
    const rawHref = m[1];
    if (
      rawHref.startsWith("http://") ||
      rawHref.startsWith("https://") ||
      rawHref.startsWith("mailto:") ||
      rawHref.startsWith("tel:")
    ) {
      continue;
    }

    const cleanHref = rawHref.split("?")[0];
    const [pathnamePart, fragment] = cleanHref.split("#");
    let targetRel = rel;

    if (pathnamePart) {
      const normalized = pathnamePart.startsWith("/") ? pathnamePart.slice(1) : pathnamePart;
      if (normalized === "") {
        targetRel = "index.html";
      } else {
        const directPath = path.join(siteDir, normalized);
        const indexPath = path.join(siteDir, normalized, "index.html");
        if (fs.existsSync(directPath) && fs.statSync(directPath).isFile()) {
          targetRel = normalized;
        } else if (fs.existsSync(indexPath) && fs.statSync(indexPath).isFile()) {
          targetRel = normalized.replace(/\/$/, "") + "/index.html";
        } else {
          errors.push(`[${rel}] Broken internal href: ${rawHref}`);
          continue;
        }
      }
    }

    if (fragment) {
      const targetIds = idCache.get(targetRel);
      if (!targetIds || !targetIds.has(fragment)) {
        errors.push(`[${rel}] Broken fragment #${fragment} in href="${rawHref}" (target: ${targetRel})`);
      }
    }
  }

  // 10. Internal asset src checks
  const srcMatches = [...html.matchAll(/\bsrc="([^"]+)"/gi)];
  for (const m of srcMatches) {
    const rawSrc = m[1];
    if (rawSrc.startsWith("http://") || rawSrc.startsWith("https://") || rawSrc.startsWith("data:")) {
      continue;
    }
    const cleanSrc = rawSrc.split("?")[0].replace(/^\//, "");
    const assetPath = path.join(siteDir, cleanSrc);
    if (!fs.existsSync(assetPath)) {
      errors.push(`[${rel}] Broken asset src: ${rawSrc}`);
    }
  }
}

if (errors.length > 0) {
  console.error(`Validation failed with ${errors.length} error(s):\n`);
  for (const err of errors) {
    console.error(`  - ${err}`);
  }
  process.exit(1);
}

console.log(`Validated ${htmlFiles.length} HTML files and sitemap.xml with 0 errors.`);

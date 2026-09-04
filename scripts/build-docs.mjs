import { copyFile, mkdir, readFile, writeFile, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const siteDir = path.join(rootDir, "site");
const siteImagesDir = path.join(siteDir, "assets/images");
const repoImagesDir = path.join(rootDir, "images");

const docsConfig = [
  {
    key: "discovery",
    slug: "docs/discovery",
    title: { en: "Integrated Plugins · Discovery", pt: "Plugins Integrados · Discovery" },
    description: {
      en: "Catalog of OFX plugins integrated with the Nexus ecosystem.",
      pt: "Catálogo de plugins OFX integrados ao ecossistema Nexus.",
    },
    source: { en: "docs/DISCOVERY.md", pt: "pt-BR/docs/DISCOVERY.md" },
  },
  {
    key: "user-guide",
    slug: "docs/user-guide",
    title: { en: "User Guide · MCNexus", pt: "Guia de Operação · MCNexus" },
    description: {
      en: "Complete guide for installing, activating, and managing plugins in MCNexus.",
      pt: "Guia completo de instalação, ativação e gerenciamento de plugins no MCNexus.",
    },
    source: { en: "docs/USER_GUIDE.md", pt: "pt-BR/docs/USER_GUIDE.md" },
  },
  {
    key: "developers",
    slug: "docs/developers",
    title: { en: "Developers · Integration & Distribution", pt: "Desenvolvedores · Integração e Distribuição" },
    description: {
      en: "Technical requirements and distribution architecture for developers integrating with Nexus.",
      pt: "Requisitos técnicos e arquitetura de distribuição para desenvolvedores que integram o Nexus.",
    },
    source: { en: "docs/DEVELOPERS.md", pt: "pt-BR/docs/DEVELOPERS.md" },
  },
  {
    key: "roadmap",
    slug: "docs/roadmap",
    title: { en: "Roadmap · MCNexus", pt: "Roadmap · MCNexus" },
    description: {
      en: "Feature status, operational model, and architectural roadmap.",
      pt: "Status dos recursos, modelo operacional e roadmap arquitetural.",
    },
    source: { en: "docs/ROADMAP.md", pt: "pt-BR/docs/ROADMAP.md" },
  },
  {
    key: "continuity",
    slug: "docs/continuity",
    title: { en: "Continuity & Recovery · MCNexus", pt: "Continuidade e Recuperação · MCNexus" },
    description: {
      en: "What happens to a developer's customers if Nexus is interrupted, wound down, or no longer operated.",
      pt: "O que acontece com os clientes de um desenvolvedor se o Nexus for interrompido, encerrado ou deixar de ser operado.",
    },
    source: { en: "docs/CONTINUITY.md", pt: "pt-BR/docs/CONTINUITY.md" },
  },
  {
    key: "faq",
    slug: "docs/faq",
    title: { en: "Frequently Asked Questions · MCNexus", pt: "Perguntas Frequentes · MCNexus" },
    description: {
      en: "Common questions about licenses, activations, platforms, and compatibility.",
      pt: "Dúvidas frequentes sobre licenças, ativações, plataformas e compatibilidade.",
    },
    source: { en: "docs/FAQ.md", pt: "pt-BR/docs/FAQ.md" },
  },
  {
    key: "tenant-legal",
    slug: "docs/tenant-legal",
    title: { en: "Tenant Legal Guide · MCNexus", pt: "Guia Legal para Tenants · MCNexus" },
    description: {
      en: "Legal and compliance framework for Nexus publishers.",
      pt: "Diretrizes legais e de conformidade para publishers do Nexus.",
    },
    source: { en: "docs/TENANT_LEGAL_GUIDE.md", pt: "pt-BR/docs/TENANT_LEGAL_GUIDE.md" },
  },
  {
    key: "terms",
    slug: "terms",
    title: { en: "Terms of Service · MCNexus", pt: "Termos de Uso · MCNexus" },
    description: {
      en: "Terms and conditions for using the MCNexus application and platform.",
      pt: "Termos e condições de uso do aplicativo e da plataforma MCNexus.",
    },
    source: { en: "TERMS.md", pt: "pt-BR/TERMS.md" },
  },
  {
    key: "privacy",
    slug: "privacy",
    title: { en: "Privacy Policy · MCNexus", pt: "Política de Privacidade · MCNexus" },
    description: {
      en: "Privacy practices and data handling for MCNexus.",
      pt: "Práticas de privacidade e tratamento de dados do MCNexus.",
    },
    source: { en: "PRIVACY.md", pt: "pt-BR/PRIVACY.md" },
  },
  {
    key: "security",
    slug: "security",
    title: { en: "Security Policy · MCNexus", pt: "Política de Segurança · MCNexus" },
    description: {
      en: "Security policy and vulnerability reporting instructions.",
      pt: "Política de segurança e instruções para reporte de vulnerabilidades.",
    },
    source: { en: "SECURITY.md", pt: "SECURITY.md" },
  },
  {
    key: "license",
    slug: "license",
    title: { en: "License · MCNexus", pt: "Licença · MCNexus" },
    description: {
      en: "Source-available license and terms for MCNexus.",
      pt: "Termos e licença source-available do MCNexus.",
    },
    source: { en: "LICENSE.md", pt: "LICENSE.md" },
  },
];

const fileToSlugMap = {
  "discovery.md": "docs/discovery",
  "user_guide.md": "docs/user-guide",
  "developers.md": "docs/developers",
  "roadmap.md": "docs/roadmap",
  "continuity.md": "docs/continuity",
  "faq.md": "docs/faq",
  "tenant_legal_guide.md": "docs/tenant-legal",
  "terms.md": "terms",
  "privacy.md": "privacy",
  "security.md": "security",
  "license.md": "license",
  "readme.md": "",
};

const navigationTabs = {
  en: [
    { label: "Discovery", href: "/docs/discovery/" },
    { label: "User Guide", href: "/docs/user-guide/" },
    { label: "Developers", href: "/docs/developers/" },
    { label: "Roadmap", href: "/docs/roadmap/" },
    { label: "Continuity", href: "/docs/continuity/" },
    { label: "FAQ", href: "/docs/faq/" },
    { label: "Tenant Legal", href: "/docs/tenant-legal/" },
    { label: "Terms", href: "/terms/" },
    { label: "Privacy", href: "/privacy/" },
    { label: "Security", href: "/security/" },
    { label: "License", href: "/license/" },
  ],
  pt: [
    { label: "Discovery", href: "/pt-BR/docs/discovery/" },
    { label: "Guia de Operação", href: "/pt-BR/docs/user-guide/" },
    { label: "Desenvolvedores", href: "/pt-BR/docs/developers/" },
    { label: "Roadmap", href: "/pt-BR/docs/roadmap/" },
    { label: "Continuidade", href: "/pt-BR/docs/continuity/" },
    { label: "FAQ", href: "/pt-BR/docs/faq/" },
    { label: "Guia Legal", href: "/pt-BR/docs/tenant-legal/" },
    { label: "Termos", href: "/pt-BR/terms/" },
    { label: "Privacidade", href: "/pt-BR/privacy/" },
    { label: "Segurança", href: "/pt-BR/security/" },
    { label: "Licença", href: "/pt-BR/license/" },
  ],
};

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[char]);
}

function parseMarkdown(md, locale) {
  const lines = md.replace(/\r\n/g, "\n").split("\n");
  const output = [];
  let inCode = false;
  let codeLang = "";
  let codeBuffer = [];
  let inList = false;
  let listType = ""; // 'ul' or 'ol'
  let listItemBuffer = []; // accumulates continuation lines for current list item
  let inTable = false;
  let tableRows = [];
  let inBlockquote = false;
  let blockquoteLines = [];
  let paragraphBuffer = [];

  function flushParagraph() {
    if (paragraphBuffer.length > 0) {
      const fullText = paragraphBuffer.join(" ");
      output.push(`<p>${parseInline(fullText, locale)}</p>`);
      paragraphBuffer = [];
    }
  }

  function flushListItem() {
    if (listItemBuffer.length > 0) {
      let fullText = listItemBuffer.join(" ");
      // Convert GFM task list checkboxes
      fullText = fullText.replace(/^\[x\]\s*/i, '<span class="task-done" aria-label="done">✓</span> ');
      fullText = fullText.replace(/^\[ \]\s*/, '<span class="task-todo" aria-label="todo">○</span> ');
      output.push(`  <li>${parseInline(fullText, locale)}</li>`);
      listItemBuffer = [];
    }
  }

  function flushList() {
    flushListItem();
    if (inList) {
      output.push(`</${listType}>`);
      inList = false;
      listType = "";
    }
  }

  function flushBlockquote() {
    if (inBlockquote) {
      const content = parseInline(blockquoteLines.join(" "), locale);
      output.push(`<blockquote><p>${content}</p></blockquote>`);
      inBlockquote = false;
      blockquoteLines = [];
    }
  }

  function flushTable() {
    if (inTable) {
      if (tableRows.length > 0) {
        let html = "<table>\n";
        // Header
        const headerCols = tableRows[0];
        html += "  <thead>\n    <tr>\n";
        for (const col of headerCols) {
          html += `      <th>${parseInline(col.trim(), locale)}</th>\n`;
        }
        html += "    </tr>\n  </thead>\n  <tbody>\n";
        // Body
        for (let i = 1; i < tableRows.length; i++) {
          html += "    <tr>\n";
          for (const col of tableRows[i]) {
            html += `      <td>${parseInline(col.trim(), locale)}</td>\n`;
          }
          html += "    </tr>\n";
        }
        html += "  </tbody>\n</table>";
        output.push(html);
      }
      inTable = false;
      tableRows = [];
    }
  }

  function parseInline(text, loc) {
    let res = text;

    // Escaped HTML checks: preserve existing safe tags (table, img, etc) or escape raw chars
    // Replace raw image paths in HTML
    res = res.replace(/src=["'](?:\.\.\/)+images\/([^"']+)["']/g, 'src="/assets/images/$1"');
    res = res.replace(/src=["']images\/([^"']+)["']/g, 'src="/assets/images/$1"');

    // Inline code: `code`
    res = res.replace(/`([^`]+)`/g, (_m, code) => `<code>${escapeHtml(code)}</code>`);

    // Bold & italic: ***text***, **text**, *text*
    res = res.replace(/\*\*\*([^*]+)\*\*\*/g, '<strong><em>$1</em></strong>');
    res = res.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    res = res.replace(/\*([^*]+)\*/g, '<em>$1</em>');

    // Markdown images: ![alt](src)
    res = res.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_m, alt, src) => {
      let imgSrc = src.trim();
      imgSrc = imgSrc.replace(/^(?:\.\.\/)+images\//, '/assets/images/');
      imgSrc = imgSrc.replace(/^images\//, '/assets/images/');
      return `<img src="${imgSrc}" alt="${escapeHtml(alt)}" loading="lazy" decoding="async">`;
    });

    // Markdown links: [text](url)
    res = res.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, linkText, url) => {
      let href = url.trim();

      // External link
      if (/^https?:\/\//i.test(href)) {
        const ghDocMatch = href.match(/^https:\/\/github\.com\/ciqueira\/MCNexus\/blob\/main\/(?:pt-BR\/)?(?:docs\/)?([a-zA-Z0-9_-]+\.md)/i);
        if (ghDocMatch) {
          const fn = ghDocMatch[1].toLowerCase();
          if (fileToSlugMap[fn] !== undefined) {
            const targetLoc = href.includes("/pt-BR/") ? "pt" : "en";
            const slug = fileToSlugMap[fn];
            const targetUrl = targetLoc === "pt" ? (slug ? `/pt-BR/${slug}/` : "/pt-BR/") : (slug ? `/${slug}/` : "/");
            return `<a href="${targetUrl}">${linkText}</a>`;
          }
        }
        return `<a href="${href}" target="_blank" rel="noopener noreferrer">${linkText}</a>`;
      }

      // Hash or mailto
      if (href.startsWith("#") || href.startsWith("mailto:")) {
        return `<a href="${href}">${linkText}</a>`;
      }

      // Internal markdown link
      const cleanUrl = href.split("?")[0].split("#")[0];
      const hash = href.includes("#") ? `#${href.split("#")[1]}` : "";
      const baseFn = path.basename(cleanUrl).toLowerCase();

      if (fileToSlugMap[baseFn] !== undefined) {
        let targetLoc = loc;
        if (cleanUrl.includes("pt-BR") || linkText.trim().toLowerCase() === "português") {
          targetLoc = "pt";
        } else if (cleanUrl.startsWith("../../docs") || cleanUrl.startsWith("../README") || cleanUrl.startsWith("docs/") && loc === "en" || linkText.trim().toLowerCase() === "english") {
          targetLoc = "en";
        }

        const slug = fileToSlugMap[baseFn];
        const targetUrl = targetLoc === "pt" ? (slug ? `/pt-BR/${slug}/${hash}` : `/pt-BR/${hash}`) : (slug ? `/${slug}/${hash}` : `/${hash}`);
        return `<a href="${targetUrl}">${linkText}</a>`;
      }

      return `<a href="${href}">${linkText}</a>`;
    });

    return res;
  }

  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    const rawLine = lines[lineIndex];
    const trimmed = rawLine.trim();

    // Code blocks
    if (trimmed.startsWith("```")) {
      flushParagraph();
      flushList();
      flushBlockquote();
      flushTable();
      if (!inCode) {
        inCode = true;
        codeLang = trimmed.slice(3).trim();
        codeBuffer = [];
      } else {
        inCode = false;
        output.push(`<pre><code class="language-${escapeHtml(codeLang)}">${escapeHtml(codeBuffer.join("\n"))}</code></pre>`);
        codeBuffer = [];
      }
      continue;
    }

    if (inCode) {
      codeBuffer.push(rawLine);
      continue;
    }

    // Empty line
    if (!trimmed) {
      flushParagraph();
      flushList();
      flushBlockquote();
      flushTable();
      continue;
    }

    // Filter redundant GitHub-only navigation / language switcher links
    const isLangSwitcherLine = /^\[English\]\([^)]+\)\s*[·|•]\s*\[Português\]\([^)]+\)$/i.test(trimmed) || /^\[Português\]\([^)]+\)\s*[·|•]\s*\[English\]\([^)]+\)$/i.test(trimmed);
    const isNavHeaderLine = /^(\[(?:Home|Início|Discovery|User Guide|Guia de Operação|Developers|Desenvolvedores|Roadmap|Continuity|Continuidade|FAQ|Termos|Terms|Privacy|Privacidade|Security|Segurança|License|Licença)\]\([^)]+\)\s*[·|•]\s*)+\[(?:Home|Início|Discovery|User Guide|Guia de Operação|Developers|Desenvolvedores|Roadmap|Continuity|Continuidade|FAQ|Termos|Terms|Privacy|Privacidade|Security|Segurança|License|Licença)\]\([^)]+\)$/i.test(trimmed);

    if (isLangSwitcherLine || isNavHeaderLine) {
      continue;
    }

    // Blockquote
    if (trimmed.startsWith(">")) {
      flushParagraph();
      flushList();
      flushTable();
      inBlockquote = true;
      blockquoteLines.push(trimmed.replace(/^>\s*/, ""));
      continue;
    } else if (inBlockquote) {
      flushBlockquote();
    }

    // Table row
    if (trimmed.startsWith("|") && trimmed.endsWith("|")) {
      flushParagraph();
      flushList();
      flushBlockquote();
      // Check if it's separator row: | --- | :---: |
      if (/^\|(?:\s*:?-+:?\s*\|)+$/.test(trimmed)) {
        continue;
      }
      const cols = trimmed.slice(1, -1).split("|");
      tableRows.push(cols);
      inTable = true;
      continue;
    } else if (inTable) {
      flushTable();
    }

    // Horizontal Rule
    if (/^(?:---|\*\*\*|___)$/.test(trimmed)) {
      flushParagraph();
      flushList();
      flushBlockquote();
      flushTable();
      output.push("<hr>");
      continue;
    }

    // Headings
    if (trimmed.startsWith("#")) {
      flushParagraph();
      flushList();
      flushBlockquote();
      flushTable();
      const match = trimmed.match(/^(#{1,6})\s+(.+)$/);
      if (match) {
        const level = match[1].length;
        const text = match[2];
        // Mesma regra de slug do GitHub: mantém letras acentuadas, descarta
        // pontuação e troca espaços por hífen. Assim uma âncora escrita no
        // Markdown vale igual no GitHub e no site.
        const headingId = text
          .toLowerCase()
          .replace(/[^\p{L}\p{N}\s-]+/gu, "")
          .trim()
          .replace(/\s+/g, "-");
        output.push(`<h${level} id="${headingId}">${parseInline(text, locale)}</h${level}>`);
        continue;
      }
    }

    // Unordered List
    if (/^[-*]\s+/.test(trimmed)) {
      flushParagraph();
      flushBlockquote();
      flushTable();
      if (!inList || listType !== "ul") {
        flushList();
        inList = true;
        listType = "ul";
        output.push("<ul>");
      } else {
        flushListItem();
      }
      const itemText = trimmed.replace(/^[-*]\s+/, "");
      listItemBuffer.push(itemText);
      continue;
    }

    // Ordered List
    if (/^\d+\.\s+/.test(trimmed)) {
      flushParagraph();
      flushBlockquote();
      flushTable();
      if (!inList || listType !== "ol") {
        flushList();
        inList = true;
        listType = "ol";
        output.push("<ol>");
      } else {
        flushListItem();
      }
      const itemText = trimmed.replace(/^\d+\.\s+/, "");
      listItemBuffer.push(itemText);
      continue;
    }

    // Indented list item continuation (lines starting with 2+ spaces that belong to a list item)
    if (inList && listItemBuffer.length > 0 && /^\s{2,}/.test(rawLine) && trimmed.length > 0) {
      listItemBuffer.push(trimmed);
      continue;
    }

    // Raw HTML block (table, img, div, etc)
    if (trimmed.startsWith("<table") || trimmed.startsWith("<img") || trimmed.startsWith("<div") || trimmed.startsWith("<tr>") || trimmed.startsWith("<td>") || trimmed.startsWith("</table>") || trimmed.startsWith("</div>")) {
      flushParagraph();
      flushList();
      flushBlockquote();
      flushTable();
      output.push(parseInline(rawLine, locale));
      continue;
    }

    // Standard paragraph - accumulate lines into single paragraph
    flushList();
    flushBlockquote();
    flushTable();
    paragraphBuffer.push(trimmed);
  }

  flushParagraph();
  flushList();
  flushBlockquote();
  flushTable();

  return output.join("\n");
}

function docPageTemplate({ locale, title, description, slug, bodyHtml }) {
  const isPt = locale === "pt";
  const lang = isPt ? "pt-BR" : "en";
  const canonicalUrl = `https://mcnexus.app/${isPt ? `pt-BR/${slug}/` : `${slug}/`}`;
  const enUrl = `https://mcnexus.app/${slug}/`;
  const ptUrl = `https://mcnexus.app/pt-BR/${slug}/`;
  const currentPath = isPt ? `/pt-BR/${slug}/` : `/${slug}/`;
  const altLink = isPt ? `/${slug}/` : `/pt-BR/${slug}/`;
  const altLabel = isPt ? "EN" : "PT";
  const altLang = isPt ? "en" : "pt-BR";
  const homeHref = isPt ? "/pt-BR/" : "/";
  const homeLabel = isPt ? "Início" : "Home";

  const tabs = navigationTabs[locale].map((tab) => {
    const isActive = tab.href === currentPath;
    return `<a href="${tab.href}" class="${isActive ? "active" : ""}">${escapeHtml(tab.label)}</a>`;
  }).join("\n        ");

  return `<!doctype html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="color-scheme" content="dark">
  <meta name="theme-color" content="#171717">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="MCNexus">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${canonicalUrl}">
  <meta name="twitter:card" content="summary_large_image">
  <title>${escapeHtml(title)}</title>
  <link rel="canonical" href="${canonicalUrl}">
  <link rel="alternate" hreflang="en" href="${enUrl}">
  <link rel="alternate" hreflang="pt-BR" href="${ptUrl}">
  <link rel="alternate" hreflang="x-default" href="${enUrl}">
  <link rel="icon" type="image/svg+xml" href="/assets/brands/mcnexus/nexus-symbol.svg?v=__SITE_VERSION__">
  <link rel="stylesheet" href="/assets/styles/site.css?v=__SITE_VERSION__">
</head>
<body>
  <a class="skip-link" href="#content">${isPt ? "Ir para o conteúdo" : "Skip to content"}</a>

  <header class="site-header">
    <div class="shell header-inner">
      <a class="brand" href="${homeHref}" aria-label="MCNexus">
        <img src="/assets/brands/mcnexus/nexus-logo.svg?v=__SITE_VERSION__" alt="Nexus">
      </a>
      <nav aria-label="${isPt ? "Navegação principal" : "Primary navigation"}">
        <a href="${isPt ? "/pt-BR/developers/" : "/developers/"}">${isPt ? "Desenvolvedores" : "Developers"}</a>
        <a href="${isPt ? "/pt-BR/pricing/" : "/pricing/"}">${isPt ? "Planos" : "Pricing"}</a>
        <a href="${isPt ? "/pt-BR/docs/discovery/" : "/docs/discovery/"}">Discovery</a>
        <a href="${homeHref}#downloads">Downloads</a>
        <a href="https://github.com/ciqueira/MCNexus" target="_blank" rel="noopener noreferrer">GitHub</a>
        <a class="language-link" href="${altLink}" lang="${altLang}">${altLabel}</a>
      </nav>
    </div>
  </header>

  <main id="content" class="doc-layout shell">
    <aside class="doc-sidebar">
      <nav class="doc-nav" aria-label="${isPt ? "Navegação da documentação" : "Documentation navigation"}">
        ${tabs}
      </nav>
    </aside>
    <article class="doc-content">
      ${bodyHtml}
    </article>
  </main>

  <footer class="site-footer">
    <div class="shell footer-main">
      <div>
        <img class="footer-logo" src="/assets/brands/mcnexus/nexus-logo.svg?v=__SITE_VERSION__" alt="Nexus">
        <p>${isPt ? "Infraestrutura de licenciamento, distribuição e atualização." : "Infrastructure for licensing, distribution, and updates."}</p>
        <p>© 2026 Magno Ciqueira.</p>
      </div>
      <div class="footer-links">
        <div><span>${isPt ? "Plataforma" : "Platform"}</span><a href="${isPt ? "/pt-BR/developers/" : "/developers/"}">${isPt ? "Desenvolvedores" : "Developers"}</a><a href="${isPt ? "/pt-BR/pricing/" : "/pricing/"}">${isPt ? "Planos e preços" : "Pricing"}</a><a href="${isPt ? "/pt-BR/docs/roadmap/" : "/docs/roadmap/"}">Roadmap</a></div>
        <div><span>${isPt ? "Produto" : "Product"}</span><a href="${homeHref}#downloads">Downloads</a><a href="https://github.com/ciqueira/MCNexus/releases" target="_blank" rel="noopener noreferrer">Releases</a><a href="${isPt ? "/pt-BR/docs/faq/" : "/docs/faq/"}">FAQ</a></div>
        <div><span>${isPt ? "Jurídico" : "Legal"}</span><a href="${isPt ? "/pt-BR/terms/" : "/terms/"}">${isPt ? "Termos" : "Terms"}</a><a href="${isPt ? "/pt-BR/privacy/" : "/privacy/"}">${isPt ? "Privacidade" : "Privacy"}</a><a href="${isPt ? "/pt-BR/license/" : "/license/"}">${isPt ? "Licença" : "License"}</a></div>
      </div>
    </div>
  </footer>
</body>
</html>
`;
}

async function syncImages() {
  await mkdir(siteImagesDir, { recursive: true });
  try {
    const files = await readdir(repoImagesDir);
    for (const file of files) {
      if (file.endsWith(".png") || file.endsWith(".jpg") || file.endsWith(".jpeg") || file.endsWith(".svg")) {
        await copyFile(path.join(repoImagesDir, file), path.join(siteImagesDir, file));
      }
    }
    console.log("Images synchronized to site/assets/images/");
  } catch (err) {
    console.warn("Could not sync images from images/ folder:", err.message);
  }
}

async function buildDocs() {
  await syncImages();

  for (const doc of docsConfig) {
    for (const locale of ["en", "pt"]) {
      const sourceRelPath = doc.source[locale];
      const sourceFullPath = path.join(rootDir, sourceRelPath);
      let rawMd = "";
      try {
        rawMd = await readFile(sourceFullPath, "utf8");
      } catch (err) {
        console.warn(`Source file not found: ${sourceFullPath}`);
        continue;
      }

      const bodyHtml = parseMarkdown(rawMd, locale);
      const title = doc.title[locale];
      const description = doc.description[locale];
      const html = docPageTemplate({
        locale,
        title,
        description,
        slug: doc.slug,
        bodyHtml,
      });

      const outputRelDir = locale === "pt" ? path.join("pt-BR", doc.slug) : doc.slug;
      const targetDir = path.join(siteDir, outputRelDir);
      await mkdir(targetDir, { recursive: true });
      await writeFile(path.join(targetDir, "index.html"), html, "utf8");
      console.log(`Generated: ${outputRelDir}/index.html`);
    }
  }

  console.log("All documentation pages built successfully!");
}

buildDocs().catch((err) => {
  console.error("Build failed:", err);
  process.exit(1);
});

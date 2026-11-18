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
      en: "Project intake, tenant setup, and NexKeyRuntime integration for developers.",
      pt: "Coleta inicial do projeto, configuração do tenant e integração do NexKeyRuntime.",
    },
    source: { en: "docs/DEVELOPERS.md", pt: "pt-BR/docs/DEVELOPERS.md" },
  },
  {
    key: "developers-licensing",
    slug: "docs/developers/licensing",
    title: { en: "Licensing & SDK · MCNexus", pt: "Licenciamento e SDK · MCNexus" },
    description: {
      en: "Offline Ed25519 verification, machine binding, lease lifecycle, and C/C++ NexKeyRuntime integration.",
      pt: "Verificação offline Ed25519, vínculo de máquina, ciclo de lease e integração C/C++ do NexKeyRuntime.",
    },
    source: { en: "docs/developers/LICENSING.md", pt: "pt-BR/docs/developers/LICENSING.md" },
  },
  {
    key: "developers-commerce",
    slug: "docs/developers/commerce",
    title: { en: "Commerce, Checkout & Delivery · MCNexus", pt: "Comércio, Checkout e Entrega · MCNexus" },
    description: {
      en: "Stripe Connect payouts, Merchant of Record options, webhooks, and automatic post-purchase license provisioning.",
      pt: "Repasses via Stripe Connect, opções de Merchant of Record, webhooks e entrega automática de licenças.",
    },
    source: { en: "docs/developers/COMMERCE.md", pt: "pt-BR/docs/developers/COMMERCE.md" },
  },
  {
    key: "developers-releases",
    slug: "docs/developers/releases",
    title: { en: "Releases, Updates & Notices · MCNexus", pt: "Releases, Updates e Avisos · MCNexus" },
    description: {
      en: "Signed releases, channel feeds, SHA-256 verification, and in-app notices via NexKeyRuntime or MCNexus Manager.",
      pt: "Releases assinados, feeds por canal, verificação SHA-256 e avisos in-app via NexKeyRuntime ou MCNexus Manager.",
    },
    source: { en: "docs/developers/RELEASES.md", pt: "pt-BR/docs/developers/RELEASES.md" },
  },
  {
    key: "developers-dctl",
    slug: "docs/developers/dctl",
    title: { en: "Native DCTL to OFX Packaging · MCNexus", pt: "Empacotamento DCTL para OFX Nativo · MCNexus" },
    description: {
      en: "Package DCTL shaders as signed native OFX plugins for macOS and Windows with integrated NexKeyRuntime licensing.",
      pt: "Empacote shaders DCTL como plugins OFX nativos assinados para macOS e Windows com licenciamento integrado.",
    },
    source: { en: "docs/developers/DCTL.md", pt: "pt-BR/docs/developers/DCTL.md" },
  },
  {
    key: "developers-midi",
    slug: "docs/developers/midi",
    title: { en: "NexControl Hardware MIDI · MCNexus", pt: "Controle por Hardware MIDI (NexControl) · MCNexus" },
    description: {
      en: "Physical MIDI controller mapping for plugin parameters with motor faders, encoders, and zero-lock UI sync.",
      pt: "Mapeamento de controladores MIDI físicos para parâmetros de plugin com motor faders, encoders e sync sem lock.",
    },
    source: { en: "docs/developers/MIDI.md", pt: "pt-BR/docs/developers/MIDI.md" },
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
      en: "Privacy practices, LGPD legal bases, data retention, and data-subject rights for MCNexus applications, SDK, and services.",
      pt: "Práticas de privacidade, bases legais da LGPD, retenção e direitos dos titulares nos aplicativos, SDK e serviços MCNexus.",
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
      en: "MCNexus Source Available License terms governing public desktop client source code and binary distribution.",
      pt: "Termos da Licença Source Available do MCNexus aplicáveis ao código-fonte público e à distribuição binária.",
    },
    source: { en: "LICENSE.md", pt: "LICENSE.md" },
  },
];

const fileToSlugMap = {
  "discovery.md": "docs/discovery",
  "user_guide.md": "docs/user-guide",
  "developers.md": "docs/developers",
  "developers/licensing.md": "docs/developers/licensing",
  "developers/commerce.md": "docs/developers/commerce",
  "developers/releases.md": "docs/developers/releases",
  "developers/dctl.md": "docs/developers/dctl",
  "developers/midi.md": "docs/developers/midi",
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

// Nova estrutura de tabs organizada em grupos lógicos (nav-group)
const navigationTabs = {
  en: [
    [
      { label: "Discovery", href: "/docs/discovery/" },
      { label: "User Guide", href: "/docs/user-guide/" },
      { label: "FAQ", href: "/docs/faq/" },
    ],
    [
      {
        label: "Developer Guide",
        href: "/docs/developers/",
        children: [
          { label: "Licensing & SDK", href: "/docs/developers/licensing/" },
          { label: "Commerce & Delivery", href: "/docs/developers/commerce/" },
          { label: "Releases & Notices", href: "/docs/developers/releases/" },
          { label: "DCTL to OFX", href: "/docs/developers/dctl/" },
          { label: "NexControl MIDI", href: "/docs/developers/midi/" },
        ],
      },
      { label: "Continuity", href: "/docs/continuity/" },
      { label: "Roadmap", href: "/docs/roadmap/" },
    ],
    [
      { label: "Security", href: "/security/" },
      { label: "License", href: "/license/" },
      { label: "Tenant Legal", href: "/docs/tenant-legal/" },
      { label: "Terms", href: "/terms/" },
      { label: "Privacy", href: "/privacy/" },
    ]
  ],
  pt: [
    [
      { label: "Discovery", href: "/pt-BR/docs/discovery/" },
      { label: "Guia de Operação", href: "/pt-BR/docs/user-guide/" },
      { label: "FAQ", href: "/pt-BR/docs/faq/" },
    ],
    [
      {
        label: "Guia do Desenvolvedor",
        href: "/pt-BR/docs/developers/",
        children: [
          { label: "Licenciamento e SDK", href: "/pt-BR/docs/developers/licensing/" },
          { label: "Comércio e Entrega", href: "/pt-BR/docs/developers/commerce/" },
          { label: "Releases e Avisos", href: "/pt-BR/docs/developers/releases/" },
          { label: "DCTL para OFX", href: "/pt-BR/docs/developers/dctl/" },
          { label: "NexControl MIDI", href: "/pt-BR/docs/developers/midi/" },
        ],
      },
      { label: "Continuidade", href: "/pt-BR/docs/continuity/" },
      { label: "Roadmap", href: "/pt-BR/docs/roadmap/" },
    ],
    [
      { label: "Segurança", href: "/pt-BR/security/" },
      { label: "Licença", href: "/pt-BR/license/" },
      { label: "Guia Legal", href: "/pt-BR/docs/tenant-legal/" },
      { label: "Termos", href: "/pt-BR/terms/" },
      { label: "Privacidade", href: "/pt-BR/privacy/" },
    ]
  ],
};

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[char]);
}

function parseMarkdown(md, locale, useSiteUtm = false, sourceRelPath = "") {
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
          const rowSubject = parseInline(tableRows[i][0].trim(), locale).split(/<br/i)[0].replace(/<[^>]+>/g, "").trim();
          for (const col of tableRows[i]) {
            let cellHtml = parseInline(col.trim(), locale);
            if (rowSubject) {
              cellHtml = cellHtml.replace(
                /<a\b([^>]*)>(Get Key|Obter chave|Become a Supporter|Torne-se um apoiador)<\/a>/gi,
                (_m, attrs, linkText) => {
                  if (/\baria-label=/i.test(attrs)) return _m;
                  return `<a${attrs} aria-label="${escapeHtml(`${linkText}: ${rowSubject}`)}">${linkText}</a>`;
                }
              );
            }
            html += `      <td>${cellHtml}</td>\n`;
          }
          html += "    </tr>\n";
        }
        html += "  </tbody>\n</table>";
        const tableLabel = locale === "pt" ? "Tabela com rolagem horizontal" : "Scrollable data table";
        output.push(`<div class="table-scroll-wrap">\n<div class="table-scroll" role="region" aria-label="${tableLabel}" tabindex="0">\n${html}\n</div>\n</div>`);
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
        const ghDocMatch = href.match(/^https:\/\/github\.com\/ciqueira\/MCNexus\/blob\/main\/(?:pt-BR\/)?(?:docs\/)?([a-zA-Z0-9_\/-]+\.md)/i);
        if (ghDocMatch) {
          const fn = ghDocMatch[1].toLowerCase();
          if (fileToSlugMap[fn] !== undefined) {
            const targetLoc = href.includes("/pt-BR/") ? "pt" : "en";
            const slug = fileToSlugMap[fn];
            const targetUrl = targetLoc === "pt" ? (slug ? `/pt-BR/${slug}/` : "/pt-BR/") : (slug ? `/${slug}/` : "/");
            return `<a href="${targetUrl}">${linkText}</a>`;
          }
        }

        const isEntryHost = /^https?:\/\/(get|buy)\.mcnexus\.app(\/|$)/i.test(href);
        let outputHref = href;
        if (isEntryHost && useSiteUtm) {
          const entryUrl = new URL(href);
          if (entryUrl.searchParams.get("utm_medium") === "docs") {
            entryUrl.searchParams.set("utm_medium", "site");
          }
          outputHref = entryUrl.toString();
        }
        const rel = isEntryHost ? "noopener noreferrer nofollow" : "noopener noreferrer";
        return `<a href="${outputHref}" target="_blank" rel="${rel}">${linkText}</a>`;
      }

      // Hash or mailto
      if (href.startsWith("#")) {
        return `<a href="${href}">${linkText}</a>`;
      }
      if (href.startsWith("mailto:")) {
        return `<!--email_off--><a href="${href}">${linkText}</a><!--/email_off-->`;
      }

      // Profile JSON download links (normalize relative GitHub path or site path to /assets/profiles/<file>.json)
      const profileMatch = href.match(/^(?:(?:\.\.\/)+site)?\/assets\/profiles\/([a-z0-9_-]+\.json)$/i);
      if (profileMatch) {
        const fileName = profileMatch[1];
        return `<a href="/assets/profiles/${fileName}" download="${fileName}">${linkText}</a>`;
      }

      // Internal markdown link
      const cleanUrl = href.split("?")[0].split("#")[0];
      const hash = href.includes("#") ? `#${href.split("#")[1]}` : "";
      const baseDir = path.posix.dirname(sourceRelPath || (loc === "pt" ? "pt-BR/docs/" : "docs/"));
      const resolvedFromRoot = path.posix.normalize(path.posix.join(baseDir, cleanUrl));
      const canonicalKey = resolvedFromRoot.replace(/^(?:pt-BR\/)?(?:docs\/)?/i, "").toLowerCase();

      if (fileToSlugMap[canonicalKey] !== undefined) {
        let targetLoc = loc;
        const lowerText = linkText.trim().toLowerCase();
        if (resolvedFromRoot.startsWith("pt-BR/") || lowerText === "português") {
          targetLoc = "pt";
        } else if (
          lowerText === "english" ||
          (loc === "pt" &&
            !resolvedFromRoot.startsWith("pt-BR/") &&
            canonicalKey !== "security.md" &&
            canonicalKey !== "license.md")
        ) {
          targetLoc = "en";
        }

        const slug = fileToSlugMap[canonicalKey];
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
    const isNavHeaderLine = /^(\[(?:Home|Início|Discovery|User Guide|Guia de Operação|Developers|Desenvolvedores|Developer Guide|Guia do Desenvolvedor|Licensing|Licenciamento|Commerce|Releases|DCTL|MIDI|Roadmap|Continuity|Continuidade|FAQ|Termos|Terms|Privacy|Privacidade|Security|Segurança|License|Licença)\]\([^)]+\)\s*[·|•]\s*)+\[(?:Home|Início|Discovery|User Guide|Guia de Operação|Developers|Desenvolvedores|Developer Guide|Guia do Desenvolvedor|Licensing|Licenciamento|Commerce|Releases|DCTL|MIDI|Roadmap|Continuity|Continuidade|FAQ|Termos|Terms|Privacy|Privacidade|Security|Segurança|License|Licença)\]\([^)]+\)$/i.test(trimmed);
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

    // Indented list item continuation
    if (inList && listItemBuffer.length > 0 && /^\s{2,}/.test(rawLine) && trimmed.length > 0) {
      listItemBuffer.push(trimmed);
      continue;
    }

    // Raw HTML block
    if (trimmed.startsWith("<table") || trimmed.startsWith("<img") || trimmed.startsWith("<div") || trimmed.startsWith("<tr>") || trimmed.startsWith("<td>") || trimmed.startsWith("</table>") || trimmed.startsWith("</div>")) {
      flushParagraph();
      flushList();
      flushBlockquote();
      flushTable();
      output.push(parseInline(rawLine, locale));
      continue;
    }

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

function docPageTemplate({ locale, title, description, slug, bodyHtml, docKey }) {
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

  // Nova estrutura de tabs organizada em grupos lógicos (nav-group) e subitens (nav-sub)
  const tabs = navigationTabs[locale].map((group) => {
    const linksHtml = group.map((tab) => {
      const isActive = tab.href === currentPath;
      const parentLink = `<a href="${tab.href}" class="${isActive ? "active" : ""}">${escapeHtml(tab.label)}</a>`;
      if (!tab.children || tab.children.length === 0) {
        return parentLink;
      }
      const subLinks = tab.children.map((child) => {
        const childActive = child.href === currentPath;
        return `<a href="${child.href}" class="${childActive ? "active" : ""}">${escapeHtml(child.label)}</a>`;
      }).join("\n          ");
      return `${parentLink}\n        <div class="nav-sub">\n          ${subLinks}\n        </div>`;
    }).join("\n        ");
    return `<div class="nav-group">\n        ${linksHtml}\n      </div>`;
  }).join("\n      ");

  return `<!doctype html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="color-scheme" content="dark">
  <meta name="theme-color" content="#171717">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="MCNexus">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${canonicalUrl}">
  <meta property="og:image" content="https://mcnexus.app/assets/images/og-mcnexus.png">
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
      <a class="brand" href="${homeHref}" aria-label="${isPt ? "Início MCNexus" : "MCNexus home"}">
        <img src="/assets/brands/mcnexus/nexus-logo.svg?v=__SITE_VERSION__" alt="Nexus" width="494" height="109">
      </a>
      <nav id="primary-nav" class="primary-nav" aria-label="${isPt ? "Navegação principal" : "Primary navigation"}">
        <a href="${isPt ? "/pt-BR/developers/" : "/developers/"}">${isPt ? "Desenvolvedores" : "Developers"}</a>
        <a href="${isPt ? "/pt-BR/pricing/" : "/pricing/"}">${isPt ? "Planos" : "Pricing"}</a>
        <a href="${isPt ? "/pt-BR/docs/discovery/" : "/docs/discovery/"}">Discovery</a>
        <a href="${homeHref}#downloads">Downloads</a>
        <a href="https://github.com/ciqueira/MCNexus" target="_blank" rel="noopener noreferrer">GitHub</a>
      </nav>
      <div class="header-actions">
        <a class="language-link" href="${altLink}" lang="${altLang}">${altLabel}</a>
        <button type="button" class="nav-toggle" aria-expanded="false" aria-controls="primary-nav" aria-label="${isPt ? "Abrir menu" : "Open menu"}">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>
      </div>
    </div>
  </header>

  <main id="content" class="doc-layout shell">
    <aside class="doc-sidebar">
      <nav class="doc-nav" aria-label="${isPt ? "Navegação da documentação" : "Documentation navigation"}">
        ${tabs}
      </nav>
    </aside>
    <article class="doc-content${docKey === "discovery" ? " page-discovery" : ""}">
      ${bodyHtml}
    </article>
  </main>

  <footer class="site-footer">
    <div class="shell footer-main">
      <div>
        <img class="footer-logo" src="/assets/brands/mcnexus/nexus-logo.svg?v=__SITE_VERSION__" alt="Nexus" width="494" height="109">
        <p>${isPt ? "Infraestrutura de licenciamento, distribuição e atualização." : "Infrastructure for licensing, distribution, and updates."}</p>
        <p>© 2026 ${isPt ? "Desenvolvedor" : "Developer"} <a href="https://www.linkedin.com/in/ciqueira/">Magno Ciqueira</a></p>
        <div class="footer-social">
          <a href="https://www.linkedin.com/in/ciqueira/" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451c.979 0 1.778-.773 1.778-1.729V1.73C24 .774 23.205 0 22.225 0z"/></svg>
          </a>
          <a href="https://www.instagram.com/magnociqueira/" target="_blank" rel="noopener noreferrer" aria-label="Instagram">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="M12 0C8.74 0 8.333.015 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.74 0 12c0 3.26.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.26-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0 3.675a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.881 1.44 1.44 0 0 0 0-2.881z"/></svg>
          </a>
        </div>
      </div>
      <div class="footer-links">
        <div>
          <span>${isPt ? "Produto" : "Product"}</span>
          <a href="${isPt ? "/pt-BR/docs/discovery/" : "/docs/discovery/"}">Discovery</a>
          <a href="${homeHref}#downloads">${isPt ? "Baixar App" : "Download App"}</a>
          <a href="${isPt ? "/pt-BR/docs/user-guide/" : "/docs/user-guide/"}">${isPt ? "Guia de Operação" : "User Guide"}</a>
          <!--email_off--><a href="mailto:support@mcnexus.app">${isPt ? "Suporte Técnico" : "Technical Support"}</a><!--/email_off-->
          <a href="${isPt ? "/pt-BR/docs/faq/" : "/docs/faq/"}">FAQ</a>
        </div>
        <div>
          <span>${isPt ? "Plataforma" : "Platform"}</span>
          <a href="${isPt ? "/pt-BR/developers/" : "/developers/"}">${isPt ? "Desenvolvedores" : "Developers"}</a>
          <a href="${isPt ? "/pt-BR/pricing/" : "/pricing/"}">${isPt ? "Planos" : "Pricing"}</a>
          <a href="${isPt ? "/pt-BR/docs/continuity/" : "/docs/continuity/"}">${isPt ? "Continuidade" : "Continuity"}</a>
          <a href="${isPt ? "/pt-BR/docs/roadmap/" : "/docs/roadmap/"}">Roadmap</a>
        </div>
        <div>
          <span>${isPt ? "Jurídico" : "Legal"}</span>
          <a href="${isPt ? "/pt-BR/terms/" : "/terms/"}">${isPt ? "Termos" : "Terms"}</a>
          <a href="${isPt ? "/pt-BR/privacy/" : "/privacy/"}">${isPt ? "Privacidade" : "Privacy"}</a>
        </div>
      </div>
    </div>
  </footer>
  <script src="/assets/scripts/site-nav.js?v=__SITE_VERSION__" defer></script>
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

async function generateSitemap() {
  const staticRoutes = ["", "developers", "pricing"];
  const allSlugs = [...staticRoutes, ...docsConfig.map((d) => d.slug)];
  const lastmod = new Date().toISOString().slice(0, 10);
  const urls = [];

  for (const slug of allSlugs) {
    const enPath = slug ? `https://mcnexus.app/${slug}/` : "https://mcnexus.app/";
    const ptPath = slug ? `https://mcnexus.app/pt-BR/${slug}/` : "https://mcnexus.app/pt-BR/";
    const alternates = `
    <xhtml:link rel="alternate" hreflang="en" href="${enPath}" />
    <xhtml:link rel="alternate" hreflang="pt-BR" href="${ptPath}" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${enPath}" />`;

    urls.push(`  <url>\n    <loc>${enPath}</loc>\n    <lastmod>${lastmod}</lastmod>${alternates}\n  </url>`);
    urls.push(`  <url>\n    <loc>${ptPath}</loc>\n    <lastmod>${lastmod}</lastmod>${alternates}\n  </url>`);
  }

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${urls.join("\n")}\n</urlset>\n`;
  await writeFile(path.join(siteDir, "sitemap.xml"), xml, "utf8");
  console.log("Generated: sitemap.xml");
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
        throw new Error(`Missing source file for ${doc.slug} (${locale}): ${sourceFullPath}`);
      }

      const bodyHtml = parseMarkdown(rawMd, locale, doc.key === "discovery", sourceRelPath);
      const title = doc.title[locale];
      const description = doc.description[locale];
      const html = docPageTemplate({
        locale,
        title,
        description,
        slug: doc.slug,
        bodyHtml,
        docKey: doc.key,
      });

      const outputRelDir = locale === "pt" ? path.join("pt-BR", doc.slug) : doc.slug;
      const targetDir = path.join(siteDir, outputRelDir);
      await mkdir(targetDir, { recursive: true });
      await writeFile(path.join(targetDir, "index.html"), html, "utf8");
      console.log(`Generated: ${outputRelDir}/index.html`);
    }
  }

  await generateSitemap();
  console.log("All documentation pages built successfully!");
}

buildDocs().catch((err) => {
  console.error("Build failed:", err);
  process.exit(1);
});
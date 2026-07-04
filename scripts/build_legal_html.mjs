// Renders the LEGAL/*.md documents to standalone, brand-styled HTML pages
// (paper/ink/terracotta, theme-aware) suitable for hosting as the app's public
// Privacy Policy and Terms of Use URLs.
//
// Usage:  node scripts/build_legal_html.mjs
// (requires `marked` available on the module path — see scratchpad install)
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { marked } from 'marked';

const OUT = 'build/legal';
// Ready-to-deploy static site (privacy + terms + index + vercel.json), served
// publicly at https://oneshot-legal.vercel.app. Regenerated from committed
// source (LEGAL/*.md + scripts/legal-site/*), so `vercel deploy --prod` from
// SITE always ships the current docs. See scripts/deploy-legal.md.
const SITE = 'build/legal-site';
mkdirSync(OUT, { recursive: true });
mkdirSync(SITE, { recursive: true });

// Shared CSS for both the standalone page and the artifact partial.
const STYLE = `<style>
  :root{
    --paper:#FBF7F0; --paper-2:#F3ECE0; --ink:#1E1B18; --ink-soft:#6B655E;
    --accent:#C05C3A; --rule:#E4D9C8; --link:#A24A2E;
  }
  @media (prefers-color-scheme: dark){
    :root{ --paper:#17140F; --paper-2:#211C15; --ink:#F1EADD; --ink-soft:#B3A895;
      --accent:#E08A63; --rule:#332B20; --link:#E08A63; }
  }
  :root[data-theme="light"]{ --paper:#FBF7F0; --paper-2:#F3ECE0; --ink:#1E1B18;
    --ink-soft:#6B655E; --accent:#C05C3A; --rule:#E4D9C8; --link:#A24A2E; }
  :root[data-theme="dark"]{ --paper:#17140F; --paper-2:#211C15; --ink:#F1EADD;
    --ink-soft:#B3A895; --accent:#E08A63; --rule:#332B20; --link:#E08A63; }

  *{ box-sizing:border-box; }
  html{ -webkit-text-size-adjust:100%; }
  body{ margin:0; background:var(--paper); color:var(--ink);
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
    line-height:1.7; }
  .top{ height:4px; background:var(--accent); }
  .wrap{ max-width:44rem; margin:0 auto; padding:2.5rem 1.5rem 5rem; }
  header.brand{ display:flex; align-items:baseline; gap:.6rem; margin-bottom:2.2rem;
    padding-bottom:1.2rem; border-bottom:1px solid var(--rule); }
  header.brand .name{ font-family:Georgia,"Iowan Old Style","Times New Roman",serif;
    font-weight:600; font-size:1.25rem; letter-spacing:.2px; }
  header.brand .kind{ color:var(--ink-soft); font-size:.8rem;
    text-transform:uppercase; letter-spacing:.12em; }
  h1{ font-family:Georgia,"Iowan Old Style","Times New Roman",serif;
    font-weight:600; font-size:2rem; line-height:1.2; text-wrap:balance; margin:.2rem 0 1rem; }
  h2{ font-family:Georgia,"Iowan Old Style","Times New Roman",serif;
    font-weight:600; font-size:1.3rem; margin:2.4rem 0 .6rem; text-wrap:balance; }
  h1 + p, h2 + p{ margin-top:0; }
  p, li{ font-size:1.02rem; }
  a{ color:var(--link); text-decoration:underline; text-underline-offset:2px; }
  a:focus-visible{ outline:2px solid var(--accent); outline-offset:2px; border-radius:2px; }
  strong{ color:var(--ink); }
  hr{ border:none; border-top:1px solid var(--rule); margin:2.2rem 0; }
  blockquote{ margin:1.4rem 0; padding:.8rem 1.1rem; background:var(--paper-2);
    border-left:3px solid var(--accent); border-radius:0 8px 8px 0; color:var(--ink-soft); }
  code{ background:var(--paper-2); padding:.12em .35em; border-radius:4px;
    font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:.9em; }
  .tablewrap{ overflow-x:auto; margin:1.2rem 0; }
  table{ border-collapse:collapse; width:100%; font-size:.94rem; }
  th, td{ text-align:left; vertical-align:top; padding:.6rem .7rem;
    border-bottom:1px solid var(--rule); }
  th{ font-size:.78rem; text-transform:uppercase; letter-spacing:.06em;
    color:var(--ink-soft); font-weight:700; }
  .meta{ color:var(--ink-soft); font-size:.85rem; text-transform:uppercase;
    letter-spacing:.08em; }
</style>`;

// The inner content (brand header + document body), shared by both outputs.
const content = (title, bodyHtml) => `  <div class="top"></div>
  <div class="wrap">
    <header class="brand">
      <span class="name">One Shot</span>
      <span class="kind">${title}</span>
    </header>
    <main>
${bodyHtml}
    </main>
  </div>`;

// Standalone document — for self-hosting / GitHub Pages.
const standalone = (title, bodyHtml) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — One Shot</title>
${STYLE}
</head>
<body>
${content(title, bodyHtml)}
</body>
</html>`;

// Body-only partial — for the Artifact host, which supplies its own
// doctype/head/body skeleton (so we must NOT include those tags).
const partial = (title, bodyHtml) =>
  `<title>${title} — One Shot</title>\n${STYLE}\n${content(title, bodyHtml)}`;

// Wrap tables for horizontal overflow on narrow screens.
const wrapTables = (html) =>
  html.replace(/<table>/g, '<div class="tablewrap"><table>')
      .replace(/<\/table>/g, '</table></div>');

const docs = [
  { src: 'LEGAL/privacy-policy.md', out: 'privacy', title: 'Privacy Policy' },
  { src: 'LEGAL/terms-of-use.md', out: 'terms', title: 'Terms of Use' },
];

for (const d of docs) {
  const md = readFileSync(d.src, 'utf8');
  const body = wrapTables(marked.parse(md, { gfm: true }));
  writeFileSync(`${OUT}/${d.out}.html`, standalone(d.title, body));
  writeFileSync(`${OUT}/${d.out}.artifact.html`, partial(d.title, body));
  // The deploy folder gets the standalone page (served at /privacy, /terms).
  writeFileSync(`${SITE}/${d.out}.html`, standalone(d.title, body));
  console.log(`wrote ${OUT}/${d.out}.html and ${d.out}.artifact.html`);
}

// Copy the committed site chrome (landing page + hosting config) into the
// deploy folder so `${SITE}` is a complete, ready-to-ship Vercel project.
for (const f of ['index.html', 'vercel.json']) {
  copyFileSync(`scripts/legal-site/${f}`, `${SITE}/${f}`);
}
console.log(`assembled deploy site -> ${SITE}/ (index.html, vercel.json, privacy.html, terms.html)`);

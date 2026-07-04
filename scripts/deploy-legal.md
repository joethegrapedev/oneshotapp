# Hosting the Privacy Policy & Terms

The app's Privacy Policy and Terms of Use are hosted as a small static site on
Vercel — public, HTTPS, no auth wall (Google Play requires a publicly reachable
Privacy Policy URL). We host here because Claude Artifacts can only be made
public on Team/Enterprise plans.

## Live URLs

- Privacy: https://oneshot-legal.vercel.app/privacy
- Terms:   https://oneshot-legal.vercel.app/terms

These are wired into `lib/core/env.dart` as the defaults for `PRIVACY_URL` /
`TOS_URL`, and referenced in `docs/browser-agent-playstore-prompt.md`.

## Source of truth

- Legal copy:  `LEGAL/privacy-policy.md`, `LEGAL/terms-of-use.md`
- Site chrome: `scripts/legal-site/index.html`, `scripts/legal-site/vercel.json`
  (`vercel.json` sets `cleanUrls` so `/privacy` serves `privacy.html`)

The rendered site is generated into `build/legal-site/` (gitignored) — never edit
it by hand; edit the source above and rebuild.

## Redeploy (after editing the legal docs)

```bash
# 1. Regenerate the deploy folder from the committed source
node scripts/build_legal_html.mjs

# 2. Ship it to the same production project
cd build/legal-site && vercel deploy --prod --yes

# 3. Sanity check (expect 200 / 200)
curl -s -o /dev/null -w "%{http_code}\n" https://oneshot-legal.vercel.app/privacy
curl -s -o /dev/null -w "%{http_code}\n" https://oneshot-legal.vercel.app/terms
```

## Vercel project

- Project: `oneshot-legal` (scope `johntowzhichongdev-gmailcoms-projects`)
- projectId: `prj_R39vKCkYPh872rU703Mk3CAJfdch`
- orgId:     `team_I37EFK4f1Ark0Mh0cTrshM3l`

If the `.vercel` link in `build/legal-site/` is lost (e.g. after a clean),
`vercel deploy --prod --yes` from that folder re-associates with the existing
`oneshot-legal` project by name. To attach a custom domain later, add it in the
Vercel dashboard and update the URLs in `env.dart` + the docs above.

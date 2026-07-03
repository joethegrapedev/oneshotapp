# Privacy Policy

**Last updated: 2026-07-01 · Version: 2026-07-01**

> In-app copy. The canonical, hostable version lives at the URL configured in
> `PRIVACY_URL` (dart-define) and in `LEGAL/privacy-policy.md`. The full text is
> bundled here so it is readable offline. **Template — pending counsel review.**

## In short

- One Shot is **anonymous** by design — no usernames or profiles. We collect as
  little as possible.
- We store your **auth identifier** (anonymous by default; an **email** only if
  you link one), your **journal entries**, and any **reports/blocks** you make.
- Entries you **share** are sent to our server, which uses **OpenAI's moderation
  endpoint** to classify them (processing only — **not sold, not used to train
  their models**). The OpenAI key is only on our server, never in the app.
- **Supabase** hosts our data; **RevenueCat/Google Play** handle subscriptions.
- We do **not** collect location, contacts, or files. You can **delete your
  account and data** in-app. **18+ only.**
- Contact: **[SUPPORT_EMAIL]**

---

## Full policy

### 1. Who this applies to
Adults **18+**. We do not knowingly collect data from children.

### 2. What we collect
- **Authentication identifier** — anonymous by default; an **email** only if you
  choose to link one (for account recovery).
- **Journal entries (text)** — private entries stay tied to your account;
  **shared** entries are additionally moderated and, if cleared, pooled
  anonymously.
- **Reports and blocks** — for safety and enforcement.
- **Moderation results** — category flags/scores and the decision for shared
  entries.
- **Optional diagnostics/analytics** (PostHog) — only if configured; the app
  works fully without it.

We do **not** collect location, contacts, photos/files, or advertising IDs.

### 3. Shared-entry moderation
When you share, the entry text is sent to our secure backend and submitted to
**OpenAI's moderation endpoint** for automated classification. Per OpenAI's API
policy this data is **not used to train their models** and is used only to return
the result, which we use to allow, hold (e.g. self-harm → crisis resources), or
reject the entry. The OpenAI key is server-side only.

### 4. Service providers
**Supabase** (hosting/database/auth), **OpenAI** (moderation classification of
shared text only), **RevenueCat + Google Play Billing** (subscriptions/payments;
we don't store card details), **PostHog** (optional analytics). We do **not
sell** your data and do **not** use your journal content for advertising.

### 5. Retention
Private entries are kept while your account exists or until you delete them.
Shared entries remain while eligible and are withdrawn on removal/report/block/
deletion. Minimal moderation records may be retained for safety and legal
compliance. Inactive anonymous accounts may be pruned.

### 6. Your choices
- **Settings → delete account** purges your entries, your matches, your reports
  and blocks, your profile, and your auth user. Exceptions: copies already served
  to others and records we must keep by law.
- Edit or delete individual entries anytime.
- Report and block to control what you see.
- You may have rights to access, correct, port, or object to processing.

### 7. Security
Encrypted **in transit** (HTTPS/TLS) and **at rest** by our hosting provider.
Production access is restricted.

### 8. International transfers
Data may be processed outside your country by the providers above, with
appropriate safeguards where required.

### 9. Changes
Material changes are reflected via the updated version/date and notified in-app
where appropriate.

### 10. Contact
Privacy questions / data requests: **[SUPPORT_EMAIL]**

*Version 2026-07-01. Template for counsel review. Consistent with the app's
Google Play Data Safety declaration.*

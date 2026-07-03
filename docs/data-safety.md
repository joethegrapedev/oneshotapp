# Google Play Data Safety — One Shot

This maps One Shot's data handling to the Play Console **Data Safety** form. It
is kept consistent with `LEGAL/privacy-policy.md` and the app's actual behaviour
(no location, no contacts, no files, INTERNET permission only).

**Summary answers**
- Does the app **collect or share** user data? **Yes** (collect; limited sharing
  with processors only).
- Is data **encrypted in transit**? **Yes** (HTTPS/TLS everywhere).
- Can users **request deletion**? **Yes** — in-app Settings → delete account.
- Is any data **sold**? **No.** Used for advertising? **No.**
- Committed to the **Play Families / target-audience** policy? App is **18+**;
  not directed to children.

---

## Data types collected

| Data type | Collected | Purpose | Shared with third parties | Optional? | Encrypted in transit | Deletable |
|---|---|---|---|---|---|---|
| **Email address** (only if user links one) | Yes | Account management & recovery | No (stored by Supabase, our processor) | Optional (anonymous auth by default) | Yes | Yes |
| **User IDs** (anonymous auth id) | Yes | App functionality (account) | No (Supabase processor) | Required | Yes | Yes |
| **Journal entries — "Other user-generated content" / messages** | Yes | App functionality; safety moderation of shared entries | **Shared for processing** with OpenAI (moderation classification of *shared* text only) and stored by Supabase | Writing is core; **sharing an entry is optional** | Yes | Yes |
| **Reports & blocks** (user actions) | Yes | Safety, abuse prevention, enforcement | No (Supabase processor) | Optional (user-initiated) | Yes | Yes |
| **App interactions / diagnostics (analytics)** | Only if PostHog configured | Analytics, reliability, product improvement | PostHog processor (if configured) | Optional; app works without it | Yes | Yes (account deletion) |
| **Purchase history** | Yes (via Play/RevenueCat) | Manage subscription/entitlement | Google Play + RevenueCat processors | Required for paid access | Yes | Managed via Play |

### Explicitly NOT collected
- **Location** (precise or approximate) — none.
- **Contacts** — none.
- **Photos / videos / files / audio** — none.
- **Health/fitness, calendar, SMS/call logs** — none.
- **Advertising ID / ad targeting** — none.

The app requests **only** the `INTERNET` permission; there are no runtime/
sensitive permissions (see `android/app/src/main/AndroidManifest.xml`).

---

## "Shared" vs "Processed" clarification

Play treats transfers to service providers acting on your behalf as *processing*,
not third-party *sharing* for the provider's own purposes. For transparency we
disclose:

- **OpenAI** — receives **shared-entry text** solely to return a moderation
  classification. **Not sold, not used to train their models** (per OpenAI's API
  data-usage policy). Server-to-server; the API key is never in the app.
- **Supabase** — hosting/database/auth processor (all stored data).
- **RevenueCat + Google Play** — subscription/payment processing.
- **PostHog** — optional analytics processor (only if configured).

None of these constitute selling data or advertising use.

---

## Deletion & retention

- **In-app deletion:** Settings → delete account runs `delete_my_account()` and
  deletes the auth user (CONTRACTS §3/§4), purging entries, matches, the user's
  reports/blocks, and profile.
- **Retention:** minimal moderation records may be retained for safety/legal
  compliance; see `LEGAL/privacy-policy.md` §6.

Keep this file, the Privacy Policy, and the Play Console form **in sync** whenever
data handling changes.

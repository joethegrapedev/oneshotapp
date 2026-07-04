# One Shot — Privacy Policy

**Last updated: 2026-07-01 · Version: 2026-07-01**

This Privacy Policy explains what information the One Shot app ("One Shot", "we",
"us") collects, why, how it is used and shared, and the choices you have. **This
policy is separate from our [Terms of Use](./terms-of-use.md).**

One Shot is designed to be **anonymous**: there are no usernames, profiles, or
public identity. We collect as little as possible.

---

## 1. Who this applies to

One Shot is for **adults aged 18 and older**. We do not knowingly collect data
from children. If we learn that a user is under 18, we will terminate the account
and delete associated data.

---

## 2. What we collect

| Data | When | Why |
|---|---|---|
| **Authentication identifier** | On sign-in. By default we use **anonymous authentication** (a random account with no email). If you optionally link an **email address**, we store it to secure and recover your account. | Account access and recovery. |
| **Journal entries (text)** | When you write them. Private entries stay tied to your account. **Entries you choose to share** are additionally processed by the moderation gate and, if cleared, added to an anonymous shared pool. | Core app function; safety moderation for shared entries. |
| **Reports and blocks** | When you report an entry or block an author. | Safety, abuse prevention, and enforcement. |
| **Moderation results** | Automatically, for shared entries. Category flags/scores and the decision are stored with the entry and in a moderation log. | Safety, transparency, and abuse handling. |
| **Basic technical/diagnostic data** | While using the app. Optional, privacy-respecting product analytics (via PostHog) **only if configured**; the app functions fully without it. | Reliability and product improvement. |

We do **not** collect your location, contacts, photos, files, precise device
identifiers for advertising, or any special-category data beyond what you
voluntarily write in your entries.

---

## 3. How shared-entry moderation works (important)

When you tap share, the entry text is sent to our secure backend, which submits
it to **OpenAI's moderation endpoint** for automated classification. Per OpenAI's
API data usage policy, data submitted to the API is **not used to train their
models** and is used only to return the moderation result. We use the result to
decide whether the entry may enter the shared pool, be held (e.g. for self-harm,
routing you to crisis resources), or be rejected.

- The OpenAI API key lives **only** on our server; it is never in the app.
- We send OpenAI the **entry text for classification only** — a processing
  ("service provider") purpose. It is **not sold** and **not used for
  advertising**.

---

## 4. Who processes your data (service providers)

- **Supabase** — our hosting/database/authentication provider (data processor).
  It stores your account, entries, reports, blocks, and moderation records on our
  behalf. Hosting region: Southeast Asia (Singapore).
- **OpenAI** — moderation classification of shared-entry text only, as described
  above (data processor / service provider).
- **RevenueCat + Google Play Billing** — subscription management and payments.
  We do not receive or store your full payment card details.
- **PostHog** — optional product analytics, only if configured for the build.

We do **not sell** your personal information and we do **not** use your journal
content for advertising.

---

## 5. Legal bases (where applicable, e.g. GDPR)

Where required, we rely on: **performance of a contract** (providing the
Service), **legitimate interests** (safety, abuse prevention, reliability),
**consent** (optional analytics; sharing an entry), and **legal obligation**
(responding to lawful requests, CSAE reporting).

---

## 6. Retention

- **Private entries** are retained while your account exists, until you delete
  them or your account.
- **Shared entries** remain in the pool while eligible; removed entries and
  reported/blocked content are withdrawn from serving. We may retain minimal
  moderation records for safety and legal compliance for a limited period.
- **Anonymous accounts** with no activity may be pruned per 12 months of inactivity.
- Backups are rotated and purged on a rolling schedule of 30 days.

---

## 7. Your choices and rights

- **Delete your data / account:** In the app, **Settings → delete account**
  purges your entries, your matches, reports and blocks you created, and your
  profile, and deletes your authentication user. Copies of shared entries already
  served to others, and records we must keep by law, are the only exceptions.
- **Edit or delete individual entries** at any time from within the app.
- **Report and block** to control what you are shown.
- Depending on your location you may have rights to access, correct, port, or
  object to processing of your data. Contact us to exercise them.

---

## 8. Security

Data is encrypted **in transit** (HTTPS/TLS) between the app, our backend, and
service providers, and is **encrypted at rest** by our hosting provider. Access
to production data is restricted. No system is perfectly secure; please use a
strong, unique method to secure any linked email account.

---

## 9. International transfers

Your data may be processed in countries other than yours (e.g. by the service
providers above). Where required, we use appropriate safeguards for such
transfers. 

---

## 10. Changes to this policy

We may update this policy; material changes will be reflected by updating the
"Last updated" date and version, and notified in the app where appropriate.

---

## 11. Contact

Privacy questions or data requests: **johntowzhichongdev@gmail.com**
Data controller: One Shot (independent developer), Singapore.

*One Shot Privacy Policy — version 2026-07-01.*

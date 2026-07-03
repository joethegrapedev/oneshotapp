# Content rating (IARC) — One Shot

Guidance for completing the **IARC content-rating questionnaire** in the Google
Play Console. Answer truthfully to the actual app behaviour; this is a
preparation aid, not the official rating.

## App profile
- **Category:** Lifestyle / Health-adjacent journaling (not a game).
- **Audience:** **Adults 18+** (enforced by in-app age gate; see CONTRACTS §6).
- **Contains user-generated content (UGC):** **Yes** — this is the key driver.

## Questionnaire answers (typical)

| Topic | Answer | Notes |
|---|---|---|
| Violence (realistic/graphic/cartoon) | **No** | App content is text journaling; graphic content is prohibited and moderated out. |
| Sexual content / nudity | **No** | Prohibited; moderation hard-rejects sexual content and (zero tolerance) any sexual content involving minors. |
| Profanity / crude humor | **Possible in UGC** | User-written text may contain profanity; disclose as user-generated. |
| Controlled substances (drugs/alcohol/tobacco) | **No** (as app content) | Promotion of illicit content is prohibited. |
| Gambling / simulated gambling | **No** | None. |
| Fear / horror | **No** | None. |
| **Users interact / share content (UGC)** | **Yes** | Opt-in exchange: users can share entries that may be shown anonymously to other users. |
| Users can communicate / message each other | **No** | Anonymous by design — no usernames, profiles, DMs, or reply channel. |
| Shares user location | **No** | No location collected. |
| Digital purchases | **Yes** | Auto-renewing subscription (entitlement `pro`). |

## UGC safety declarations (important for Play policy)

- User content **can be shared** and shown **anonymously** to other users after
  passing an **automated (AI) moderation gate**. Content is **not
  human-pre-screened**; disclose this.
- **Report** and **block** controls are provided in-app (CONTRACTS §3
  `apply_report`, blocks table). Report removes an entry from serving and flags
  it; block prevents an author's entries from being served to the user again.
- **Enforcement:** accounts are suspended after a threshold of upheld reports
  (`UPHELD_REPORTS_TO_SUSPEND = 3`).
- A published **Terms of Use** defines and prohibits objectionable content
  (`LEGAL/terms-of-use.md`), as required by Google Play's UGC policy.

## Recommended outcome
Given anonymous UGC that can be shared plus 18+ enforcement, expect a **mature
(18+) rating** across boards (e.g. IARC → ESRB Mature 17+ / PEGI 18 / USK 16-18),
driven mainly by the UGC and unrestricted-user-interaction factors rather than by
inherent app content. Set the app's **target age to 18+** and complete the UGC
sections carefully. Re-run the questionnaire if content handling changes.

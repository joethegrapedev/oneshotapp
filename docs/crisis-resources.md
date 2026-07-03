# Crisis resources (Singapore) — build-time verification

One Shot routes possible self-harm content to crisis resources instead of the
shared pool (moderation `held_selfharm`; CONTRACTS §5). The edge function returns
a `crisis` payload (CONTRACTS §4) and the app also ships a **local fallback copy**
in `lib/features/crisis/crisis_screen.dart`.

> **CRITICAL:** Hotline numbers, names, and operating hours change. **Every one
> of the entries below MUST be re-verified against the official sources before
> each store submission** (and periodically after). Do not ship stale crisis
> information. Treat the values below as *placeholders pending verification*.

## Resources to verify

| Resource | Contact (verify) | Hours (verify) | Source to check |
|---|---|---|---|
| **Emergency services** (police/ambulance) | **995** | 24h | Official SG government / SCDF |
| **Samaritans of Singapore (SOS)** 24h hotline | **1767** | 24h | https://www.sos.org.sg |
| **SOS CareText** (WhatsApp) | **9151 1767** | Check current hours | https://www.sos.org.sg |
| **national mindline / mindline.sg** | **1771** and web chat at https://mindline.sg | Check current hours | https://mindline.sg |

> Note: CONTRACTS §9 lists the SOS hotline as "1-767"; the widely published
> number is **1767**. Confirm the exact current dialling format at
> https://www.sos.org.sg before submission and align the app + edge function.

## Verification checklist (run before each submission)

- [ ] Open **https://www.sos.org.sg** — confirm the **24h hotline number**
      (currently shown as **1767**) and its exact dialling format.
- [ ] Confirm **SOS CareText** WhatsApp number (**9151 1767**) and its current
      operating hours.
- [ ] Open **https://mindline.sg** — confirm the **1771** number, web-chat
      availability, and current hours.
- [ ] Confirm **995** as the emergency number for Singapore.
- [ ] Ensure the values match in **both** places:
      - `supabase/functions/_shared/moderation.ts` / the `moderate-and-pool`
        crisis payload, and
      - the local fallback in `lib/features/crisis/crisis_screen.dart`.
- [ ] Confirm each hotline `note` still reads sensibly (e.g. "verify at build
      time" removed or updated) and links open via `url_launcher` (tel:/https).
- [ ] Record the verification **date** and who verified, in the PR that ships the
      release.

## Notes
- The app renders whatever the edge function returns in the `crisis` payload; the
  local copy is a fallback for offline / cold-start.
- Keep phrasing supportive and non-judgmental; the crisis screen is shown at a
  vulnerable moment.
- Last verified: **[FILL IN DATE]** by **[NAME]** — update on every release.

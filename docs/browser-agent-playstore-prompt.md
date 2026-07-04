# Paste this to the browser Claude (it has your Play Console + RevenueCat open)

Everything it needs is below. It should complete every step it can and only stop
for the few things that genuinely require you (payment, email confirmation, the
final AAB upload). Copy from the line below to the end.

---

You are driving my browser. I have the **Google Play Console** and **RevenueCat**
dashboards open (RevenueCat is on the "New Play Store configuration" screen). Set
up my app end-to-end as far as possible. **Fill in every form yourself using the
values I give below** — do not ask me to type things. Only pause and ask me when a
step genuinely requires me (spending money, clicking a link in an email, a
legal/business decision, or uploading the app binary which I build separately).
Work top to bottom. After each dashboard section, tell me in one line what you
finished. At the very end, give me a short list of any values I need to copy back
to my developer (see "Report back" at the bottom).

## App facts (use these everywhere)
- App name: **One Shot**  (if that exact name is taken on Play, use **One Shot: Private Journal**)
- Package / applicationId: **com.oneshot.journal**
- Platform: Android (Flutter). iOS comes later — ignore iOS.
- Category: **Lifestyle**
- Content: **18+ / mature**, single launch country: **Singapore**, currency **SGD**.
- What it is: a private journaling app with an **opt-in anonymous exchange** —
  when a user shares an entry it passes an **automated AI moderation gate** before
  it can be shown, anonymously, to one other user. Users can keep any entry fully
  private. No usernames, no profiles, no direct messaging, no reply channel.
- Monetization: hard paywall, auto-renewing subscription with **weekly** and
  **yearly** options.
- Support email: **johntowzhichongdev@gmail.com**
- **Privacy Policy URL:** https://claude.ai/code/artifact/7398c441-773d-46c9-b57f-06f177954f63
- **Terms of Use URL:** https://claude.ai/code/artifact/93f6bd3a-e28f-44d2-be7a-06ac8655c874
  (both are live public pages; use them wherever a Privacy Policy or Terms URL is required)

---

## PART A — RevenueCat (the screen currently open)

1. There's a banner saying my email isn't confirmed / "Failed to re-send." **I
   must click the confirmation link in my email — you can't do this. Remind me
   and continue with everything else.**

2. On the **New Play Store configuration** form:
   - **App name:** `One Shot (Play Store)`
   - **Google Play package name:** `com.oneshot.journal`
   - **Service Account Credentials JSON:** this needs a Google Cloud service
     account with Play access. Do this now (steps in PART B-0), download the JSON,
     then come back and upload it here. If you can't complete B-0 for any reason,
     tell me exactly what's blocking and I'll paste the JSON.

3. After the Play Store app is connected in RevenueCat, configure:
   - **Entitlement:** create one with identifier **`pro`** (exactly this).
   - **Products:** import/add the two Play subscription base plans created in
     PART C: `pro:weekly` and `pro:annual`. Attach BOTH to the `pro` entitlement.
   - **Offering:** create/confirm an offering named **`default`**, marked current,
     with two packages:
       - **Weekly** package → product `pro:weekly`
       - **Annual** package → product `pro:annual`
   - Use RevenueCat's standard package identifiers (`$rc_weekly`, `$rc_annual`).
   - Find the **Android public SDK/API key** (Project settings → API keys →
     Google Play, the "public app-specific" key). Copy it for "Report back."

---

## PART B — Google Play Console: prerequisites

**B-0. Service account for RevenueCat (needed by PART A step 2):**
   a. In Play Console → **Setup → API access** (or Users & permissions), find or
      create a linked Google Cloud project.
   b. In Google Cloud Console → IAM & Admin → **Service Accounts** → create one
      (e.g. `revenuecat-billing`). Create a **JSON key** and download it.
   c. Enable the **Google Play Android Developer API** for that project.
   d. Back in Play Console → **Users & permissions → Invite new user**, add the
      service account email, and grant it at least: **View financial data** and
      **Manage orders and subscriptions** (app-level is fine). 
   e. Give that JSON to PART A step 2.
   If any sub-step needs me to pick a billing project or accept terms, ask me.

**B-1. Create the app** (if not already created):
   - Play Console → **Create app**
   - App name: **One Shot** (fallback above), Default language **English (US)**,
     App type **App**, **Free** (subscriptions are separate), accept declarations.

---

## PART C — Subscriptions (Play Console → Monetize → Subscriptions)

Create ONE subscription with TWO base plans (this matches the app + RevenueCat):

- **Subscription product ID:** `pro`
- **Name:** `One Shot Pro`
- **Base plan 1:**
   - Base plan ID: `weekly`
   - Type: **Auto-renewing**, billing period **1 week**
   - Price (Singapore): **S$6.98**
- **Base plan 2:**
   - Base plan ID: `annual`
   - Type: **Auto-renewing**, billing period **1 year**
   - Price (Singapore): **S$54.98**
- Activate both base plans. Availability: Singapore (add more countries later if
  I ask). Leave free trials/intro offers off for now unless I say otherwise.

(These IDs must stay exactly `pro`, `pro:weekly`, `pro:annual` so RevenueCat and
the app line up.)

---

## PART D — Play Console "App content" / Policy declarations

Complete each section under **Policy → App content** with these answers:

**Privacy policy:** enter this URL:
`https://claude.ai/code/artifact/7398c441-773d-46c9-b57f-06f177954f63`

**Ads:** No, this app does **not** contain ads.

**App access:** All functionality is behind a **paywall + anonymous sign-in**, so
reviewers need access. Provide these review instructions in the "instructions"
box: *"The app uses anonymous sign-in (no login needed). All features are behind a
subscription paywall. Please use a Play license-test account, or contact the
developer for a promo code, to bypass the paywall for review. The optional
'exchange' shows one anonymous, AI-moderated entry from the shared pool."* If Play
lets me add a license-tester email, add **johntowzhichongdev@gmail.com** under
Setup → License testing.

**Content ratings (IARC questionnaire):** start it and answer:
   - Category: **Utility / Productivity / Communication** (or "Reference/News/Other"
     if that's the closest non-game option). This is **not a game**.
   - Violence: **No**. Sexuality/nudity: **No**. Controlled substances: **No**.
     Gambling: **No**. Fear/horror: **No**. Crude humor: **No**.
   - **Does the app let users interact or exchange content?** **Yes.**
   - **Can users share user-generated content?** **Yes** — text entries can be
     shown anonymously to other users after automated AI moderation.
   - **Can users communicate / message each other?** **No** — anonymous, no DMs,
     no profiles, no reply channel.
   - Shares location: **No.** Digital purchases: **Yes** (subscription).
   - Profanity may appear in **user-generated** text — declare as UGC.
   Expect a mature (18+) rating; that's intended.

**Target audience and content:**
   - Target age group: **18 and over only.** Not designed for children.
   - Do not appeal to children: **correct / no.**

**Data safety:** fill the form using these answers:
   - Does the app collect or share user data? **Yes** (collect; sharing limited to
     processors).
   - Encrypted in transit? **Yes.** Users can request deletion? **Yes** (in-app,
     Settings → delete account). Data sold? **No.** Used for ads? **No.**
   - Data types collected & purposes:
       - **Email address** (only if the user links one) — Account management —
         optional — not shared for third-party use — encrypted — deletable.
       - **User IDs** (anonymous auth id) — App functionality (account) — required.
       - **Other user-generated content / "Messages"** (journal text) — App
         functionality + safety moderation — writing is core; **sharing an entry
         is optional**. Processed by OpenAI (moderation of *shared* text only) and
         stored by Supabase. Encrypted, deletable.
       - **App activity: other actions** (reports/blocks) — Safety / abuse
         prevention — optional (user-initiated).
       - **Purchase history** — manage subscription — required (via Google Play /
         RevenueCat).
       - **App interactions / diagnostics** — ONLY if I tell you analytics is on;
         otherwise **do not** declare analytics.
   - Explicitly **NOT collected:** location, contacts, photos/videos/files/audio,
     health/fitness, calendar, SMS/call logs, advertising ID.

**Government apps / Financial features / Health / News:** **No** to all.

**Advertising ID:** the app does **not** use it — declare accordingly.

---

## PART E — Store listing (Play Console → Grow → Main store listing)

- **App name:** One Shot (or fallback)
- **Short description (≤80 chars):**
  `A private journal you can keep — or share one entry to read a stranger's.`
- **Full description:**
```
One Shot is a calm, private place to write.

Keep everything to yourself — your journal is private by default. Or, when you
feel like it, share a single entry and, in return, read one honest entry from
someone you'll never meet. It's an opt-in exchange: anonymous, gentle, and
completely optional.

• Private by default. Any entry you write stays yours unless you choose to share it.
• A quiet exchange. Share an entry and read one from a stranger — no names, no
  profiles, no messaging, no way to reply. Just words.
• Safety first. Anything shared passes an automated moderation check before it
  can ever be shown to someone else. You can report or block at any time.
• Beautiful and distraction-free. A warm, paper-like writing surface designed to
  help you think.

One Shot is for adults (18+). Sharing is always your choice, and you can keep
writing privately forever if you prefer.

One Shot Pro unlocks the app with a weekly or yearly subscription. Subscriptions
renew automatically until cancelled; manage or cancel anytime in Google Play.
```
- **App icon (512×512), Feature graphic (1024×500), phone screenshots (≥2):** I
  will provide these images — tell me this is the one thing you need assets for,
  and leave placeholders/draft saved. Do not generate fake screenshots.
- **Contact email:** johntowzhichongdev@gmail.com
- **Category:** Lifestyle. Tags: journal, diary, mindfulness, writing, wellbeing.

---

## PART F — What to STOP before
- **Do NOT create/submit the production release.** I build the app bundle (AAB)
  on my own machine and will upload it myself. You can set up an **internal
  testing** track shell if useful, but do not upload a binary and do not click
  "Send for review."
- Do not enter or invent a Privacy Policy / Terms URL — ask me for the live URLs.
- Do not spend money or accept paid agreements without asking.

## Report back (give me these at the end)
1. The **RevenueCat Android public API key** (starts with `goog_…`).
2. Confirmation the subscription IDs are exactly `pro`, `pro:weekly`, `pro:annual`.
3. Which sections are **Complete** vs **still need me** (privacy URL, images,
   email confirmation, AAB upload).
4. Anything Play flagged that needs a human decision.

# Tests

Run all Dart/Flutter tests from the repo root:

```bash
flutter test
```

Run a single file:

```bash
flutter test test/models_test.dart
```

These are pure Dart + widget tests — no device, no network, no live Supabase.
Font fetching is disabled in the widget test (`GoogleFonts.config.allowRuntimeFetching = false`)
so runs stay offline and deterministic.

## What each test asserts

### `models_test.dart` (unit)
- **`Entry.fromJson` / `toInsertJson`**: parses all columns and derives
  `isPrivate` / `isInPool`. Critically asserts `toInsertJson()` **never**
  includes `is_shareable` — the client is not allowed to assert pool
  eligibility (CONTRACTS §2 `entries.insert`). Also checks `visibility` and
  `moderation_status` mapping, and that `isInPool` requires **both**
  `is_shareable == true` **and** `moderation_status == clean`.
- **`ModerationStatus.fromDb` / `.db`**: every known db string maps to the right
  enum, unknown/null falls back to `private`, and a full `db → fromDb`
  round-trip holds for every value.
- **`ModerationOutcome.fromJson`**: clean outcome has no crisis resources;
  `held_selfharm` parses the nested `crisis.resources[]` into `CrisisResource`s
  (name/contact/hours/note, with safe defaults); unknown status defaults to
  `rejected_objectionable` with `isShareable == false`.
- **`ServedEntry.fromJson`**: the minimal anonymous served shape
  (id, body, createdAt, authorId), tolerant of a missing body.
- **`Profile.isOnboarded`**: true only when `age_confirmed` **and**
  `tos_accepted_at != null`; `hasAcceptedTos` reflects the timestamp presence.

### `moderation_gate_contract_test.dart` (unit, mocktail)
Uses a `Mock implements ModerationRepository` to assert the write-flow contract
at the repository/model layer — no live edge function:
- `clean` → `isShareable == true`, `isSelfHarm == false`.
- `held_selfharm` → `isSelfHarm == true`, `isShareable == false`, crisis
  resources present (self-harm always routes to support).
- `rejected` and `rejected_objectionable` → `isShareable == false`.
It also re-asserts the security contract that the client never sets
`is_shareable`: `Entry.toInsertJson()` omits it even when the local object has
`isShareable == true`. The server (service role / SECURITY DEFINER) is the sole
authority for pool promotion.

### `widget_smoke_test.dart` (widget)
Pumps screens inside a `ProviderScope` with mocktail fakes, wrapped in a plain
`MaterialApp` (not `MaterialApp.router`) — the screens build standalone and use
`context.goNamed` only inside callbacks, so no GoRouter is required:
- **CrisisScreen**: builds; shows the supportive headline
  ("You matter. Support is available."), the local fallback resources
  (e.g. Samaritans of Singapore), and the 995 emergency caption.
- **ReadBackScreen** with `serveOne()` → `null`: shows the kind cold-start
  empty state ("No entries to read just yet…"). Never fabricates entries.
- **ReadBackScreen** with a served entry: shows the body and the two distinct
  safety actions, **Report** and **Block writer** (kept separate per Google
  Play UGC rules).
- **JournalScreen** with empty `myEntries`: shows "One Shot" title, Write /
  Read one actions, and the empty-state copy. With one entry, shows the body
  snippet and its "Private" status chip.

## Backend RLS tests (not run by `flutter test`)

The security-critical **failing-attempt** integration tests live under
`supabase/` (SQL / pgTAP against the migrations in `supabase/migrations/`, run
via the Supabase CLI, not the Flutter toolchain). They assert that the RLS
policies and column-guard triggers in `0002_rls.sql` reject what the client
must never be able to do (CONTRACTS §2):

- A normal authenticated client **cannot `select` the pool directly** — only
  its own entries or rows served to it via `matches`.
- A client **`insert` with `is_shareable = true` is rejected** (only
  `false` + `moderation_status in ('private','pending')` is allowed).
- A client **`update` that changes `is_shareable`, `moderation_status`, or
  `moderation_categories` is rejected** by the guard trigger; only body /
  visibility edits and a self `moderation_status='removed'` soft-delete pass.
- A client **cannot `insert` into `matches`** (only the `serve_entry`
  SECURITY DEFINER function does) and **has no access to `moderation_log`**.
- `profiles.suspended` / `report_strikes` are **not client-updatable**.

These belong to the backend module; keep them alongside the SQL so they run in
the Supabase CI, separate from `flutter test`.

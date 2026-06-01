# M6 — Polish (Design Spec)

**Date:** 2026-06-02 · **Milestone:** M6 (issue #6) · **Tasks:** T22–T24 · the
finishing layer for the MVP.

## Context
M1–M5 deliver the full product loop. M6 hardens it: offline resilience,
accessibility, consistent states, and a CI coverage gate.

## T22 — Offline persistence
The handoff framed this as "Hive ↔ Firestore sync", but **`cloud_firestore`
already provides offline-first behavior**: local cache, queued writes, and
read-from-cache when offline are on by default on mobile. A parallel Hive mirror
would duplicate that, double the write path, and add a reconciliation bug
surface — for Firestore-backed data it is redundant. Bundled data (exercises /
programs / skills) is already offline (assets). So T22:
- Explicitly enable + size Firestore persistence in `firebase_providers`
  (`Settings(persistenceEnabled: true, cacheSizeBytes: unlimited)`), so offline
  is intentional and generous, not implicit.
- Document the "Firestore cache, not Hive" decision in an ADR-style note.
(Hive stays a dependency for any future non-Firestore local cache; not used now.)

## T23 — Accessibility + states
- `Semantics` labels / tooltips on icon-only controls (set steppers, skill
  steppers, log `+` buttons, day/skill nav) so screen readers announce them.
- Audit every async surface for loading / error / empty (most already have them;
  fill any gaps).
- Light, tasteful motion already present (modal transitions, summary dialog);
  ensure nothing janky. No heavy animation work.

## T24 — Coverage gate
- CI runs `flutter test --coverage` and fails if line coverage drops below a
  threshold (start at a realistic bar given the current suite, e.g. 70%),
  enforced by a small step parsing `coverage/lcov.info`.
- Fill obvious gaps to clear the bar.

## Out of scope (owner / later)
Live Firebase + on-device offline verification (`flutterfire configure`),
function deploy, iOS/Android release builds + signing.

## Acceptance (M6 / MVP exit)
Offline persistence enabled + documented; icon controls are screen-reader
labelled; CI enforces coverage. The app is code-complete for the MVP, pending
the owner's Firebase/Apple steps.

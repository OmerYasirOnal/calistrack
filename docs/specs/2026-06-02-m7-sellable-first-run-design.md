# M7 — Sellable First-Run (Onboarding + Coaching + AdMob)

**Date:** 2026-06-02
**Status:** Design — awaiting owner approval
**Milestone:** M7 (post-MVP). Turns the technically-complete MVP into a product a
real, first-time user can be dropped into and convert — the gap surfaced by the
2026-06-02 new-user-journey audit (5-agent workflow).

## Problem (from the audit)

The MVP is technically sound (auth, Riverpod, go_router gating, AI generation,
safe empty states) but the **first run is not sellable**:

1. **No onboarding.** A new user is dropped straight onto an empty `Today`
   ("No active program yet"). First-run == returning-user. The 5 great
   personalization questions are buried behind the `Generate` FAB on the
   Programs tab instead of being step 1.
2. **No coaching/education.** `description` fields are one-liners ("Horizontal
   push."); empty Progress/Skills tabs don't guide; steppers lack context.
3. **No monetization.** Zero revenue code. **Owner chose AdMob (ads)**, not a
   paywall — app stays fully free, revenue from ads.

Plus the funnel dead-ends: activating a program dumps the user back on Programs
with no nudge to return to Today.

## Decisions (owner-approved)

- **Scope:** full sellable pass — onboarding + coaching + monetization.
- **Monetization model:** **AdMob** (`google_mobile_ads`). App free; revenue from
  ads. No paywall/IAP. (Studio charter explicitly permits AdMob as revenue-side.)
- **AI-key constraint unchanged:** OpenAI only via the server-side Cloud Function;
  ads/onboarding never touch it.

## Non-goals (deliberately deferred — not gold-plating)

- IAP/subscription/paywall (model is ads).
- Demo videos, social proof carousel, friends/leaderboards.
- Push notifications / streak reminders (Phase 2 retention work).
- Guest/anonymous "try before sign-up" mode (recommended fast-follow, not in M7).

## Architecture overview

Three independent workstreams, each task = its own issue + branch + PR + a fresh
zero-context adversarial review + merge (the established discipline). Workstream A
is the spine; B and C are largely independent and can be built in parallel.

```
A. Onboarding (spine)        B. Coaching/education       C. Monetization (AdMob)
   T25 model + router gate      T28 exercise coaching       T30 android/ios + dep + IDs
   T26 Welcome + About You      T29 guidance polish         T31 AdService + banner + interstitial
   T27 Program + primer
```

### Workstream A — Onboarding

A one-time, ~90-second, 4-screen flow that runs once after first sign-up and ends
with the user on a ready-to-train `Today` tab.

- **T25 — Gate + state.** Add `onboardingCompletedAt: DateTime?` to `AppUser`
  (+ JSON round-trip, `copyWith`, default null). In `app_router.dart`'s redirect:
  once `signedIn`, if the loaded profile has `onboardingCompletedAt == null` and
  not already on `/onboarding`, redirect to `/onboarding`. `_bootstrapProfile`
  already guarantees the doc exists, so the flag is readable immediately.
  `OnboardingController` (Riverpod) holds in-progress answers; writes the flag on
  completion so the flow never repeats. **Test:** new profile → routed to
  onboarding; completed profile → routed to `/today`.
- **T26 — Screens 1–2.**
  - *Welcome:* branded panel (dumbbell + "CalisTrack") + one-line value prop
    ("Track calisthenics, build strength, unlock skills") + "Get started".
  - *About You:* experience level (segmented), goal chips (multi), days/week
    slider 1–7, equipment chips (Bar/Rings/Parallettes/None), optional collapsible
    body stats (height/weight) with a clear **Skip**. Reuses the existing
    `AiGenerationScreen` form widgets. Persists to `AppUser` (level/goals/
    heightCm/weightKg). **Test:** answers persist to the profile.
- **T27 — Screens 3–4 + funnel fix.**
  - *Your program:* feed About-You answers into the **existing** AI-generation /
    recommendation path; present ONE recommended program with a plain-language
    summary ("3 days/week · strength · bar+rings") + a "See other programs"
    escape hatch to presets. "Start this program" → existing set-active logic
    (writes `activeProgramId`).
  - *First-session primer:* show Day-1 exercises with names + one-line cues + a
    short legend for set types and the +/- steppers. Sets
    `onboardingCompletedAt = now()`, routes to `/today` with **Day 1 pre-selected**.
  - *Funnel fix (global):* after activating any program (onboarding OR Programs
    tab), navigate to Today with the next day pre-selected + a one-time hint.
    Kills the "dumped on Programs" dead-end. **Test:** completing onboarding sets
    the flag, sets an active program, and lands on Today with a day selected.

### Workstream B — Coaching / education

- **T28 — Exercise coaching content.** Enrich `assets/data/exercises.json`: keep
  `name`, expand `description` into a genuine one-line **cue** (e.g. "Hands under
  shoulders, body in a straight line, lower until elbows ~90°"). Add an optional
  `tips` array if useful. Audit every surface (program detail, today logger,
  AI preview) to confirm the human-readable `name` + cue is shown, never the raw
  `id`. Verify/add stepper tooltips (some added in T23). **Test:** a known
  exercise renders its name + cue; no raw id leaks to UI.
- **T29 — Guidance polish.** Progress empty state gains a CTA button ("Log your
  first workout" → Today). Skills tab gains a dismissible explainer banner ("Log
  workouts to progress these skills"). Add a brief **post-session celebration**
  after a finished workout explaining what Progress + Skills now track. **Test:**
  empty Progress shows the CTA; first finished session shows the celebration once.

### Workstream C — Monetization (AdMob)

- **T30 — Platforms + dependency + IDs.** `flutter create . --platforms=android,ios`
  to add the native folders (also required to ship at all). Add
  `google_mobile_ads`. Put the AdMob **App ID** in `AndroidManifest.xml` +
  iOS `Info.plist`. Use Google's official **TEST** App ID + test ad-unit IDs as
  placeholders, each with a **paired TODO** ("owner: replace with real AdMob unit
  before release") — no magic numbers: IDs live in
  `assets/data/ad_config.json` (test vs prod, gated by build mode). CI stays
  green (web build unaffected; ads are mobile-only). **Test:** ad-id config loads;
  the prod-vs-test selection logic.
- **T31 — AdService + placements.** `AdService` abstraction that is a **no-op on
  web / unsupported platforms** (so `lib/preview.dart` and CI are unaffected).
  Placements (low-friction, non-dark-pattern):
  - **Banner** anchored on the Progress tab (content-dense, not the training flow).
  - **Interstitial** after *finishing* a session — **frequency-capped** (e.g. at
    most once per N finished sessions / cooldown window; cap value in
    `ad_config.json`, no magic numbers). Never interrupt mid-set.
  - **GDPR/UMP consent** + iOS **ATT** prompt stubbed with a clear owner-TODO
    (real consent needs the owner's AdMob + privacy policy URL).
  **Test:** frequency-cap logic (Nth session triggers, others don't); web/unsupported
  → no-op; cap value read from config.

## Owner-only steps (flagged, cannot be done from this session)

- Real **AdMob** account + app + ad-unit IDs (swap the test placeholders).
- **Privacy policy + terms** URLs (required by both stores, by Google sign-in, and
  by AdMob/UMP consent).
- iOS **ATT** string in `Info.plist` is added; real ATT requires the owner's
  App Store metadata.
- App icon + branded splash + store screenshots (recommended fast-follow).

## Recommended fast-follow (not in M7, flagged for sequencing)

`Forgot password?` + email verification + branded splash — the audit's remaining
majors. Cheap, removes refund/lockout landmines. Propose as **M8** after M7 lands.

## Testing strategy

Every task ships a widget/unit test (per the project discipline) and keeps the
suite + coverage gate (≥75%) green. Onboarding routing is tested with provider
overrides (no Firebase). AdService is tested via its abstraction (no real SDK
calls in tests; web no-op path is the default test target). Visual proof per
workstream via `lib/preview.dart` (onboarding gets a preview entrypoint variant).

## Definition of done

A brand-new user: sign up → guided onboarding (value prop → about you →
recommended program → primer) → lands on a ready Today with Day 1 selected → logs
a set with visible coaching cues → sees Progress/Skills guidance → encounters ads
at non-intrusive placements. CI green, coverage ≥75%, every task adversarially
reviewed. The only things between this and a live build are the owner-only steps.

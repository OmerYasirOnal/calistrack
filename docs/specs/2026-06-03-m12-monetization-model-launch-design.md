# M12 — Monetization (Freemium) + On-Device Model + Live Web (Design Spec)

**Date:** 2026-06-03 · **Milestone:** M12 (post-launch growth) · **Tasks:** T40–T45
**Status:** Approved (owner) · brainstorm → this spec → build.

## Context

CalisTrack is code-complete (M1–M11) with **ads-only** monetization (`AdService`, no
entitlement gating) and a **paid-OpenAI** AI program generator (a Cloud Function, undeployed;
client falls back to a local template). The owner wants, on a **$0 budget**:

1. A research-backed **freemium** model (free+ads + Pro subscription) — strategy in
   [`docs/strategy/2026-06-03-monetization-strategy-brief.md`](../strategy/2026-06-03-monetization-strategy-brief.md).
2. A **tiny on-device ML model** that runs for $0, offline, in-app.
3. A **live web/PWA** deploy at $0, plus a store-ready mobile package (store publish is owner-only).
4. A re-review of the project and a **financial roadmap with real charts**.

Constraints proven this session: Flutter 3.38.9, Python 3.14, `gh` (authed) are all local;
`wrangler`/`firebase` are not (so live deploy goes via GitHub Actions → GitHub Pages, no extra
login). `lib/preview.dart` is a Firebase-free in-memory demo with seeded progression history — it
is the live-web artifact.

## Non-goals (deliberately deferred — not gold-plating)

- Real store publishing (Apple $99/yr, Google $25, signing, devices) — **owner-only**; documented.
- Real RevenueCat / AdMob / Firebase credentials & deploy — **owner-only**; code ships ready.
- Cloud sync, social features, paid LLM, pose-estimation/camera ML.

## Architecture — six workstreams

### T40 — On-device model: training (Python) → exported weights

`tools/ml/` (gitignored venv): a reproducible Python pipeline that

1. **Generates synthetic training data** from verified progression heuristics (double progression,
   RPE autoregulation, deload ~5 wk, novice LP, 2-session stall rule). Each sample = features for one
   exercise's recent history + a heuristic label.
2. Trains a **logistic-regression** "progression-readiness" classifier (3 classes via one-vs-rest or
   a small decision head: `DELOAD` / `HOLD` / `PROGRESS`; plus a regression/rule for the concrete next
   target). scikit-learn; standardized features (mean/std stored).
3. Prints **metrics** (accuracy, per-class precision/recall, confusion matrix) and a held-out
   evaluation — this is the "training we go through together"; we may tune features/threshold.
4. **Exports** weights + bias + feature normalization to `assets/data/progression_model.json`
   (mirrors the `training_defaults.json` asset pattern). The rule-based heuristic is retained as the
   ground-truth oracle.

**Test:** the export round-trips and the Python model's predictions on a fixed eval set are saved as
golden cases for the Dart parity test (T41).

### T41 — On-device model: pure-Dart inference + "Smart next target" feature

- `lib/features/progress/application/progression_model.dart` — loads
  `assets/data/progression_model.json`, standardizes features, computes `z = w·x + b`,
  `sigmoid`/softmax, returns a `ProgressionSuggestion {action, targetReps?, targetAddedWeightKg?,
  rationale, confidence}`. **Pure Dart, no native deps** → works on web. Falls back to the rule-based
  heuristic if the asset is missing.
- Feature extraction from existing `ExerciseDataPoint`/`LoggedSet` history (rep trend, top-of-range
  hit, sessions-at-load); RIR optional (see T42).
- **UI:** a "Smart target" chip/line on the `exercise_logger_card` (Today) and/or the program-detail
  view — replaces the bare "last time" pre-fill with a recommended next target + one-line rationale.
  **Free feature** (cheap, retention/wow).
- **Test:** Python↔Dart **parity** on the golden eval set (predictions match within tolerance);
  suggestion mapping; missing-asset fallback to heuristic; pure function unit-tested.

### T42 — `LoggedSet` optional effort field

- Add optional `rir`/`effort` (`int?`) to `LoggedSet` (`lib/models/workout.dart`) with JSON
  round-trip + `copyWith`. The model uses it when present; everything still works without it (so
  existing data + the web preview suffice). Optional small UI affordance to record it.
- **Test:** JSON round-trip with/without the field; model uses default when absent.

### T43 — Freemium scaffolding: entitlement + ad gating + paywall

- `lib/features/billing/application/entitlement.dart` — `Entitlement {isPro, adsRemoved, source}` +
  `entitlementProvider` (Riverpod). Default **free**. A `DemoEntitlementController` lets the web
  preview toggle Pro to show both states. Real source (RevenueCat `purchases_flutter`) is an owner
  step — the provider is the seam; **no store SDK wired/charged here**.
- **Gate ads on `!isPro`:** `AdService.banner()`/`maybeShowInterstitial()` become no-ops when
  `adsRemoved`. Keep `shouldShowInterstitial` pure.
- **Paywall** (`lib/features/billing/presentation/paywall_screen.dart`): Pro benefits, 3 plans
  ($5.99/mo, $29.99/yr highlighted, optional $79 lifetime), restore button (stub), legal links
  (privacy/terms — owner URLs TODO). Pricing + copy in an asset (`assets/data/pricing.json`), no
  magic numbers.
- **Pro gates:** AI program generation + full skill-trees + advanced analytics show a Pro lock →
  paywall (or "watch a rewarded ad to unlock once" upsell hook, behind the existing AdService
  abstraction; rewarded is a fast-follow if the SDK call is non-trivial).
- **Test:** ads no-op when Pro; paywall renders all plans from config; gated feature routes to
  paywall when free; entitlement default is free.

### T44 — Live web/PWA deploy (GitHub Actions → GitHub Pages)

- `.github/workflows/deploy-web.yml` — on push to the deploy branch / manual dispatch: set up Flutter,
  `flutter build web --release -t lib/preview.dart --base-href /calistrack/`, publish `build/web` to
  GitHub Pages. PWA manifest already present (`web/manifest.json`).
- A short `docs/DEPLOY-WEB.md`: the one setting the owner flips (Pages → GitHub Actions) and the
  Cloudflare Pages swap for the commercial launch.
- **Verify:** the workflow builds green; the published URL loads and the demo (incl. Smart-target +
  paywall) works in a real browser.

### T45 — Re-review + financial roadmap with charts

- **Re-review:** multi-agent adversarial workflow over the new diff (correctness, repo separation
  rules, test/coverage discipline, security, strategy-consistency). Findings fixed on-branch.
- **Financial model + charts:** `tools/finance/model.py` (matplotlib) → real PNGs in
  `docs/finance/`: (1) 18-month revenue scenarios low/base/high; (2) cumulative net cash incl.
  $25/$99 costs; (3) revenue mix subscription vs ads; (4) sensitivity conversion% → MRR; (5) funnel.
  Parameterized by **monthly installs** as scenarios (the largest unknown — ranges, not a point
  estimate). Uses the §7 inputs (rows 1–3, 5, 7–15); the §7 row-6 RLTV/payer is
  an independent top-down cross-check, not a bound input (the bottom-up model
  derives its own per-payer LTV from price × mix × churn).
- **Roadmap:** `docs/finance/ROADMAP-FINANCIAL.md` — Mermaid gantt (Now → web/PWA → Android paywall →
  iOS) + the charts + a plain-language financial read.

## No-magic-numbers / security

Pricing, model weights, and ad pacing live in `assets/data/*.json`. No secrets added. The OpenAI key
constraint is unchanged (server-only); the on-device model needs no key. Entitlement defaults to free
(no accidental Pro unlock). Ads remain GDPR/UMP + ATT gated as today.

## Testing strategy

Every task ships unit/widget tests; the suite + ≥75% coverage gate stay green (`flutter analyze`
clean, `flutter test`). Model parity is enforced against Python golden cases. Web/no-op ad paths are
the default test target (no real SDK calls).

## Task order

**T42** (model field) → **T40** (train+export) → **T41** (Dart inference+feature+parity) →
**T43** (freemium) → **T44** (web deploy) → **T45** (re-review + finance). Logical commits; PR at the
end (or per workstream).

## Definition of done

Free user sees a $0/offline **Smart-target** suggestion; AI-gen/skill-trees/analytics + ad-removal
sit behind a research-priced **paywall**; ads no-op for Pro; a **live web/PWA URL** demonstrates it
all; the project is **re-reviewed**; and a **financial roadmap with real charts** is presented. The
only gaps to live revenue are the documented owner-only store/credential steps.

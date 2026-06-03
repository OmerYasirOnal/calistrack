# CalisTrack — Monetization & Go-to-Market Strategy Brief

**Date:** 2026-06-03
**Context:** Solo-dev, $0-budget Flutter calisthenics tracker. Freemium (free+ads + Pro
subscription). Web/PWA live now; store-ready mobile later. Tiny on-device "smart
progression" ML model.

> Every number is tagged with **confidence** and **verification** status. Figures marked
> **[CORRECTED]** were refuted or rangified by an adversarial fact-checking pass (a 21-agent
> research workflow: multi-angle web research → independent second-source verification →
> synthesis). Sources are listed in §8.

---

## 1. Monetization strategy

**Principle: subscriptions carry the revenue; ads are a small top-up and an upsell surface.
Build the financial model on Pro, not on ads.**

### Pro price points **[CORRECTED]**

The naive anchor ($9.99/mo, $39.99/yr) is a *cross-category global* median. True
Health & Fitness-specific medians are lower (~$7.73/mo, ~$29.65/yr); the niche calisthenics
freemium cluster sits at **$5.99–9.99/mo** (Calistree/Fitloop $5.99; Caliverse $9.49;
Calisteniapp/Madbarz $9.99), with Thenx the $19.99/mo premium ceiling.

| Plan | Price (USD anchor) | Rationale |
|---|---|---|
| **Pro monthly** | **$5.99/mo** | Undercuts Thenx 3×; matches the Caliverse/Fitloop band. Monthly is intentionally "expensive per month" to steer users to annual. |
| **Pro annual** | **$29.99/yr** (≈ $2.50/mo) | ≈ verified H&F annual median ($29.65). Annual drives ~60% of H&F revenue and 2–4× the LTV. |
| **Lifetime** *(optional)* | **$79–99** | Banks cash from power users at zero CAC; useful for a $0 runway. Confidence: medium. |

**Turkey (confidence: medium):** Do **not** FX-convert the USD price. Turkey is a low-ARPU,
price-sensitive market (German annual H&F prices ≈ 4.4× Turkish for the same product).
Use store-native local tiers: target **₺49–79/mo** and **₺249–399/yr** (≈ 40–60% discount
vs the FX-equivalent). The TR beachhead's job is reviews + Day-7 retention + ranking, **not**
revenue.

### Free vs Pro (the Hevy playbook — free is generous on purpose)

| Free | Pro |
|---|---|
| Unlimited workout logging & history | **AI program generation** (existing `ai_program_service`) — primary paywall hook |
| Basic skill progressions | **Full visual skill-trees** (muscle-up, front lever, planche, handstand) |
| Streaks, basic stats, offline-first | **Advanced progress/skill analytics** |
| **On-device "smart progression" suggestion** (kept free — $0 to run, retention/wow) | **Remove ads** (bundled into Pro; also sold standalone) |
| | Cloud sync / multi-device *(if/when built)* |

### Ad strategy for the free tier

- **Format priority: rewarded video > interstitial >> banner** (rewarded pays ~2–3× interstitial,
  ~10× banner, in every geography). Use rewarded video to *unlock* a feature → doubles as a Pro upsell.
- **Interstitials** sparingly, on natural breaks (post-session). The codebase already has
  `shouldShowInterstitial(finishedSessions, everyN)` — keep `everyN` high (3rd–4th session) to
  protect Day-7 retention (a ranking factor).
- **Gate ALL ads on `!isPro`** so "remove ads" is a one-line flip. `AdService` currently has **no
  entitlement gating** — this is the first thing to add.

### Free→paid conversion (model input) **[CORRECTED]**

Use **net download-to-paid**, NOT the ~38% trial-to-paid headline (that applies only to users who
*start a trial*). Two independent sources converge near ~3% category median; discount for a niche
organic-only launch:

| | LOW | BASE | HIGH |
|---|---|---|---|
| **Net free→paid** | **1.0%** | **2.0%** | **3.5%** |

(2.5% base is also defensible — tracks the category median more closely. HIGH 3.5% sits just above
both medians.)

---

## 2. Ad revenue assumptions **[CORRECTED → rangified]**

Hard ARPDAU benchmarks are almost all from *games*; CalisTrack is a low-ad-density habit-tracking
utility, so realized ARPDAU likely sits at/below the LOW end.

| | LOW | BASE | HIGH |
|---|---|---|---|
| **Ad ARPDAU (USD, TR/EU mix)** | **$0.01** | **$0.03** | **$0.10** |

eCPM hierarchy (verified): rewarded > interstitial >> banner. US rewarded ~$16–20, interstitial ~$14,
banner ~$0.45–0.68; W. Europe interstitial ~$3.3–3.7; Turkey has **no published eCPM** (assume
interstitial ~$2–4, banner <$1). **Do not let ads carry the model.**

---

## 3. Store economics

- **Commission: 15%, not 30%** (high confidence, verified). Apple **Small Business Program**
  (≤$1M proceeds/yr, opt-in — enroll day one); Google Play 15% on first $1M **and** flat 15% on
  auto-renewing subscriptions regardless of revenue.
- **Publish costs:** Apple Developer **$99/yr recurring**; Google Play **$25 one-time**.
- **Net retained at scale:** list − 15% store − ~1% RevenueCat ≈ **~85%** (RevenueCat is **0%**
  below $2,500 MTR).
- **Sequencing for $0 budget:** ship **Android first** ($25), defer the $99/yr Apple fee until an
  iOS paywall release. Web/PWA costs $0 and needs neither.

---

## 4. $0 hosting decision

- **Production target: Cloudflare Pages (Free)** — the only strong *commercial-safe* free static
  host: unlimited static bandwidth/requests (fair-use), free HTTPS + custom domains, caps trivial
  for one SPA (500 builds/mo, 20k files, 25 MiB/file).
- **Now (zero extra owner-auth): GitHub Pages via GitHub Actions** — the repo is already on GitHub;
  a CI workflow builds `flutter build web` and publishes a real live URL with no `wrangler`/`firebase`
  login. (GH Pages is non-commercial-leaning → fine for a *demo/PWA*; swap to Cloudflare for the
  commercial launch — a config change.)
- **Rejected:** Vercel Hobby (non-commercial only), Netlify (new accounts hard-pause on credit
  exhaustion).
- **The real cost trap is Firebase, not the host.** Stay on **Spark ($0)** using only Auth +
  Firestore (50k MAU; 50k reads / 20k writes / 20k deletes per day; 1 GiB stored). **Cloud Functions
  require Blaze** (credit card) — so the existing OpenAI `generateProgram` function forces Blaze if
  deployed. Blaze still bills ~$0 at small scale, but Spark's hard caps no longer protect you → **set
  a budget alert.** Prefer keeping the smart-progression model on-device (no function, stays $0).

---

## 5. On-device model decision

**A tiny logistic-regression "progression-readiness" model (+ optional linear head for next-session
target reps), trained offline in Python on synthetic data, shipped as exported weights run in
~30 lines of pure Dart. No `tflite_flutter`, no `onnxruntime`.**

- **Pure-Dart exported weights is a genuine model** — the trained parameters executing
  `z = w·x + b; p = sigmoid(z)`. **$0**, fully **offline**, **zero native deps**, ~0 binary size,
  data stays **on-device/private**, works **identically on web/mobile/desktop**.
- `tflite_flutter` has **no Flutter web support** + native C libs (dealbreaker — web ships first);
  `onnxruntime` is native-only/heavier; logistic regression beats GBTs here (few features, synthetic
  data → GBTs overfit; logistic is interpretable).
- **0.5 threshold is the tunable default decision rule**, not part of the model (tune 0.3–0.7 later).

**Training with NO real user data — synthetic from verified heuristics:**
- **Double progression (RPE-gated):** rep range not maxed → add reps; maxed at ≤ target RPE → add load.
- **Autoregulation:** working sets RPE 7–8 (2–3 RIR); productive window RPE 7–9.
- **Deload [CORRECTED → rangified]:** every ~5 wk (survey mean 5.6 ± 2.3) — model 4 (low) / 5–6 (base)
  / 8 (high); cut volume 20–30% (widen to 30–60% for severe fatigue).
- **Novice linear progression** for low-experience profiles; **stall/regress** needs 2 consecutive
  successes/failures.

**Inputs (per exercise, from recent set history):** last-session top-set reps; top-of-range hit
(binary); avg RIR/RPE of recent working sets; sessions at current load/variation; fatigue flag;
(optional) experience level. **Output:** `readiness` ∈ [0,1] → progress if ≥ threshold; optional
predicted next-session target reps.

**Required code change:** `LoggedSet` has no effort field — add an **optional** `rir`/effort to
`lib/models/workout.dart`. The model must still work from rep history alone (so existing data + the
web demo suffice). Keep the rule-based heuristic as a transparent fallback **and** as the ground
truth the Dart inference is regression-tested against.

---

## 6. Market & positioning

- **Positioning (1 line):** *"The skill-progression tracker for calisthenics — the gap between Hevy
  (great logging, no skill structure) and Thenx ($19.99/mo videos, weak tracker)."*
- **Wedge:** visual skill-trees (muscle-up / front lever / planche / handstand) + AI program
  generation + privacy/offline-first.
- **Beachhead ($0):** (1) r/bodyweightfitness (2M+) + calisthenics Discords — ship the free tracker
  for the community's "Recommended Routine," earn organic adoption (don't spam). (2) **Turkish listing**
  ("kalisteni") — active scene, low ASO competition → rank #1 cheaply, harvest reviews + Day-7
  retention, compound into English ranking.
- **ASO keywords** (avoid head terms; difficulty **< 50**, volume **20–~50/60 not 20–80** **[CORRECTED]**):
  `calisthenics tracker`, `muscle up workout`, `front lever progression`, `planche progression`,
  `bodyweight workout no equipment`, `pull up push up tracker`. Apple indexes **screenshot caption
  text** (since Jun 2025) — write keyword-rich captions; use Custom Product Pages per skill;
  optimize for **Day-7 retention** (ranking factor) via streaks + skill milestones.
- **Market (confidence: medium):** fitness app market ~$12B (2025); H&F IAP pool ~$4.0B (2024)
  → ~$4.5B (2025, +13% YoY) **[CORRECTED]**; US >50%.

---

## 7. Financial-model input table

"Verified" = independently corroborated by the adversarial verifier. **C** = confidence.

| # | Assumption | LOW | BASE | HIGH | C | Verified | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Net free→paid conversion | 1.0% | 2.0% | 3.5% | High | ✅ **CORRECTED** | Net download-to-paid, not 38% trial figure. |
| 2 | Pro monthly (USD) | $4.99 | **$5.99** | $9.99 | High | ✅ **CORRECTED** | Niche cluster $5.99–9.99. |
| 3 | Pro annual (USD) | $24.99 | **$29.99** | $39.99 | High | ✅ **CORRECTED** | ≈ verified H&F median $29.65. |
| 4 | Lifetime (USD) | $69 | $79 | $99 | Med | ⚠️ competitor-derived | Optional. |
| 5 | Annual mix (% of payers) | 50% | 60% | 67% | High | ✅ | H&F = the category where annual dominates. |
| 6 | Year-1 RLTV / payer (USD) | ~$17 | ~$35.64 | ~$70 | High | ⚠️ researched | Low-tier ~$17, high-tier annual ~$70. |
| 7 | Ad ARPDAU (USD) | $0.01 | $0.03 | $0.10 | Med | ✅ **CORRECTED** | Utility app likely at/below LOW. |
| 8 | Apple commission | — | **15%** | (30% >$1M) | High | ✅ | Opt into Small Business Program. |
| 9 | Google commission | — | **15%** | (30% non-sub >$1M) | High | ✅ | 15% flat on subs. |
| 10 | RevenueCat fee | 0% | 0% | 1% MTR (>$2.5k) | High | ✅ | ~1.4% effective on net; negligible early. |
| 11 | Net revenue retained | ~84% | ~85% | ~85% | High | ✅ derived | list − 15% − ~1%. |
| 12 | Apple Dev fee (recurring) | — | $99/yr | — | High | ✅ | Defer to iOS launch. |
| 13 | Google Play fee (one-time) | — | $25 | — | High | ✅ | Android-first. |
| 14 | Web hosting | $0 | $0 | $0 | High | ✅ | Cloudflare Pages free / GH Pages. |
| 15 | Firebase backend | $0 (Spark) | $0 (Blaze free) | overage risk | High | ✅ | Functions force Blaze; budget alert. |
| 16 | ML run cost | $0 | $0 | $0 | High | ✅ | Pure-Dart on-device. |
| 17 | Download→trial (if used) | — | ~7% | — | High | ✅ | Apply only if a trial exists. |
| 18 | Trial→paid (trialed cohort) | ~28% | ~38% | ~68% | High | ✅ | Do NOT apply to all downloads. |
| 19 | TR Pro monthly (₺) | ₺49 | ₺59 | ₺79 | Low | ⚠️ assumption | Refine vs store tiers. |
| 20 | TR Pro annual (₺) | ₺249 | ₺299 | ₺399 | Low | ⚠️ assumption | ~40–60% discount vs FX. |
| 21 | Deload cadence (ML synthetic) | 4 wk | 5–6 wk | 8 wk | High | ✅ **CORRECTED** | Survey mean 5.6 ± 2.3 wk. |

**Largest unknowns (model as scenarios, not point estimates):** monthly organic installs (depends
entirely on r/bodyweightfitness + ASO traction); TR-specific eCPM & conversion; churn/retention
curves for this niche.

---

## 8. Sources

RevenueCat State of Subscription Apps 2026/2025 & Pricing; Adapty H&F Benchmarks 2026 & State of
In-App Subscriptions 2026; ARPU Brothers 2025 trends; Maf.ad, Bidlogic Q4 2025, Udonis, GameDevReports
(Tenjin) eCPM; Apple Small Business Program / Developer enrollment / Review Guidelines; Google Play
service fees / registration; Cloudflare Pages limits; Firebase Hosting/Firestore/Functions quotas &
pricing & Cloud Storage Blaze change; Vercel Hobby; Netlify pricing; GitHub Pages limits; pub.dev
(tflite_flutter, flutter_onnxruntime, in_app_purchase, ml_algo); Google ML Crash Course (sigmoid);
Wikipedia Logistic Regression; MOPs&MOEs / Hevy Coach (double progression); Calisthenics Association
(autoregulation); Bell et al. deload survey (Sports Medicine–Open 2024); Starting Strength; Grand
View Research; Sensor Tower State of Mobile H&F 2025; Statista (H&F IAP, Turkey H&F); Thenx; Fitloop;
ASOTools / ASO Pulse / ASOMobile. (Full URLs in the research workflow output.)

---

### Three $0 actions this week
1. Add `isPro`/`adsRemoved` entitlement; gate `AdService` on `!isPro`.
2. Add optional `rir`/effort to `LoggedSet`; ship the Python synthetic-data generator + pure-Dart
   inference + parity test.
3. Deploy `flutter build web` to GitHub Pages (Actions); stay on Firebase **Spark**; set a budget
   alert before any Blaze trigger.

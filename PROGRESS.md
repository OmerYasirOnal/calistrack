# CalisTrack — Progress Log

Append-only. Newest at top. One entry per completed task/work session.

---

## 2026-06-02 — 🎉 MVP CODE-COMPLETE (M1–M6 all merged to `main`)
- **Milestones:** M1 Foundation · M2 Auth · M3 Programs & Workout · M4 Progress &
  Skills · M5 AI generation (Cloud Function + fallback) · M6 Polish — all done,
  issues #1–#6 closed, PRs #7–#19 merged (merge commits, history preserved).
- **Quality bar:** CI green on `main` — format · analyze · 69 tests · **80.1%**
  line coverage (75% gate). Every task went through a fresh adversarial review.
- **Architecture:** feature-first (data/application/presentation), Riverpod,
  go_router shell, repository pattern, all balance/preset data in `assets/data/*`
  (no magic numbers), every async surface has loading/error/empty states.
- **AI safety constraint honored:** OpenAI is called **only** server-side from the
  `generateProgram` Cloud Function (auth-gated, key in a Firebase secret). The
  client never holds an API key; it falls back to a local preset when undeployed.
- **Owner-only steps remaining (cannot run from this session):**
  `flutterfire configure` (real Firebase config) · deploy the function
  (`firebase functions:secrets:set OPENAI_API_KEY` + `firebase deploy --only
  functions`) · iOS/Android release builds + Apple/Play signing.

## 2026-06-02 — M6 T24 CI coverage gate [branch feat/calistrack-m6-t24-coverage]
- **Task:** enforce test coverage in CI.
- **Added:** CI `ci.yml` now runs `flutter test --coverage` + a **line-coverage
  gate (≥ 75%)** that parses `coverage/lcov.info` and fails the build below the
  bar. `coverage/` gitignored.
- **Current coverage:** **80.1%** (1503/1876 lines) — comfortably above the gate.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 69/69 pass.

## 2026-06-02 — M6 T22+T23 Offline persistence + a11y polish [branch feat/calistrack-m6-t22-offline]
- **T22 Offline:** enable Firestore persistence explicitly in `main.dart`
  (`Settings(persistenceEnabled: true, cacheSizeBytes: CACHE_SIZE_UNLIMITED)`),
  set after `initializeApp` (only when Firebase is wired). Offline-first via the
  built-in cache; a Hive mirror would be redundant for Firestore data — decision
  documented in the M6 spec.
- **T23 a11y:** tooltips/semantics on the icon-only steppers (logger reps/kg/sec,
  skill +/-, AI days). States audited — every async surface already has
  loading/error/empty.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 69/69 pass.

## 2026-06-02 — M5 T21 AI generation screen + user programs [branch feat/calistrack-m5-t21-ai-screen]
- **Task:** the AI UI — form → generate → preview → save — and surface user
  programs in the Programs tab.
- **Added:** `programs/presentation/ai_generation_screen.dart` (level/days/goals/
  equipment form → Generate → preview w/ fallback banner → Save & set active),
  `AiGenerationController` (generate/save). Programs screen now has a "Generate"
  FAB (pushes the AI screen) + a "Your programs" section (userProgramsProvider).
  Preview extended with an in-memory user-program repo so save works without
  Firebase.
- **Tests:** AI form → generate (fake service) → preview → save persists +
  sets active. `save` now awaits auth (robust to an unresolved auth snapshot).
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 67/67 pass.

## 2026-06-02 — M5 T20 AI client service + persist + fallback [branch feat/calistrack-m5-t20-ai-client]
- **Task:** the client side of AI generation — call the function, parse, persist,
  and a fallback so it works without deploy.
- **Added:** `programs/application/ai_program_service.dart` — `GenerationRequest`,
  `AiProgramService.generate` (injectable Cloud Function caller; parses the
  response resolving movement names from the library + dropping unknown ids;
  `usedFallback` flag), pure `fallbackProgram` (preset matching daysPerWeek →
  Foundations, renamed). `programs/data/user_program_repository.dart`
  (`saveProgram` + `watch` `users/{uid}/programs`, `userProgramsProvider`).
  **activeProgramProvider now resolves presets + user programs.** Fakes added.
- **Tests:** fallback mapping (days-match / no-match), generate (valid parse +
  name resolve + unknown-id drop), error→fallback, empty-days→fallback. 65/65 pass.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 65/65 pass.

## 2026-06-02 — M5 T19 generateProgram Cloud Function [branch feat/calistrack-m5-t19-generate-function]
- **Task:** server-side AI program generation (OpenAI), deploy-ready.
- **Added:** `functions/` (TS) — `generateProgram` onCall: validates the request,
  prompts OpenAI (`gpt-4o-mini`) for strict-JSON, **sanitizes** the output
  server-side (only known exerciseIds, ≥1 day, sane sets) and returns a
  Program-shaped object. Key read from a Firebase **secret** `OPENAI_API_KEY`
  (never in client/repo). `functions/{package.json,tsconfig.json,README.md,
  .gitignore}` + root `firebase.json`. **Not deployed** (needs owner's Firebase
  + key — see functions/README.md); the client (T20) is fallback-first so the
  feature works meanwhile.
- **Verified:** Flutter package unaffected (analyze clean, smoke green); secret
  scan finds no committed key. (Node function not exercised by the Flutter CI.)

## 2026-06-02 — M4 T18 Skills screen [branch feat/calistrack-m4-t18-skills-screen]
- **Task:** browse skill progressions, log step attempts, advance the ladder.
- **Added:** `features/skills/presentation/skills_screen.dart` (list with
  completion bars + next step, replaces placeholder), `skill_detail_screen.dart`
  (step ladder done/current/locked, keyed per-step logger for reps/hold,
  mark-complete + step-back), `application/skill_providers.dart`
  (`SkillController` log/setStep). Router: nested `/skills/:skillId`. Preview
  extended with an in-memory `_PreviewSkills` (seeded Front Lever 25% / Pistol
  50%) so the tab renders without Firebase.
- **Tests:** list renders both skills; detail opens → logs an attempt
  (logCalls + saved logs) → advances the step (setStepCalls + index).
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 58/58 pass
  · Progress + Skills screenshotted from the preview.

## 2026-06-02 — M4 T17 Skill trees + SkillRepository [branch feat/calistrack-m4-t17-skills-repo]
- **Task:** preset skill progressions + a repo that merges them with saved progress.
- **Added:** `assets/data/skills.json` — 5 trees (Muscle-up / Front Lever /
  Planche / Handstand / Pistol Squat), each step with exactly one target
  (reps or hold). `features/skills/data/skill_repository.dart` — `SkillRepository`
  (presets from assets, `watch(uid)` merging saved `users/{uid}/skills` progress,
  `logAttempt` via arrayUnion, `setStep`), pure `mergeSkills()` overlay,
  `skillRepositoryProvider` + `userSkillsProvider`. `FakeSkillRepository` added.
- **Tests:** preset parse + integrity (5 skills, unique step ids, exactly-one-
  target per step, start at step 0), `mergeSkills` overlay.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 56/56 pass.

## 2026-06-02 — M4 T16 Progress screen + fl_chart [branch feat/calistrack-m4-t16-progress-screen]
- **Task:** turn aggregated history into a visual Progress tab.
- **Added:** `features/progress/presentation/progress_screen.dart` — overall
  stats card (streak / this-week / workouts / volume), a history-only exercise
  picker (ChoiceChips), and a **type-aware fl_chart line chart**
  (volume / best-hold / distance / sets) with empty + "<2 points" states.
  Replaces the placeholder (router unchanged — same class).
- **Preview:** `lib/preview.dart` seeded with 3 prior Push sessions so charts +
  the "last time" reference both render.
- **Tests:** empty state + chart renders (stats card, picker name, metric label,
  `LineChart`) for an exercise with history.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 50/50 pass.

## 2026-06-02 — M4 T15 Progress repository [branch feat/calistrack-m4-t15-progress-repo]
- **Task:** aggregate logged workouts into progress insight.
- **Added:** `features/progress/data/progress_repository.dart` — pure
  `exerciseHistory()` (chart-ready per-exercise series: reps/volume/top-weight/
  best-hold/distance, oldest→newest) + `overallStats()` (totals, this-week,
  consecutive-day streak ending today/yesterday). `ProgressRepository` wraps
  `WorkoutRepository.recent`; providers `overallStatsProvider`,
  `exercisesWithHistoryProvider`, `exerciseHistoryProvider.family`.
- **Tests:** pure aggregation (history ordering + aggregates, cardio distance),
  stats + streak edge cases (empty / today-yesterday / gap / stale), and the
  repo wired to a fake. M4 design spec committed.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 47/47 pass.

## 2026-06-01 — M3 T13+T14 Today + session engine + set logging [branch feat/calistrack-m3-t13-today-logging]
- **Task:** the core loop — pick a program day, log sets, finish to a summary.
- **Data:** `features/workout/data/workout_repository.dart` (save + recent +
  `lastSetsFor` for the "last time" reference), `training_defaults.dart` +
  `assets/data/training_defaults.json` (rest-by-type, no magic numbers).
- **Engine:** `features/workout/application/workout_session.dart` — immutable
  `WorkoutSession` (completion% + volume + `toWorkout`) and a **keepAlive**
  `WorkoutSessionController` (startDay/logSet/removeSet/finish→persist).
  `lastSetsForProvider` family. Reintroduced `activeProgramProvider` (now
  **awaits** the profile, fixing a flash-of-empty-state).
- **UI:** `today_screen.dart` (empty state → day-picker chips → live header
  (progress + volume) → finish), `widgets/exercise_logger_card.dart` (per-set
  steppers for reps/weight/hold/distance/duration, logged chips, last-time ref,
  post-set rest countdown), `session_summary.dart` (completion dialog).
- **Preview:** `lib/preview.dart` — fake-backed entrypoint
  (`flutter run -t lib/preview.dart`) that boots into a seeded Push session, so
  the authed UI is runnable/screenshottable without Firebase.
- **Tests:** session-engine logic (log/edit/finish/volume/completion/toWorkout)
  + Today widget flow (pick day → log → finish → summary) + empty state; smoke
  & splash tests updated for the real Today screen.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 35/35 pass
  · preview web build screenshotted (logging UX).

## 2026-06-01 — M3 T12 Programs screen [branch feat/calistrack-m3-t12-programs-screen]
- **Task:** browse presets, open a program's day/movement breakdown, set it active.
- **Added:** `programs/presentation/programs_screen.dart` (real list, replaces
  placeholder), `program_detail_screen.dart` (days + targets + set-active +
  active footer), `widgets/program_card.dart`, `program_format.dart`
  (`targetSummary` — reps/hold/distance/duration). State:
  `profile/application/profile_providers.dart` (`currentUserProfileProvider`),
  `programs/application/program_providers.dart` (`activeProgramProvider`,
  `ActiveProgramController.setActive`). `UserRepository.setActiveProgram` (merge
  write) + fake updated to a live broadcast stream. Router: nested
  `/programs/:programId` detail route.
- **Tests:** new widget test pumps the app → Programs → detail → Set as active →
  asserts persistence + active footer. Smoke test updated for the real screen.
- **Note:** in-app screens are auth-gated; live screenshots await Firebase config
  or a preview mode (planned for T13/T14).
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 27/27 pass.

## 2026-06-01 — M3 T11 Programs repo + presets [branch feat/calistrack-m3-t11-programs-repo]
- **Task:** preset programs + ProgramRepository, plus a backward-compatible
  cardio model extension so a Run day logs end-to-end.
- **Models:** `LoggedSet` += `distanceMeters?` / `durationSeconds?`;
  `ProgramExercise` += `targetDistanceMeters?` / `targetDurationSeconds?` (all
  nullable + conditional JSON → legacy docs still parse).
- **Added:** `assets/data/programs.json` — 4 presets (Classic PPL · PPL + Core ·
  Foundations · Hybrid w/ a Run day), storing ids + targets only with names
  resolved from the library. `features/programs/data/program_repository.dart`
  (`presets(library)` resolves names, throws on unknown ids) with
  `programRepositoryProvider` + `presetProgramsProvider`.
- **Tests:** model round-trip + legacy-parse for the new fields; ProgramRepository
  preset parse, **preset-integrity** (every exerciseId resolves in the library),
  cardio-target presence, and a `StateError` on an unknown id.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 26/26 pass.

## 2026-06-01 — M3 T10 Exercise library repo [branch feat/calistrack-m3-t10-exercise-repo]
- **Task:** ExerciseRepository — load the bundled movement library from assets.
- **Added:** `features/exercises/data/exercise_repository.dart` (injectable
  `AssetBundle`, in-memory cache, `all()` + `byId()`) with
  `exerciseRepositoryProvider` + `exerciseLibraryProvider`. Tests:
  `test/features/exercises/exercise_repository_test.dart` — real-asset load
  (19 unique, well-formed movements), `byId` hit/miss, cache identity, and an
  injected-fixture parse proving the loader is unit-testable.
- **Also:** corrected the design spec's library count (18 → 19).
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 18/18 pass.

## 2026-06-01 — M2 Auth (T6–T9) [branch feat/calistrack-m2-auth]
- **Task:** Firebase-backed auth — email + Google sign-in, gated routing,
  profile bootstrap.
- **Changed:** `core/providers/firebase_providers.dart`,
  `features/auth/data/auth_repository.dart` (+`authStateProvider`),
  `features/profile/data/user_repository.dart` (`ensureProfile` = T9),
  `features/auth/application/auth_controller.dart`,
  `features/auth/presentation/{login,register}_screen.dart` + `auth_form_fields`,
  `core/router/app_router.dart` → `goRouterProvider` w/ auth gate,
  `app.dart` → ConsumerWidget, `features/profile/presentation/profile_screen.dart`.
  Tests: `auth_controller_test`, `login_screen_test`, updated `app_smoke_test`,
  `test/support/fakes.dart`.
- **Process note:** code-signing only works from the main checkout, not linked
  worktrees — so milestones are developed in the main checkout on feature
  branches (worktree commit attempts fail signing). Lost the first worktree copy
  to a bad `worktree remove` and recreated it here.
- **Verified locally (Flutter 3.44.0):** format clean · analyze clean · 13/13 pass.

## 2026-06-01 — Local Flutter toolchain + verified-green M1
- Installed **Flutter 3.44.0 stable** in the session container (network policy
  allows storage.googleapis.com), ending blind CI iteration. All future
  milestones are now verified locally (`dart format`, `flutter analyze`,
  `flutter test`) before pushing.
- Ran the real gates on the branch and fixed the last issues definitively:
  - `flutter analyze` → removed `unnecessary_import` (foundation in main.dart)
    and `unused_import` (material in app_smoke_test) → **No issues found**.
  - `dart format` (3.44 "tall" style) reformatted `firebase_options.dart` and
    `exercise.dart` → **clean**.
  - `flutter test` → **8/8 passed**.
- M1 is functionally complete pending the CI mirror going green.

## 2026-06-01 — M1 review + CI fix
- **Review:** Fresh zero-context agent audited the M1 diff against the CI gates
  (`dart format`, `flutter analyze`, `flutter test`).
- **Findings & resolution:**
  - Two `dart format` wraps (`models_test.dart` SkillLog, `app_smoke_test.dart`
    for-loop) → pre-wrapped to match `dart format` output.
  - One `require_trailing_commas` lint (`models_test.dart` ProgramDay) → fixed.
  - Agent also flagged `Color.withValues`/`CardThemeData` as "3.22 blockers".
    **Overridden:** CI runs *latest stable* Flutter (≥3.27) where these are the
    correct, non-deprecated APIs; switching to `withOpacity`/`CardTheme` would
    fail analyze on deprecation infos. Instead bumped pubspec floor to
    flutter ≥3.27 / Dart ≥3.6 so the manifest matches the APIs used.
  - Removed unused codegen dev-deps (build_runner/riverpod_generator/
    hive_generator) + riverpod_annotation to avoid `analyzer` resolution
    conflicts on latest stable; they return when codegen is actually used.
- **Result:** Pending CI re-run on PR #64.

## 2026-06-01 — T1–T5 Foundation (M1)
- **Task:** Bootstrap the CalisTrack Flutter project (scaffold, theme, router, models, CI).
- **Changed:**
  - `calistrack/pubspec.yaml`, `analysis_options.yaml`, `.gitignore`
  - `lib/main.dart`, `lib/app.dart`
  - `lib/core/theme/app_theme.dart` — Material 3 dark-first theme + tokens
  - `lib/core/router/app_router.dart` — go_router + bottom-nav shell
  - `lib/models/{app_user,program,workout,skill_progress,exercise}.dart` — JSON models
  - `lib/features/*/presentation/*_screen.dart` — five shell screens
  - `test/models/*_test.dart` — model round-trip tests
  - `.github/workflows/calistrack-ci.yml` — analyze + test gate
- **Result:** Scaffold compiles to a navigable 5-tab shell (pending CI confirmation — no local Flutter SDK in the build container, so `flutter analyze`/`test` run in CI).
- **Next:** M2 Auth (T6–T9).
